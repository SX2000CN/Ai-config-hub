#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { EnvHttpProxyAgent, setGlobalDispatcher } from "undici"
import { lookup } from "node:dns/promises"
import TurndownService from "turndown"
import { z } from "zod"

// Node's global fetch does not read HTTP_PROXY/HTTPS_PROXY by itself.
// This makes it honor those env vars when set; VPN/system-routed traffic
// works regardless since that happens below the application layer.
setGlobalDispatcher(new EnvHttpProxyAgent())

const MAX_RESPONSE_SIZE = 5 * 1024 * 1024 // 5MB
const DEFAULT_TIMEOUT_SEC = 30
const MAX_TIMEOUT_SEC = 120

const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"

const BLOCKED_HOSTNAMES = new Set(["metadata.google.internal", "metadata.goog", "kubernetes.default.svc", "localhost"])

function ip4ToInt(ip) {
  const parts = ip.split(".")
  return ((+parts[0] << 24) | (+parts[1] << 16) | (+parts[2] << 8) | +parts[3]) >>> 0
}

const BLOCKED_IPV4_RANGES = [
  [ip4ToInt("127.0.0.0"), ip4ToInt("127.255.255.255")], // loopback
  [ip4ToInt("10.0.0.0"), ip4ToInt("10.255.255.255")], // private class A
  [ip4ToInt("172.16.0.0"), ip4ToInt("172.31.255.255")], // private class B
  [ip4ToInt("192.168.0.0"), ip4ToInt("192.168.255.255")], // private class C
  [ip4ToInt("169.254.0.0"), ip4ToInt("169.254.255.255")], // link-local / cloud metadata
]

function isBlockedIPv4(ip) {
  const n = ip4ToInt(ip)
  return BLOCKED_IPV4_RANGES.some(([start, end]) => n >= start && n <= end)
}

async function assertSafeUrl(urlString) {
  const parsed = new URL(urlString)
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error(`Blocked protocol "${parsed.protocol}" — only http/https allowed`)
  }
  const hostname = parsed.hostname.replace(/^\[|\]$/g, "")
  if (BLOCKED_HOSTNAMES.has(hostname.toLowerCase())) {
    throw new Error(`Blocked hostname "${hostname}"`)
  }
  if (/^\d+\.\d+\.\d+\.\d+$/.test(hostname)) {
    if (isBlockedIPv4(hostname)) throw new Error(`Blocked private/internal IP "${hostname}"`)
    return
  }
  try {
    const { address, family } = await lookup(hostname)
    if (family === 4 && isBlockedIPv4(address)) {
      throw new Error(`Hostname "${hostname}" resolves to blocked IP "${address}"`)
    }
  } catch (e) {
    if (e.message?.startsWith("Blocked") || e.message?.startsWith("Hostname")) throw e
    // DNS lookup failure: let the actual fetch surface the real network error instead of masking it here.
  }
}

const turndown = new TurndownService({
  headingStyle: "atx",
  hr: "---",
  bulletListMarker: "-",
  codeBlockStyle: "fenced",
  emDelimiter: "*",
})
turndown.remove(["script", "style", "meta", "link", "noscript"])

function htmlToPlainText(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/[ \t]+/g, " ")
    .replace(/\n\s*\n+/g, "\n\n")
    .trim()
}

const server = new McpServer({ name: "local-webfetch", version: "1.0.0" })

server.registerTool(
  "fetch",
  {
    title: "Fetch URL (local network)",
    description:
      "Fetches a URL using this machine's own network stack, so it honors HTTP_PROXY/HTTPS_PROXY env vars and VPN routing. Use this when the built-in WebFetch tool fails or is blocked, since that one runs cloud-side and ignores local proxy/VPN settings.",
    inputSchema: {
      url: z.string().describe("The URL to fetch (must start with http:// or https://)"),
      format: z.enum(["markdown", "text", "html"]).default("markdown").describe("Output format for HTML content"),
      timeout: z.number().int().positive().max(MAX_TIMEOUT_SEC).optional().describe(`Timeout in seconds (max ${MAX_TIMEOUT_SEC}, default ${DEFAULT_TIMEOUT_SEC})`),
    },
  },
  async ({ url, format, timeout }) => {
    try {
      if (!url.startsWith("http://") && !url.startsWith("https://")) {
        throw new Error("URL must start with http:// or https://")
      }
      await assertSafeUrl(url)

      const timeoutMs = (timeout ?? DEFAULT_TIMEOUT_SEC) * 1000
      const controller = new AbortController()
      const timer = setTimeout(() => controller.abort(), timeoutMs)

      let response
      try {
        response = await fetch(url, {
          signal: controller.signal,
          redirect: "follow",
          headers: {
            "User-Agent": BROWSER_USER_AGENT,
            Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,text/plain;q=0.8,*/*;q=0.5",
            "Accept-Language": "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7",
          },
        })
      } finally {
        clearTimeout(timer)
      }

      // If a redirect landed on a different host, re-validate the final URL.
      if (response.url && response.url !== url) {
        await assertSafeUrl(response.url)
      }

      if (!response.ok) {
        throw new Error(`Request failed: ${response.status} ${response.statusText}`)
      }

      const contentLength = response.headers.get("content-length")
      if (contentLength && parseInt(contentLength, 10) > MAX_RESPONSE_SIZE) {
        throw new Error(`Response too large (Content-Length exceeds ${MAX_RESPONSE_SIZE / 1024 / 1024}MB limit)`)
      }

      const buffer = await response.arrayBuffer()
      if (buffer.byteLength > MAX_RESPONSE_SIZE) {
        throw new Error(`Response too large (exceeds ${MAX_RESPONSE_SIZE / 1024 / 1024}MB limit)`)
      }

      const contentType = response.headers.get("content-type") || ""
      const isHtml = contentType.includes("text/html") || contentType.includes("application/xhtml")
      const rawText = new TextDecoder("utf-8").decode(buffer)

      let output
      if (isHtml && format === "markdown") {
        output = turndown.turndown(rawText)
      } else if (isHtml && format === "text") {
        output = htmlToPlainText(rawText)
      } else {
        // format === "html", or content wasn't HTML to begin with — return as-is.
        output = rawText
      }

      return {
        content: [
          {
            type: "text",
            text: `Fetched ${url} (${contentType || "unknown content-type"})\n\n${output}`,
          },
        ],
      }
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Fetch failed: ${err.message}` }],
      }
    }
  },
)

const transport = new StdioServerTransport()
await server.connect(transport)
