#!/usr/bin/env python3
"""Tests for agent-router.py routing logic."""

import pytest

from agent_router import detect_agent, matches_any, CODEX_TRIGGERS, GEMINI_TRIGGERS, SKIP_PATTERNS


class TestDetectAgent:
    """Test the detect_agent function."""

    # Codex routing tests
    @pytest.mark.parametrize(
        "prompt",
        [
            "How should I design this authentication system?",
            "Can you debug why this test is failing?",
            "There's an error in the payment processing",
            "Review this code for potential issues",
            "Compare Redux vs Zustand for state management",
            "What's the best pattern for this use case?",
            "Why isn't this function working correctly?",
            "Help me refactor this messy component",
            "Analyze the trade-offs between these approaches",
            "How to implement a caching layer here?",
        ],
    )
    def test_routes_to_codex(self, prompt: str):
        """Prompts requiring deep reasoning should route to Codex."""
        agent, trigger = detect_agent(prompt)
        assert agent == "codex", f"Expected codex for: {prompt}"
        assert trigger, "Should have a trigger pattern"

    # Gemini routing tests
    @pytest.mark.parametrize(
        "prompt",
        [
            "Research best practices for API rate limiting",
            "What does the latest React documentation say about hooks?",
            "Read this PDF document for me",  # "Analyze" would trigger Codex first
            "Help me understand the entire codebase",  # Avoid "structure" which triggers Codex
            "What library should I use for date formatting?",
            "Investigate how other teams handle authentication",
            "Look up the latest version of this package",
            "Give me an overview of this repository",
        ],
    )
    def test_routes_to_gemini(self, prompt: str):
        """Research and multimodal tasks should route to Gemini."""
        agent, trigger = detect_agent(prompt)
        assert agent == "gemini", f"Expected gemini for: {prompt}"
        assert trigger, "Should have a trigger pattern"

    # Skip tests
    @pytest.mark.parametrize(
        "prompt",
        [
            "yes",
            "no",
            "ok",
            "sure",
            "thanks",
            "y",
            "n",
            "/commit",
            "/review",
            "commit the changes",
            "push to remote",
            "short",  # Too short (< 15 chars)
        ],
    )
    def test_skips_commands_and_short_prompts(self, prompt: str):
        """Commands, confirmations, and short prompts should not route."""
        agent, _trigger = detect_agent(prompt)
        assert agent is None, f"Should skip: {prompt}"

    # No match tests
    @pytest.mark.parametrize(
        "prompt",
        [
            "Add a button to the navbar please",
            "Create a new component called UserProfile",
            "Update the README with installation instructions",
        ],
    )
    def test_no_match_returns_none(self, prompt: str):
        """Generic implementation tasks without triggers should not route."""
        agent, trigger = detect_agent(prompt)
        assert agent is None, f"Should not match: {prompt}"
        assert trigger == ""


class TestMatchesAny:
    """Test the matches_any helper function."""

    def test_matches_pattern(self):
        """Should return True and the pattern when matched."""
        matched, trigger = matches_any("debug this error", [r"\bdebug\b", r"\berror\b"])
        assert matched is True
        assert trigger == r"\bdebug\b"  # First match wins

    def test_no_match(self):
        """Should return False and empty string when no match."""
        matched, trigger = matches_any("hello world", [r"\bdebug\b", r"\berror\b"])
        assert matched is False
        assert trigger == ""

    def test_case_insensitive(self):
        """Matching should be case insensitive."""
        matched, _trigger = matches_any("DEBUG THIS", [r"\bdebug\b"])
        assert matched is True


class TestTriggerPatterns:
    """Verify trigger patterns are valid regex."""

    def test_codex_triggers_are_valid_regex(self):
        """All Codex triggers should be valid regex patterns."""
        import re

        for pattern in CODEX_TRIGGERS:
            try:
                re.compile(pattern)
            except re.error as e:
                pytest.fail(f"Invalid regex in CODEX_TRIGGERS: {pattern} - {e}")

    def test_gemini_triggers_are_valid_regex(self):
        """All Gemini triggers should be valid regex patterns."""
        import re

        for pattern in GEMINI_TRIGGERS:
            try:
                re.compile(pattern)
            except re.error as e:
                pytest.fail(f"Invalid regex in GEMINI_TRIGGERS: {pattern} - {e}")

    def test_skip_patterns_are_valid_regex(self):
        """All skip patterns should be valid regex patterns."""
        import re

        for pattern in SKIP_PATTERNS:
            try:
                re.compile(pattern)
            except re.error as e:
                pytest.fail(f"Invalid regex in SKIP_PATTERNS: {pattern} - {e}")


class TestEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_empty_prompt(self):
        """Empty prompt should not route."""
        agent, _trigger = detect_agent("")
        assert agent is None

    def test_whitespace_only(self):
        """Whitespace-only prompt should not route."""
        agent, _trigger = detect_agent("   \n\t  ")
        assert agent is None

    def test_codex_takes_priority_over_gemini(self):
        """When both could match, Codex triggers are checked first."""
        # "design" is in Codex, "research" is in Gemini
        prompt = "research and design this authentication flow"
        agent, trigger = detect_agent(prompt)
        # Codex patterns checked first, so "design" wins over "research"
        assert agent == "codex"
        assert "design" in trigger

    def test_long_prompt_with_trigger_at_end(self):
        """Triggers at the end of long prompts should still match."""
        prompt = "This is a very long prompt with lots of context about the project " * 5 + "please debug"
        agent, _trigger = detect_agent(prompt)
        assert agent == "codex"
