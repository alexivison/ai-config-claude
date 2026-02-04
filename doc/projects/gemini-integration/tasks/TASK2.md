# TASK2: gemini-ui-debugger Agent

**Issue:** gemini-integration-ui-debugger
**Depends on:** TASK0

## Objective

Create an agent that uses Gemini's multimodal capabilities to compare browser screenshots against Figma designs.

## Required Context

Read these files first:
- `claude/agents/codex.md` — Agent definition pattern
- Check available MCP tools: `mcp__figma__*`, `mcp__chrome-devtools__*`
- `gemini-cli/config.toml` — Gemini configuration (from TASK0)

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

3. **Comparison via Gemini:**
   ```bash
   # Multiple --image flags supported (max 4 images per request)
   # Images are base64-encoded internally by gemini-cli
   gemini-cli exec \
     --image /tmp/screenshot.png \
     --image /tmp/figma-design.png \
     "Compare these two images:
     Image 1: Browser screenshot (actual implementation)
     Image 2: Figma design (expected design)

     Identify all visual discrepancies:
     - Layout differences (positioning, alignment, spacing)
     - Size differences (width, height, padding, margins)
     - Color differences (background, text, borders)
     - Typography differences (font, size, weight)
     - Missing or extra elements
     - Responsive/overflow issues

     For each discrepancy:
     1. Describe what's different
     2. Rate severity: HIGH (broken), MEDIUM (noticeable), LOW (minor)
     3. Suggest CSS fix if applicable"
   ```

   **Image Requirements:**
   - Max 4 images per request
   - Max 20MB per image (resize larger images)
   - Supported formats: PNG, JPEG, WebP, GIF

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
      - Suggested fix:
        ```css
        .selector {
          property: value;
        }
        ```

   #### MEDIUM Severity
   ...

   #### LOW Severity
   ...

   ### Recommendations
   - {Prioritized action items}
   ```

**Edge Cases:**
- No Figma URL provided → request from user
- Screenshot capture fails → provide helpful error
- Figma fetch fails → fall back to screenshot-only analysis with warning

## Verification

```bash
# Agent file exists
test -f claude/agents/gemini-ui-debugger.md && echo "File exists"

# Check for MCP tool references
grep -q "mcp__figma" claude/agents/gemini-ui-debugger.md
grep -q "mcp__chrome-devtools" claude/agents/gemini-ui-debugger.md

# Check for multimodal invocation
grep -q "\-\-image" claude/agents/gemini-ui-debugger.md
```

## Acceptance Criteria

- [ ] Agent definition created at `claude/agents/gemini-ui-debugger.md`
- [ ] Supports screenshot from file path or Chrome DevTools capture
- [ ] Fetches Figma design via Figma MCP
- [ ] Uses `gemini-cli exec --image` with both images (multiple --image flags)
- [ ] Output includes severity ratings and suggested fixes
- [ ] Handles edge cases:
  - Missing Figma URL → request from user or analyze screenshot only
  - Capture failures → clear error message with troubleshooting
  - Image too large → resize before sending (max 20MB)
- [ ] Requires Figma URL/file key upfront (documented in agent description)
