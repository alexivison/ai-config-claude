package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ANSI palette colors — inherits terminal theme automatically.
var (
	blue  = lipgloss.Color("4")
	green = lipgloss.Color("2")
	dim   = lipgloss.Color("8")
	red   = lipgloss.Color("1")
	fg    = lipgloss.Color("7")

	titleStyle    = lipgloss.NewStyle().Foreground(blue).Bold(true)
	activeStyle   = lipgloss.NewStyle().Foreground(green)
	stoppedStyle  = lipgloss.NewStyle().Foreground(red)
	dimStyle      = lipgloss.NewStyle().Foreground(dim)
	selectedStyle = lipgloss.NewStyle().Foreground(blue).Bold(true)
	snippetStyle  = lipgloss.NewStyle().Foreground(dim).PaddingLeft(6)
	footerStyle   = lipgloss.NewStyle().Foreground(dim)
	headerRule    = lipgloss.NewStyle().Foreground(dim)
)

type mode int

const (
	modeNormal mode = iota
	modeRelay
	modeBroadcast
	modeSpawn
)

type tickMsg time.Time
type refreshMsg struct{}

type model struct {
	masterID string
	workers  []Worker
	cursor   int
	mode     mode
	input    textinput.Model
	width    int
	height   int
	err      error
}

func initialModel(masterID string) model {
	ti := textinput.New()
	ti.CharLimit = 500
	ti.Width = 60

	return model{
		masterID: masterID,
		workers:  fetchWorkers(masterID),
		input:    ti,
	}
}

func tickCmd() tea.Cmd {
	return tea.Tick(3*time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m model) Init() tea.Cmd {
	return tickCmd()
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tickMsg, refreshMsg:
		m.workers = fetchWorkers(m.masterID)
		if m.cursor >= len(m.workers) {
			m.cursor = max(0, len(m.workers)-1)
		}
		if _, ok := msg.(tickMsg); ok {
			return m, tickCmd()
		}
		return m, nil

	case tea.KeyMsg:
		if m.mode != modeNormal {
			return m.updateInput(msg)
		}
		return m.updateNormal(msg)
	}

	return m, nil
}

func (m model) updateNormal(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "j", "down":
		if m.cursor < len(m.workers)-1 {
			m.cursor++
		}

	case "k", "up":
		if m.cursor > 0 {
			m.cursor--
		}

	case "enter":
		if len(m.workers) > 0 && m.workers[m.cursor].Status == "active" {
			_ = attachWorker(m.workers[m.cursor].ID)
			// Immediate refresh after returning
			m.workers = fetchWorkers(m.masterID)
		}

	case "r":
		if len(m.workers) > 0 {
			m.mode = modeRelay
			m.input.Placeholder = fmt.Sprintf("message to %s...", m.workers[m.cursor].ID)
			m.input.Reset()
			m.input.Focus()
			return m, textinput.Blink
		}

	case "b":
		m.mode = modeBroadcast
		m.input.Placeholder = "broadcast to all workers..."
		m.input.Reset()
		m.input.Focus()
		return m, textinput.Blink

	case "s":
		m.mode = modeSpawn
		m.input.Placeholder = "worker title..."
		m.input.Reset()
		m.input.Focus()
		return m, textinput.Blink

	case "x":
		if len(m.workers) > 0 {
			w := m.workers[m.cursor]
			_ = stopWorker(w.ID)
			m.workers = fetchWorkers(m.masterID)
			if m.cursor >= len(m.workers) {
				m.cursor = max(0, len(m.workers)-1)
			}
		}
	}

	return m, nil
}

func (m model) updateInput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.mode = modeNormal
		m.input.Blur()
		return m, nil

	case "enter":
		val := m.input.Value()
		if val != "" {
			switch m.mode {
			case modeRelay:
				if len(m.workers) > 0 {
					_ = relayMessage(m.workers[m.cursor].ID, val)
				}
			case modeBroadcast:
				_ = broadcastMessage(m.masterID, val)
			case modeSpawn:
				_ = spawnWorker(m.masterID, val)
			}
		}
		m.mode = modeNormal
		m.input.Blur()
		// Delayed refresh after action (non-blocking)
		return m, tea.Tick(500*time.Millisecond, func(time.Time) tea.Msg { return refreshMsg{} })
	}

	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)
	return m, cmd
}

func (m model) View() string {
	var b strings.Builder

	// Header
	workerCount := len(m.workers)
	header := titleStyle.Render(fmt.Sprintf("  Master: %s", m.masterID))
	count := dimStyle.Render(fmt.Sprintf("  %d worker(s)", workerCount))
	b.WriteString(header + count + "\n")
	b.WriteString(headerRule.Render("  " + strings.Repeat("─", max(40, m.width-4))) + "\n\n")

	// Worker list
	if workerCount == 0 {
		b.WriteString(dimStyle.Render("  No workers. Press 's' to spawn one.") + "\n")
	} else {
		for i, w := range m.workers {
			cursor := "  "
			nameStyle := dimStyle
			if i == m.cursor {
				cursor = selectedStyle.Render("▸ ")
				nameStyle = selectedStyle
			}

			// Status indicator
			var status string
			if w.Status == "active" {
				status = activeStyle.Render("● active")
			} else {
				status = stoppedStyle.Render("○ stopped")
			}

			// Worker line
			title := w.Title
			if title == "" {
				title = w.ID
			}
			line := fmt.Sprintf("%s%s  %s", cursor, nameStyle.Render(title), status)
			b.WriteString(line + "\n")

			// Snippet
			if w.Snippet != "" {
				b.WriteString(snippetStyle.Render(w.Snippet) + "\n")
			}

			b.WriteString("\n")
		}
	}

	// Footer
	b.WriteString(headerRule.Render("  " + strings.Repeat("─", max(40, m.width-4))) + "\n")

	if m.mode != modeNormal {
		// Input mode
		var label string
		switch m.mode {
		case modeRelay:
			label = "relay"
		case modeBroadcast:
			label = "broadcast"
		case modeSpawn:
			label = "spawn"
		}
		b.WriteString(fmt.Sprintf("  %s> %s\n", label, m.input.View()))
		b.WriteString(footerStyle.Render("  enter:send  esc:cancel") + "\n")
	} else {
		b.WriteString(footerStyle.Render("  j/k:nav  ⏎:attach  r:relay  b:bcast  s:spawn  x:stop  q:quit") + "\n")
	}

	return b.String()
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: party-tracker <master-session-id>\n")
		os.Exit(1)
	}

	masterID := os.Args[1]

	p := tea.NewProgram(
		initialModel(masterID),
		tea.WithAltScreen(),
	)

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
