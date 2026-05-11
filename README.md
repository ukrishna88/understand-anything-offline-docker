# Understand Anything — Offline Installer

A fully self-contained, offline package for visualizing and generating codebase knowledge graphs. All runtime dependencies (Node.js, pnpm, Python3) are pre-installed inside the Docker container — your machine only needs Docker.

**No host dependencies. No internet at runtime. No third-party references.**

## How it works

```
Your laptop (only Docker needed)
│
├── understand-dashboard ~/project   ← starts the dashboard
│     └── Docker container serves http://localhost:5173
│
├── ua-exec python3 ...              ← runs commands inside Docker
│     └── Docker has Node.js 22, pnpm, Python3 pre-installed
│
└── /understand (in Claude/Cursor)   ← AI tool generates the graph
      └── LLM reads files, runs ua-exec for scripts
```

## Prerequisite

- **Docker Desktop** — [download](https://www.docker.com/products/docker-desktop/)

That's it. Node.js, pnpm, Python3 are all inside the container.

## Supported Platforms

| Platform | Skill Install Path |
|----------|-------------------|
| Claude Code | `~/.claude/skills/` |
| Cursor | `~/.cursor/skills/` |
| VS Code + GitHub Copilot | `~/.copilot/skills/` |
| Copilot CLI | `~/.copilot/skills/` |
| Codex | `~/.agents/skills/` |
| Gemini CLI | `~/.agents/skills/` |
| OpenCode | `~/.agents/skills/` |
| Pi Agent | `~/.agents/skills/` |
| Vibe CLI | `~/.agents/skills/` |
| OpenClaw | `~/.openclaw/skills/` |
| Antigravity | `~/.gemini/antigravity/skills/` |
| Hermes | `~/.hermes/skills/` |

## Installation

### 1. Download the Docker image

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
3. Install `understand-dashboard` and `ua-exec` commands
4. Optionally install skills for your AI coding platform

### 3. Done

```bash
understand-dashboard /path/to/your/project
```

## Commands installed

| Command | Purpose |
|---------|---------|
| `understand-dashboard /path/to/repo` | Start the interactive dashboard |
| `ua-exec <command>` | Run any command inside the Docker container |

### ua-exec examples

```bash
ua-exec node --version       # Node.js 22 inside container
ua-exec python3 --version    # Python 3 inside container
ua-exec pnpm --version       # pnpm inside container
```

Your machine doesn't need any of these installed — they're all in Docker.

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
```

Only one team member needs the skill. Everyone else just views.

## Security

| Property | Detail |
|----------|--------|
| Internet access | **None** at runtime — DNS set to `0.0.0.0` |
| Source code | **Read-only** mount — container cannot modify files |
| Writable scope | Only `.understand-anything/` directory |
| Secrets | **None** required — no API keys, no credentials |
| Dashboard auth | Random token per launch (in `docker logs`) |
| Exposure | `localhost` only — not accessible from network |

```bash
# Verify isolation
docker exec understand-anything node -e \
  "fetch('https://example.com',{signal:AbortSignal.timeout(3000)}).then(()=>console.log('HAS INTERNET')).catch(()=>console.log('SANDBOXED'))"
# Prints: SANDBOXED
```

## Fully Offline Transfer

For machines with zero internet:

```bash
# On a connected machine — download once:
git clone https://github.com/ukrishna88/understand-anything-offline-docker.git
cd understand-anything-offline-docker
# Download .tar.gz from Releases

# Transfer the entire folder via USB / file share
# On the offline machine:
./install.sh
```

## Uninstall

```bash
cd ~/.understand-anything-docker && docker compose down
docker rmi understand-anything-dashboard:latest
rm -rf ~/.understand-anything-docker
rm -rf ~/.understand-anything-plugin
rm -f /usr/local/bin/understand-dashboard /usr/local/bin/ua-exec
rm -f ~/.local/bin/understand-dashboard ~/.local/bin/ua-exec
# Remove platform symlinks (whichever you installed)
rm -rf ~/.claude/skills/understand* ~/.claude/agents/*.md
rm -rf ~/.cursor/skills/understand* ~/.copilot/skills/understand*
rm -rf ~/.agents/skills/understand* ~/.openclaw/skills/understand-anything
rm -rf ~/.gemini/antigravity/skills/understand-anything ~/.hermes/skills/understand-anything
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
| `ua-exec` fails | Make sure the container is running: `understand-dashboard /path/to/repo` |
| `/understand` not found | Check symlinks: `ls -la ~/.claude/skills/` (or your platform path) |
