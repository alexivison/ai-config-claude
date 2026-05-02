//go:build linux || darwin

package session

import (
	"context"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func initRepo(t *testing.T, dir string) {
	t.Helper()
	for _, args := range [][]string{
		{"init", "--initial-branch=main"},
		{
			"-c", "user.email=t@t",
			"-c", "user.name=t",
			"-c", "commit.gpgsign=false",
			"-c", "gpg.format=openpgp",
			"commit", "--allow-empty", "-m", "init",
		},
	} {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
		}
	}
}

func TestEnsureWorktree_CreatesWorktree(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	repo := filepath.Join(root, "myrepo")
	if err := exec.Command("mkdir", "-p", repo).Run(); err != nil {
		t.Fatal(err)
	}
	initRepo(t, repo)

	path, err := EnsureWorktree(t.Context(), WorktreeOpts{
		Cwd:    repo,
		Branch: "feat/x",
		Title:  "ignored",
	})
	if err != nil {
		t.Fatalf("EnsureWorktree: %v", err)
	}
	want := filepath.Join(root, "myrepo-feat-x")
	if path != want {
		t.Errorf("worktree path = %q, want %q", path, want)
	}
}

func TestEnsureWorktree_ReusesNonMainWorktree(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	repo := filepath.Join(root, "myrepo")
	if err := exec.Command("mkdir", "-p", repo).Run(); err != nil {
		t.Fatal(err)
	}
	initRepo(t, repo)

	// Create a worktree manually, then ask EnsureWorktree from inside it.
	cmd := exec.Command("git", "worktree", "add", "../myrepo-existing", "-b", "existing")
	cmd.Dir = repo
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git worktree add: %v\n%s", err, out)
	}
	insideWorktree := filepath.Join(root, "myrepo-existing")

	path, err := EnsureWorktree(t.Context(), WorktreeOpts{
		Cwd:    insideWorktree,
		Branch: "ignored",
	})
	if err != nil {
		t.Fatalf("EnsureWorktree: %v", err)
	}
	if path != insideWorktree {
		t.Errorf("expected reuse of %q, got %q", insideWorktree, path)
	}
}

func TestEnsureWorktree_NotGitRepo(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	_, err := EnsureWorktree(context.Background(), WorktreeOpts{Cwd: dir, Branch: "x"})
	if err == nil {
		t.Fatal("expected error when not in a git repo")
	}
}

func TestSanitizeBranchName(t *testing.T) {
	t.Parallel()
	cases := map[string]string{
		"feature/foo":    "feature/foo",
		"My Title Here":  "My-Title-Here",
		"  spaces  ":     "spaces",
		"weird!@#chars$": "weird-chars",
		"":               "",
	}
	for in, want := range cases {
		if got := sanitizeBranchName(in); got != want {
			t.Errorf("sanitizeBranchName(%q) = %q, want %q", in, got, want)
		}
	}
}
