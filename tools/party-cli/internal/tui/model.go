package tui

import (
	"fmt"
	"os"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/anthropics/ai-config/tools/party-cli/internal/state"
)

// ViewMode determines which top-level view the TUI renders.
type ViewMode int

const (
	// ViewWorker renders the worker/standalone sidebar shell.
	ViewWorker ViewMode = iota
	// ViewMaster renders the master tracker shell.
	ViewMaster
)

func (v ViewMode) String() string {
	switch v {
	case ViewWorker:
		return "worker"
	case ViewMaster:
		return "master"
	default:
		return "unknown"
	}
}

// pollInterval is the standard tick cadence for data refresh.
const pollInterval = 3 * time.Second

// tickMsg triggers a periodic refresh.
type tickMsg time.Time

// refreshMsg triggers an immediate one-shot refresh.
type refreshMsg struct{}

// SessionResolver discovers the current session and its mode.
// Injected for testability — production code auto-discovers from PARTY_SESSION env.
type SessionResolver func() (sessionID string, mode ViewMode, err error)

// Model is the shared Bubble Tea model for the party-cli TUI.
type Model struct {
	SessionID string
	Mode      ViewMode
	Width     int
	Height    int

	resolver SessionResolver
}

// NewModel creates a Model with auto-discovery from environment and state store.
func NewModel(store *state.Store) Model {
	return Model{
		resolver: newAutoResolver(store),
	}
}

// NewModelWithResolver creates a Model with an injected resolver for testing.
func NewModelWithResolver(resolver SessionResolver) Model {
	return Model{resolver: resolver}
}

// Init discovers the session and starts the polling loop.
func (m Model) Init() tea.Cmd {
	return tea.Batch(m.resolveSession(), tickCmd())
}

// Update handles messages for the shared TUI shell.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.Width = msg.Width
		m.Height = msg.Height
		return m, nil

	case sessionMsg:
		m.SessionID = msg.id
		m.Mode = msg.mode
		return m, nil

	case tickMsg, refreshMsg:
		cmd := m.resolveSession()
		if _, ok := msg.(tickMsg); ok {
			return m, tea.Batch(cmd, tickCmd())
		}
		return m, cmd

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		}
	}

	return m, nil
}

// View renders the current TUI state.
func (m Model) View() string {
	var b strings.Builder
	inner := m.innerWidth()
	compact := m.Width > 0 && m.Width < compactThreshold

	// Header
	switch m.Mode {
	case ViewMaster:
		if compact {
			b.WriteString(titleStyle.Render(truncate(fmt.Sprintf(" %s", m.SessionID), inner)) + "\n")
			b.WriteString(dimStyle.Render(" master") + "\n")
		} else {
			b.WriteString(titleStyle.Render(fmt.Sprintf("  Master: %s", m.SessionID)) + "\n")
		}
	case ViewWorker:
		if compact {
			b.WriteString(titleStyle.Render(truncate(fmt.Sprintf(" %s", m.SessionID), inner)) + "\n")
			b.WriteString(dimStyle.Render(" worker") + "\n")
		} else {
			b.WriteString(titleStyle.Render(fmt.Sprintf("  Worker: %s", m.SessionID)) + "\n")
		}
	}
	b.WriteString(headerRule.Render("  " + strings.Repeat("\u2500", inner)) + "\n\n")

	// Placeholder body — final views are added by Task 12 (worker) and Task 13 (master)
	b.WriteString(dimStyle.Render("  (view pending)") + "\n\n")

	// Footer
	b.WriteString(headerRule.Render("  " + strings.Repeat("\u2500", inner)) + "\n")
	if compact {
		b.WriteString(footerStyle.Render(" q:quit") + "\n")
	} else {
		b.WriteString(footerStyle.Render("  q:quit") + "\n")
	}

	return b.String()
}

// innerWidth returns usable content width after padding.
func (m Model) innerWidth() int {
	w := m.Width - 4 // 2 char padding each side
	if w < 10 {
		w = 10
	}
	return w
}

// truncate cuts a string to maxLen, adding ellipsis if needed.
func truncate(s string, maxLen int) string {
	if maxLen <= 0 || len(s) <= maxLen {
		return s
	}
	if maxLen <= 1 {
		return "\u2026"
	}
	return s[:maxLen-1] + "\u2026"
}

func tickCmd() tea.Cmd {
	return tea.Tick(pollInterval, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

// sessionMsg carries resolved session info from the async resolver.
type sessionMsg struct {
	id   string
	mode ViewMode
}

func (m Model) resolveSession() tea.Cmd {
	resolver := m.resolver
	return func() tea.Msg {
		id, mode, err := resolver()
		if err != nil {
			return sessionMsg{id: "unknown", mode: ViewWorker}
		}
		return sessionMsg{id: id, mode: mode}
	}
}

// newAutoResolver builds a SessionResolver that reads PARTY_SESSION env
// and checks the manifest's session_type to determine mode.
func newAutoResolver(store *state.Store) SessionResolver {
	return func() (string, ViewMode, error) {
		sessionID := os.Getenv("PARTY_SESSION")
		if sessionID == "" {
			return "", ViewWorker, fmt.Errorf("PARTY_SESSION not set")
		}

		m, err := store.Read(sessionID)
		if err != nil {
			return sessionID, ViewWorker, nil
		}

		if m.SessionType == "master" {
			return sessionID, ViewMaster, nil
		}
		return sessionID, ViewWorker, nil
	}
}
