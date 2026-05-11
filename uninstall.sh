#!/bin/bash

# ─────────────────────────────────────────────────────────────
# Understand Anything — Uninstaller
# Removes all installed components from your system
# ─────────────────────────────────────────────────────────────

DOCKER_IMAGE="understand-anything-dashboard:latest"
CONTAINER_NAME="understand-anything"
COMPOSE_DIR="$HOME/.understand-anything-docker"
PLUGIN_DIR="$HOME/.understand-anything-plugin"

echo ""
echo "======================================================"
echo "  Understand Anything — Uninstaller"
echo "======================================================"
echo ""
echo "  This will remove:"
echo "    - Docker container and image"
echo "    - Dashboard and ua-exec commands"
echo "    - Plugin files and skill symlinks"
echo ""
echo "  This will NOT remove:"
echo "    - knowledge-graph.json files in your projects"
echo "    - Docker Desktop itself"
echo ""
read -p "  Continue? [y/N] " CONFIRM </dev/tty

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "  Cancelled."
    exit 0
fi

echo ""

# ── Stop and remove container ────────────────────────────

echo "  [1/5] Removing Docker container..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null && echo "    Container removed." || echo "    No container found."

# Also try compose down in case it was started via compose
if [ -f "$COMPOSE_DIR/docker-compose.yml" ]; then
    cd "$COMPOSE_DIR" && docker compose down 2>/dev/null || true
fi

# ── Remove Docker image ──────────────────────────────────

echo "  [2/5] Removing Docker image..."
docker rmi "$DOCKER_IMAGE" 2>/dev/null && echo "    Image removed." || echo "    No image found."

# ── Remove commands ──────────────────────────────────────

echo "  [3/5] Removing commands..."

for cmd_path in \
    /usr/local/bin/understand-dashboard \
    /usr/local/bin/ua-exec \
    "$HOME/.local/bin/understand-dashboard" \
    "$HOME/.local/bin/ua-exec"; do
    if [ -L "$cmd_path" ] || [ -f "$cmd_path" ]; then
        rm -f "$cmd_path"
        echo "    Removed: $cmd_path"
    fi
done

# ── Remove compose directory ─────────────────────────────

echo "  [4/5] Removing config files..."

if [ -d "$COMPOSE_DIR" ]; then
    rm -rf "$COMPOSE_DIR"
    echo "    Removed: $COMPOSE_DIR"
else
    echo "    Not found: $COMPOSE_DIR"
fi

# ── Remove plugin and skill symlinks ─────────────────────

echo "  [5/5] Removing plugin and skill symlinks..."

if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
    echo "    Removed: $PLUGIN_DIR"
else
    echo "    Not found: $PLUGIN_DIR"
fi

# Remove symlinks from all platform directories
REMOVED_LINKS=0
for skill_dir in \
    "$HOME/.claude/skills" \
    "$HOME/.claude/agents" \
    "$HOME/.cursor/skills" \
    "$HOME/.cursor/agents" \
    "$HOME/.copilot/skills" \
    "$HOME/.copilot/agents" \
    "$HOME/.agents/skills" \
    "$HOME/.agents/agents" \
    "$HOME/.openclaw/skills" \
    "$HOME/.gemini/antigravity/skills" \
    "$HOME/.hermes/skills"; do

    if [ -d "$skill_dir" ]; then
        # Remove understand-* symlinks
        for link in "$skill_dir"/understand*; do
            if [ -L "$link" ]; then
                rm -f "$link"
                echo "    Removed symlink: $link"
                REMOVED_LINKS=$((REMOVED_LINKS + 1))
            fi
        done

        # Remove agent symlinks (*.md files that are symlinks)
        for link in "$skill_dir"/*.md; do
            if [ -L "$link" ]; then
                # Only remove if it points to our plugin dir
                TARGET=$(readlink "$link" 2>/dev/null || true)
                if echo "$TARGET" | grep -q "understand-anything-plugin"; then
                    rm -f "$link"
                    echo "    Removed symlink: $link"
                    REMOVED_LINKS=$((REMOVED_LINKS + 1))
                fi
            fi
        done
    fi
done

if [ "$REMOVED_LINKS" -eq 0 ]; then
    echo "    No skill symlinks found."
fi

# ── Done ─────────────────────────────────────────────────

echo ""
echo "======================================================"
echo "  Uninstall complete."
echo "======================================================"
echo ""
echo "  Everything has been removed from your system."
echo "  knowledge-graph.json files in your projects are untouched."
echo ""
echo "  To reinstall: ./install.sh"
echo ""
