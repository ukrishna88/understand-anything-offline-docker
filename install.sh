#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────
# Understand Anything — Offline Installer
# Sandboxed Docker dashboard + multi-platform skill installation
#
# Prerequisite: Docker Desktop only.
# All runtime dependencies (Node.js, pnpm, Python3) are
# pre-installed inside the Docker container.
# ─────────────────────────────────────────────────────────────

DOCKER_IMAGE="understand-anything-dashboard:latest"
CONTAINER_NAME="understand-anything"
COMPOSE_DIR="$HOME/.understand-anything-docker"
PLUGIN_DIR="$HOME/.understand-anything-plugin"
IMAGE_FILE="understand-anything-dashboard.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/plugin"

echo ""
echo "======================================================"
echo "  Understand Anything — Offline Installer"
echo "======================================================"
echo ""
echo "  Prerequisite: Docker Desktop (that's it)"
echo ""

# ── Step 1: Check Docker ──────────────────────────────────

echo "[1/4] Checking Docker..."

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
echo "[2/4] Loading Docker image..."

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

# ── Step 3: Setup dashboard + exec helpers ───────────────

echo ""
echo "[3/4] Setting up dashboard and command-line tools..."

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

# ── Dashboard launcher ──
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
    echo "    1. Open your AI coding tool in the project directory"
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

# ── ua-exec: run any command inside the Docker container ──
cat > "$COMPOSE_DIR/ua-exec.sh" << 'UAEXEC'
#!/bin/bash
#
# ua-exec — Run commands inside the understand-anything Docker container.
# All dependencies (node, pnpm, python3, git) are pre-installed in the container.
#
# Usage:
#   ua-exec python3 /opt/understand-anything/plugin/skills/understand/merge-batch-graphs.py /workspace
#   ua-exec node -e "console.log('hello')"
#   ua-exec pnpm --version
#
# The container must be running (start with: understand-dashboard /path/to/repo)

if [ -z "$1" ]; then
    echo "Usage: ua-exec <command> [args...]"
    echo ""
    echo "Runs a command inside the understand-anything Docker container."
    echo "All dependencies (node, pnpm, python3) are pre-installed."
    echo ""
    echo "Examples:"
    echo "  ua-exec node --version"
    echo "  ua-exec python3 --version"
    echo "  ua-exec pnpm --version"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q '^understand-anything$'; then
    echo "ERROR: understand-anything container is not running."
    echo "Start it first: understand-dashboard /path/to/your/repo"
    exit 1
fi

docker exec -w /workspace understand-anything "$@"
UAEXEC

chmod +x "$COMPOSE_DIR/ua-exec.sh"

# ── Install commands to PATH ──
INSTALL_DIR=""
if [ -w /usr/local/bin ]; then
    INSTALL_DIR="/usr/local/bin"
else
    mkdir -p "$HOME/.local/bin"
    INSTALL_DIR="$HOME/.local/bin"
fi

ln -sf "$COMPOSE_DIR/start-dashboard.sh" "$INSTALL_DIR/understand-dashboard"
ln -sf "$COMPOSE_DIR/ua-exec.sh" "$INSTALL_DIR/ua-exec"

echo "  Commands installed:"
echo "    understand-dashboard  — Start the dashboard for a project"
echo "    ua-exec               — Run commands inside the Docker container"

if [ "$INSTALL_DIR" = "$HOME/.local/bin" ]; then
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo ""
        echo "  NOTE: Add ~/.local/bin to your PATH:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi

# ── Step 4: Install AI coding tool skill ─────────────────

echo ""
echo "[4/4] AI coding tool skill setup..."
echo ""
echo "  The Docker dashboard is VIEW-ONLY."
echo "  The skill lets you GENERATE knowledge graphs via /understand."
echo ""
echo "  Who needs this?"
echo "    - Install if YOU will run /understand to generate graphs"
echo "    - Skip if a teammate generates and commits them for you"
echo ""

# Verify skill files exist
if [ ! -d "$SKILL_SOURCE/skills/understand" ]; then
    echo "  ERROR: Skill files missing from this package."
    echo "  Expected at: $SKILL_SOURCE/skills/understand"
    echo ""
    echo "  This is a packaging bug. Re-clone the repo from:"
    echo "  https://github.com/ukrishna88/understand-anything-offline-docker"
    echo ""
    echo "  Skipping skill installation. Dashboard will still work."
    echo ""
else
    read -p "  Install the skill for your AI coding tool? [y/N] " INSTALL_SKILL </dev/tty

    if [[ "$INSTALL_SKILL" =~ ^[Yy]$ ]]; then

        # ── Platform selection (supports comma-separated) ──
        echo ""
        echo "  Which AI coding tool(s) do you use?"
        echo "  Select multiple with commas, e.g.: 1,2,5"
        echo ""
        echo "     1)  Claude Code"
        echo "     2)  Cursor"
        echo "     3)  VS Code + GitHub Copilot"
        echo "     4)  Copilot CLI"
        echo "     5)  Codex"
        echo "     6)  Gemini CLI"
        echo "     7)  OpenCode"
        echo "     8)  Pi Agent"
        echo "     9)  Vibe CLI"
        echo "    10)  OpenClaw"
        echo "    11)  Antigravity"
        echo "    12)  Hermes"
        echo ""
        read -p "  Select [1-12, comma-separated] and press Enter: " PLATFORM_INPUT </dev/tty

        # ── Copy plugin files once ──
        echo ""
        echo "  Copying plugin files to: $PLUGIN_DIR"
        rm -rf "$PLUGIN_DIR"
        cp -r "$SKILL_SOURCE" "$PLUGIN_DIR"

        # ── Function to link a single platform ──
        link_platform() {
            local NUM="$1"
            local PLATFORM="" SKILL_TARGET="" AGENT_TARGET="" LINK_STYLE=""

            case "$NUM" in
                1)  PLATFORM="Claude Code"        ; SKILL_TARGET="$HOME/.claude/skills"                ; AGENT_TARGET="$HOME/.claude/agents"  ; LINK_STYLE="per-skill" ;;
                2)  PLATFORM="Cursor"              ; SKILL_TARGET="$HOME/.cursor/skills"                ; AGENT_TARGET="$HOME/.cursor/agents"  ; LINK_STYLE="per-skill" ;;
                3)  PLATFORM="VS Code + Copilot"   ; SKILL_TARGET="$HOME/.copilot/skills"               ; AGENT_TARGET="$HOME/.copilot/agents" ; LINK_STYLE="per-skill" ;;
                4)  PLATFORM="Copilot CLI"         ; SKILL_TARGET="$HOME/.copilot/skills"               ; AGENT_TARGET="$HOME/.copilot/agents" ; LINK_STYLE="per-skill" ;;
                5)  PLATFORM="Codex"               ; SKILL_TARGET="$HOME/.agents/skills"                ; AGENT_TARGET="$HOME/.agents/agents"  ; LINK_STYLE="per-skill" ;;
                6)  PLATFORM="Gemini CLI"          ; SKILL_TARGET="$HOME/.agents/skills"                ; AGENT_TARGET="$HOME/.agents/agents"  ; LINK_STYLE="per-skill" ;;
                7)  PLATFORM="OpenCode"            ; SKILL_TARGET="$HOME/.agents/skills"                ; AGENT_TARGET="$HOME/.agents/agents"  ; LINK_STYLE="per-skill" ;;
                8)  PLATFORM="Pi Agent"            ; SKILL_TARGET="$HOME/.agents/skills"                ; AGENT_TARGET="$HOME/.agents/agents"  ; LINK_STYLE="per-skill" ;;
                9)  PLATFORM="Vibe CLI"            ; SKILL_TARGET="$HOME/.agents/skills"                ; AGENT_TARGET="$HOME/.agents/agents"  ; LINK_STYLE="per-skill" ;;
                10) PLATFORM="OpenClaw"            ; SKILL_TARGET="$HOME/.openclaw/skills"              ; AGENT_TARGET=""                      ; LINK_STYLE="folder"    ;;
                11) PLATFORM="Antigravity"         ; SKILL_TARGET="$HOME/.gemini/antigravity/skills"    ; AGENT_TARGET=""                      ; LINK_STYLE="folder"    ;;
                12) PLATFORM="Hermes"              ; SKILL_TARGET="$HOME/.hermes/skills"                ; AGENT_TARGET=""                      ; LINK_STYLE="folder"    ;;
                *)  echo "  Skipping invalid choice: $NUM"; return ;;
            esac

            echo "  Linking: $PLATFORM → $SKILL_TARGET/"

            if [ "$LINK_STYLE" = "per-skill" ]; then
                mkdir -p "$SKILL_TARGET"
                for skill_dir in "$PLUGIN_DIR/skills/"*/; do
                    skill_name=$(basename "$skill_dir")
                    ln -sfn "$skill_dir" "$SKILL_TARGET/$skill_name"
                done

                if [ -n "$AGENT_TARGET" ]; then
                    mkdir -p "$AGENT_TARGET"
                    for agent_file in "$PLUGIN_DIR/agents/"*.md; do
                        agent_name=$(basename "$agent_file")
                        ln -sfn "$agent_file" "$AGENT_TARGET/$agent_name"
                    done
                fi

            elif [ "$LINK_STYLE" = "folder" ]; then
                mkdir -p "$SKILL_TARGET"
                ln -sfn "$PLUGIN_DIR/skills" "$SKILL_TARGET/understand-anything"
            fi
        }

        # ── Process each selection ──
        INSTALLED_COUNT=0
        IFS=',' read -ra SELECTIONS <<< "$PLATFORM_INPUT"
        for choice in "${SELECTIONS[@]}"; do
            choice=$(echo "$choice" | tr -d ' ')  # trim spaces
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le 12 ]; then
                link_platform "$choice"
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            else
                echo "  Skipping invalid choice: '$choice'"
            fi
        done

        if [ "$INSTALLED_COUNT" -gt 0 ]; then
            echo ""
            echo "  Skill installed for $INSTALLED_COUNT platform(s)."
            echo ""
            echo "  Available commands in your AI coding tool:"
            echo "    /understand              — Generate knowledge graph"
            echo "    /understand-dashboard    — Launch dashboard (non-Docker)"
            echo "    /understand-chat         — Ask questions about the codebase"
            echo "    /understand-diff         — Analyze git diffs"
            echo "    /understand-explain      — Deep-dive a file or function"
            echo "    /understand-onboard      — Generate onboarding guide"
            echo "    /understand-domain       — Extract business domain flows"
            echo "    /understand-knowledge    — Analyze knowledge bases"
            echo ""
            echo "  All node/python/pnpm commands run inside the Docker"
            echo "  container — nothing extra needed on your machine."
        else
            echo ""
            echo "  No valid platforms selected. Dashboard still works."
        fi
    else
        echo "  Skipped. You can still view dashboards generated by others."
    fi
fi

# ── Verify ───────────────────────────────────────────────

echo ""
echo "  Verifying installation..."
echo ""

if docker image inspect "$DOCKER_IMAGE" &>/dev/null 2>&1; then
    echo "  Docker image:      loaded"
    # Show what's inside the container
    echo "  Container has:     $(docker run --rm --entrypoint sh $DOCKER_IMAGE -c 'echo "Node $(node -v), pnpm $(pnpm -v), Python $(python3 --version 2>&1 | cut -d" " -f2)"')"
else
    echo "  Docker image:      MISSING"
fi

if [ -f "$COMPOSE_DIR/start-dashboard.sh" ]; then
    echo "  Dashboard command:  installed"
else
    echo "  Dashboard command:  MISSING"
fi

if [ -f "$COMPOSE_DIR/ua-exec.sh" ]; then
    echo "  ua-exec command:    installed"
else
    echo "  ua-exec command:    MISSING"
fi

if [ -d "$PLUGIN_DIR/skills/understand" ]; then
    echo "  Skill plugin:      installed"
    for check_dir in \
        "$HOME/.claude/skills" \
        "$HOME/.cursor/skills" \
        "$HOME/.copilot/skills" \
        "$HOME/.agents/skills" \
        "$HOME/.openclaw/skills" \
        "$HOME/.gemini/antigravity/skills" \
        "$HOME/.hermes/skills"; do
        if [ -L "$check_dir/understand" ] || [ -L "$check_dir/understand-anything" ]; then
            platform_name=$(echo "$check_dir" | sed "s|$HOME/\.||" | cut -d/ -f1)
            echo "  Linked to:         $platform_name"
        fi
    done
else
    echo "  Skill plugin:      not installed (optional — dashboard still works)"
fi

echo ""
echo "======================================================"
echo "  Installation complete!"
echo "======================================================"
echo ""
echo "  View a project dashboard:"
echo "    understand-dashboard /path/to/your/project"
echo ""
if [ -d "$PLUGIN_DIR/skills/understand" ]; then
    echo "  Generate a knowledge graph (in your AI coding tool):"
    echo "    /understand"
    echo ""
fi
echo "  Run commands inside the container:"
echo "    ua-exec node --version"
echo "    ua-exec python3 --version"
echo "    ua-exec pnpm --version"
echo ""
echo "  One image, any project. Zero host dependencies."
echo ""
