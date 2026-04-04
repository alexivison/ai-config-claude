# Task 8 — Stub Companion Implementation

**Dependencies:** Task 1

## Goal

Create a documented stub `Companion` implementation in Go that serves as a reference for anyone adding a new companion CLI to the harness. It implements the full `Companion` interface with clear comments, but its behavior is minimal (auto-approve reviews, log prompts to file).

## Scope Boundary

**In scope:**
- `tools/party-cli/internal/companion/stub.go` — fully documented implementation
- Inline comments explaining what a real companion would do at each step
- Registration in the default registry when `.party.toml` references it

**Out of scope:**
- Any real companion CLI integration
- Transport or hook changes
- Modifying the `Companion` interface

**Design References:** N/A (non-UI task)

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/party-cli/internal/companion/stub.go` | Create |

## Requirements

**Functionality:**
- Implements `Companion` interface: `Name()="stub"`, `CLI()="stub"`, `Role()="stub"`, `Capabilities()=["review","plan","prompt"]`, `PaneWindow()=0`
- `Start()`: Log "Starting stub companion in pane" and set `@party_role` metadata via tmux. Comment: "Real companions launch the CLI binary here, optionally with a thread ID for session resumption."
- `ParseCompletion()`: Match `"Stub complete. Findings at: "` prefix. Comment: "Real companions match their CLI's specific completion message format."
- When used as the active companion for `review` mode: the stub should write a TOON findings file with `VERDICT: APPROVED` and zero findings to the expected path. Comment: "Real companions produce findings from actual code review."
- Include a file-level doc comment with: purpose, how to register in `.party.toml`, and what methods to implement.
- Include a `.party.toml` snippet in comments:
  ```toml
  [companions.stub]
  cli = "stub"
  role = "stub"
  capabilities = ["review", "plan", "prompt"]
  pane_window = 0
  ```

**Key gotchas:**
- The stub should be functional enough that the harness doesn't break when it's the active companion — workflows complete, evidence records, PR gates pass
- This is the onboarding ramp for new companion authors; clarity matters more than cleverness
- The stub doesn't need a real CLI binary — it operates entirely through tmux pane manipulation and file writes

## Tests

- `stub.Name()` returns "stub"
- `stub.Capabilities()` includes "review", "plan", "prompt"
- `stub.ParseCompletion("Stub complete. Findings at: /tmp/f.toon")` returns correct result
- `stub.ParseCompletion("random message")` returns false

## Acceptance Criteria

- [ ] Stub implements full `Companion` interface
- [ ] Every method has doc comments explaining what real companions do
- [ ] File-level comment includes `.party.toml` registration snippet
- [ ] Stub auto-approves reviews (harness completes without a real companion)
- [ ] Tests pass
