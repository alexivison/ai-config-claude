# TASK0: Gemini CLI Wrapper Infrastructure

**Issue:** gemini-integration-cli

## Objective

Create the Gemini CLI wrapper that all agents will use to invoke Gemini API.

## Required Context

Read these files first:
- `codex/config.toml` — Reference for configuration pattern
- `codex/AGENTS.md` — Reference for instructions pattern
- `gemini/` — Existing directory (Google CLI OAuth creds) — DO NOT MODIFY

## Files to Create

| File | Purpose |
|------|---------|
| `gemini-cli/config.toml` | Model and API configuration |
| `gemini-cli/AGENTS.md` | Instructions for Gemini (general guidance) |
| `gemini-cli/bin/gemini-cli` | CLI entry point (executable shell script) |
| `.gitignore` (update) | Add Gemini CLI cache exclusions |

**Note:** Using `gemini-cli/` to avoid collision with existing `gemini/` directory.

## Implementation Details

### gemini-cli/config.toml

```toml
# Gemini CLI Configuration

[api]
endpoint = "https://generativelanguage.googleapis.com/v1beta"
# API key loaded from environment: GEMINI_API_KEY

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
```

### gemini-cli/bin/gemini-cli

Shell script that:
1. Loads config from `gemini-cli/config.toml`
2. Reads `GEMINI_API_KEY` from environment
3. Accepts subcommands: `exec`
4. Supports options: `--model`, `--image`, `--stdin`, `--file`
5. Handles large input via stdin or file (CRITICAL for logs > 100KB)
6. Base64-encodes images for multimodal requests
7. Calls Gemini API via `curl`
8. Outputs response to stdout

**CLI Interface:**
```bash
# Basic usage (prompt as argument)
gemini-cli exec "prompt text"

# Model selection
gemini-cli exec --model flash "prompt text"

# Single image
gemini-cli exec --image /path/to/image.png "prompt text"

# Multiple images (for comparison)
gemini-cli exec --image img1.png --image img2.png "Compare these images"

# Large input via stdin (REQUIRED for inputs > 100KB)
cat large.log | gemini-cli exec --stdin "Analyze these logs..."

# Large input via file reference
gemini-cli exec --file /path/to/large.log "Analyze these logs..."
```

**Input Handling:**
- Shell argument limit is ~256KB on macOS
- For inputs > 100KB: MUST use `--stdin` or `--file`
- `--stdin`: Read content from stdin, append to prompt
- `--file`: Read content from specified file, append to prompt
- Images: Base64-encode, include as inline_data in API request

### gemini-cli/AGENTS.md

General instructions for Gemini when invoked. Keep minimal — specific behavior defined in Claude agent definitions.

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

## Verification

```bash
# Check script is executable
ls -la gemini-cli/bin/gemini-cli

# Test basic invocation (requires API key)
GEMINI_API_KEY=test gemini-cli exec "Hello" 2>&1 | head -5

# Verify config parsing
grep -q "gemini-1.5-pro" gemini-cli/config.toml && echo "Config OK"

# Test stdin handling
echo "test content" | gemini-cli exec --stdin "Echo this:" 2>&1 | head -5

# Test error on missing API key
unset GEMINI_API_KEY && gemini-cli exec "test" 2>&1 | grep -q "GEMINI_API_KEY" && echo "Error handling OK"
```

## Acceptance Criteria

- [ ] `gemini-cli/config.toml` created with model configuration
- [ ] `gemini-cli/AGENTS.md` created with general instructions
- [ ] `gemini-cli/bin/gemini-cli` is executable and handles `exec` subcommand
- [ ] CLI supports `--model` option for model selection
- [ ] CLI supports `--image` option (single and repeated for multiple images)
- [ ] CLI supports `--stdin` for reading large input from stdin
- [ ] CLI supports `--file` for reading large input from file
- [ ] Images are base64-encoded before API call
- [ ] `.gitignore` updated with Gemini CLI cache patterns
- [ ] Error message shown when `GEMINI_API_KEY` not set
- [ ] Existing `gemini/` directory NOT modified
