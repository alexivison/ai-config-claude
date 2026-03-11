package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// sessionScript resolves a script name to its full path.
// Uses PARTY_REPO_ROOT (set by party.sh launcher), falls back to bare name.
func sessionScript(name string) string {
	if root := os.Getenv("PARTY_REPO_ROOT"); root != "" {
		candidate := filepath.Join(root, "session", name)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return name
}

// attachWorker switches the tmux client to the worker session.
func attachWorker(workerID string) error {
	cmd := exec.Command("tmux", "switch-client", "-t", workerID)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// relayMessage sends a message to a worker's Claude pane.
// Uses the direct relay path (no master session validation needed).
func relayMessage(workerID, message string) error {
	return exec.Command("bash", sessionScript("party-relay.sh"), workerID, message).Run()
}

// broadcastMessage sends a message to all workers' Claude panes.
func broadcastMessage(masterID, message string) error {
	cmd := exec.Command("bash", sessionScript("party-relay.sh"), "--broadcast", message)
	cmd.Env = append(os.Environ(), fmt.Sprintf("PARTY_SESSION=%s", masterID))
	return cmd.Run()
}

// spawnWorker creates a new worker session under the master.
func spawnWorker(masterID, title string) error {
	args := []string{sessionScript("party.sh"), "--detached", "--master-id", masterID, "--"}
	if title != "" {
		args = append(args, title)
	}
	cmd := exec.Command("bash", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// stopWorker stops a worker session.
func stopWorker(workerID string) error {
	cmd := exec.Command("bash", sessionScript("party.sh"), "--stop", workerID)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
