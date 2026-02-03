#!/usr/bin/env python3
"""Tests for skill_eval.py skill detection logic."""

import pytest

from skill_eval import detect_skill, format_output, MUST_TRIGGERS, SHOULD_TRIGGERS


class TestDetectSkill:
    """Test the detect_skill function."""

    # Task workflow triggers
    @pytest.mark.parametrize(
        "prompt",
        [
            "Let's work on TASK-01",
            "Pick up task 3 from the plan",
            "Execute task from the plan",
            "Implement task 5",
            "Work on the task_file now",  # Must use underscore/hyphen, not space
        ],
    )
    def test_task_workflow_triggers(self, prompt: str):
        """Task-related prompts should trigger task-workflow."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == "task-workflow"
        assert trigger.priority == "must"

    # Write tests triggers
    @pytest.mark.parametrize(
        "prompt",
        [
            "Write tests for this function",
            "Add a test for the login component",
            "Create tests for the API",
            "Improve test coverage",
            "Add coverage for this module",
        ],
    )
    def test_write_tests_triggers(self, prompt: str):
        """Test-writing prompts should trigger write-tests."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == "write-tests"
        assert trigger.priority == "must"

    # Bugfix workflow triggers
    @pytest.mark.parametrize(
        "prompt",
        [
            "There's a bug in the checkout flow",
            "The login is broken",
            "Getting an error when submitting",
            "This feature is not working",
            "Debug why this fails",
            "The app crashes on startup",
            "Fix this bug please",
        ],
    )
    def test_bugfix_workflow_triggers(self, prompt: str):
        """Bug-related prompts should trigger bugfix-workflow."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == "bugfix-workflow"
        assert trigger.priority == "must"

    # Plan workflow triggers
    @pytest.mark.parametrize(
        "prompt",
        [
            "Build a new authentication system",
            "Create a dashboard component",
            "Implement user notifications",
            "Add a new feature for exports",
        ],
    )
    def test_plan_workflow_triggers(self, prompt: str):
        """Feature-building prompts should trigger plan-workflow."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == "plan-workflow"
        assert trigger.priority == "must"

    # Pre-PR verification triggers
    # Note: "create pr" conflicts with plan-workflow's "create" pattern
    # so we need unambiguous prompts or reorder triggers
    @pytest.mark.parametrize(
        "prompt",
        [
            "I'm ready for pr now",
            "Let's submit pr to main",
            "Time to open pr",
        ],
    )
    def test_pre_pr_verification_triggers(self, prompt: str):
        """PR-related prompts should trigger pre-pr-verification."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == "pre-pr-verification"
        assert trigger.priority == "must"

    # Code review triggers
    @pytest.mark.parametrize(
        "prompt",
        [
            "Review this code",
            "Code review please",
            "Review my PR",
            "Check this code for issues",
            "Give me feedback on the code",
        ],
    )
    def test_code_review_triggers(self, prompt: str):
        """Review-related prompts should trigger code-review."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == "code-review"
        assert trigger.priority == "must"

    # SHOULD triggers
    @pytest.mark.parametrize(
        "prompt,expected_skill",
        [
            ("This code is quality critical", "cli-orchestrator"),
            ("Check for security vulnerabilities", "security-scanner"),
            ("Address the PR comments", "address-pr"),
            ("This PR is too big, minimize it", "minimize"),
            ("Learn from this session", "autoskill"),
        ],
    )
    def test_should_triggers(self, prompt: str, expected_skill: str):
        """SHOULD triggers should match with correct priority."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == expected_skill
        assert trigger.priority == "should"

    # No match
    @pytest.mark.parametrize(
        "prompt",
        [
            "Hello",
            "What time is it?",
            "Tell me about Python",
            "List the files in this directory",
        ],
    )
    def test_no_match(self, prompt: str):
        """Unrelated prompts should not trigger any skill."""
        trigger, pattern = detect_skill(prompt)
        assert trigger is None
        assert pattern == ""


class TestPriority:
    """Test that MUST triggers take priority over SHOULD."""

    def test_must_takes_priority(self):
        """When both could match, MUST triggers first."""
        # "bug" is MUST (bugfix), "security" is SHOULD
        prompt = "There's a security bug in the code"
        trigger, _pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.priority == "must"
        # bugfix-workflow matches first due to "bug"
        assert trigger.name == "bugfix-workflow"

    def test_trigger_order_matters(self):
        """More specific triggers should come before general ones."""
        # "task-01" should trigger task-workflow, not plan-workflow
        prompt = "Implement task-01 from the plan"
        trigger, _pattern = detect_skill(prompt)
        assert trigger is not None
        assert trigger.name == "task-workflow"


class TestFormatOutput:
    """Test output formatting."""

    def test_must_format(self):
        """MUST triggers should include blocking requirement message."""
        trigger = MUST_TRIGGERS[0]  # task-workflow
        output = format_output(trigger)

        assert "additionalContext" in output
        assert 'priority="MUST"' in output["additionalContext"]
        assert "BLOCKING REQUIREMENT" in output["additionalContext"]

    def test_should_format(self):
        """SHOULD triggers should not include blocking message."""
        trigger = SHOULD_TRIGGERS[0]  # cli-orchestrator
        output = format_output(trigger)

        assert "additionalContext" in output
        assert 'priority="SHOULD"' in output["additionalContext"]
        assert "BLOCKING REQUIREMENT" not in output["additionalContext"]


class TestTriggerPatterns:
    """Verify trigger patterns are valid regex."""

    def test_must_triggers_valid_regex(self):
        """All MUST trigger patterns should be valid regex."""
        import re

        for trigger in MUST_TRIGGERS:
            for pattern in trigger.patterns:
                try:
                    re.compile(pattern)
                except re.error as e:
                    pytest.fail(f"Invalid regex in {trigger.name}: {pattern} - {e}")

    def test_should_triggers_valid_regex(self):
        """All SHOULD trigger patterns should be valid regex."""
        import re

        for trigger in SHOULD_TRIGGERS:
            for pattern in trigger.patterns:
                try:
                    re.compile(pattern)
                except re.error as e:
                    pytest.fail(f"Invalid regex in {trigger.name}: {pattern} - {e}")


class TestEdgeCases:
    """Test edge cases."""

    def test_empty_prompt(self):
        """Empty prompt should not trigger."""
        trigger, pattern = detect_skill("")
        assert trigger is None

    def test_case_insensitive(self):
        """Matching should be case insensitive."""
        trigger, _pattern = detect_skill("WRITE TESTS FOR THIS")
        assert trigger is not None
        assert trigger.name == "write-tests"

    def test_word_boundary_matching(self):
        """Word boundary patterns should match correctly."""
        # "debugging" doesn't match \bbug\b but "debug" matches \bdebug\b
        # However "debugging" as a word doesn't match \bdebug\b either
        # The pattern \bdebug\b matches "debug" as a standalone word

        # This should NOT match because "debugging" != "debug"
        trigger, _pattern = detect_skill("I'm currently debugging")
        # Actually it doesn't match because \bdebug\b needs word boundary after
        # and "debugging" has 'ging' after debug, so it doesn't match
        assert trigger is None

        # This SHOULD match
        trigger, _pattern = detect_skill("Help me debug this issue")
        assert trigger is not None
        assert trigger.name == "bugfix-workflow"
