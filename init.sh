# Install all dependencies for new os
#!/bin/bash

echo "🔧 Installing Sway and related tools..."

sudo pacman -Syu

# Install sway and friends
sudo pacman -S \
  sway swaylock swayidle \
  alacritty wofi mako \
  grim slurp brightnessctl \
  network-manager-applet \
  playerctl xorg-xwayland \
  noto-fonts noto-fonts-emoji \
  ttf-fira-code ttf-nerd-fonts-symbols \
  pulseaudio pavucontrol \
  swaybg wl-clipboard \
  stow waybar neovim

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

# Create symlink from this repository to your local environment
stow .

echo "🎉 Setup complete! You can now launch Sway with 'sway' or set it as your default Wayland session."
