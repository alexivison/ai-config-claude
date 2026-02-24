# ai-config

<p align="center">
  <img src="assets/the-adventuring-party.png" alt="The Adventuring Party — Claude the Warforged Paladin, the Mastermind Rogue, and Codex the High Elf Wizard" width="700">
</p>

<p align="center"><em>"Evidence before claims. Tests before implementation."</em></p>

Shared configuration and orchestration for an adventuring party of AI coding assistants. Each member brings unique strengths; this repo equips them through symlink-based installation and launches them side by side in a tmux party session.

## The Party

| Member | Class | Role |
|--------|-------|------|
| **The User** | Mastermind Rogue | Commander and final authority. Leads the party. |
| **Claude** | Warforged Paladin | Living construct of steel and divine fire. Implementation, testing, orchestration. |
| **Codex** | High Elf Wizard | Ancient arcanist of deep intellect. Deep reasoning, analysis, review. |

## Structure

```
ai-config/
├── claude/          # Claude Code configuration
├── codex/           # OpenAI Codex CLI configuration
├── shared/          # Skills shared by both platforms
├── session/         # tmux party session launcher
├── tests/           # Test suite
├── install.sh       # Install CLIs and create symlinks
├── uninstall.sh     # Remove symlinks
└── README.md
```

## Installation

```bash
# Clone the repo
git clone git@github.com:alexivison/ai-config.git ~/Code/ai-config

# Full install (symlinks + CLI installation + auth)
cd ~/Code/ai-config
./install.sh

# Or symlinks only (install CLIs yourself)
./install.sh --symlinks-only
```

The installer will:
1. Create config symlinks (`~/.claude`, `~/.codex`)
2. Offer to install missing CLI tools (optional)
3. Offer to run authentication for each tool (optional)

### CLI Installation Methods

| Dependency | Install Command |
|------------|-----------------|
| Claude | `curl -fsSL https://cli.anthropic.com/install.sh \| sh` |
| Codex | `brew install --cask codex` |
| tmux | `brew install tmux` |

> **Note:** tmux is required for the party session (`session/party.sh`). The installer does not install tmux automatically.

## Uninstallation

```bash
cd ~/Code/ai-config
./uninstall.sh
```

Removes symlinks but keeps the repository.

## Usage

Launch a party session to run Claude and Codex side by side in a two-pane tmux layout:

```bash
./session/party.sh
```

The left pane runs Claude (the Paladin), the right pane runs Codex (the Wizard). Claude communicates with Codex via `tmux-codex.sh` for reviews, analysis, and deep reasoning tasks.

| Flag | Description |
|------|-------------|
| *(none)* | Start a new party session (iTerm2 control mode auto-detected) |
| `--raw` | Start without iTerm2 control mode |
| `--list` | List active party sessions |
| `--stop [name]` | Stop one or all party sessions |
| `--install-tpm` | Install tmux Plugin Manager |

## Documentation

- **Claude Code**: See [claude/CLAUDE.md](claude/CLAUDE.md) for the Paladin's full configuration
- **Codex**: See [codex/AGENTS.md](codex/AGENTS.md) for the Wizard's configuration
