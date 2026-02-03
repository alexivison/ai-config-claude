#!/usr/bin/env python3
"""
PostToolUse hook: Log sub-agent invocations and create PR gate markers.

Triggered: PostToolUse on Task tool
Input: JSON via stdin with tool_name, tool_input, tool_response
"""

import json
import logging
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

# Logging setup
LOG_DIR = Path.home() / ".claude" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "agent-trace.log"
TRACE_FILE = LOG_DIR / "agent-trace.jsonl"

logging.basicConfig(
    level=logging.DEBUG if os.environ.get("CLAUDE_TRACE_DEBUG") else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stderr)]
    if os.environ.get("CLAUDE_TRACE_DEBUG")
    else [logging.FileHandler(LOG_FILE)],
)
logger = logging.getLogger(__name__)


@dataclass
class VerdictPattern:
    """A verdict detection pattern."""

    verdict: str
    patterns: list[str]


# Verdict patterns ordered by specificity (most specific first)
VERDICT_PATTERNS = [
    VerdictPattern("REQUEST_CHANGES", [r"REQUEST_CHANGES", r"CHANGES REQUESTED"]),
    VerdictPattern("NEEDS_DISCUSSION", [r"NEEDS_DISCUSSION"]),
    VerdictPattern("APPROVED", [r"APPROVE"]),
    VerdictPattern("SKIP", [r"SKIP"]),
    VerdictPattern("ISSUES_FOUND", [r"CRITICAL", r"HIGH"]),
    VerdictPattern("FAIL", [r"FAIL"]),
    VerdictPattern("PASS", [r"PASS"]),
    VerdictPattern("CLEAN", [r"CLEAN"]),
    VerdictPattern("COMPLETED", [r"complete", r"done", r"finished"]),
]


def detect_verdict(response_text: str) -> str:
    """Detect verdict from response text."""
    for vp in VERDICT_PATTERNS:
        for pattern in vp.patterns:
            if re.search(pattern, response_text, re.IGNORECASE):
                return vp.verdict
    return "unknown"


def detect_task_type(response_text: str) -> str | None:
    """Detect task type from cli-orchestrator output headers."""
    patterns = {
        "code-review": [r"Code Review \(Codex\)", r"## Code Review"],
        "architecture": [r"Architecture Review \(Codex\)", r"## Architecture Review"],
        "plan-review": [r"Plan Review \(Codex\)", r"## Plan Review"],
    }

    for task_type, task_patterns in patterns.items():
        for pattern in task_patterns:
            if re.search(pattern, response_text, re.IGNORECASE):
                return task_type
    return None


def create_marker(marker_name: str, session_id: str) -> None:
    """Create a PR gate marker file."""
    marker_path = Path(f"/tmp/claude-{marker_name}-{session_id}")
    marker_path.touch()
    logger.info("Created marker: %s", marker_path)


def create_markers(agent_type: str, verdict: str, response_text: str, session_id: str) -> None:
    """Create appropriate markers based on agent type and verdict."""
    # security-scanner: any completion creates marker
    if agent_type == "security-scanner":
        create_marker("security-scanned", session_id)

    # architecture-critic: any verdict creates marker (review happened)
    elif agent_type == "architecture-critic":
        create_marker("architecture-reviewed", session_id)

    # code-critic: only APPROVE creates marker
    elif agent_type == "code-critic" and verdict == "APPROVED":
        create_marker("code-critic", session_id)

    # cli-orchestrator: detect task type from output
    elif agent_type == "cli-orchestrator":
        task_type = detect_task_type(response_text)

        if task_type == "code-review" and verdict == "APPROVED":
            create_marker("code-critic", session_id)
        elif task_type == "architecture":
            create_marker("architecture-reviewed", session_id)
        elif task_type == "plan-review" and verdict == "APPROVED":
            create_marker("plan-reviewer", session_id)

    # test-runner: only PASS creates marker
    elif agent_type == "test-runner" and verdict == "PASS":
        create_marker("tests-passed", session_id)

    # check-runner: PASS or CLEAN creates marker
    elif agent_type == "check-runner" and verdict in ("PASS", "CLEAN"):
        create_marker("checks-passed", session_id)

    # plan-reviewer: legacy agent (now handled by cli-orchestrator)
    elif agent_type == "plan-reviewer" and verdict == "APPROVED":
        create_marker("plan-reviewer", session_id)


def write_trace(
    session_id: str,
    project: str,
    agent_type: str,
    description: str,
    model: str,
    verdict: str,
) -> None:
    """Write trace entry to JSONL file."""
    entry = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "session": session_id,
        "project": project,
        "agent": agent_type,
        "description": description,
        "model": model,
        "verdict": verdict,
    }

    with open(TRACE_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")

    logger.info("Traced: %s (%s) -> %s", agent_type, description[:40], verdict)


def main():
    try:
        hook_input = json.load(sys.stdin)

        # Only process Task tool
        tool_name = hook_input.get("tool_name", "")
        if tool_name != "Task":
            return

        # Extract agent details
        tool_input = hook_input.get("tool_input", {})
        agent_type = tool_input.get("subagent_type", "unknown")
        description = tool_input.get("description", "")
        model = tool_input.get("model", "inherit")

        # Extract response (first 500 chars for verdict detection)
        response_text = str(hook_input.get("tool_response", ""))[:500]

        # Detect verdict
        verdict = detect_verdict(response_text)

        # Get session/project info
        session_id = hook_input.get("session_id", "unknown")
        cwd = hook_input.get("cwd", "")
        project = Path(cwd).name if cwd else "unknown"

        # Write trace entry
        write_trace(session_id, project, agent_type, description, model, verdict)

        # Create markers for PR gate
        create_markers(agent_type, verdict, response_text, session_id)

    except json.JSONDecodeError as e:
        logger.error("Failed to parse input JSON: %s", e)
        # Also write to hook-errors.log for compatibility
        error_log = LOG_DIR / "hook-errors.log"
        with open(error_log, "a") as f:
            f.write(json.dumps({"error": "Invalid JSON input", "details": str(e)}) + "\n")
    except Exception as e:
        logger.exception("Unexpected error in agent-trace: %s", e)


if __name__ == "__main__":
    main()
