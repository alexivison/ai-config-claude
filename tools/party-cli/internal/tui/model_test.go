package tui

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func stubResolver(id string, mode ViewMode) SessionResolver {
	return func() (string, ViewMode, error) {
		return id, mode, nil
	}
}

// ---------------------------------------------------------------------------
// Boot path
// ---------------------------------------------------------------------------

func TestModel_Init_ReturnsCommands(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-test", ViewWorker))
	cmd := m.Init()

	if cmd == nil {
		t.Fatal("Init() must return a command (tick + resolve batch)")
	}
}

// ---------------------------------------------------------------------------
// Mode selection
// ---------------------------------------------------------------------------

func TestModel_ModeSelection_Master(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-master-1", ViewMaster))
	updated, _ := m.Update(sessionMsg{id: "party-master-1", mode: ViewMaster})
	model := updated.(Model)

	if model.Mode != ViewMaster {
		t.Errorf("expected ViewMaster, got %v", model.Mode)
	}
	if model.SessionID != "party-master-1" {
		t.Errorf("expected session 'party-master-1', got %q", model.SessionID)
	}
}

func TestModel_ModeSelection_Worker(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-worker-1", ViewWorker))
	updated, _ := m.Update(sessionMsg{id: "party-worker-1", mode: ViewWorker})
	model := updated.(Model)

	if model.Mode != ViewWorker {
		t.Errorf("expected ViewWorker, got %v", model.Mode)
	}
}

// ---------------------------------------------------------------------------
// Narrow-width rendering
// ---------------------------------------------------------------------------

func TestModel_View_Compact(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-narrow", ViewWorker))
	m.SessionID = "party-narrow"
	m.Width = 40 // below compactThreshold
	m.Height = 24

	view := m.View()

	if !strings.Contains(view, "party-narrow") {
		t.Error("compact view should contain session ID")
	}
	if !strings.Contains(view, "worker") {
		t.Error("compact worker view should show 'worker' label")
	}
}

func TestModel_View_Wide(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-wide", ViewMaster))
	m.SessionID = "party-wide"
	m.Mode = ViewMaster
	m.Width = 120
	m.Height = 40

	view := m.View()

	if !strings.Contains(view, "Master:") {
		t.Error("wide master view should contain 'Master:' header")
	}
}

// ---------------------------------------------------------------------------
// Tick refresh
// ---------------------------------------------------------------------------

func TestModel_TickMsg_ReturnsCommand(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-tick", ViewWorker))
	m.SessionID = "party-tick"

	_, cmd := m.Update(tickMsg{})

	if cmd == nil {
		t.Fatal("tickMsg should return a command (resolve + next tick)")
	}
}

func TestModel_RefreshMsg_ReturnsCommand(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-refresh", ViewWorker))
	m.SessionID = "party-refresh"

	_, cmd := m.Update(refreshMsg{})

	if cmd == nil {
		t.Fatal("refreshMsg should return a resolve command")
	}
}

// ---------------------------------------------------------------------------
// Quit
// ---------------------------------------------------------------------------

func TestModel_QuitOnQ(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-q", ViewWorker))
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'q'}})

	if cmd == nil {
		t.Fatal("'q' should produce a quit command")
	}
}

func TestModel_QuitOnCtrlC(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-cc", ViewWorker))
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlC})

	if cmd == nil {
		t.Fatal("ctrl+c should produce a quit command")
	}
}

// ---------------------------------------------------------------------------
// WindowSizeMsg
// ---------------------------------------------------------------------------

func TestModel_WindowSizeMsg(t *testing.T) {
	t.Parallel()

	m := NewModelWithResolver(stubResolver("party-sz", ViewWorker))
	updated, _ := m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	model := updated.(Model)

	if model.Width != 80 {
		t.Errorf("expected Width=80, got %d", model.Width)
	}
	if model.Height != 24 {
		t.Errorf("expected Height=24, got %d", model.Height)
	}
}

// ---------------------------------------------------------------------------
// ViewMode stringer
// ---------------------------------------------------------------------------

func TestViewMode_String(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		mode ViewMode
		want string
	}{
		"worker":  {ViewWorker, "worker"},
		"master":  {ViewMaster, "master"},
		"unknown": {ViewMode(99), "unknown"},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			if got := tc.mode.String(); got != tc.want {
				t.Errorf("String(): got %q, want %q", got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func TestTruncate(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		s      string
		maxLen int
		want   string
	}{
		"no truncation":   {"hello", 10, "hello"},
		"exact fit":       {"hello", 5, "hello"},
		"truncated":       {"hello world", 8, "hello w\u2026"},
		"maxLen 1":        {"ab", 1, "\u2026"},
		"maxLen 0":        {"ab", 0, "ab"},
		"negative maxLen": {"ab", -1, "ab"},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			got := truncate(tc.s, tc.maxLen)
			if got != tc.want {
				t.Errorf("truncate(%q, %d): got %q, want %q", tc.s, tc.maxLen, got, tc.want)
			}
		})
	}
}

func TestInnerWidth(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		width int
		want  int
	}{
		"normal":    {80, 76},
		"narrow":    {12, 10},
		"very narrow": {8, 10},
		"zero":      {0, 10},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			m := Model{Width: tc.width}
			if got := m.innerWidth(); got != tc.want {
				t.Errorf("innerWidth() with Width=%d: got %d, want %d", tc.width, got, tc.want)
			}
		})
	}
}
