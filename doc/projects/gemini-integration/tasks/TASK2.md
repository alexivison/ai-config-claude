# TASK2: gemini-ui-debugger Agent

**Issue:** gemini-integration-ui-debugger
**Depends on:** TASK0

## Objective

Create an agent that uses Gemini's multimodal capabilities to compare browser screenshots against Figma designs.

## Required Context

Read these files first:
- `claude/agents/codex.md` — Agent definition pattern
- `gemini/AGENTS.md` — Gemini instructions (from TASK0)
- Check available MCP tools: `mcp__figma__*`, `mcp__chrome-devtools__*`
- Run `gemini --help` and `gemini extensions list` for CLI capabilities

## Multimodal Approach

**Decision:** Use Gemini API directly via curl with base64-encoded images. This is the most reliable approach as it doesn't depend on CLI extension availability.

**Implementation Pattern:**
```bash
# Encode images to base64 (use -b 0 on macOS to prevent line breaks)
SCREENSHOT_B64=$(base64 -b 0 -i "$SCREENSHOT_PATH")
FIGMA_B64=$(base64 -b 0 -i "$FIGMA_PATH")

# Send images to Gemini API for comparison
HTTP_STATUS=$(curl -s -w '%{http_code}' -o /tmp/gemini-response.json \
  -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -d '{
    "contents": [{
      "parts": [
        {"text": "Compare these two UI images. The first is the current implementation screenshot, the second is the Figma design. Identify all visual discrepancies including layout, spacing, colors, typography, and responsive issues. Rate each by severity (HIGH/MEDIUM/LOW) and suggest specific CSS fixes."},
        {"inline_data": {"mime_type": "image/png", "data": "'"$SCREENSHOT_B64"'"}},
        {"inline_data": {"mime_type": "image/png", "data": "'"$FIGMA_B64"'"}}
      ]
    }]
  }')

# Error handling
if [[ "$HTTP_STATUS" -ne 200 ]]; then
  echo "API error (HTTP $HTTP_STATUS):"
  jq -r '.error.message // "Unknown error"' /tmp/gemini-response.json
  exit 1
fi

# Extract response (with fallback for missing candidates)
jq -e -r '.candidates[0].content.parts[0].text // "No response generated"' /tmp/gemini-response.json
```

**Why API over CLI:** The Gemini CLI has no image extensions installed. The API provides guaranteed multimodal support without additional setup.

**Runtime Requirements:** `jq` must be available for JSON parsing.

## Files to Create

| File | Action |
|------|--------|
| `claude/agents/gemini-ui-debugger.md` | Create |

## Implementation Details

### claude/agents/gemini-ui-debugger.md

**Frontmatter:**
```yaml
---
name: gemini-ui-debugger
description: "Compare screenshots to Figma designs using Gemini's multimodal capabilities. Identifies visual discrepancies."
model: haiku
tools: Bash, Read, Write, mcp__figma__get_figma_data, mcp__figma__download_figma_images, mcp__chrome-devtools__take_screenshot
color: purple
---
```

**Core Behavior:**

1. **Input Handling:**
   - Accept screenshot path directly, OR
   - Capture via Chrome DevTools MCP: `mcp__chrome-devtools__take_screenshot`

2. **Figma Design Fetching:**
   - Extract Figma URL/file key from user input
   - Use `mcp__figma__get_figma_data` to get node info
   - Use `mcp__figma__download_figma_images` to get design image

3. **Comparison via Gemini API:**
   - Base64-encode both images
   - Send to Gemini API via curl (see Multimodal Approach above)
   - Parse JSON response for comparison findings

4. **Output Format:**
   ```markdown
   ## UI Comparison Report

   **Screenshot:** {path}
   **Figma Design:** {figma_url}

   ### Summary
   Found {N} discrepancies: {HIGH} high, {MEDIUM} medium, {LOW} low

   ### Discrepancies

   #### HIGH Severity
   1. **{Issue Title}**
      - Description: {what's different}
      - Location: {area of screen}
      - Suggested fix: {CSS or component change}

   ### Recommendations
   - {Prioritized action items}
   ```

**Edge Cases:**
- No Figma URL provided → request from user
- Screenshot capture fails → provide helpful error
- Multimodal not available → fall back to text description request

## Verification

```bash
# Agent file exists
test -f claude/agents/gemini-ui-debugger.md && echo "File exists"

# Check for MCP tool references
grep -q "mcp__figma" claude/agents/gemini-ui-debugger.md
grep -q "mcp__chrome-devtools" claude/agents/gemini-ui-debugger.md
```

## Acceptance Criteria

- [ ] Agent definition created at `claude/agents/gemini-ui-debugger.md`
- [ ] Supports screenshot from file path or Chrome DevTools capture
- [ ] Fetches Figma design via Figma MCP
- [ ] Sends images to Gemini (CLI or API)
- [ ] Output includes severity ratings and suggested fixes
- [ ] Handles edge cases:
  - Missing Figma URL → request from user or analyze screenshot only
  - Capture failures → clear error message
  - Multimodal unavailable → graceful fallback
- [ ] Requires Figma URL/file key upfront (documented in agent description)
