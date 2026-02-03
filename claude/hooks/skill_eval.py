#!/usr/bin/env python3
"""
UserPromptSubmit hook: Detect skill triggers and inject suggestions.

MANDATORY = blocking requirement per CLAUDE.md
SHOULD = recommended but not required

NOTE: This is a reminder system. Hard enforcement is in pr-gate.sh.
"""

import json
import logging
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Logging setup
LOG_DIR = Path.home() / ".claude" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "skill-eval.log"

logging.basicConfig(
    level=logging.DEBUG if os.environ.get("CLAUDE_SKILL_DEBUG") else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stderr)]
    if os.environ.get("CLAUDE_SKILL_DEBUG")
    else [logging.FileHandler(LOG_FILE)],
)
logger = logging.getLogger(__name__)


@dataclass
class SkillTrigger:
    """A skill trigger with pattern, suggestion, and priority."""

    name: str
    patterns: list[str]
    suggestion: str
    priority: str  # "must" or "should"


# MUST invoke skills (highest priority, blocking)
MUST_TRIGGERS = [
    SkillTrigger(
        name="task-workflow",
        patterns=[
            r"\btask[_-]?[0-9]",
            r"\btask[_-]?file",
            r"\bpick up task",
            r"\bfrom (the )?plan\b",
            r"\bexecute task\b",
            r"\bimplement task\b",
        ],
        suggestion="MANDATORY: Invoke task-workflow skill for planned task execution.",
        priority="must",
    ),
    SkillTrigger(
        name="write-tests",
        patterns=[
            r"\bwrite (a |the )?tests?\b",
            r"\badd (a |the )?tests?\b",
            r"\bcreate (a |the )?tests?\b",
            r"\btest coverage\b",
            r"\badd coverage\b",
        ],
        suggestion="MANDATORY: Invoke /write-tests skill BEFORE writing any tests.",
        priority="must",
    ),
    SkillTrigger(
        name="bugfix-workflow",
        patterns=[
            r"\bbug\b",
            r"\bbroken\b",
            r"\berror\b",
            r"\bnot work",
            r"\bdebug\b",
            r"\bcrash",
            r"\bfail(s|ed|ing|ure)?\b",
            r"\bfix(es|ed|ing)?\b.*(bug|error|issue|broken|crash|fail)",
            r"\b(bug|error|issue|broken|crash).*(fix|fixes|fixed|fixing)\b",
        ],
        suggestion="MANDATORY: Invoke bugfix-workflow skill for debugging workflow.",
        priority="must",
    ),
    SkillTrigger(
        name="plan-workflow",
        patterns=[
            r"\bnew feature\b",
            r"\bimplement\b",
            r"\bbuild\b",
            r"\bcreate\b",
            r"\badd (a |the |new )?[a-z]+\b",
        ],
        suggestion="MANDATORY: Invoke plan-workflow skill for planning workflow.",
        priority="must",
    ),
    SkillTrigger(
        name="pre-pr-verification",
        patterns=[
            r"\bcreate pr\b",
            r"\bmake pr\b",
            r"\bready for pr\b",
            r"\bopen pr\b",
            r"\bsubmit pr\b",
        ],
        suggestion="MANDATORY: Run /pre-pr-verification + security-scanner BEFORE creating PR. PR gate will block without these.",
        priority="must",
    ),
    SkillTrigger(
        name="code-review",
        patterns=[
            r"\breview (this|my|the) code\b",
            r"\bcode review\b",
            r"\breview (this|my) pr\b",
            r"\bcheck this code\b",
            r"\bfeedback on.*code",
        ],
        suggestion="MANDATORY: Invoke /code-review skill for systematic review.",
        priority="must",
    ),
]

# SHOULD invoke skills (recommended)
SHOULD_TRIGGERS = [
    SkillTrigger(
        name="cli-orchestrator",
        patterns=[
            r"\bquality.?critical\b",
            r"\bimportant.*code\b",
            r"\bproduction.*ready\b",
        ],
        suggestion="RECOMMENDED: Use cli-orchestrator agent for iterative quality refinement via Codex.",
        priority="should",
    ),
    SkillTrigger(
        name="security-scanner",
        patterns=[
            r"\bsecurity\b",
            r"\bvulnerab",
            r"\baudit\b",
            r"\bsecret\b",
        ],
        suggestion="RECOMMENDED: Run security-scanner agent for security analysis.",
        priority="should",
    ),
    SkillTrigger(
        name="address-pr",
        patterns=[
            r"\bpr comment",
            r"\breview(er)? (comment|feedback|request)",
            r"\baddress (the |this |pr )?feedback",
            r"\bfix.*comment",
            r"\brespond to.*review",
        ],
        suggestion="RECOMMENDED: Invoke /address-pr to systematically address comments.",
        priority="should",
    ),
    SkillTrigger(
        name="minimize",
        patterns=[
            r"\bbloat\b",
            r"\btoo (big|large|much)\b",
            r"\bminimize\b",
            r"\bsimplify\b",
            r"\bover.?engineer",
        ],
        suggestion="RECOMMENDED: Invoke /minimize to identify unnecessary complexity.",
        priority="should",
    ),
    SkillTrigger(
        name="autoskill",
        patterns=[
            r"\blearn from (this|session)\b",
            r"\bremember (this|that)\b",
            r"\bsave (this |that |)preference\b",
            r"\bextract pattern\b",
            r"/autoskill",
        ],
        suggestion="RECOMMENDED: Invoke /autoskill to learn from this session.",
        priority="should",
    ),
]


def detect_skill(prompt: str) -> tuple[SkillTrigger | None, str]:
    """
    Detect which skill should be triggered for this prompt.

    Returns (trigger, matched_pattern) or (None, "") if no match.
    """
    prompt_lower = prompt.lower()

    # Check MUST triggers first (higher priority, in order of specificity)
    for trigger in MUST_TRIGGERS:
        for pattern in trigger.patterns:
            if re.search(pattern, prompt_lower, re.IGNORECASE):
                logger.info(
                    "Triggered %s (MUST) | pattern=%s | prompt=%s",
                    trigger.name,
                    pattern,
                    prompt[:80],
                )
                return trigger, pattern

    # Check SHOULD triggers
    for trigger in SHOULD_TRIGGERS:
        for pattern in trigger.patterns:
            if re.search(pattern, prompt_lower, re.IGNORECASE):
                logger.info(
                    "Triggered %s (SHOULD) | pattern=%s | prompt=%s",
                    trigger.name,
                    pattern,
                    prompt[:80],
                )
                return trigger, pattern

    logger.debug("No skill trigger for: %s", prompt[:80])
    return None, ""


def format_output(trigger: SkillTrigger) -> dict:
    """Format the output JSON for the hook."""
    if trigger.priority == "must":
        context = (
            f"<skill-trigger priority=\"MUST\">\n"
            f"{trigger.suggestion}\n"
            f"This is a BLOCKING REQUIREMENT per CLAUDE.md.\n"
            f"</skill-trigger>"
        )
    else:
        context = f"<skill-trigger priority=\"SHOULD\">\n{trigger.suggestion}\n</skill-trigger>"

    return {"additionalContext": context}


def main():
    try:
        data = json.load(sys.stdin)
        prompt = data.get("prompt", "")

        if not prompt:
            print(json.dumps({}))
            return

        trigger, _pattern = detect_skill(prompt)

        if trigger:
            print(json.dumps(format_output(trigger)))
        else:
            print(json.dumps({}))

    except json.JSONDecodeError as e:
        logger.error("Failed to parse input JSON: %s", e)
        print(json.dumps({}))
    except Exception as e:
        logger.exception("Unexpected error in skill-eval: %s", e)
        print(json.dumps({}))


if __name__ == "__main__":
    main()
