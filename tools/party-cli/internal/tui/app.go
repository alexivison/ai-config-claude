package tui

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/anthropics/ai-config/tools/party-cli/internal/state"
)

// Option configures the TUI launch.
type Option func(*launchOpts)

type launchOpts struct {
	sessionOverride string
}

// WithSession forces a specific session ID instead of auto-discovery.
func WithSession(id string) Option {
	return func(o *launchOpts) { o.sessionOverride = id }
}

// Launch starts the Bubble Tea TUI application.
// When no options are provided, it auto-discovers the session from environment.
func Launch(opts ...Option) error {
	o := launchOpts{}
	for _, apply := range opts {
		apply(&o)
	}

	var m Model
	if o.sessionOverride != "" {
		m = NewModelWithResolver(staticResolver(o.sessionOverride))
	} else {
		m = newAutoModel()
	}

	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		return fmt.Errorf("tui: %w", err)
	}
	return nil
}

// staticResolver returns a resolver that reads the manifest for the given session
// to determine mode, falling back to worker if the manifest is unreadable.
func staticResolver(sessionID string) SessionResolver {
	return func() (string, ViewMode, error) {
		root := stateRoot()
		store, err := state.NewStore(root)
		if err != nil {
			return sessionID, ViewWorker, nil
		}
		manifest, err := store.Read(sessionID)
		if err != nil {
			return sessionID, ViewWorker, nil
		}
		if manifest.SessionType == "master" {
			return sessionID, ViewMaster, nil
		}
		return sessionID, ViewWorker, nil
	}
}

// newAutoModel builds a model using environment-derived state root.
// Falls back to a worker-mode fallback resolver if the store cannot be created.
func newAutoModel() Model {
	root := stateRoot()
	store, err := state.NewStore(root)
	if err != nil {
		return NewModelWithResolver(func() (string, ViewMode, error) {
			return "unknown", ViewWorker, nil
		})
	}
	return NewModel(store)
}

// stateRoot returns the party state directory from env or default.
func stateRoot() string {
	if root := os.Getenv("PARTY_STATE_ROOT"); root != "" {
		return root
	}
	home, _ := os.UserHomeDir()
	return home + "/.party-state"
}
