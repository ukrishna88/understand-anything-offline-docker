#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────
# Understand Anything — Offline Installer
# One-time setup for the sandboxed knowledge graph dashboard
# and optional Claude Code skill
# ─────────────────────────────────────────────────────────────

DOCKER_IMAGE="understand-anything-dashboard:latest"
CONTAINER_NAME="understand-anything"
COMPOSE_DIR="$HOME/.understand-anything-docker"
PLUGIN_DIR="$HOME/.understand-anything-plugin"
IMAGE_FILE="understand-anything-dashboard.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "======================================================"
echo "  Understand Anything — Offline Installer"
echo "======================================================"
echo ""

# ── Step 1: Check Docker ──────────────────────────────────

echo "[1/5] Checking Docker..."

if ! command -v docker &>/dev/null; then
    echo ""
    echo "  ERROR: Docker is not installed."
    echo "  Install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
    echo "  Then re-run this script."
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    echo ""
    echo "  ERROR: Docker is not running."
    echo "  Start Docker Desktop and re-run this script."
    exit 1
fi

echo "  Docker is running."

# ── Step 2: Load Docker image ────────────────────────────

echo ""
echo "[2/5] Loading Docker image..."

IMAGE_PATH=""
for candidate in "./$IMAGE_FILE" "$SCRIPT_DIR/$IMAGE_FILE"; do
    if [ -f "$candidate" ]; then
        IMAGE_PATH="$candidate"
        break
    fi
done

if [ -z "$IMAGE_PATH" ]; then
    echo ""
    echo "  ERROR: Docker image not found."
    echo ""
    echo "  Download '$IMAGE_FILE' from the Releases page:"
    echo "  https://github.com/ukrishna88/understand-anything-offline-docker/releases"
    echo ""
    echo "  Place it in this directory: $SCRIPT_DIR"
    echo "  Then re-run this script."
    exit 1
fi

IMAGE_SIZE=$(du -h "$IMAGE_PATH" | cut -f1)
echo "  Found: $IMAGE_PATH ($IMAGE_SIZE)"

if docker image inspect "$DOCKER_IMAGE" &>/dev/null 2>&1; then
    echo "  Image already loaded. Replacing..."
    docker rmi "$DOCKER_IMAGE" &>/dev/null 2>&1 || true
fi

echo "  Loading image (this may take a minute)..."
gunzip -c "$IMAGE_PATH" | docker load
echo "  Image loaded."

# ── Step 3: Setup dashboard launcher ─────────────────────

echo ""
echo "[3/5] Setting up dashboard launcher..."

mkdir -p "$COMPOSE_DIR"

cat > "$COMPOSE_DIR/docker-compose.yml" << 'COMPOSEFILE'
services:
  understand-dashboard:
    image: understand-anything-dashboard:latest
    container_name: understand-anything
    ports:
      - "${PORT:-5173}:5173"
    volumes:
      - ${REPO_PATH:-.}:/workspace:ro
      - ${REPO_PATH:-.}/.understand-anything:/workspace/.understand-anything:rw
    dns:
      - "0.0.0.0"
    restart: unless-stopped
COMPOSEFILE

cat > "$COMPOSE_DIR/start-dashboard.sh" << 'LAUNCHER'
#!/bin/bash
set -e

COMPOSE_DIR="$HOME/.understand-anything-docker"

if [ -z "$1" ]; then
    echo ""
    echo "Usage: understand-dashboard /path/to/your/repo"
    echo ""
    echo "Examples:"
    echo "  understand-dashboard ~/Desktop/my-project"
    echo "  understand-dashboard ."
    echo ""
    exit 1
fi

REPO_PATH="$(cd "$1" && pwd)"

if [ ! -f "$REPO_PATH/.understand-anything/knowledge-graph.json" ]; then
    echo ""
    echo "  No knowledge-graph.json found in: $REPO_PATH/.understand-anything/"
    echo ""
    echo "  To generate one:"
    echo "    1. Open Claude Code in your project directory"
    echo "    2. Run: /understand"
    echo "    3. Commit the generated knowledge-graph.json"
    echo "    4. Re-run this command"
    echo ""
    echo "  Or pull from git if a teammate already generated it."
    exit 1
fi

cd "$COMPOSE_DIR"
docker compose down 2>/dev/null || true
REPO_PATH="$REPO_PATH" docker compose up -d

echo ""
sleep 3

TOKEN_URL=$(docker logs understand-anything 2>&1 | grep -o 'http://127.0.0.1:[0-9]*?token=[a-f0-9]*' | head -1)

if [ -n "$TOKEN_URL" ]; then
    echo "  Dashboard ready!"
    echo ""
    echo "  Open: $TOKEN_URL"
else
    echo "  Dashboard starting..."
    echo "  Run 'docker logs understand-anything' to get the access URL."
fi

echo ""
echo "  Viewing: $REPO_PATH"
echo "  Stop:    cd $COMPOSE_DIR && docker compose down"
echo ""
LAUNCHER

chmod +x "$COMPOSE_DIR/start-dashboard.sh"

# Install the command
COMMAND_INSTALLED=false
if [ -w /usr/local/bin ]; then
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" /usr/local/bin/understand-dashboard
    COMMAND_INSTALLED=true
    echo "  Command installed: understand-dashboard"
elif [ -d "$HOME/.local/bin" ]; then
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" "$HOME/.local/bin/understand-dashboard"
    COMMAND_INSTALLED=true
    echo "  Command installed: understand-dashboard (in ~/.local/bin/)"
else
    mkdir -p "$HOME/.local/bin"
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" "$HOME/.local/bin/understand-dashboard"
    COMMAND_INSTALLED=true
    echo "  Command installed: understand-dashboard (in ~/.local/bin/)"
    echo "  NOTE: Add ~/.local/bin to your PATH if not already there."
fi

# ── Step 4: Install Claude Code skill ────────────────────

echo ""
echo "[4/5] Claude Code skill setup..."
echo ""
echo "  The Docker dashboard is VIEW-ONLY."
echo "  The Claude Code skill lets you GENERATE knowledge graphs."
echo ""
echo "  Who needs this?"
echo "    - Install if YOU will run /understand to generate graphs"
echo "    - Skip if a teammate generates and commits them for you"
echo ""

SKILL_SOURCE="$SCRIPT_DIR/claude-skill"

# Verify skill files exist in this package
if [ ! -d "$SKILL_SOURCE/skills/understand" ]; then
    echo "  ERROR: Skill files missing from this package."
    echo "  Expected at: $SKILL_SOURCE/skills/understand"
    echo ""
    echo "  This is a packaging bug. Contact the person who shared"
    echo "  this installer to re-download from:"
    echo "  https://github.com/ukrishna88/understand-anything-offline-docker"
    echo ""
    echo "  Skipping skill installation. Dashboard will still work."
    echo ""
else
    SKILL_ALREADY_INSTALLED=false
    if [ -d "$PLUGIN_DIR/skills/understand" ]; then
        echo "  Skill already installed at: $PLUGIN_DIR"
        SKILL_ALREADY_INSTALLED=true
    fi

    if [ "$SKILL_ALREADY_INSTALLED" = true ]; then
        read -p "  Re-install / update? [y/N] " REINSTALL
        if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
            echo "  Keeping existing installation."
        else
            SKILL_ALREADY_INSTALLED=false
        fi
    fi

    if [ "$SKILL_ALREADY_INSTALLED" = false ]; then
        read -p "  Install Claude Code skill? [y/N] " INSTALL_SKILL

        if [[ "$INSTALL_SKILL" =~ ^[Yy]$ ]]; then
            echo ""
            echo "  Checking prerequisites (Node.js, pnpm, Python3)..."

            MISSING=""
            if ! command -v node &>/dev/null; then MISSING="$MISSING Node.js"; fi
            if ! command -v pnpm &>/dev/null; then MISSING="$MISSING pnpm"; fi
            if ! command -v python3 &>/dev/null; then MISSING="$MISSING Python3"; fi

            if [ -n "$MISSING" ]; then
                echo ""
                echo "  ERROR: Missing required tools:$MISSING"
                echo ""
                echo "  Install them first:"
                echo "    Node.js >= 22: https://nodejs.org/"
                echo "    pnpm >= 10:    npm install -g pnpm"
                echo "    Python 3:      https://www.python.org/"
                echo ""
                echo "  Then re-run this script."
                echo "  (Dashboard still works without the skill.)"
            else
                NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
                echo "  Node.js: v$(node -v | sed 's/v//') (need >= 22)"
                echo "  pnpm: $(pnpm -v)"
                echo "  Python3: $(python3 --version | cut -d' ' -f2)"

                if [ "$NODE_VERSION" -lt 22 ]; then
                    echo ""
                    echo "  WARNING: Node.js $NODE_VERSION is too old. Need >= 22."
                    echo "  The skill may not work correctly."
                    echo ""
                    read -p "  Continue anyway? [y/N] " CONTINUE
                    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
                        echo "  Skipped. Dashboard still works."
                    fi
                fi

                echo ""
                echo "  Installing plugin to: $PLUGIN_DIR"

                # Copy the full plugin structure
                rm -rf "$PLUGIN_DIR"
                cp -r "$SKILL_SOURCE" "$PLUGIN_DIR"

                # Build the core package
                echo "  Building core package..."
                cd "$PLUGIN_DIR"
                pnpm install --ignore-scripts --no-frozen-lockfile 2>&1 | tail -3
                pnpm --filter @understand-anything/core build 2>&1 | tail -3

                # Create symlinks for Claude Code
                mkdir -p "$HOME/.claude/skills"

                # Link each skill
                for skill_dir in "$PLUGIN_DIR/skills/"*/; do
                    skill_name=$(basename "$skill_dir")
                    ln -sf "$skill_dir" "$HOME/.claude/skills/$skill_name"
                done

                # Link agents
                mkdir -p "$HOME/.claude/agents"
                for agent_file in "$PLUGIN_DIR/agents/"*.md; do
                    agent_name=$(basename "$agent_file")
                    ln -sf "$agent_file" "$HOME/.claude/agents/$agent_name"
                done

                echo ""
                echo "  Skill installed."
                echo "  Skills linked to: ~/.claude/skills/"
                echo "  Agents linked to: ~/.claude/agents/"
                echo ""
                echo "  Available commands in Claude Code:"
                echo "    /understand            — Generate knowledge graph"
                echo "    /understand-dashboard   — Launch dashboard (non-Docker)"
                echo "    /understand-chat        — Ask questions about the graph"
                echo "    /understand-diff        — Analyze git diffs"
                echo "    /understand-explain     — Deep-dive a file or function"
                echo "    /understand-onboard     — Generate onboarding guide"
            fi
        else
            echo "  Skipped. You can still view dashboards generated by others."
        fi
    fi
fi

# ── Step 5: Verify ───────────────────────────────────────

echo ""
echo "[5/5] Verifying installation..."

CHECKS_PASSED=true

# Check Docker image
if docker image inspect "$DOCKER_IMAGE" &>/dev/null 2>&1; then
    echo "  Docker image: loaded"
else
    echo "  Docker image: MISSING"
    CHECKS_PASSED=false
fi

# Check launcher
if [ -f "$COMPOSE_DIR/start-dashboard.sh" ]; then
    echo "  Dashboard launcher: installed"
else
    echo "  Dashboard launcher: MISSING"
    CHECKS_PASSED=false
fi

# Check skill (optional)
if [ -d "$HOME/.claude/skills/understand" ]; then
    echo "  Claude Code skill: installed"
else
    echo "  Claude Code skill: not installed (optional)"
fi

echo ""
echo "======================================================"
if [ "$CHECKS_PASSED" = true ]; then
    echo "  Installation complete!"
else
    echo "  Installation completed with warnings (see above)"
fi
echo "======================================================"
echo ""
echo "  View a project dashboard:"
echo "    understand-dashboard /path/to/your/project"
echo ""
if [ -d "$HOME/.claude/skills/understand" ]; then
    echo "  Generate a knowledge graph (in Claude Code):"
    echo "    /understand"
    echo ""
fi
echo "  Works with any project. Switch repos anytime."
echo ""
