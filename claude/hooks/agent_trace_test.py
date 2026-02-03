#!/usr/bin/env python3
"""Tests for agent_trace.py verdict detection and marker creation."""

import json
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

from agent_trace import (
    detect_verdict,
    detect_task_type,
    create_marker,
    create_markers,
    write_trace,
    VERDICT_PATTERNS,
)


class TestDetectVerdict:
    """Test verdict detection from response text."""

    @pytest.mark.parametrize(
        "text,expected",
        [
            ("## Code Review\n\n**Verdict**: APPROVE", "APPROVED"),
            ("Verdict: REQUEST_CHANGES", "REQUEST_CHANGES"),
            ("CHANGES REQUESTED - please fix", "REQUEST_CHANGES"),
            ("NEEDS_DISCUSSION on the architecture", "NEEDS_DISCUSSION"),
            ("Skipping review. **Verdict**: SKIP", "SKIP"),
            ("Found CRITICAL vulnerability", "ISSUES_FOUND"),
            ("HIGH severity issue detected", "ISSUES_FOUND"),
            ("Tests FAIL with 3 errors", "FAIL"),
            ("All tests PASS", "PASS"),
            ("Lint CLEAN, no issues", "CLEAN"),
            ("Task completed successfully", "COMPLETED"),
            ("Analysis done and finished", "COMPLETED"),
        ],
    )
    def test_verdict_detection(self, text: str, expected: str):
        """Should detect correct verdict from response text."""
        assert detect_verdict(text) == expected

    def test_unknown_verdict(self):
        """Should return 'unknown' when no verdict pattern matches."""
        assert detect_verdict("Here is some random output") == "unknown"

    def test_priority_order(self):
        """More specific verdicts should take priority."""
        # REQUEST_CHANGES should match before APPROVED when both could apply
        text = "REQUEST_CHANGES - please APPROVE after fixing"
        assert detect_verdict(text) == "REQUEST_CHANGES"

    def test_case_insensitive(self):
        """Verdict detection should be case insensitive."""
        assert detect_verdict("approve") == "APPROVED"
        assert detect_verdict("PASS") == "PASS"
        assert detect_verdict("Fail") == "FAIL"


class TestDetectTaskType:
    """Test task type detection from cli-orchestrator output."""

    @pytest.mark.parametrize(
        "text,expected",
        [
            ("## Code Review\n\nLooking good", "code-review"),
            ("Code Review (Codex)\n\nAnalysis:", "code-review"),
            ("## Architecture Review\n\nStructure is solid", "architecture"),
            ("Architecture Review (Codex)", "architecture"),
            ("## Plan Review\n\nPlan looks complete", "plan-review"),
            ("Plan Review (Codex)", "plan-review"),
        ],
    )
    def test_task_type_detection(self, text: str, expected: str):
        """Should detect task type from output headers."""
        assert detect_task_type(text) == expected

    def test_no_task_type(self):
        """Should return None when no task type header found."""
        assert detect_task_type("Some research output here") is None
        assert detect_task_type("") is None


class TestCreateMarker:
    """Test marker file creation."""

    def test_creates_marker_file(self):
        """Should create marker file in /tmp."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Patch the marker path to use temp directory
            with patch("agent_trace.Path") as mock_path:
                marker_path = Path(tmpdir) / "claude-test-marker-session123"
                mock_path.return_value = marker_path

                create_marker("test-marker", "session123")

                # The actual implementation uses Path(f"/tmp/...")
                # So we test by checking the function doesn't raise
                # In real usage, it creates /tmp/claude-{name}-{session}


class TestCreateMarkers:
    """Test marker creation logic for different agent types."""

    def test_security_scanner_creates_marker(self):
        """security-scanner should always create marker."""
        with patch("agent_trace.create_marker") as mock_create:
            create_markers("security-scanner", "unknown", "", "sess1")
            mock_create.assert_called_once_with("security-scanned", "sess1")

    def test_architecture_critic_creates_marker(self):
        """architecture-critic should create marker on any verdict."""
        with patch("agent_trace.create_marker") as mock_create:
            create_markers("architecture-critic", "REQUEST_CHANGES", "", "sess1")
            mock_create.assert_called_once_with("architecture-reviewed", "sess1")

    def test_code_critic_only_on_approve(self):
        """code-critic should only create marker on APPROVED."""
        with patch("agent_trace.create_marker") as mock_create:
            # Should not create marker
            create_markers("code-critic", "REQUEST_CHANGES", "", "sess1")
            mock_create.assert_not_called()

            # Should create marker
            create_markers("code-critic", "APPROVED", "", "sess1")
            mock_create.assert_called_once_with("code-critic", "sess1")

    def test_cli_orchestrator_code_review(self):
        """cli-orchestrator code review should create marker on APPROVED."""
        with patch("agent_trace.create_marker") as mock_create:
            response = "## Code Review\n\n**Verdict**: APPROVE"

            # Not approved - no marker
            create_markers("cli-orchestrator", "REQUEST_CHANGES", response, "sess1")
            mock_create.assert_not_called()

            # Approved - creates marker
            create_markers("cli-orchestrator", "APPROVED", response, "sess1")
            mock_create.assert_called_once_with("code-critic", "sess1")

    def test_cli_orchestrator_architecture(self):
        """cli-orchestrator architecture review should always create marker."""
        with patch("agent_trace.create_marker") as mock_create:
            response = "## Architecture Review\n\nLooks good"
            create_markers("cli-orchestrator", "REQUEST_CHANGES", response, "sess1")
            mock_create.assert_called_once_with("architecture-reviewed", "sess1")

    def test_cli_orchestrator_plan_review(self):
        """cli-orchestrator plan review should create marker on APPROVED."""
        with patch("agent_trace.create_marker") as mock_create:
            response = "## Plan Review\n\n**Verdict**: APPROVE"
            create_markers("cli-orchestrator", "APPROVED", response, "sess1")
            mock_create.assert_called_once_with("plan-reviewer", "sess1")

    def test_test_runner_only_on_pass(self):
        """test-runner should only create marker on PASS."""
        with patch("agent_trace.create_marker") as mock_create:
            create_markers("test-runner", "FAIL", "", "sess1")
            mock_create.assert_not_called()

            create_markers("test-runner", "PASS", "", "sess1")
            mock_create.assert_called_once_with("tests-passed", "sess1")

    def test_check_runner_on_pass_or_clean(self):
        """check-runner should create marker on PASS or CLEAN."""
        with patch("agent_trace.create_marker") as mock_create:
            create_markers("check-runner", "FAIL", "", "sess1")
            mock_create.assert_not_called()

            create_markers("check-runner", "PASS", "", "sess1")
            mock_create.assert_called_once_with("checks-passed", "sess1")

            mock_create.reset_mock()
            create_markers("check-runner", "CLEAN", "", "sess1")
            mock_create.assert_called_once_with("checks-passed", "sess1")

    def test_plan_reviewer_legacy(self):
        """Legacy plan-reviewer should create marker on APPROVED."""
        with patch("agent_trace.create_marker") as mock_create:
            create_markers("plan-reviewer", "APPROVED", "", "sess1")
            mock_create.assert_called_once_with("plan-reviewer", "sess1")

    def test_unknown_agent_no_marker(self):
        """Unknown agent types should not create markers."""
        with patch("agent_trace.create_marker") as mock_create:
            create_markers("unknown-agent", "APPROVED", "", "sess1")
            mock_create.assert_not_called()


class TestWriteTrace:
    """Test trace entry writing."""

    def test_writes_jsonl_entry(self):
        """Should write valid JSONL entry."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False) as f:
            trace_file = Path(f.name)

        with patch("agent_trace.TRACE_FILE", trace_file):
            write_trace(
                session_id="sess123",
                project="myproject",
                agent_type="test-runner",
                description="Run unit tests",
                model="haiku",
                verdict="PASS",
            )

            # Read and verify
            with open(trace_file) as f:
                entry = json.loads(f.readline())

            assert entry["session"] == "sess123"
            assert entry["project"] == "myproject"
            assert entry["agent"] == "test-runner"
            assert entry["description"] == "Run unit tests"
            assert entry["model"] == "haiku"
            assert entry["verdict"] == "PASS"
            assert "timestamp" in entry

        # Cleanup
        trace_file.unlink()


class TestVerdictPatterns:
    """Verify verdict patterns are valid regex."""

    def test_all_patterns_valid_regex(self):
        """All verdict patterns should be valid regex."""
        import re

        for vp in VERDICT_PATTERNS:
            for pattern in vp.patterns:
                try:
                    re.compile(pattern)
                except re.error as e:
                    pytest.fail(f"Invalid regex for {vp.verdict}: {pattern} - {e}")
