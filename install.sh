#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────
# Understand Anything — Offline Installer
# Sandboxed Docker dashboard + multi-platform skill installation
# Supports: Claude Code, Cursor, VS Code Copilot, Codex,
#           Gemini CLI, OpenCode, Pi Agent, Vibe, OpenClaw,
#           Antigravity, Hermes
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

# Install the command
if [ -w /usr/local/bin ]; then
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" /usr/local/bin/understand-dashboard
    echo "  Command installed: understand-dashboard"
elif [ -d "$HOME/.local/bin" ]; then
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" "$HOME/.local/bin/understand-dashboard"
    echo "  Command installed: understand-dashboard (in ~/.local/bin/)"
else
    mkdir -p "$HOME/.local/bin"
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" "$HOME/.local/bin/understand-dashboard"
    echo "  Command installed: understand-dashboard (in ~/.local/bin/)"
    echo "  NOTE: Add ~/.local/bin to your PATH if not already there."
fi

# ── Step 4: Install AI coding tool skill ─────────────────

echo ""
echo "[4/5] AI coding tool skill setup..."
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

        # ── Platform selection ──
        echo ""
        echo "  Which AI coding tool do you use?"
        echo ""
        echo "    1)  Claude Code"
        echo "    2)  Cursor"
        echo "    3)  VS Code + GitHub Copilot"
        echo "    4)  Copilot CLI"
        echo "    5)  Codex"
        echo "    6)  Gemini CLI"
        echo "    7)  OpenCode"
        echo "    8)  Pi Agent"
        echo "    9)  Vibe CLI"
        echo "    10) OpenClaw"
        echo "    11) Antigravity"
        echo "    12) Hermes"
        echo ""
        read -p "  Select [1-12]: " PLATFORM_CHOICE </dev/tty

        case "$PLATFORM_CHOICE" in
            1)  PLATFORM="claude"     ; SKILL_TARGET="$HOME/.claude/skills"     ; AGENT_TARGET="$HOME/.claude/agents"     ; LINK_STYLE="per-skill" ;;
            2)  PLATFORM="cursor"     ; SKILL_TARGET="$HOME/.cursor/skills"     ; AGENT_TARGET="$HOME/.cursor/agents"     ; LINK_STYLE="per-skill" ;;
            3)  PLATFORM="vscode"     ; SKILL_TARGET="$HOME/.copilot/skills"    ; AGENT_TARGET="$HOME/.copilot/agents"    ; LINK_STYLE="per-skill" ;;
            4)  PLATFORM="copilot"    ; SKILL_TARGET="$HOME/.copilot/skills"    ; AGENT_TARGET="$HOME/.copilot/agents"    ; LINK_STYLE="per-skill" ;;
            5)  PLATFORM="codex"      ; SKILL_TARGET="$HOME/.agents/skills"     ; AGENT_TARGET="$HOME/.agents/agents"     ; LINK_STYLE="per-skill" ;;
            6)  PLATFORM="gemini"     ; SKILL_TARGET="$HOME/.agents/skills"     ; AGENT_TARGET="$HOME/.agents/agents"     ; LINK_STYLE="per-skill" ;;
            7)  PLATFORM="opencode"   ; SKILL_TARGET="$HOME/.agents/skills"     ; AGENT_TARGET="$HOME/.agents/agents"     ; LINK_STYLE="per-skill" ;;
            8)  PLATFORM="pi"         ; SKILL_TARGET="$HOME/.agents/skills"     ; AGENT_TARGET="$HOME/.agents/agents"     ; LINK_STYLE="per-skill" ;;
            9)  PLATFORM="vibe"       ; SKILL_TARGET="$HOME/.agents/skills"     ; AGENT_TARGET="$HOME/.agents/agents"     ; LINK_STYLE="per-skill" ;;
            10) PLATFORM="openclaw"   ; SKILL_TARGET="$HOME/.openclaw/skills"   ; AGENT_TARGET=""                         ; LINK_STYLE="folder"    ;;
            11) PLATFORM="antigravity"; SKILL_TARGET="$HOME/.gemini/antigravity/skills"; AGENT_TARGET=""                  ; LINK_STYLE="folder"    ;;
            12) PLATFORM="hermes"     ; SKILL_TARGET="$HOME/.hermes/skills"     ; AGENT_TARGET=""                         ; LINK_STYLE="folder"    ;;
            *)
                echo "  Invalid choice. Skipping skill installation."
                echo "  Dashboard still works for viewing."
                PLATFORM=""
                ;;
        esac

        if [ -n "$PLATFORM" ]; then
            echo ""
            echo "  Installing for: $PLATFORM"

            # ── Check prerequisites ──
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
                echo "  Node.js: $(node -v) | pnpm: $(pnpm -v) | Python3: $(python3 --version | cut -d' ' -f2)"

                if [ "$NODE_VERSION" -lt 22 ]; then
                    echo ""
                    echo "  WARNING: Node.js $NODE_VERSION is too old. Need >= 22."
                    read -p "  Continue anyway? [y/N] " CONTINUE </dev/tty
                    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
                        echo "  Skipped."
                        PLATFORM=""
                    fi
                fi
            fi
        fi

        if [ -n "$PLATFORM" ] && [ -z "$MISSING" ]; then
            # ── Install plugin root ──
            echo ""
            echo "  Installing plugin to: $PLUGIN_DIR"

            rm -rf "$PLUGIN_DIR"
            cp -r "$SKILL_SOURCE" "$PLUGIN_DIR"

            # Build the core package
            echo "  Building core package..."
            cd "$PLUGIN_DIR"
            pnpm install --ignore-scripts --no-frozen-lockfile 2>&1 | tail -3
            pnpm --filter @understand-anything/core build 2>&1 | tail -3
            cd "$SCRIPT_DIR"

            # ── Create symlinks based on platform style ──
            if [ "$LINK_STYLE" = "per-skill" ]; then
                # Per-skill: individual symlink for each skill
                mkdir -p "$SKILL_TARGET"

                for skill_dir in "$PLUGIN_DIR/skills/"*/; do
                    skill_name=$(basename "$skill_dir")
                    ln -sfn "$skill_dir" "$SKILL_TARGET/$skill_name"
                done

                echo "  Skills linked to: $SKILL_TARGET/"
                ls -1 "$SKILL_TARGET/" | grep understand | sed 's/^/    /'

                # Link agents if target exists
                if [ -n "$AGENT_TARGET" ]; then
                    mkdir -p "$AGENT_TARGET"
                    for agent_file in "$PLUGIN_DIR/agents/"*.md; do
                        agent_name=$(basename "$agent_file")
                        ln -sfn "$agent_file" "$AGENT_TARGET/$agent_name"
                    done
                    echo "  Agents linked to: $AGENT_TARGET/"
                fi

            elif [ "$LINK_STYLE" = "folder" ]; then
                # Folder: single symlink for entire skills directory
                mkdir -p "$SKILL_TARGET"
                ln -sfn "$PLUGIN_DIR/skills" "$SKILL_TARGET/understand-anything"
                echo "  Skills linked to: $SKILL_TARGET/understand-anything"
            fi

            echo ""
            echo "  Skill installed for $PLATFORM."
            echo ""
            echo "  Available commands:"
            echo "    /understand              — Generate knowledge graph"
            echo "    /understand-dashboard    — Launch dashboard (non-Docker)"
            echo "    /understand-chat         — Ask questions about the codebase"
            echo "    /understand-diff         — Analyze git diffs"
            echo "    /understand-explain      — Deep-dive a file or function"
            echo "    /understand-onboard      — Generate onboarding guide"
            echo "    /understand-domain       — Extract business domain flows"
            echo "    /understand-knowledge    — Analyze knowledge bases"
        fi
    else
        echo "  Skipped. You can still view dashboards generated by others."
    fi
fi

# ── Step 5: Verify ───────────────────────────────────────

echo ""
echo "[5/5] Verifying installation..."

# Check Docker image
if docker image inspect "$DOCKER_IMAGE" &>/dev/null 2>&1; then
    echo "  Docker image:      loaded"
else
    echo "  Docker image:      MISSING"
fi

# Check launcher
if [ -f "$COMPOSE_DIR/start-dashboard.sh" ]; then
    echo "  Dashboard command:  installed"
else
    echo "  Dashboard command:  MISSING"
fi

# Check skill
if [ -d "$PLUGIN_DIR/skills/understand" ]; then
    echo "  Skill plugin:      installed ($PLUGIN_DIR)"
    # Show which platforms have symlinks
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
echo "  One image, any project. Switch repos anytime."
echo ""
