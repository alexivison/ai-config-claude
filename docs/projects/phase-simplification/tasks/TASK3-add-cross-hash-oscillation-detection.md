# Task 3 — Add Cross-Hash Oscillation Detection

**Dependencies:** none | **Issue:** N/A (phase-simplification)

---

## Goal

Extend critic oscillation handling so the **minimizer** re-raising the same normalized `REQUEST_CHANGES` finding across multiple committed hashes auto-triages after the third distinct hash, preventing the minimizer loop from resurfacing the same complaint forever under slightly different diffs. Cross-hash auto-triage is **minimizer-only** — `code-critic` finds correctness bugs that legitimately persist across fix attempts and must not be auto-approved.

## Scope Boundary (REQUIRED)

**In scope:**
- Cross-hash oscillation logic in `claude/hooks/agent-trace-stop.sh`
- Stable finding fingerprint extraction from critic `REQUEST_CHANGES` output
- Persistence of whatever fingerprint metadata the detector needs without modifying `claude/hooks/lib/evidence.sh`
- New regression cases in `claude/hooks/tests/test-agent-trace.sh`

**Out of scope (handled by other tasks):**
- Same-hash alternation logic, except to preserve it
- PR gate simplification
- Codex hook simplification
- Any changes to `claude/hooks/lib/evidence.sh`

**Cross-task consistency check:**
- Task 4 must document both same-hash and cross-hash oscillation behavior in `execution-core.md`.
- If this task stores extra fields on `{critic}-run` evidence entries, the format must remain compatible with `check_evidence()` in `claude/hooks/lib/evidence.sh:276-305`, which ignores extra JSON keys.

## Reference

Files to study before implementing:

- `claude/hooks/agent-trace-stop.sh:34-72` — verdict extraction and response parsing
- `claude/hooks/agent-trace-stop.sh:119-148` — current same-hash oscillation logic
- `claude/hooks/lib/evidence.sh:185-205` — minimal evidence append contract
- `claude/hooks/lib/evidence.sh:212-271` — triage override rules and current-hash requirement
- `claude/hooks/tests/test-agent-trace.sh:213-275` — current oscillation coverage to preserve and extend

## Design References (REQUIRED for UI/component tasks)

N/A (non-UI task)

## Data Transformation Checklist (REQUIRED for shape changes)

This task adds internal metadata for critic-run analysis.

- [ ] The finding fingerprint is derived only from `REQUEST_CHANGES` content, not `APPROVE` messages
- [ ] Fingerprint normalization removes verdict banners and low-value formatting noise so the same finding hashes consistently
- [ ] Same-hash alternation still keys off the current `diff_hash`
- [ ] Cross-hash detection counts identical fingerprints across distinct hashes only
- [ ] The auto-triage threshold is three or more distinct hashes for the same **minimizer** fingerprint
- [ ] Cross-hash auto-triage is NOT applied to `code-critic` (correctness bugs may legitimately persist)
- [ ] Two hashes or clearly different normalized findings do not trigger override

## Files to Create/Modify

| File | Action |
|------|--------|
| `claude/hooks/agent-trace-stop.sh` | Modify |
| `claude/hooks/tests/test-agent-trace.sh` | Modify |

## Requirements

**Functionality:**
- After the existing same-hash oscillation check, gather prior runs for the **minimizer** across all hashes (skip this for `code-critic`).
- For `REQUEST_CHANGES`, derive a deterministic fingerprint from the normalized finding body. At minimum, strip verdict headers/Markdown emphasis, collapse whitespace, lowercase the text, and hash the normalized result.
- Persist or otherwise record that fingerprint in the critic-run history without changing `claude/hooks/lib/evidence.sh`.
- If the minimizer produces the same fingerprint on three or more distinct hashes, auto-call `append_triage_override()` with a rationale that names cross-hash oscillation.
- Do NOT apply cross-hash auto-triage to `code-critic` — correctness bugs legitimately persist across fix attempts.
- Preserve the current same-hash alternation override behavior and all non-critic evidence behavior.

**Key gotchas:**
- `append_triage_override()` at `claude/hooks/lib/evidence.sh:232-244` requires proof that the critic ran at the current hash, so the current run must still be recorded before cross-hash detection fires.
- A whole-message fingerprint is simpler than fuzzy matching and avoids new dependencies; normalization should be strong enough to absorb trivial wording noise but not so broad that unrelated findings collide.
- The test suite must distinguish true repeated findings from legitimate new findings on later hashes.

## Tests

Test cases:
- Minimizer same fingerprint across three distinct hashes creates an auto-triage override
- Minimizer same fingerprint across two hashes only does not trigger override
- Minimizer different fingerprints across hashes do not trigger override
- Code-critic same fingerprint across three hashes does NOT auto-triage (correctness exemption)
- Existing same-hash alternation still triggers override for both critic types
- Different critic types do not cross-trigger each other

Verification commands:
- `bash claude/hooks/tests/test-agent-trace.sh`

## Acceptance Criteria

- [ ] `claude/hooks/agent-trace-stop.sh` still detects same-hash alternation
- [ ] Repeated normalized minimizer `REQUEST_CHANGES` findings across three hashes now auto-triage
- [ ] Code-critic is exempt from cross-hash auto-triage (correctness bugs persist legitimately)
- [ ] Different findings and two-hash repeats do not auto-triage
- [ ] No changes are made to `claude/hooks/lib/evidence.sh`
- [ ] All Task 3 verification commands pass
