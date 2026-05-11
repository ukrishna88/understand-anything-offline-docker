# Understand Anything — Offline Installer

A fully self-contained, offline package for visualizing codebase knowledge graphs. Includes a sandboxed Docker dashboard and skill files for 12 AI coding platforms.

**No external dependencies. No internet required after download. No third-party references at runtime.**

## Supported Platforms

| Platform | Skill Install Path | Status |
|----------|-------------------|--------|
| Claude Code | `~/.claude/skills/` | Tested |
| Cursor | `~/.cursor/skills/` | Supported |
| VS Code + GitHub Copilot | `~/.copilot/skills/` | Supported |
| Copilot CLI | `~/.copilot/skills/` | Supported |
| Codex | `~/.agents/skills/` | Supported |
| Gemini CLI | `~/.agents/skills/` | Supported |
| OpenCode | `~/.agents/skills/` | Supported |
| Pi Agent | `~/.agents/skills/` | Supported |
| Vibe CLI | `~/.agents/skills/` | Supported |
| OpenClaw | `~/.openclaw/skills/` | Supported |
| Antigravity | `~/.gemini/antigravity/skills/` | Supported |
| Hermes | `~/.hermes/skills/` | Supported |

All platforms get the same 8 skills and 9 agents. The installer handles the correct directory and symlink structure for each.

## What's in this package

| Component | Purpose | Required? |
|-----------|---------|-----------|
| Docker image (`.tar.gz`) | Sandboxed dashboard viewer (no internet at runtime) | Yes |
| `plugin/` | Complete skill + agent + core files for all 12 platforms | Only if you generate graphs |
| `install.sh` | Interactive installer with platform selection | Yes |

## Prerequisites

- **Docker Desktop** — [download](https://www.docker.com/products/docker-desktop/)
- **Node.js >= 22, pnpm >= 10, Python 3** — only if installing the skill (not needed for dashboard-only)

## Installation

### 1. Download

From the [Releases](https://github.com/ukrishna88/understand-anything-offline-docker/releases) page, download:
- `understand-anything-dashboard.tar.gz` (~193MB)

### 2. Clone and install

```bash
git clone https://github.com/ukrishna88/understand-anything-offline-docker.git
cd understand-anything-offline-docker

# Place the downloaded .tar.gz here
mv ~/Downloads/understand-anything-dashboard.tar.gz .

# Run the installer
./install.sh
```

The installer will:
1. Verify Docker is running
2. Load the Docker image (offline — from the `.tar.gz`)
3. Install the `understand-dashboard` command
4. Ask which AI coding platform you use (12 options)
5. Install skills + agents for your platform
6. Verify everything works

### 3. Done

```bash
understand-dashboard /path/to/your/project
```

## Available Skills (after installation)

| Command | Description |
|---------|-------------|
| `/understand` | Analyze codebase and build knowledge graph |
| `/understand-dashboard` | Launch interactive dashboard (non-Docker) |
| `/understand-chat` | Ask questions about the codebase using the graph |
| `/understand-diff` | Analyze impact of git diffs / PRs |
| `/understand-explain` | Deep-dive into a specific file or function |
| `/understand-onboard` | Generate an onboarding guide for new team members |
| `/understand-domain` | Extract business domain flows and processes |
| `/understand-knowledge` | Analyze Karpathy-pattern LLM wiki knowledge bases |

## Usage

### View a project's knowledge graph

```bash
understand-dashboard ~/Desktop/my-project
# Opens at http://localhost:5173?token=...
```

### Switch between projects

```bash
cd ~/.understand-anything-docker && docker compose down
understand-dashboard ~/Desktop/other-project
```

### Generate a knowledge graph

In your AI coding tool (Claude Code, Cursor, Copilot, etc.), inside any project:
```
/understand
```

Commit the generated `.understand-anything/knowledge-graph.json` to git.

## Team Workflow

```
Developer A (has skill installed):
  1. Runs /understand in their project
  2. Commits knowledge-graph.json to git
  3. Pushes

Developer B, C, D (Docker dashboard only):
  1. git pull
  2. understand-dashboard .
  3. Opens the URL in browser
  4. Explores architecture, layers, guided tour
```

Only one team member needs the skill. Everyone else just views.

## What gets committed to project repos

```
your-project/
  .understand-anything/
    knowledge-graph.json     ← the graph data (~300KB)
    meta.json                ← analysis timestamp
    .understandignore        ← exclusion patterns
```

## Security

| Property | Detail |
|----------|--------|
| Internet access | **None** at runtime — DNS set to `0.0.0.0` |
| Source code | **Read-only** mount — container cannot modify files |
| Writable scope | Only `.understand-anything/` directory |
| Secrets | **None** required — no API keys, no credentials |
| Dashboard auth | Random token per launch (in `docker logs`) |
| Exposure | `localhost` only — not accessible from network |

### Verify isolation

```bash
docker exec understand-anything node -e \
  "fetch('https://example.com',{signal:AbortSignal.timeout(3000)}).then(()=>console.log('HAS INTERNET')).catch(()=>console.log('SANDBOXED'))"
# Prints: SANDBOXED
```

## Fully Offline Transfer

For machines with zero internet:

```bash
# On a connected machine — download everything once:
git clone https://github.com/ukrishna88/understand-anything-offline-docker.git
cd understand-anything-offline-docker
# Download .tar.gz from Releases

# Transfer the entire folder via USB / file share

# On the offline machine:
cd understand-anything-offline-docker
./install.sh
```

## Adding to a second platform

If you already installed for one platform and want to add another:

```bash
./install.sh
# Say 'y' to skill installation, pick a different platform
# The plugin root is shared — only new symlinks are created
```

## Uninstall

```bash
# Stop and remove container + image
cd ~/.understand-anything-docker && docker compose down
docker rmi understand-anything-dashboard:latest

# Remove all installed files
rm -rf ~/.understand-anything-docker
rm -rf ~/.understand-anything-plugin
rm -f /usr/local/bin/understand-dashboard
rm -f ~/.local/bin/understand-dashboard

# Remove platform symlinks (whichever you installed)
rm -rf ~/.claude/skills/understand*
rm -rf ~/.claude/agents/*.md
rm -rf ~/.cursor/skills/understand*
rm -rf ~/.copilot/skills/understand*
rm -rf ~/.agents/skills/understand*
rm -rf ~/.openclaw/skills/understand-anything
rm -rf ~/.gemini/antigravity/skills/understand-anything
rm -rf ~/.hermes/skills/understand-anything
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Docker is not installed" | Install Docker Desktop and restart |
| "Docker is not running" | Start Docker Desktop |
| "Docker image not found" | Download `.tar.gz` from Releases, place in this directory |
| "Skill files missing" | Re-clone this repo — `plugin/` should be present |
| "No knowledge-graph.json" | Run `/understand` in your AI tool, or `git pull` |
| Port 5173 in use | `PORT=5174 understand-dashboard /path/to/repo` |
| Stale dashboard | Refresh browser — re-reads JSON on each load |
| Node.js too old | Upgrade to >= 22 (only needed for skill, not dashboard) |
| `/understand` not found | Check symlinks: `ls -la ~/.claude/skills/` (or your platform path) |
