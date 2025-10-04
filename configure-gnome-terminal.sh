#!/bin/bash

# GNOME Terminal Configuration Script
# Applies coolnight color scheme with transparency

echo "Configuring GNOME Terminal..."

# Get the default profile UUID
PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")

if [ -z "$PROFILE" ]; then
    echo "Error: Could not find default GNOME Terminal profile"
    exit 1
fi

PROFILE_PATH="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/"

# Enable transparency
gsettings set "$PROFILE_PATH" use-transparent-background true
gsettings set "$PROFILE_PATH" background-transparency-percent 15

# Disable theme colors and set custom colors
gsettings set "$PROFILE_PATH" use-theme-colors false
gsettings set "$PROFILE_PATH" foreground-color '#c0caf5'
gsettings set "$PROFILE_PATH" background-color '#1a1b26'

# Set cursor color
gsettings set "$PROFILE_PATH" cursor-colors-set true
gsettings set "$PROFILE_PATH" cursor-foreground-color '#1a1b26'
gsettings set "$PROFILE_PATH" cursor-background-color '#c0caf5'

# Set bold color
gsettings set "$PROFILE_PATH" bold-color-same-as-fg true

# Set color palette (Tokyo Night scheme)
gsettings set "$PROFILE_PATH" palette "['#15161E', '#f7768e', '#9ece6a', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#a9b1d6', '#414868', '#f7768e', '#9ece6a', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#c0caf5']"

echo "✓ GNOME Terminal configured successfully!"
echo "  - Transparency: 85% opacity"
echo "  - Color scheme: Tokyo Night"
echo "  - Background: #1a1b26"
echo "  - Foreground: #c0caf5"
