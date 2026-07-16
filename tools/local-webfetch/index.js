#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { EnvHttpProxyAgent } from "undici"
import TurndownService from "turndown"
import { z } from "zod"
import { readFileSync } from "node:fs"
import {
  DEFAULT_TIMEOUT_SEC,
  MAX_TIMEOUT_SEC,
  buildUntrustedToolContent,
  createPinnedLookup,
  fetchUrlBytes,
} from "./fetch-core.js"

const packageJson = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf-8"))
const nodeVersion = process.versions.node.split(".").map((part) => Number.parseInt(part, 10))
const [nodeMajor = 0, nodeMinor = 0] = nodeVersion
if (nodeMajor < 22 || (nodeMajor === 22 && nodeMinor < 19) || nodeMajor >= 25) {
  throw new Error(`local-webfetch requires Node.js >=22.19.0 and <25.0.0; current version is ${process.versions.node}`)
}

function createRequestDispatcher({ hostname, addresses }) {
  return new EnvHttpProxyAgent({
    connect: {
      lookup: createPinnedLookup({ hostname, addresses }),
    },
  })
}

const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"

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

const server = new McpServer({ name: "local-webfetch", version: packageJson.version })

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
      const timeoutMs = (timeout ?? DEFAULT_TIMEOUT_SEC) * 1000
      const result = await fetchUrlBytes(url, {
        timeoutMs,
        dispatcherFactory: createRequestDispatcher,
        headers: {
          "User-Agent": BROWSER_USER_AGENT,
          Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,text/plain;q=0.8,*/*;q=0.5",
          "Accept-Language": "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7",
        },
      })

      const contentType = result.response.headers.get("content-type") || ""
      const isHtml = contentType.includes("text/html") || contentType.includes("application/xhtml")
      const rawText = new TextDecoder("utf-8").decode(result.bytes)

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
        content: buildUntrustedToolContent({
          requestedUrl: url,
          finalUrl: result.finalUrl,
          contentType,
          output,
        }),
      }
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Fetch failed: ${err instanceof Error ? err.message : String(err)}` }],
      }
    }
  },
)

const transport = new StdioServerTransport()
await server.connect(transport)
