## About Obsidian MCP Server

The Obsidian MCP Server is a Model Context Protocol server that lets Large Language Models interact with an
[Obsidian](https://obsidian.md/) vault. It talks to Obsidian through the
[Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) community plugin, exposing your notes to MCP
clients such as Claude Desktop for reading, searching, and editing.

The server provides tools that can:

- List files and directories in a vault
- Read the contents of one or more notes
- Search across the vault, including complex queries and tag search
- Append, patch, replace, and delete note content
- Read frontmatter and recent or periodic notes

### Key Features

- **Vault access over a stable API**: Reads and writes go through the Obsidian Local REST API plugin rather than
  touching vault files directly
- **Search and retrieval**: Simple text search, complex queries, and tag-based lookups for grounding LLM responses in
  your own notes
- **Note editing**: Append, patch, and replace operations let assistants update notes as part of a workflow
- **Periodic notes**: Tools for daily and other periodic notes, plus recent-changes queries

### Use Cases

- Knowledge-base question answering grounded in a personal or team vault
- Note-taking and journaling assistants that read and write Obsidian notes
- Research workflows that search and summarize existing notes
- Automated capture of meeting notes, tasks, and references

For more details, see the [official documentation](https://github.com/MarkusPfundstein/mcp-obsidian).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. Obsidian is a trademark of Dynalist Inc. All other third-party product names, logos,
and trademarks are the property of their respective owners and are used solely for identification. Docker claims no
interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
