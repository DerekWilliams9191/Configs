#!/bin/bash

# Simple script to symlink config files from Configs dir to parent .config dir
# Prompts user to manually resolve conflicts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(dirname "$SCRIPT_DIR")"

echo "Creating symlinks from $SCRIPT_DIR to $TARGET_DIR"
echo ""

# Files and directories to symlink
ITEMS=(
    "nvim"
    ".oh-my-zsh"
    ".zshrc"
    ".gitconfig"
    ".gitignore_global"
    ".tmux.conf"
    ".wezterm.lua"
    ".p10k.zsh"
    "Brewfile"
)

for item in "${ITEMS[@]}"; do
    source="$SCRIPT_DIR/$item"
    target="$TARGET_DIR/$item"

    # Check if source exists
    if [ ! -e "$source" ]; then
        echo "⚠️  Source does not exist: $source (skipping)"
        continue
    fi

    # Check if target is already a symlink
    if [ -L "$target" ]; then
        # Check if it points to the correct source
        if [ "$(readlink "$target")" = "$source" ]; then
            echo "✓ Already linked: $item"
            continue
        else
            echo "⚠️  Symlink exists but points to wrong location: $target"
            echo "   Current: $(readlink "$target")"
            echo "   Expected: $source"
            echo "   Please manually resolve this conflict before proceeding."
            echo ""
            continue
        fi
    fi

    # Check if target exists as regular file/directory
    if [ -e "$target" ]; then
        echo "⚠️  Target already exists: $target"
        echo "   Please manually resolve this conflict before proceeding."
        echo ""
        continue
    fi

    # Create symlink
    ln -s "$source" "$target"
    if [ $? -eq 0 ]; then
        echo "✓ Linked: $item"
    else
        echo "✗ Failed to link: $item"
    fi
done

echo ""
echo "Done! Please manually resolve any conflicts listed above."
