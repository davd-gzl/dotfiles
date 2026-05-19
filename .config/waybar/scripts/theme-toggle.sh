#!/usr/bin/env bash
# Toggle GTK/libadwaita light <-> dark via gsettings.
# Modes:
#   status  -> print waybar JSON for current state (default)
#   toggle  -> flip light/dark, then signal waybar to refresh
#   light   -> force light
#   dark    -> force dark
set -euo pipefail

DARK_GTK="Adwaita-dark"
LIGHT_GTK="Adwaita"

current() {
    gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'"
}

apply_dark() {
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme "$DARK_GTK"
}

apply_light() {
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme "$LIGHT_GTK"
}

print_status() {
    case "$(current)" in
        prefer-dark)
            printf '{"text":"","tooltip":"Theme: dark — click for light","class":"dark","alt":"dark"}\n'
            ;;
        *)
            printf '{"text":"","tooltip":"Theme: light — click for dark","class":"light","alt":"light"}\n'
            ;;
    esac
}

case "${1:-status}" in
    toggle)
        case "$(current)" in
            prefer-dark) apply_light ;;
            *)           apply_dark  ;;
        esac
        pkill -RTMIN+8 waybar 2>/dev/null || true
        ;;
    dark)   apply_dark  ;;
    light)  apply_light ;;
    status) print_status ;;
    *) echo "usage: $0 {toggle|dark|light|status}" >&2; exit 1 ;;
esac
