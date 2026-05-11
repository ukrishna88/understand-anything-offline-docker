# Understand Anything — Offline Installer

A fully self-contained, offline package for visualizing codebase knowledge graphs. Includes a sandboxed Docker dashboard and the Claude Code skill for generating graphs.

**No external dependencies. No internet required after download. No third-party references.**

## What's in this package

| Component | Purpose | Required? |
|-----------|---------|-----------|
| Docker image (`.tar.gz`) | Serves the interactive dashboard in a network-isolated container | Yes |
| `claude-skill/` | Claude Code skill files for generating knowledge graphs | Only if you generate graphs |
| `install.sh` | One-time installer that sets up everything | Yes |

## Prerequisites

- **Docker Desktop** — [download](https://www.docker.com/products/docker-desktop/)
- **Claude Code** — only if you will generate knowledge graphs (not needed for view-only)

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
4. Ask if you want the Claude Code skill (optional)
5. Verify everything works

### 3. Done

```bash
understand-dashboard /path/to/your/project
```

## Usage

### View a project's knowledge graph

```bash
# Any project with a .understand-anything/knowledge-graph.json
understand-dashboard ~/Desktop/my-project

# Opens dashboard at http://localhost:5173?token=...
```

### Switch between projects

```bash
# Stop current
cd ~/.understand-anything-docker && docker compose down

# Start another
understand-dashboard ~/Desktop/other-project
```

### Generate a knowledge graph (requires Claude Code skill)

In Claude Code, inside any project directory:
```
/understand
```

This produces `.understand-anything/knowledge-graph.json`. Commit it to git.

## Team Workflow

```
Developer A (has Claude Code + skill installed):
  1. Runs /understand in their project
  2. Commits knowledge-graph.json to git
  3. Pushes

Developer B, C, D (Docker dashboard only):
  1. git pull (gets the latest knowledge-graph.json)
  2. understand-dashboard .
  3. Opens the URL in browser
  4. Explores architecture, layers, guided tour
```

Only one team member needs the Claude Code skill. Everyone else just views.

## What gets committed to project repos

```
your-project/
  .understand-anything/
    knowledge-graph.json     ← commit (the graph data, ~300KB)
    meta.json                ← commit (analysis timestamp)
    .understandignore        ← commit (exclusion patterns)
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

## Offline transfer (no internet on target machine)

If the target machine has no internet at all:

```bash
# On a machine with internet — download everything once:
git clone https://github.com/ukrishna88/understand-anything-offline-docker.git
cd understand-anything-offline-docker
# Download .tar.gz from Releases page

# Transfer the entire folder via USB / file share

# On the target machine:
cd understand-anything-offline-docker
./install.sh
```

## Uninstall

```bash
# Stop and remove container
cd ~/.understand-anything-docker && docker compose down
docker rmi understand-anything-dashboard:latest

# Remove files
rm -rf ~/.understand-anything-docker
rm -rf ~/.understand-anything-plugin
rm -f /usr/local/bin/understand-dashboard
rm -f ~/.local/bin/understand-dashboard

# Remove Claude Code skill (optional)
rm -rf ~/.claude/skills/understand*
rm -rf ~/.claude/agents/*.md
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Docker is not installed" | Install Docker Desktop and restart |
| "Docker is not running" | Start Docker Desktop |
| "Docker image not found" | Download `.tar.gz` from Releases, place in this directory |
| "No knowledge-graph.json" | Run `/understand` in Claude Code or `git pull` |
| "Skill files missing" | Re-clone this repo — the `claude-skill/` folder should be present |
| Port 5173 in use | `PORT=5174 understand-dashboard /path/to/repo` |
| Stale dashboard | Refresh browser — re-reads JSON on load |
| Node.js too old for skill | Upgrade to Node.js >= 22 (only needed for skill, not dashboard) |
