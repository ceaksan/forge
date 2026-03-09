#!/bin/bash
set -e

FORGE_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_TARGET="$HOME/.claude/skills/forge"

echo "Forge installer"
echo "==============="
echo ""
echo "Source: $FORGE_DIR/skills"
echo "Target: $SKILLS_TARGET"
echo ""

# Check if target already exists
if [ -L "$SKILLS_TARGET" ]; then
    echo "Existing symlink found. Updating..."
    rm "$SKILLS_TARGET"
elif [ -d "$SKILLS_TARGET" ]; then
    echo "WARNING: $SKILLS_TARGET is a directory, not a symlink."
    echo "Back it up and remove it, then run install again."
    exit 1
fi

# Create symlink
ln -sf "$FORGE_DIR/skills" "$SKILLS_TARGET"
echo "Symlinked: $SKILLS_TARGET -> $FORGE_DIR/skills"

# Verify
if [ -f "$SKILLS_TARGET/SKILL.md" ]; then
    echo ""
    echo "Installed skills:"
    for f in "$SKILLS_TARGET"/*.md; do
        name=$(basename "$f" .md)
        echo "  - $name"
    done
    echo ""
    echo "Done. Skills are available in Claude Code."
    echo ""
    echo "Usage:"
    echo "  /implement [feature-name]     Build with memory tracking"
    echo "  /implement --hotfix [desc]    Quick fix, bypass court"
    echo "  /critique                     Review last implementation"
    echo "  /retro [feature-name]         Consolidate learnings"
else
    echo "ERROR: Symlink created but SKILL.md not found. Check paths."
    exit 1
fi
