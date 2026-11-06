#!/usr/bin/env bash
# Switch for the Offware Syncthing instance, which syncs ~/Offware/to-tablet.
#
#   status -> print waybar JSON for the current state (default)
#   toggle -> start it if it is off, stop it if it is on
#
# Any other Syncthing on this machine is a separate service.
set -euo pipefail

UNIT=syncthing-offware

running() { systemctl --user is-active --quiet "$UNIT"; }

refresh_bar() { pkill -RTMIN+10 waybar 2>/dev/null || true; }

print_status() {
    if running; then
        printf '{"text":"󰓦 on","tooltip":"Tablet sync is on, ~/Offware/to-tablet goes to the tablet. Click to stop.","class":"on","alt":"on"}\n'
    else
        printf '{"text":"󰓦 off","tooltip":"Tablet sync is off, nothing listens on the network. Click to start.","class":"off","alt":"off"}\n'
    fi
}

case "${1:-status}" in
    toggle)
        if running; then
            systemctl --user stop "$UNIT"
        else
            systemctl --user start "$UNIT"
            # New reviews go out with this sync. Waybar's PATH lacks ~/.local/bin.
            PATH="$HOME/.local/bin:$PATH" nohup ink-reviews >"${XDG_RUNTIME_DIR:-/tmp}/ink-reviews.log" 2>&1 &
        fi
        refresh_bar
        ;;
    status) print_status ;;
    *) echo "usage: $0 {status|toggle}" >&2; exit 1 ;;
esac
