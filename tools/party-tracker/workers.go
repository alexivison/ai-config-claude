package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Worker represents a party worker session.
type Worker struct {
	ID      string
	Title   string
	Status  string // "active" or "stopped"
	Snippet string // last meaningful line from Claude pane
}

// manifest is the subset of party manifest fields we need.
type manifest struct {
	Workers []string `json:"workers"`
	Title   string   `json:"title"`
}

func stateRoot() string {
	if root := os.Getenv("PARTY_STATE_ROOT"); root != "" {
		return root
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".party-state")
}

func manifestPath(sessionID string) string {
	return filepath.Join(stateRoot(), sessionID+".json")
}

func readManifest(sessionID string) (manifest, error) {
	var m manifest
	data, err := os.ReadFile(manifestPath(sessionID))
	if err != nil {
		return m, err
	}
	err = json.Unmarshal(data, &m)
	return m, err
}

// readManifestPretty returns the manifest JSON pretty-printed for display.
func readManifestPretty(sessionID string) (string, error) {
	data, err := os.ReadFile(manifestPath(sessionID))
	if err != nil {
		return "", err
	}
	var raw json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return string(data), nil // return raw if not valid JSON
	}
	pretty, err := json.MarshalIndent(raw, "", "  ")
	if err != nil {
		return string(data), nil
	}
	return string(pretty), nil
}

// fetchWorkers reads the master manifest and returns worker status.
func fetchWorkers(masterID string) []Worker {
	m, err := readManifest(masterID)
	if err != nil || len(m.Workers) == 0 {
		return nil
	}

	// Batch: get all live tmux sessions at once
	liveSessions := make(map[string]bool)
	out, err := exec.Command("tmux", "list-sessions", "-F", "#{session_name}").Output()
	if err == nil {
		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			liveSessions[line] = true
		}
	}

	workers := make([]Worker, 0, len(m.Workers))
	for _, wid := range m.Workers {
		w := Worker{ID: wid}

		// Title from worker manifest
		wm, err := readManifest(wid)
		if err == nil {
			w.Title = wm.Title
		}

		// Status from tmux
		if liveSessions[wid] {
			w.Status = "active"
			w.Snippet = captureSnippet(wid)
		} else {
			w.Status = "stopped"
		}

		workers = append(workers, w)
	}

	return workers
}

// captureSnippet grabs the last few meaningful lines from the Claude pane.
func captureSnippet(sessionID string) string {
	// Find the Claude pane (role=claude)
	paneOut, err := exec.Command("tmux", "list-panes", "-t", sessionID+":0",
		"-F", "#{pane_index} #{@party_role}").Output()
	if err != nil {
		return ""
	}

	claudePane := ""
	for _, line := range strings.Split(strings.TrimSpace(string(paneOut)), "\n") {
		parts := strings.SplitN(line, " ", 2)
		if len(parts) == 2 && parts[1] == "claude" {
			claudePane = parts[0]
			break
		}
	}
	if claudePane == "" {
		return ""
	}

	target := fmt.Sprintf("%s:0.%s", sessionID, claudePane)
	captured, err := exec.Command("tmux", "capture-pane", "-t", target, "-p", "-S", "-500").Output()
	if err != nil {
		return ""
	}

	// Filter for meaningful lines (agent actions and user prompts)
	lines := strings.Split(string(captured), "\n")
	var meaningful []string
	for _, l := range lines {
		trimmed := strings.TrimSpace(l)
		if strings.HasPrefix(trimmed, "\u23fa") || strings.HasPrefix(trimmed, "\u276f") {
			if trimmed != "\u23fa" && trimmed != "\u276f" {
				meaningful = append(meaningful, trimmed)
			}
		}
	}

	if len(meaningful) == 0 {
		return ""
	}
	// Take last 4 meaningful lines
	start := len(meaningful) - 4
	if start < 0 {
		start = 0
	}
	return strings.Join(meaningful[start:], "\n")
}

