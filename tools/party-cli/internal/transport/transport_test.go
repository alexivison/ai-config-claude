//go:build linux || darwin

package transport

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// parseVerdict
// ---------------------------------------------------------------------------

func TestParseVerdict(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		content string
		want    string
	}{
		"approved": {
			content: "Some preamble\nVERDICT: APPROVED\nMore text",
			want:    "APPROVED",
		},
		"request_changes": {
			content: "findings here\nVERDICT: REQUEST_CHANGES\n",
			want:    "REQUEST_CHANGES",
		},
		"needs_discussion": {
			content: "VERDICT: NEEDS_DISCUSSION\n",
			want:    "NEEDS_DISCUSSION",
		},
		"no verdict": {
			content: "some findings without verdict line\n",
			want:    "",
		},
		"empty file": {
			content: "",
			want:    "",
		},
		"verdict prefix but wrong format": {
			content: "VERDICT: UNKNOWN_VALUE\n",
			want:    "",
		},
		"verdict buried in text": {
			content: "line 1\nline 2\nline 3\nVERDICT: APPROVED\nline 5\n",
			want:    "APPROVED",
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			f := filepath.Join(t.TempDir(), "findings.toon")
			if err := os.WriteFile(f, []byte(tc.content), 0o644); err != nil {
				t.Fatalf("write test file: %v", err)
			}
			got := parseVerdict(f)
			if got != tc.want {
				t.Errorf("parseVerdict(): got %q, want %q", got, tc.want)
			}
		})
	}
}

func TestParseVerdict_MissingFile(t *testing.T) {
	t.Parallel()
	got := parseVerdict("/nonexistent/file.toon")
	if got != "" {
		t.Errorf("parseVerdict(missing): got %q, want empty", got)
	}
}

// ---------------------------------------------------------------------------
// isCompletionMessage
// ---------------------------------------------------------------------------

func TestIsCompletionMessage(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		msg  string
		want bool
	}{
		"review complete": {
			msg:  "Review complete. Findings at: /tmp/findings.toon",
			want: true,
		},
		"plan review complete": {
			msg:  "Plan review complete. Findings at: /tmp/plan.toon",
			want: true,
		},
		"task complete": {
			msg:  "Task complete. Response at: /tmp/response.toon",
			want: true,
		},
		"unrelated message": {
			msg:  "Hello from Codex",
			want: false,
		},
		"partial match": {
			msg:  "Review complete but wrong format",
			want: false,
		},
		"empty message": {
			msg:  "",
			want: false,
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			got := isCompletionMessage(tc.msg)
			if got != tc.want {
				t.Errorf("isCompletionMessage(%q): got %v, want %v", tc.msg, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// extractFilePath
// ---------------------------------------------------------------------------

func TestExtractFilePath(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		msg  string
		want string
	}{
		"review findings": {
			msg:  "Review complete. Findings at: /tmp/codex-findings-123.toon",
			want: "/tmp/codex-findings-123.toon",
		},
		"plan review findings": {
			msg:  "Plan review complete. Findings at: /tmp/plan-findings.toon",
			want: "/tmp/plan-findings.toon",
		},
		"task response": {
			msg:  "Task complete. Response at: /tmp/response.toon",
			want: "/tmp/response.toon",
		},
		"trailing whitespace": {
			msg:  "Review complete. Findings at: /tmp/findings.toon  \n",
			want: "/tmp/findings.toon",
		},
		"no match": {
			msg:  "some other message",
			want: "",
		},
		"empty": {
			msg:  "",
			want: "",
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			got := extractFilePath(tc.msg)
			if got != tc.want {
				t.Errorf("extractFilePath(%q): got %q, want %q", tc.msg, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// WriteCodexStatus
// ---------------------------------------------------------------------------

func TestWriteCodexStatus_Working(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	err := WriteCodexStatus(dir, CodexStatus{
		State:  "working",
		Target: "main",
		Mode:   "review",
	})
	if err != nil {
		t.Fatalf("WriteCodexStatus: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(dir, "codex-status.json"))
	if err != nil {
		t.Fatalf("read status: %v", err)
	}

	var status CodexStatus
	if err := json.Unmarshal(data, &status); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if status.State != "working" {
		t.Errorf("state: got %q, want %q", status.State, "working")
	}
	if status.Target != "main" {
		t.Errorf("target: got %q, want %q", status.Target, "main")
	}
	if status.Mode != "review" {
		t.Errorf("mode: got %q, want %q", status.Mode, "review")
	}
	if status.StartedAt == "" {
		t.Error("started_at should be set for working state")
	}
	if status.FinishedAt != "" {
		t.Error("finished_at should be empty for working state")
	}
}

func TestWriteCodexStatus_Idle(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	err := WriteCodexStatus(dir, CodexStatus{
		State:   "idle",
		Verdict: "APPROVED",
	})
	if err != nil {
		t.Fatalf("WriteCodexStatus: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(dir, "codex-status.json"))
	if err != nil {
		t.Fatalf("read status: %v", err)
	}

	var status CodexStatus
	if err := json.Unmarshal(data, &status); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if status.State != "idle" {
		t.Errorf("state: got %q, want %q", status.State, "idle")
	}
	if status.Verdict != "APPROVED" {
		t.Errorf("verdict: got %q, want %q", status.Verdict, "APPROVED")
	}
	if status.FinishedAt == "" {
		t.Error("finished_at should be set for idle state")
	}
	if status.StartedAt != "" {
		t.Error("started_at should be empty for idle state")
	}
}

func TestWriteCodexStatus_Error(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	err := WriteCodexStatus(dir, CodexStatus{
		State: "error",
		Error: "transport timeout",
	})
	if err != nil {
		t.Fatalf("WriteCodexStatus: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(dir, "codex-status.json"))
	if err != nil {
		t.Fatalf("read status: %v", err)
	}

	var status CodexStatus
	if err := json.Unmarshal(data, &status); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if status.State != "error" {
		t.Errorf("state: got %q, want %q", status.State, "error")
	}
	if status.Error != "transport timeout" {
		t.Errorf("error: got %q, want %q", status.Error, "transport timeout")
	}
	if status.FinishedAt == "" {
		t.Error("finished_at should be set for error state")
	}
}

func TestWriteCodexStatus_Atomicity(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	_ = WriteCodexStatus(dir, CodexStatus{State: "idle"})

	// No .tmp file should remain
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("readdir: %v", err)
	}
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".tmp") {
			t.Errorf("found lingering .tmp file: %s", e.Name())
		}
	}
}

func TestWriteCodexStatus_CreatesDir(t *testing.T) {
	t.Parallel()

	dir := filepath.Join(t.TempDir(), "nested", "runtime")
	err := WriteCodexStatus(dir, CodexStatus{State: "working", Mode: "prompt"})
	if err != nil {
		t.Fatalf("WriteCodexStatus: %v", err)
	}

	if _, err := os.Stat(filepath.Join(dir, "codex-status.json")); err != nil {
		t.Errorf("status file should exist: %v", err)
	}
}

func TestWriteCodexStatus_ValidJSON(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	_ = WriteCodexStatus(dir, CodexStatus{
		State:  "working",
		Target: "feature-branch",
		Mode:   "review",
	})

	data, err := os.ReadFile(filepath.Join(dir, "codex-status.json"))
	if err != nil {
		t.Fatalf("read: %v", err)
	}

	// Must be valid JSON
	if !json.Valid(data) {
		t.Error("status file is not valid JSON")
	}

	// Must be indented (pretty-printed)
	if !strings.Contains(string(data), "\n  ") {
		t.Error("status file should be indented")
	}

	// Must end with newline
	if !strings.HasSuffix(string(data), "\n") {
		t.Error("status file should end with newline")
	}
}

// ---------------------------------------------------------------------------
// RenderTemplate
// ---------------------------------------------------------------------------

func TestRenderTemplate_BasicSubstitution(t *testing.T) {
	t.Parallel()

	tmpl := filepath.Join(t.TempDir(), "test.md")
	os.WriteFile(tmpl, []byte("Hello {{NAME}}, welcome to {{PLACE}}."), 0o644)

	result, err := RenderTemplate(tmpl, map[string]string{
		"NAME":  "Claude",
		"PLACE": "the party",
	})
	if err != nil {
		t.Fatalf("RenderTemplate: %v", err)
	}

	want := "Hello Claude, welcome to the party."
	if result != want {
		t.Errorf("got %q, want %q", result, want)
	}
}

func TestRenderTemplate_StripUnreplacedPlaceholders(t *testing.T) {
	t.Parallel()

	tmpl := filepath.Join(t.TempDir(), "test.md")
	content := "Line 1\n{{OPTIONAL_SECTION}}\nLine 3\n{{ANOTHER_OPTIONAL}}\nLine 5"
	os.WriteFile(tmpl, []byte(content), 0o644)

	result, err := RenderTemplate(tmpl, map[string]string{})
	if err != nil {
		t.Fatalf("RenderTemplate: %v", err)
	}

	if strings.Contains(result, "{{") {
		t.Errorf("should not contain unreplaced placeholders: %s", result)
	}

	lines := strings.Split(result, "\n")
	if len(lines) != 3 {
		t.Errorf("expected 3 lines after stripping, got %d: %v", len(lines), lines)
	}
}

func TestRenderTemplate_MixedReplacedAndUnreplaced(t *testing.T) {
	t.Parallel()

	tmpl := filepath.Join(t.TempDir(), "test.md")
	content := "Review: {{TITLE}}\n{{SCOPE_SECTION}}\nFindings: {{FINDINGS_FILE}}"
	os.WriteFile(tmpl, []byte(content), 0o644)

	result, err := RenderTemplate(tmpl, map[string]string{
		"TITLE":         "My Review",
		"FINDINGS_FILE": "/tmp/findings.toon",
	})
	if err != nil {
		t.Fatalf("RenderTemplate: %v", err)
	}

	if !strings.Contains(result, "My Review") {
		t.Error("should contain replaced TITLE")
	}
	if !strings.Contains(result, "/tmp/findings.toon") {
		t.Error("should contain replaced FINDINGS_FILE")
	}
	if strings.Contains(result, "SCOPE_SECTION") {
		t.Error("should strip unreplaced SCOPE_SECTION line")
	}
}

func TestRenderTemplate_EmptyVarReplacesInline(t *testing.T) {
	t.Parallel()

	tmpl := filepath.Join(t.TempDir(), "test.md")
	content := "Before {{VAR}} After"
	os.WriteFile(tmpl, []byte(content), 0o644)

	result, err := RenderTemplate(tmpl, map[string]string{"VAR": ""})
	if err != nil {
		t.Fatalf("RenderTemplate: %v", err)
	}

	// Empty replacement leaves the line with surrounding text
	if result != "Before  After" {
		t.Errorf("got %q, want %q", result, "Before  After")
	}
}

func TestRenderTemplate_MultilineReplacement(t *testing.T) {
	t.Parallel()

	tmpl := filepath.Join(t.TempDir(), "test.md")
	content := "Header\n{{SECTION}}\nFooter"
	os.WriteFile(tmpl, []byte(content), 0o644)

	result, err := RenderTemplate(tmpl, map[string]string{
		"SECTION": "## Scope\n\nOnly review auth module.",
	})
	if err != nil {
		t.Fatalf("RenderTemplate: %v", err)
	}

	if !strings.Contains(result, "## Scope") {
		t.Error("should contain multiline replacement content")
	}
	if !strings.Contains(result, "auth module") {
		t.Error("should contain second line of multiline replacement")
	}
}

func TestRenderTemplate_MissingFile(t *testing.T) {
	t.Parallel()

	_, err := RenderTemplate("/nonexistent/template.md", map[string]string{})
	if err == nil {
		t.Error("expected error for missing template")
	}
}

// ---------------------------------------------------------------------------
// NeedsDiscussion / TriageOverride (pure formatting)
// ---------------------------------------------------------------------------

func TestNeedsDiscussion(t *testing.T) {
	t.Parallel()

	got := NeedsDiscussion("conflicting approaches")
	want := "CODEX NEEDS_DISCUSSION — conflicting approaches"
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestNeedsDiscussion_Default(t *testing.T) {
	t.Parallel()

	got := NeedsDiscussion("")
	if !strings.Contains(got, "Multiple valid approaches") {
		t.Errorf("default reason missing: %q", got)
	}
}

func TestTriageOverride(t *testing.T) {
	t.Parallel()

	got := TriageOverride("SKIP", "out of scope")
	want := "TRIAGE_OVERRIDE SKIP | out of scope"
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

// ---------------------------------------------------------------------------
// ReviewComplete
// ---------------------------------------------------------------------------

func TestReviewComplete_Approved(t *testing.T) {
	t.Parallel()

	f := filepath.Join(t.TempDir(), "findings.toon")
	os.WriteFile(f, []byte("findings[0]{id,severity}:\n  F1,low\nVERDICT: APPROVED\n"), 0o644)

	result, err := ReviewComplete(f)
	if err != nil {
		t.Fatalf("ReviewComplete: %v", err)
	}
	if !result.ReviewRan {
		t.Error("ReviewRan should be true")
	}
	if result.Verdict != "APPROVED" {
		t.Errorf("verdict: got %q, want %q", result.Verdict, "APPROVED")
	}
}

func TestReviewComplete_RequestChanges(t *testing.T) {
	t.Parallel()

	f := filepath.Join(t.TempDir(), "findings.toon")
	os.WriteFile(f, []byte("VERDICT: REQUEST_CHANGES\n"), 0o644)

	result, err := ReviewComplete(f)
	if err != nil {
		t.Fatalf("ReviewComplete: %v", err)
	}
	if result.Verdict != "REQUEST_CHANGES" {
		t.Errorf("verdict: got %q, want %q", result.Verdict, "REQUEST_CHANGES")
	}
}

func TestReviewComplete_MissingFile(t *testing.T) {
	t.Parallel()

	_, err := ReviewComplete("/nonexistent/findings.toon")
	if err == nil {
		t.Error("expected error for missing findings file")
	}
}

func TestReviewComplete_NoVerdict(t *testing.T) {
	t.Parallel()

	f := filepath.Join(t.TempDir(), "findings.toon")
	os.WriteFile(f, []byte("some findings without a verdict\n"), 0o644)

	result, err := ReviewComplete(f)
	if err != nil {
		t.Fatalf("ReviewComplete: %v", err)
	}
	if result.Verdict != "" {
		t.Errorf("verdict should be empty, got %q", result.Verdict)
	}
}

// ---------------------------------------------------------------------------
// fileExists
// ---------------------------------------------------------------------------

func TestFileExists(t *testing.T) {
	t.Parallel()

	f := filepath.Join(t.TempDir(), "exists.txt")
	os.WriteFile(f, []byte("hi"), 0o644)

	if !fileExists(f) {
		t.Error("fileExists should return true for existing file")
	}
	if fileExists("/nonexistent/file.txt") {
		t.Error("fileExists should return false for missing file")
	}
}
