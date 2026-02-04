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
│       │                           gemini -p                      │
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

### 1. Gemini CLI Configuration (`gemini/`)

Use the existing Gemini CLI (already installed at `/Users/aleksituominen/.nvm/versions/node/v24.12.0/bin/gemini`).

**Existing Directory Structure:**
```
gemini/
├── oauth_creds.json     # OAuth credentials (existing)
├── settings.json        # Auth settings (existing)
├── google_accounts.json # Account info (existing)
├── AGENTS.md            # Instructions for Gemini (NEW)
└── config.toml          # Model defaults (NEW - optional)
```

**CLI Interface (existing commands):**
```bash
# Non-interactive query
gemini -p "Analyze these logs for error patterns..."

# Large input via stdin (pipe content before -p flag)
cat large.log | gemini -p "Analyze these logs..."

# Model selection
gemini -m gemini-2.0-flash -p "Quick synthesis..."
gemini -m gemini-2.5-pro -p "Deep analysis..."

# Read-only mode (no file modifications by Gemini)
gemini --approval-mode plan -p "Review this code..."

# Note: Multimodal (images) uses Gemini API directly, not CLI
# See gemini-ui-debugger agent for implementation
```

**Key Differences from Codex:**
| Codex CLI | Gemini CLI |
|-----------|------------|
| `codex exec -s read-only "..."` | `gemini --approval-mode plan -p "..."` |
| Inline prompt | `-p` flag for prompt |
| N/A | Native stdin support (pipe before command) |

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
3. If > 100K tokens → invoke `cat logs | gemini -p` with full log content
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
3. Invoke Gemini API via curl with base64-encoded images
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
4. Invoke `gemini -m gemini-2.0-flash -p` to synthesize results
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
3. Both images → Gemini API via curl (multimodal)

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
│ - gemini -p         │
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
│ - Gemini API (curl)     │
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
│ - gemini -m flash -p    │
│ - Synthesize + cite     │
└─────────┬───────────────┘
          │
          ▼
   Research findings + sources
```

## Configuration

### gemini/AGENTS.md (NEW)

Instructions for Gemini when invoked by Claude Code agents:

```markdown
# Gemini — Specialized Analysis Agent

You are invoked by Claude Code for tasks requiring:
- Large context analysis (up to 2M tokens)
- Multimodal understanding (images)
- Fast synthesis (Flash model)

## Output Format

Provide structured, actionable output. Include:
- Clear findings with specifics
- Severity/priority where applicable
- Actionable recommendations

## Boundaries

- Analysis and synthesis only
- No code generation unless specifically requested
- No file modifications
```

### Model Selection

| Use Case | Model | Flag |
|----------|-------|------|
| Log analysis | gemini-2.5-pro | `-m gemini-2.5-pro` |
| UI comparison | gemini-2.5-pro | `-m gemini-2.5-pro` |
| Web search synthesis | gemini-2.0-flash | `-m gemini-2.0-flash` |

### Environment

```bash
export GEMINI_API_KEY="..."
```

## Error Handling

| Scenario | Handling |
|----------|----------|
| API key missing | Error with setup instructions |
| Rate limit (429) | Retry with exponential backoff |
| HTTP error (non-2xx) | Log status code, extract error message from response, exit 1 |
| Network timeout | curl with `--max-time 60`, report timeout and retry once |
| Invalid JSON response | Check `jq -e` exit code, report parse failure |
| `jq` not available | Fallback to grep-based extraction or error with install instructions |
| Empty candidates array | Report "No response generated", suggest prompt adjustment |
| Context overflow | Truncate with warning, suggest chunking |
| Image too large | Resize before sending (max 4MB per image) |
| Figma fetch fails | Fall back to user-provided screenshot only |

## Security Considerations

- API key stored in environment, never in config files
- No sensitive data in prompts (sanitize if needed)
- **Gemini is read-only:** Uses `--approval-mode plan` for CLI, API calls are analysis only
- **Agents can write reports:** The wrapper agents (Haiku) write findings to disk; Gemini does analysis only
- Images processed locally, not stored remotely beyond API call

## Runtime Requirements

- `gemini` CLI available in PATH
- `GEMINI_API_KEY` environment variable set (for multimodal API calls)
- `jq` available for JSON parsing (gemini-ui-debugger)
- `base64` with `-b 0` flag support (macOS) or `tr -d '\n'` fallback (Linux)
