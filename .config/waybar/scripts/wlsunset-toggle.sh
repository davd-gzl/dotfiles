#!/usr/bin/env bash
# Blue light filter (wlsunset) control for waybar and sway.
#
#   status        -> print waybar JSON for the current state (default)
#   toggle        -> cycle automatic -> day -> night -> automatic
#   auto|day|night-> go straight to that mode
#   dim <0.1-1.0> -> software gamma, for when the backlight is already at its floor
#   temp <K>      -> night colour temperature, higher is less yellow
#   start         -> launch wlsunset if it is not already running
#
# wlsunset has no IPC. SIGUSR1 cycles it through forced-day, forced-night and
# automatic, always in that order, and it starts in automatic. We mirror that
# cycle in a state file so the bar can show which mode is live, which means
# every mode change has to go through this script or the two fall out of step.
# Gamma is not runtime-adjustable, so changing it relaunches wlsunset.
set -euo pipefail

# The location comes from the private settings, as LAT= and LON= lines, and
# stays out of this public repository. wlsunset ignores anything past one decimal.
LAT=0
LON=0
if [[ -f "$HOME/.config/wlsunset/location" ]]; then
    source "$HOME/.config/wlsunset/location"
fi
DAY_TEMP=6500
NIGHT_TEMP=3500

RUN="${XDG_RUNTIME_DIR:-/tmp}"
STATE="$RUN/wlsunset-mode"
GAMMA_FILE="$RUN/wlsunset-gamma"
TEMP_FILE="$RUN/wlsunset-night-temp"

ORDER=(auto day night)

gamma() { cat "$GAMMA_FILE" 2>/dev/null || echo 1.0; }
night_temp() { cat "$TEMP_FILE" 2>/dev/null || echo "$NIGHT_TEMP"; }

running() { pgrep -x wlsunset >/dev/null 2>&1; }

current() {
    if ! running; then echo off; return; fi
    cat "$STATE" 2>/dev/null || echo auto
}

launch() {
    wlsunset -l "$LAT" -L "$LON" -t "$(night_temp)" -T "$DAY_TEMP" -g "$(gamma)" >/dev/null 2>&1 &
    # wlsunset always comes up in automatic.
    echo auto > "$STATE"
    sleep 0.3
}

start() {
    if running; then return 0; fi
    launch
}

index_of() {
    local want=$1 i
    for i in "${!ORDER[@]}"; do
        [[ ${ORDER[$i]} == "$want" ]] && { echo "$i"; return; }
    done
    echo 0
}

# Walk wlsunset's SIGUSR1 cycle until it lands on the requested mode.
set_mode() {
    local target=$1 cur steps i
    start
    cur=$(current)
    [[ $cur == off ]] && cur=auto
    steps=$(( ( $(index_of "$target") - $(index_of "$cur") + 3 ) % 3 ))
    for (( i = 0; i < steps; i++ )); do
        pkill -USR1 -x wlsunset || true
        sleep 0.1
    done
    echo "$target" > "$STATE"
}

# Neither gamma nor temperature is adjustable at runtime, so both relaunch
# wlsunset and put it back into whatever mode was active.
relaunch() {
    local mode
    mode=$(current)
    [[ $mode == off ]] && mode=auto
    pkill -x wlsunset 2>/dev/null || true
    sleep 0.3
    launch
    set_mode "$mode"
}

set_gamma() {
    awk -v g="$1" 'BEGIN { exit !(g > 0 && g <= 1.0) }' \
        || { echo "gamma must be in (0, 1.0]" >&2; exit 1; }
    echo "$1" > "$GAMMA_FILE"
    relaunch
}

set_temp() {
    awk -v t="$1" 'BEGIN { exit !(t >= 1000 && t <= 10000) }' \
        || { echo "temperature must be 1000-10000 K" >&2; exit 1; }
    echo "$1" > "$TEMP_FILE"
    relaunch
}

refresh_bar() { pkill -RTMIN+9 waybar 2>/dev/null || true; }

print_status() {
    local g suffix
    g=$(gamma)
    suffix=""
    [[ $g != "1.0" ]] && suffix=", dimmed to $g gamma"
    case "$(current)" in
        day)
            printf '{"text":"󰖙","tooltip":"Blue light filter off, held at %sK%s. Click for night.","class":"day","alt":"day"}\n' "$DAY_TEMP" "$suffix"
            ;;
        night)
            printf '{"text":"󰖔","tooltip":"Blue light filter on, held at %sK%s. Click for automatic.","class":"night","alt":"night"}\n' "$(night_temp)" "$suffix"
            ;;
        off)
            printf '{"text":"󰖙","tooltip":"wlsunset is not running. Click to start it.","class":"off","alt":"off"}\n'
            ;;
        *)
            printf '{"text":"󰔎","tooltip":"Blue light filter automatic: %sK by day, %sK after sunset%s. Click to hold day.","class":"auto","alt":"auto"}\n' "$DAY_TEMP" "$(night_temp)" "$suffix"
            ;;
    esac
}

case "${1:-status}" in
    toggle)
        if ! running; then
            start
        else
            cur=$(current)
            set_mode "${ORDER[$(( ( $(index_of "$cur") + 1 ) % 3 ))]}"
        fi
        refresh_bar
        ;;
    auto|day|night) set_mode "$1"; refresh_bar ;;
    dim)   set_gamma "${2:?usage: $0 dim <0.1-1.0>}"; refresh_bar ;;
    temp)  set_temp "${2:?usage: $0 temp <1000-10000>}"; refresh_bar ;;
    start) start ;;
    status) print_status ;;
    *) echo "usage: $0 {status|toggle|auto|day|night|dim <0.1-1.0>|temp <1000-10000>|start}" >&2; exit 1 ;;
esac
