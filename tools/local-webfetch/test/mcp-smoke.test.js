import test from "node:test"
import assert from "node:assert/strict"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { Client } from "@modelcontextprotocol/sdk/client/index.js"
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js"

const packageRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)))

test("MCP stdio server starts and exposes only the fetch tool", { timeout: 10_000 }, async () => {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [path.join(packageRoot, "index.js")],
    cwd: packageRoot,
    stderr: "pipe",
  })
  const client = new Client({ name: "local-webfetch-test", version: "1.0.0" })
  try {
    await client.connect(transport)
    const result = await client.listTools()
    assert.deepEqual(result.tools.map((tool) => tool.name), ["fetch"])
    const blocked = await client.callTool({
      name: "fetch",
      arguments: { url: "http://127.0.0.1/private" },
    })
    assert.equal(blocked.isError, true)
    assert.match(blocked.content[0].text, /Blocked private, local, or reserved IP/)
  } finally {
    await client.close()
  }
})
