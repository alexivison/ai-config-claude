# TASK3: gemini-web-search Agent

**Issue:** gemini-integration-web-search
**Depends on:** TASK0

## Objective

Create an agent that researches questions via web search and synthesizes results using Gemini.

## Required Context

Read these files first:
- `claude/agents/codex.md` — Agent definition pattern
- `gemini/AGENTS.md` — Gemini instructions (from TASK0)
- Run `gemini --help` to understand CLI options
- Note: WebSearch and WebFetch are built-in Claude Code tools (available to all agents)

## Files to Create

| File | Action |
|------|--------|
| `claude/agents/gemini-web-search.md` | Create |

## Implementation Details

### claude/agents/gemini-web-search.md

**Frontmatter:**
```yaml
---
name: gemini-web-search
description: "Research agent that searches the web and synthesizes findings using Gemini Flash for fast inference."
model: haiku
tools: WebSearch, WebFetch, Bash, Read, Write
color: cyan
---
```

**Core Behavior:**

1. **Query Formulation:**
   - Parse user's research question
   - Generate 2-3 targeted search queries
   - Consider temporal relevance (current year: 2026)

2. **Search Execution:**
   - Use WebSearch tool for each query
   - Collect top results (URLs, snippets)

3. **Deep Fetch (Optional):**
   - For complex topics, use WebFetch on top 2-3 results
   - Extract full page content for deeper context

4. **Synthesis via Gemini:**
   ```bash
   gemini -m gemini-2.0-flash -p "Synthesize these search results into a comprehensive answer.

   Original Question: {question}

   Search Results:
   {formatted_results}

   Instructions:
   - Provide a clear, structured answer
   - Cite sources with [Source Name](URL) format
   - Note any conflicting information between sources
   - Indicate confidence level (high/medium/low)
   - Flag if information might be outdated"
   ```

5. **Output Format:**
   ```markdown
   ## Research Findings

   **Question:** {original question}
   **Confidence:** HIGH | MEDIUM | LOW

   ### Answer
   {Synthesized answer with inline citations}

   ### Key Points
   - {Point 1} [Source](url)
   - {Point 2} [Source](url)

   ### Sources
   1. [Title](url) — {brief description of source}
   2. [Title](url) — {brief description of source}

   ### Caveats
   - {Any conflicting information}
   - {Potential outdated info}
   ```

**Guidelines:**
- Use Gemini Flash for speed (research is latency-sensitive)
- Include all sources used
- Be explicit about confidence and limitations
- Don't fabricate sources — only cite what WebSearch returned

## Verification

```bash
# Agent file exists
test -f claude/agents/gemini-web-search.md && echo "File exists"

# Check for WebSearch tool reference
grep -q "WebSearch" claude/agents/gemini-web-search.md

# Check for Gemini Flash usage
grep -q "flash\|Flash" claude/agents/gemini-web-search.md
```

## Acceptance Criteria

- [ ] Agent definition created at `claude/agents/gemini-web-search.md`
- [ ] Uses WebSearch tool for queries
- [ ] Optionally uses WebFetch for deeper content
- [ ] Uses Gemini Flash for fast synthesis
- [ ] Output includes source citations with URLs
- [ ] Indicates confidence level in findings
