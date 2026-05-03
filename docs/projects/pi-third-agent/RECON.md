# Pi Phase 0 Reconnaissance

Plan source: `docs/projects/pi-third-agent/PLAN.md`, Phase 0.

Binary under test: `/opt/homebrew/bin/pi`, version `0.72.1`.

No successful model call was made during this reconnaissance. Prompt-invoking commands were run with a temporary `PI_CODING_AGENT_DIR`, `PI_OFFLINE=1`, and provider API key environment variables unset; those commands failed before a provider request because no API key was available.

### 0.1

Question: Do `--append-system-prompt`, `--no-session`, `--session <id>`, `--mode json`, `--mode rpc`, `--thinking <level>` exist? Is `--session` a flag (Claude-style) or positional subcommand (Codex-style `resume <id>`)? Does the master pane support high effort?

Commands:

```sh
/opt/homebrew/bin/pi --version
/opt/homebrew/bin/pi --help
```

Captured output:

```text
0.72.1
```

```text
Usage:
  pi [options] [@files...] [messages...]

Options:
  --append-system-prompt <text>  Append text or file contents to the system prompt (can be used multiple times)
  --mode <mode>                  Output mode: text (default), json, or rpc
  --print, -p                    Non-interactive mode: process prompt and exit
  --continue, -c                 Continue previous session
  --resume, -r                   Select a session to resume
  --session <path|id>            Use specific session file or partial UUID
  --fork <path|id>               Fork specific session file or partial UUID into a new session
  --session-dir <dir>            Directory for session storage and lookup
  --no-session                   Don't save session (ephemeral)
  --thinking <level>             Set thinking level: off, minimal, low, medium, high, xhigh
```

Decision: This unblocks the Phase 1 `BuildCmd` branch that uses Pi flags directly. `--session` is a flag taking `<path|id>`, not a positional `resume <id>` subcommand. `--mode json`, `--mode rpc`, `--append-system-prompt`, and `--no-session` are available. Master panes can request high effort with `--thinking high`.

### 0.2

Question: What does a Pi session ID look like? Path, UUID, short token, or none-exposed?

Commands:

```sh
ls -la ~/.pi/agent/sessions
find ~/.pi/agent/sessions -maxdepth 3 -type f -print -exec ls -l {} \;
sed -n '1,6p' ~/.pi/agent/sessions/--Users-aleksituominen-Code-ai-party--/2026-05-03T15-16-13-988Z_019dee69-5623-75c9-9317-04bf7f94e92b.jsonl

TMPAGENT=$(mktemp -d)
env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_OAUTH_TOKEN -u GEMINI_API_KEY \
  PI_CODING_AGENT_DIR="$TMPAGENT" PI_OFFLINE=1 \
  /opt/homebrew/bin/pi --provider openai --model gpt-4o-mini --mode json -p "hi"
```

Captured output:

```text
/Users/aleksituominen/.pi/agent/sessions:
total 0
drwxr-xr-x@ 3 aleksituominen  staff   96 May  4 00:17 --Users-aleksituominen-Code-ai-party--
```

```text
/Users/aleksituominen/.pi/agent/sessions/--Users-aleksituominen-Code-ai-party--/2026-05-03T15-16-13-988Z_019dee69-5623-75c9-9317-04bf7f94e92b.jsonl
-rw-r--r--@ 1 aleksituominen  staff  1327 May  4 00:17 /Users/aleksituominen/.pi/agent/sessions/--Users-aleksituominen-Code-ai-party--/2026-05-03T15-16-13-988Z_019dee69-5623-75c9-9317-04bf7f94e92b.jsonl
```

```json
{"type":"session","version":3,"id":"019dee69-5623-75c9-9317-04bf7f94e92b","timestamp":"2026-05-03T15:16:13.988Z","cwd":"/Users/aleksituominen/Code/ai-party"}
{"type":"thinking_level_change","id":"39634324","parentId":null,"timestamp":"2026-05-03T15:16:13.994Z","thinkingLevel":"off"}
{"type":"model_change","id":"9f933fb7","parentId":"39634324","timestamp":"2026-05-03T15:16:29.698Z","provider":"anthropic","modelId":"claude-opus-4-7"}
```

```text
{"type":"session","version":3,"id":"019dee81-6581-7171-a5a5-4472fb1dda49","timestamp":"2026-05-03T15:42:30.786Z","cwd":"/Users/aleksituominen/Code/ai-party-pi-recon"}
No API key found for openai.
```

Decision: This unblocks Phase 3 branch 1. Pi exposes UUIDv7-style IDs containing lowercase hex and hyphens, for example `019dee69-5623-75c9-9317-04bf7f94e92b`; those match the planned `[A-Za-z0-9_-]+` resume ID shape. The session file path includes the timestamp and UUID, but `--session <partial UUID>` can address the session, so the manifest should store the UUID, not a path.

### 0.3

Question: Does `--session <id> --append-system-prompt "..."` re-apply the prompt cleanly on resume?

Commands:

```sh
SESSION_FILE="$HOME/.pi/agent/sessions/--Users-aleksituominen-Code-ai-party--/2026-05-03T15-16-13-988Z_019dee69-5623-75c9-9317-04bf7f94e92b.jsonl"
wc -l "$SESSION_FILE"

env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_OAUTH_TOKEN \
  PI_OFFLINE=1 \
  /opt/homebrew/bin/pi --mode json --session 019dee69 \
  --append-system-prompt "RECON_SYSTEM_PROMPT" -p

wc -l "$SESSION_FILE"

sed -n '320,342p' /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/resource-loader.js
sed -n '650,674p' /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/agent-session.js
```

Captured output:

```text
before:
       6 /Users/aleksituominen/.pi/agent/sessions/--Users-aleksituominen-Code-ai-party--/2026-05-03T15-16-13-988Z_019dee69-5623-75c9-9317-04bf7f94e92b.jsonl
{"type":"session","version":3,"id":"019dee69-5623-75c9-9317-04bf7f94e92b","timestamp":"2026-05-03T15:16:13.988Z","cwd":"/Users/aleksituominen/Code/ai-party"}
after:
       6 /Users/aleksituominen/.pi/agent/sessions/--Users-aleksituominen-Code-ai-party--/2026-05-03T15-16-13-988Z_019dee69-5623-75c9-9317-04bf7f94e92b.jsonl
```

```js
const appendSources = this.appendSystemPromptSource ??
    (this.discoverAppendSystemPromptFile() ? [this.discoverAppendSystemPromptFile()] : []);
const baseAppend = appendSources
    .map((s) => resolvePromptInput(s, "append system prompt"))
    .filter((s) => s !== undefined);
this.appendSystemPrompt = this.appendSystemPromptOverride
    ? this.appendSystemPromptOverride(baseAppend)
    : baseAppend;
```

```js
const loaderSystemPrompt = this._resourceLoader.getSystemPrompt();
const loaderAppendSystemPrompt = this._resourceLoader.getAppendSystemPrompt();
const appendSystemPrompt = loaderAppendSystemPrompt.length > 0 ? loaderAppendSystemPrompt.join("\n\n") : undefined;
this._baseSystemPromptOptions = {
    cwd: this._cwd,
    skills: loadedSkills,
    contextFiles: loadedContextFiles,
    customPrompt: loaderSystemPrompt,
    appendSystemPrompt,
```

Decision: This unblocks the `continue.go` branch that passes `MasterPrompt()`/`WorkerPrompt()` every launch. The local binary accepts `--session <partial UUID>` together with `--append-system-prompt`; opening the resumed session without a prompt leaves the session file unchanged. The installed source applies appended prompt text from CLI/resource-loader state when constructing runtime system-prompt options, not by appending it to the persisted JSONL history. A semantic model-level duplicate-prompt check was not run because that would require a real model call.

### 0.4

Question: What does `pi --mode json -p "list files"` actually emit?

Commands:

```sh
TMPAGENT=$(mktemp -d)
OUT=$(mktemp)
ERR=$(mktemp)
env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_OAUTH_TOKEN -u GEMINI_API_KEY \
  PI_CODING_AGENT_DIR="$TMPAGENT" PI_OFFLINE=1 \
  /opt/homebrew/bin/pi --provider openai --model gpt-4o-mini \
  --mode json -p "list files" >"$OUT" 2>"$ERR"
echo "exit=$?"
sed -n '1,20p' "$OUT"
sed -n '1,20p' "$ERR"

sed -n '1,120p' /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/modes/print-mode.js
```

Captured output:

```text
exit=1
stdout:
{"type":"session","version":3,"id":"019dee82-5167-7469-ba29-5ce0cf013d70","timestamp":"2026-05-03T15:43:31.177Z","cwd":"/Users/aleksituominen/Code/ai-party-pi-recon"}
stderr:
No API key found for openai.

Use /login to log into a provider via OAuth or API key. See:
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/docs/providers.md
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/docs/models.md
```

```js
unsubscribe = session.subscribe((event) => {
    if (mode === "json") {
        writeRawStdout(`${JSON.stringify(event)}\n`);
    }
});
...
if (mode === "json") {
    const header = session.sessionManager.getHeader();
    if (header) {
        writeRawStdout(`${JSON.stringify(header)}\n`);
    }
}
```

Decision: This partially unblocks Phase 2 branch 1, but with a caveat. The binary really does emit a JSON session header on stdout in `--mode json`, and the installed print-mode implementation writes subscribed session events as JSONL. However, a successful assistant/tool event stream for `"list files"` was not verified because the constraints prohibited a real model call. If Phase 2 requires only fully runtime-observed evidence, choose Phase 2 branch 3 (raw capture fallback) until an API-backed smoke test confirms event schemas; if local source inspection is accepted, JSON sidecar is the preferred implementation branch with stderr/raw fallback for startup errors.

### 0.5

Question: What does an interactive Pi pane look like under `tmux capture-pane`? Glyph prefixes? Differential render artifacts?

Commands:

```sh
SESSION=pi-recon-$$
TMPAGENT=$(mktemp -d)
tmux new-session -d -s "$SESSION" -x 100 -y 32 \
  -c /Users/aleksituominen/Code/ai-party-pi-recon \
  "env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_OAUTH_TOKEN -u GEMINI_API_KEY PI_CODING_AGENT_DIR='$TMPAGENT' PI_OFFLINE=1 /opt/homebrew/bin/pi --provider openai --model gpt-4o-mini --api-key invalid --no-tools --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes"
sleep 2
tmux capture-pane -t "$SESSION:0.0" -p -S -200
tmux send-keys -t "$SESSION:0.0" -l "!pwd"
tmux send-keys -t "$SESSION:0.0" Enter
sleep 2
tmux capture-pane -t "$SESSION:0.0" -p -S -200
tmux kill-session -t "$SESSION"
```

Captured output:

```text
initial capture:

 pi v0.72.1
 escape interrupt · ctrl+c/ctrl+d clear/exit · / commands · ! bash · ctrl+o more
 Press ctrl+o to show full startup help and loaded resources.

 Pi can explain its own features and look up its docs. Ask it how to use or extend Pi.


────────────────────────────────────────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────────────────────────────────────────
~/Code/ai-party-pi-recon (pi-recon)
0.0%/128k (auto)                                                                         gpt-4o-mini
```

```text
after !pwd capture:

 pi v0.72.1
 escape interrupt · ctrl+c/ctrl+d clear/exit · / commands · ! bash · ctrl+o more
 Press ctrl+o to show full startup help and loaded resources.

 Pi can explain its own features and look up its docs. Ask it how to use or extend Pi.


────────────────────────────────────────────────────────────────────────────────────────────────────
 $ pwd

 /Users/aleksituominen/Code/ai-party-pi-recon

────────────────────────────────────────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────────────────────────────────────────
~/Code/ai-party-pi-recon (pi-recon)
0.0%/128k (auto)                                                                         gpt-4o-mini
```

Decision: This blocks Phase 2 branch 2. The captured pane is readable, but there are no stable Claude/Codex-style glyph prefixes to filter. The TUI emits separators, footer state, and `$ <command>` lines for local bash commands. If Phase 2 does not take the JSON sidecar branch from 0.4, the safe branch is Phase 2 branch 3: return raw last-N lines for Pi with a short raw-output header.

### 0.6

Question: How is the initial user-turn prompt delivered? Positional arg, stdin, dedicated flag?

Commands:

```sh
TMP1=$(mktemp -d)
env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_OAUTH_TOKEN -u GEMINI_API_KEY \
  PI_CODING_AGENT_DIR="$TMP1" PI_OFFLINE=1 \
  /opt/homebrew/bin/pi --provider openai --model gpt-4o-mini \
  --no-tools --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes \
  "hello positional"

TMP2=$(mktemp -d)
printf 'hello stdin' | env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_OAUTH_TOKEN -u GEMINI_API_KEY \
  PI_CODING_AGENT_DIR="$TMP2" PI_OFFLINE=1 \
  /opt/homebrew/bin/pi --provider openai --model gpt-4o-mini \
  --no-tools --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes

/opt/homebrew/bin/pi --help
sed -n '1,80p' /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/cli/initial-message.js
```

Captured output:

```text
positional:
exit=1
stdout:
stderr:
No API key found for openai.

Use /login to log into a provider via OAuth or API key. See:
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/docs/providers.md
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/docs/models.md
```

```text
stdin:
exit=1
stdout:
stderr:
No API key found for openai.

Use /login to log into a provider via OAuth or API key. See:
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/docs/providers.md
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/docs/models.md
```

```text
Usage:
  pi [options] [@files...] [messages...]

Examples:
  # Interactive mode with initial prompt
  pi "List all .ts files in src/"

  # Include files in initial message
  pi @prompt.md @image.png "What color is the sky?"

  # Non-interactive mode (process and exit)
  pi -p "List all .ts files in src/"

  # Multiple messages (interactive)
  pi "Read package.json" "What dependencies do we have?"
```

```js
export function buildInitialMessage({ parsed, fileText, fileImages, stdinContent, }) {
    const parts = [];
    if (stdinContent !== undefined) {
        parts.push(stdinContent);
    }
    if (fileText) {
        parts.push(fileText);
    }
    if (parsed.messages.length > 0) {
        parts.push(parsed.messages[0]);
        parsed.messages.shift();
    }
    return {
        initialMessage: parts.length > 0 ? parts.join("") : undefined,
        initialImages: fileImages && fileImages.length > 0 ? fileImages : undefined,
    };
}
```

Decision: This unblocks the Phase 1 `BuildCmd` branch that appends the initial user turn as a positional argument. Pi also reads piped stdin in non-interactive mode, but for tmux-launched interactive panes the documented and parsed shape is `[messages...]`; no dedicated prompt flag is needed, and post-launch `tmux send-keys` is not required for the initial prompt.

### 0.7

Question: What `PI_*` env vars does Pi read at launch? Any collision with planned `PI_SESSION_ID`? Confirm fallback path.

Commands:

```sh
which pi
ls -l /opt/homebrew/bin/pi

/opt/homebrew/bin/pi --help

rg -n --glob '!*.map' "PI_(CODING_AGENT_DIR|CODING_AGENT_SESSION_DIR|PACKAGE_DIR|OFFLINE|TELEMETRY|SHARE_VIEWER_URL|STARTUP_BENCHMARK|SKIP_VERSION_CHECK|CACHE_RETENTION|OAUTH_CALLBACK_HOST|TUI_WRITE_LOG|HARDWARE_CURSOR|CLEAR_ON_SHRINK|DEBUG_REDRAW|TUI_DEBUG|TIMING)" \
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist \
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-ai/dist \
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist

rg -n --glob '!*.map' "PI_SESSION_ID" \
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist \
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-ai/dist \
  /opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist || true
```

Captured output:

```text
/opt/homebrew/bin/pi
lrwxr-xr-x@ 1 aleksituominen  admin  61 May  4 00:14 /opt/homebrew/bin/pi -> ../lib/node_modules/@mariozechner/pi-coding-agent/dist/cli.js
```

```text
Environment Variables:
  PI_CODING_AGENT_DIR              - Config directory (default: ~/.pi/agent)
  PI_CODING_AGENT_SESSION_DIR      - Session storage directory (overridden by --session-dir)
  PI_PACKAGE_DIR                   - Override package directory (for Nix/Guix store paths)
  PI_OFFLINE                       - Disable startup network operations when set to 1/true/yes
  PI_TELEMETRY                     - Override install telemetry when set to 1/true/yes or 0/false/no
  PI_SHARE_VIEWER_URL              - Base URL for /share command (default: https://pi.dev/session/)
```

```text
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/main.js:322:    const offlineMode = args.includes("--offline") || isTruthyEnvFlag(process.env.PI_OFFLINE);
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/main.js:325:        process.env.PI_SKIP_VERSION_CHECK = "1";
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/main.js:523:    const startupBenchmark = isTruthyEnvFlag(process.env.PI_STARTUP_BENCHMARK);
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/config.js:217:    const envDir = process.env.PI_PACKAGE_DIR;
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/config.js:314:// e.g., PI_CODING_AGENT_DIR or TAU_CODING_AGENT_DIR
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/config.js:327:    const baseUrl = process.env.PI_SHARE_VIEWER_URL || DEFAULT_SHARE_VIEWER_URL;
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/telemetry.js:6:export function isInstallTelemetryEnabled(settingsManager, telemetryEnv = process.env.PI_TELEMETRY) {
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/timings.js:5:const ENABLED = process.env.PI_TIMING === "1";
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-ai/dist/providers/anthropic.js:20:    if (typeof process !== "undefined" && process.env.PI_CACHE_RETENTION === "long") {
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-ai/dist/utils/oauth/anthropic.js:15:const CALLBACK_HOST = process.env.PI_OAUTH_CALLBACK_HOST || "127.0.0.1";
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist/terminal.js:23:        const env = process.env.PI_TUI_WRITE_LOG || "";
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist/tui.js:90:    showHardwareCursor = process.env.PI_HARDWARE_CURSOR === "1";
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist/tui.js:91:    clearOnShrink = process.env.PI_CLEAR_ON_SHRINK === "1";
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist/tui.js:728:        const debugRedraw = process.env.PI_DEBUG_REDRAW === "1";
/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist/tui.js:928:        if (process.env.PI_TUI_DEBUG === "1") {
```

```text
PI_SESSION_ID search:

```

Decision: This unblocks the Phase 1 provider defaults as planned. `FallbackPath()` should be `/opt/homebrew/bin/pi`. The planned `EnvVar()` value `PI_SESSION_ID` does not collide with any `PI_SESSION_ID` read in the installed Pi package or bundled `pi-ai`/`pi-tui` packages. `PreLaunchSetup()` does not need to unset `PI_SESSION_ID`; it should avoid setting Pi-owned vars such as `PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, `PI_OFFLINE`, and `PI_PACKAGE_DIR` unless deliberately overriding them.

## Summary

| Question | Decision |
|---|---|
| 0.1 | Phase 1 `BuildCmd` can use Pi flags directly: `--append-system-prompt`, `--thinking high`, `--session <id>`, `--mode json/rpc`, and `--no-session`. |
| 0.2 | Phase 3 branch 1: store UUIDv7-style resume IDs; no regex relaxation or indirection needed. |
| 0.3 | `continue.go` can pass the party prompt every launch; appended prompts are runtime inputs, not persisted session history. Semantic duplicate behavior still needs one API-backed smoke test. |
| 0.4 | Phase 2 branch 1 is supported by local source and startup JSON output, but successful event schemas were not runtime-verified without an API call; strict no-API default is branch 3 until smoke-tested. |
| 0.5 | Phase 2 branch 2 is not supported; capture-pane has readable raw output but no stable glyph prefixes. |
| 0.6 | Phase 1 `BuildCmd` should deliver initial user text as positional `[messages...]`; stdin works for non-interactive mode but is not the pane-launch path. |
| 0.7 | Use `FallbackPath()` `/opt/homebrew/bin/pi` and keep `EnvVar()` as `PI_SESSION_ID`; no observed collision or unset requirement. |
