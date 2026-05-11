#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────
# Understand Anything — Offline Docker Installer
# One-time setup script for the sandboxed knowledge graph dashboard
# ─────────────────────────────────────────────────────────────

DOCKER_IMAGE="understand-anything-dashboard:latest"
CONTAINER_NAME="understand-anything"
COMPOSE_DIR="$HOME/.understand-anything-docker"
IMAGE_FILE="understand-anything-dashboard.tar.gz"

echo ""
echo "======================================================"
echo "  Understand Anything — Offline Dashboard Installer"
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

echo "  Docker is running. ✓"

# ── Step 2: Check for image file ─────────────────────────

echo ""
echo "[2/5] Looking for the Docker image..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_PATH=""

# Check current directory first, then script directory
for candidate in "./$IMAGE_FILE" "$SCRIPT_DIR/$IMAGE_FILE"; do
    if [ -f "$candidate" ]; then
        IMAGE_PATH="$candidate"
        break
    fi
done

if [ -z "$IMAGE_PATH" ]; then
    echo ""
    echo "  Docker image not found locally."
    echo ""
    echo "  Download it from the GitHub Releases page:"
    echo "  https://github.com/ukrishna88/understand-anything-offline-docker/releases"
    echo ""
    echo "  Place '$IMAGE_FILE' in this directory and re-run."
    exit 1
fi

IMAGE_SIZE=$(du -h "$IMAGE_PATH" | cut -f1)
echo "  Found: $IMAGE_PATH ($IMAGE_SIZE)"

# ── Step 3: Load the Docker image ────────────────────────

echo ""
echo "[3/5] Loading Docker image (this may take a minute)..."

if docker image inspect "$DOCKER_IMAGE" &>/dev/null 2>&1; then
    echo "  Image already loaded. Replacing with new version..."
    docker rmi "$DOCKER_IMAGE" &>/dev/null 2>&1 || true
fi

gunzip -c "$IMAGE_PATH" | docker load
echo "  Image loaded. ✓"

# ── Step 4: Create the compose directory ─────────────────

echo ""
echo "[4/5] Setting up compose file..."

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

# Create the launcher script
cat > "$COMPOSE_DIR/start-dashboard.sh" << 'LAUNCHER'
#!/bin/bash
set -e

COMPOSE_DIR="$HOME/.understand-anything-docker"

if [ -z "$1" ]; then
    echo ""
    echo "Usage: start-dashboard.sh /path/to/your/repo"
    echo ""
    echo "Examples:"
    echo "  start-dashboard.sh ~/Desktop/my-project"
    echo "  start-dashboard.sh ."
    echo ""
    exit 1
fi

REPO_PATH="$(cd "$1" && pwd)"

# Verify knowledge graph exists
if [ ! -f "$REPO_PATH/.understand-anything/knowledge-graph.json" ]; then
    echo ""
    echo "  No knowledge-graph.json found in: $REPO_PATH/.understand-anything/"
    echo ""
    echo "  Generate one first:"
    echo "    1. Open Claude Code in your project directory"
    echo "    2. Run: /understand"
    echo "    3. Commit the generated knowledge-graph.json"
    echo "    4. Re-run this script"
    echo ""
    echo "  Or pull from git if a teammate already generated it."
    exit 1
fi

# Stop existing container if running
cd "$COMPOSE_DIR"
docker compose down 2>/dev/null || true

# Start with the specified repo
REPO_PATH="$REPO_PATH" docker compose up -d

echo ""
sleep 3

# Extract the token URL from logs
TOKEN_URL=$(docker logs understand-anything 2>&1 | grep -o 'http://127.0.0.1:[0-9]*?token=[a-f0-9]*' | head -1)

if [ -n "$TOKEN_URL" ]; then
    echo "  Dashboard ready!"
    echo ""
    echo "  Open: $TOKEN_URL"
    echo ""
else
    echo "  Dashboard starting..."
    echo "  Run 'docker logs understand-anything' to get the access URL."
    echo ""
fi

echo "  Viewing: $REPO_PATH"
echo "  Stop:    cd $COMPOSE_DIR && docker compose down"
echo ""
LAUNCHER

chmod +x "$COMPOSE_DIR/start-dashboard.sh"

# Create a symlink in /usr/local/bin if possible, otherwise suggest PATH
if [ -w /usr/local/bin ]; then
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" /usr/local/bin/understand-dashboard
    echo "  Installed command: understand-dashboard"
    echo "  Compose dir: $COMPOSE_DIR"
elif [ -d "$HOME/.local/bin" ]; then
    ln -sf "$COMPOSE_DIR/start-dashboard.sh" "$HOME/.local/bin/understand-dashboard"
    echo "  Installed command: understand-dashboard (in ~/.local/bin/)"
    echo "  Compose dir: $COMPOSE_DIR"
else
    echo "  Compose dir: $COMPOSE_DIR"
    echo "  Launcher: $COMPOSE_DIR/start-dashboard.sh"
fi

echo "  ✓"

# ── Step 5: Install Claude Code skill (optional) ─────────

echo ""
echo "[5/5] Claude Code skill (optional)..."
echo ""
echo "  The Docker dashboard is VIEW-ONLY. To generate knowledge graphs,"
echo "  you need the understand-anything skill in Claude Code."
echo ""

SKILL_INSTALLED=false

# Check if skill is already installed
if [ -L "$HOME/.claude/skills/understand" ] || [ -d "$HOME/.claude/skills/understand" ]; then
    echo "  Claude Code skill already installed. ✓"
    SKILL_INSTALLED=true
fi

if [ "$SKILL_INSTALLED" = false ]; then
    echo "  Do you want to install the Claude Code skill?"
    echo "  (Required only if YOU will generate knowledge graphs."
    echo "   Skip if a teammate generates and commits them.)"
    echo ""
    read -p "  Install Claude Code skill? [y/N] " INSTALL_SKILL

    if [[ "$INSTALL_SKILL" =~ ^[Yy]$ ]]; then
        if [ -d "$SCRIPT_DIR/claude-skill" ]; then
            mkdir -p "$HOME/.claude/skills"
            # Copy skill files
            cp -r "$SCRIPT_DIR/claude-skill/understand" "$HOME/.claude/skills/understand"
            cp -r "$SCRIPT_DIR/claude-skill/understand-dashboard" "$HOME/.claude/skills/understand-dashboard"
            echo ""
            echo "  Claude Code skill installed. ✓"
            echo "  Use /understand and /understand-dashboard in Claude Code."
        else
            echo ""
            echo "  Skill files not found in this package."
            echo "  Ask your team lead for the skill installation instructions."
        fi
    else
        echo ""
        echo "  Skipped. You can still view dashboards generated by others."
    fi
fi

# ── Done ─────────────────────────────────────────────────

echo ""
echo "======================================================"
echo "  Installation complete!"
echo "======================================================"
echo ""
echo "  Quick start:"
echo "    understand-dashboard /path/to/your/repo"
echo ""
echo "  Or manually:"
echo "    cd $COMPOSE_DIR"
echo "    REPO_PATH=/path/to/repo docker compose up -d"
echo "    docker logs understand-anything  # get the URL"
echo ""
echo "  Works with any project that has a knowledge-graph.json."
echo "  Switch projects by stopping and starting with a new REPO_PATH."
echo ""
