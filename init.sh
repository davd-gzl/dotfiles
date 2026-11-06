#!/bin/bash
# Sets up a new machine: packages, then links this repository into the home
# folder, then personal settings where this GitHub account can reach them.
# Safe to run again.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

echo "🔧 Installing Sway and related tools..."

# Install sway and friends
sudo pacman -Syu --needed \
  sway swaylock swayidle \
  alacritty wofi mako \
  grim slurp brightnessctl \
  network-manager-applet \
  playerctl xorg-xwayland \
  noto-fonts noto-fonts-emoji \
  ttf-fira-code ttf-nerd-fonts-symbols \
  pulseaudio pavucontrol \
  swaybg wl-clipboard \
  stow waybar neovim \
  go github-cli python syncthing

# Optional: swaylock-effects (prettier lock screen)
#yay -S swaylock-effects --noconfirm

# Enable network applet
nmcli networking on

# Set wallpaper using swaybg if desired
# cp your wallpaper to that folder
mkdir -p ~/Pictures/wallpapers

# Install LunarVim if not already installed
if ! command -v lvim &> /dev/null; then
  echo "Installing LunarVim..."
  LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)
fi

# Stow links a whole folder when the target lacks it, which would put
# everything later written to these folders inside this repository.
mkdir -p ~/.config/systemd/user ~/.local/bin

# Create symlink from this repository to your local environment
stow .
systemctl --user daemon-reload || true

# The ink-drop tools the tablet sync uses, built from their public source.
GOBIN="$HOME/.local/bin" go install github.com/offware-apps/ink-drop/cmd/ink-epub@latest github.com/offware-apps/ink-drop/cmd/ink-send@latest
"$HOME/.local/bin/ink-send" -install

# Personal settings live in a private repository of this account, laid out like
# this one. Without a login or that repository, everything above still works.
private="$HOME/dotfiles-private"
if [ ! -d "$private" ] && gh auth status &> /dev/null; then
  gh repo clone "$(gh api user --jq .login)/dotfiles-private" "$private" || echo "No private settings found."
fi
if [ -d "$private" ]; then
  stow -d "$private" -t "$HOME" .
fi

echo "🎉 Setup complete! You can now launch Sway with 'sway' or set it as your default Wayland session."
