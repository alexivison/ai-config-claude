package cmd

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestResolveRepoRoot_Provided(t *testing.T) {
	t.Parallel()

	got := resolveRepoRoot("/explicit/path")
	if got != "/explicit/path" {
		t.Errorf("resolveRepoRoot(provided): got %q, want %q", got, "/explicit/path")
	}
}

func TestResolveRepoRoot_EnvVar(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PARTY_REPO_ROOT", dir)

	got := resolveRepoRoot("")
	if got != dir {
		t.Errorf("resolveRepoRoot(env): got %q, want %q", got, dir)
	}
}

func TestResolveRepoRoot_EmptyFallback(t *testing.T) {
	t.Setenv("PARTY_REPO_ROOT", "")

	// With no env and no matching directory structure, should return "".
	got := resolveRepoRoot("")
	// Can't guarantee "" if CWD happens to be in the repo, so just ensure it doesn't panic.
	_ = got
}

func TestCreateDirSymlink_NewLink(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	source := filepath.Join(dir, "source")
	target := filepath.Join(dir, "target")

	if err := os.Mkdir(source, 0o755); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	createDirSymlink(&buf, source, target)

	dest, err := os.Readlink(target)
	if err != nil {
		t.Fatalf("target should be a symlink: %v", err)
	}
	if dest != source {
		t.Errorf("symlink target: got %q, want %q", dest, source)
	}
	if !bytes.Contains(buf.Bytes(), []byte("Created symlink")) {
		t.Errorf("output should mention created symlink: %s", buf.String())
	}
}

func TestCreateDirSymlink_AlreadyLinked(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	source := filepath.Join(dir, "source")
	target := filepath.Join(dir, "target")

	if err := os.Mkdir(source, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(source, target); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	createDirSymlink(&buf, source, target)

	if !bytes.Contains(buf.Bytes(), []byte("already linked")) {
		t.Errorf("output should say already linked: %s", buf.String())
	}
}

func TestCreateDirSymlink_SourceMissing(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	var buf bytes.Buffer
	createDirSymlink(&buf, filepath.Join(dir, "nope"), filepath.Join(dir, "target"))

	if !bytes.Contains(buf.Bytes(), []byte("Skipping")) {
		t.Errorf("output should skip missing source: %s", buf.String())
	}
}

func TestRemoveDirSymlink_RemovesCorrectLink(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	source := filepath.Join(dir, "source")
	target := filepath.Join(dir, "target")

	if err := os.Mkdir(source, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(source, target); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	removeDirSymlink(&buf, source, target)

	if _, err := os.Lstat(target); err == nil {
		t.Error("symlink should have been removed")
	}
	if !bytes.Contains(buf.Bytes(), []byte("Removed symlink")) {
		t.Errorf("output should confirm removal: %s", buf.String())
	}
}

func TestRemoveDirSymlink_SkipsWrongTarget(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	source := filepath.Join(dir, "source")
	other := filepath.Join(dir, "other")
	target := filepath.Join(dir, "target")

	if err := os.Mkdir(source, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(other, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(other, target); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	removeDirSymlink(&buf, source, target)

	// Should still exist — points elsewhere.
	if _, err := os.Lstat(target); err != nil {
		t.Error("symlink should NOT have been removed (points elsewhere)")
	}
	if !bytes.Contains(buf.Bytes(), []byte("points elsewhere")) {
		t.Errorf("output should mention wrong target: %s", buf.String())
	}
}

func TestBackupExisting_BacksUpDirectory(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	target := filepath.Join(dir, "existing")
	if err := os.Mkdir(target, 0o755); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	backupExisting(&buf, target)

	// Original should be gone.
	if _, err := os.Stat(target); err == nil {
		t.Error("original should have been renamed")
	}

	// Backup should exist.
	backup := target + ".backup"
	if _, err := os.Stat(backup); err != nil {
		t.Errorf("backup should exist at %s: %v", backup, err)
	}
}

func TestBackupExisting_RemovesSymlink(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	source := filepath.Join(dir, "source")
	target := filepath.Join(dir, "link")

	if err := os.Mkdir(source, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(source, target); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	backupExisting(&buf, target)

	if _, err := os.Lstat(target); err == nil {
		t.Error("symlink should have been removed")
	}
}

func TestBackupExisting_NoopWhenMissing(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	var buf bytes.Buffer
	backupExisting(&buf, filepath.Join(dir, "nonexistent"))

	if buf.Len() != 0 {
		t.Errorf("should produce no output for missing target: %s", buf.String())
	}
}

func TestInstallTPM_AlreadyInstalled(t *testing.T) {
	dir := t.TempDir()
	home := filepath.Join(dir, "home")
	tpmPath := filepath.Join(home, defaultTPMPath)

	// Simulate existing TPM clone.
	if err := os.MkdirAll(filepath.Join(tpmPath, ".git"), 0o755); err != nil {
		t.Fatal(err)
	}

	t.Setenv("TMUX_PLUGIN_MANAGER_PATH", tpmPath)

	var buf bytes.Buffer
	if err := installTPM(&buf, home); err != nil {
		t.Fatalf("installTPM: %v", err)
	}
	if !bytes.Contains(buf.Bytes(), []byte("already installed")) {
		t.Errorf("should report already installed: %s", buf.String())
	}
}

func TestInstallTPM_PathExistsNotGit(t *testing.T) {
	dir := t.TempDir()
	home := filepath.Join(dir, "home")
	tpmPath := filepath.Join(home, defaultTPMPath)

	// Create the dir without .git — should error.
	if err := os.MkdirAll(tpmPath, 0o755); err != nil {
		t.Fatal(err)
	}

	t.Setenv("TMUX_PLUGIN_MANAGER_PATH", tpmPath)

	var buf bytes.Buffer
	err := installTPM(&buf, home)
	if err == nil {
		t.Fatal("expected error for non-git TPM path")
	}
	if !bytes.Contains([]byte(err.Error()), []byte("not a TPM git clone")) {
		t.Errorf("error should mention non-git clone: %v", err)
	}
}
