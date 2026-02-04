# Gemini Integration Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Claude Code (Orchestrator)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  skill-eval.sh ──auto-suggest──► gemini-web-search              │
│                                                                  │
│  User request ──────────────────► gemini-log-analyzer           │
│       │                                  │                       │
│       │                                  ▼                       │
│       │                           gemini exec                    │
│       │                                  │                       │
│       ▼                                  ▼                       │
│  gemini-ui-debugger              Gemini API                     │
│       │                                                          │
│       ├──► Chrome DevTools MCP (screenshots)                    │
│       └──► Figma MCP (designs)                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. Gemini CLI Wrapper (`gemini-cli/`)

Mirror the Codex CLI pattern for consistency.

**Note:** Using `gemini-cli/` to avoid collision with existing `gemini/` directory (contains Google CLI OAuth credentials).

**Directory Structure:**
```
gemini-cli/
├── config.toml          # Model configuration
├── AGENTS.md            # Instructions for Gemini
└── bin/
    └── gemini-cli       # CLI entry point (shell script)
```

**CLI Interface:**
```bash
# Text-only query (prompt as argument)
gemini-cli exec "Analyze these logs for error patterns..."

# Large input via stdin (REQUIRED for logs > 100KB to avoid shell arg limits)
cat large.log | gemini-cli exec --stdin "Analyze these logs..."

# Large input via file reference
gemini-cli exec --file /path/to/large.log "Analyze these logs..."

# With image input (single)
gemini-cli exec --image /path/to/screenshot.png "Describe this image..."

# With multiple images (for comparison)
gemini-cli exec --image /path/to/img1.png --image /path/to/img2.png "Compare these images..."

# Model selection
gemini-cli exec --model flash "Quick synthesis of search results..."
```

**Input Handling (Critical for Large Logs):**
- Shell argument limit is ~256KB on macOS
- For inputs > 100KB: MUST use `--stdin` or `--file` flag
- CLI reads from stdin when `--stdin` flag present
- Images are base64-encoded internally, max 20MB per image (Gemini limit)

**Implementation:** Shell script wrapping `curl` to Gemini API. Handles stdin/file input, base64 encoding for images, and model selection.

### 2. Agent Definitions (`claude/agents/`)

#### gemini-log-analyzer.md

```yaml
---
name: gemini-log-analyzer
description: "Large-scale log analysis using Gemini's 2M token context. Use for logs exceeding 100K tokens."
model: haiku
tools: Bash, Glob, Grep, Read, Write
color: green
---
```

**Behavior:**
1. Estimate log size (line count × avg line length)
2. If < 100K tokens → delegate to standard log-analyzer
3. If > 100K tokens → invoke `gemini exec` with full log content
4. Write findings to `~/.claude/logs/{identifier}.md`

#### gemini-ui-debugger.md

```yaml
---
name: gemini-ui-debugger
description: "Compare screenshots to Figma designs using Gemini's multimodal capabilities."
model: haiku
tools: Bash, Read, Write, mcp__figma__*, mcp__chrome-devtools__*
color: purple
---
```

**Behavior:**
1. Capture screenshot via Chrome DevTools MCP (or accept file path)
2. Fetch Figma design via Figma MCP
3. Invoke `gemini exec --image` with both images
4. Parse findings into structured format
5. Return discrepancy report

#### gemini-web-search.md

```yaml
---
name: gemini-web-search
description: "Research agent that searches the web and synthesizes findings using Gemini."
model: haiku
tools: WebSearch, WebFetch, Read, Write
color: cyan
---
```

**Behavior:**
1. Formulate search queries from user question
2. Execute WebSearch tool
3. Optionally fetch full pages via WebFetch for deeper context
4. Invoke `gemini exec --model flash` to synthesize results
5. Return structured findings with source citations

### 3. skill-eval.sh Updates

Add auto-suggest pattern for web search:

```bash
# Web search triggers
elif echo "$PROMPT_LOWER" | grep -qE '\bresearch\b|\blook up\b|\bfind out\b|\bwhat is the (latest|current)\b|\bhow do (i|we|you)\b.*\b(in 2026|nowadays|currently)\b|\bsearch for\b'; then
  SUGGESTION="RECOMMENDED: Use gemini-web-search agent for research queries."
  PRIORITY="should"
```

### 4. MCP Integration

**Chrome DevTools MCP** (existing):
- `mcp__chrome-devtools__take_screenshot` - Capture current page
- `mcp__chrome-devtools__take_snapshot` - Get accessibility tree

**Figma MCP** (existing):
- `mcp__figma__get_figma_data` - Fetch design data
- `mcp__figma__download_figma_images` - Download design as image

**Usage in gemini-ui-debugger:**
1. Screenshot → save to temp file
2. Figma design → download to temp file
3. Both images → `gemini exec --image`

## Data Flow

### Log Analysis Flow

```
User: "Analyze these production logs"
         │
         ▼
┌─────────────────────┐
│ Main Agent          │
│ - Estimate log size │
│ - > 100K tokens?    │
└─────────┬───────────┘
          │ Yes
          ▼
┌─────────────────────┐
│ gemini-log-analyzer │
│ - Read log files    │
│ - gemini exec       │
│ - Write findings    │
└─────────┬───────────┘
          │
          ▼
   Findings file + summary
```

### UI Debugging Flow

```
User: "Compare my implementation to the Figma design"
         │
         ▼
┌─────────────────────────┐
│ Main Agent              │
│ - Spawn gemini-ui-debug │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│ gemini-ui-debugger      │
│ - Screenshot (DevTools) │
│ - Figma design (MCP)    │
│ - gemini exec --image   │
│ - Parse findings        │
└─────────┬───────────────┘
          │
          ▼
   Discrepancy report with fixes
```

### Web Search Flow

```
User: "What's the best practice for X in 2026?"
         │
         ▼
┌─────────────────────────┐
│ skill-eval.sh           │
│ "RECOMMENDED: web-search│
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│ gemini-web-search       │
│ - WebSearch queries     │
│ - Optional WebFetch     │
│ - gemini exec --flash   │
│ - Synthesize + cite     │
└─────────┬───────────────┘
          │
          ▼
   Research findings + sources
```

## Configuration

### gemini-cli/config.toml

```toml
# Gemini CLI Configuration

[api]
# API key loaded from environment: GEMINI_API_KEY
endpoint = "https://generativelanguage.googleapis.com/v1beta"

[models]
default = "gemini-1.5-pro-latest"
fast = "gemini-1.5-flash-latest"

[limits]
max_input_tokens = 2000000
max_output_tokens = 8192
max_image_size_mb = 20
max_images = 4

[input]
# Use stdin or file for inputs > 100KB to avoid shell arg limits
large_input_threshold_kb = 100

[features]
multimodal = true
```

### Environment

```bash
export GEMINI_API_KEY="..."
```

## Error Handling

| Scenario | Handling |
|----------|----------|
| API key missing | Error with setup instructions |
| Rate limit | Retry with exponential backoff |
| Context overflow | Truncate with warning, suggest chunking |
| Image too large | Resize before sending |
| Figma fetch fails | Fall back to user-provided screenshot only |

## Security Considerations

- API key stored in environment, never in config files
- No sensitive data in prompts (sanitize if needed)
- Read-only operations only (no file modifications via Gemini)
- Images processed locally, not stored remotely beyond API call
