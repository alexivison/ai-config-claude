package session

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// ErrNotGitRepo is returned when worktree creation is requested but the
// directory is not inside a git working tree.
var ErrNotGitRepo = errors.New("not inside a git repository")

// WorktreeOpts configures a worktree creation request.
type WorktreeOpts struct {
	// Cwd is the directory used to locate the repo root. Required.
	Cwd string
	// Branch is the branch to create or check out in the new worktree.
	// When empty, a name is derived from Title (or a timestamp fallback).
	Branch string
	// Title is the human-readable session title; used to derive a branch
	// name when Branch is empty.
	Title string
}

// EnsureWorktree creates a git worktree near the repo root and returns
// its absolute path. If the cwd is already a non-main worktree, the
// existing path is returned unchanged.
//
// Path layout: <repo-parent>/<repo-name>-<branch-slug>. If that path
// already exists as a worktree, it is reused.
func EnsureWorktree(ctx context.Context, opts WorktreeOpts) (string, error) {
	if opts.Cwd == "" {
		return "", fmt.Errorf("worktree: cwd is required")
	}

	mainRoot, currentRoot, err := gitRoots(ctx, opts.Cwd)
	if err != nil {
		return "", err
	}
	if mainRoot != currentRoot {
		// Already in a non-main worktree — reuse it.
		return currentRoot, nil
	}

	branch := opts.Branch
	if branch == "" {
		branch = deriveBranchName(opts.Title)
	}
	branch = sanitizeBranchName(branch)
	if branch == "" {
		return "", fmt.Errorf("worktree: empty branch name after sanitization")
	}

	repoName := filepath.Base(mainRoot)
	worktreePath := filepath.Join(filepath.Dir(mainRoot), repoName+"-"+strings.ReplaceAll(branch, "/", "-"))

	if existing, ok := existingWorktreePath(ctx, mainRoot, worktreePath, branch); ok {
		return existing, nil
	}

	if out, err := runGit(ctx, mainRoot, "worktree", "add", worktreePath, "-b", branch); err != nil {
		// Branch may already exist; retry without -b.
		out2, err2 := runGit(ctx, mainRoot, "worktree", "add", worktreePath, branch)
		if err2 != nil {
			return "", fmt.Errorf("git worktree add %s: %w\n%s\n%s", worktreePath, err2, strings.TrimSpace(out), strings.TrimSpace(out2))
		}
	}
	return worktreePath, nil
}

// gitRoots returns the main worktree root and the current worktree root
// for the given directory. They differ when cwd is in a linked worktree.
func gitRoots(ctx context.Context, cwd string) (mainRoot, currentRoot string, err error) {
	current, err := runGit(ctx, cwd, "rev-parse", "--show-toplevel")
	if err != nil {
		return "", "", fmt.Errorf("%w: %s", ErrNotGitRepo, strings.TrimSpace(current))
	}
	currentRoot = strings.TrimSpace(current)

	gitCommonDir, err := runGit(ctx, cwd, "rev-parse", "--git-common-dir")
	if err != nil {
		return "", "", fmt.Errorf("git rev-parse --git-common-dir: %w", err)
	}
	commonDir := strings.TrimSpace(gitCommonDir)
	if !filepath.IsAbs(commonDir) {
		commonDir = filepath.Join(currentRoot, commonDir)
	}
	// commonDir is the .git directory of the main worktree; its parent is
	// the main worktree root.
	mainRoot = filepath.Dir(commonDir)
	return mainRoot, currentRoot, nil
}

// existingWorktreePath returns the path of an existing worktree that
// matches either the desired path or branch, if any.
func existingWorktreePath(ctx context.Context, repoRoot, desiredPath, branch string) (string, bool) {
	out, err := runGit(ctx, repoRoot, "worktree", "list", "--porcelain")
	if err != nil {
		return "", false
	}
	var path string
	branchRef := "refs/heads/" + branch
	for _, line := range strings.Split(out, "\n") {
		switch {
		case strings.HasPrefix(line, "worktree "):
			path = strings.TrimPrefix(line, "worktree ")
		case strings.HasPrefix(line, "branch "):
			ref := strings.TrimPrefix(line, "branch ")
			if path == desiredPath || ref == branchRef {
				return path, true
			}
		case line == "":
			path = ""
		}
	}
	if _, err := os.Stat(desiredPath); err == nil {
		return desiredPath, true
	}
	return "", false
}

// runGit runs a git command in the given directory and returns its
// combined stdout/stderr output.
func runGit(ctx context.Context, dir string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	return string(out), err
}

var branchSanitizeRe = regexp.MustCompile(`[^a-zA-Z0-9._/-]+`)

func sanitizeBranchName(name string) string {
	name = strings.TrimSpace(name)
	name = strings.ReplaceAll(name, " ", "-")
	name = branchSanitizeRe.ReplaceAllString(name, "-")
	name = strings.Trim(name, "-./")
	return name
}

func deriveBranchName(title string) string {
	if s := sanitizeBranchName(title); s != "" {
		return s
	}
	return fmt.Sprintf("session-%d", time.Now().Unix())
}
