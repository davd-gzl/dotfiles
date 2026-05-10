#!/bin/sh
# Hook payload on stdin: { hook_event_name, message, cwd, ... }
input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
proj=$(basename "$cwd")
suffix=" - $proj - Visual Studio Code"

# Event → urgency (mako maps to color: critical=red, low=green) + body.
case "$event" in
    Stop)              urgency=low;      msg="Done" ;;
    StopFailure)       urgency=critical; msg="Claude errored" ;;
    Notification)      urgency=critical; msg=$(printf '%s' "$input" | jq -r '.message // "Waiting for input"') ;;
    PreToolUse)        urgency=critical; msg="Question for you" ;;
    PermissionRequest) urgency=critical; msg="Permission requested" ;;
    Elicitation)       urgency=critical; msg="Input needed" ;;
    *)                 urgency=normal;   msg=$(printf '%s' "$input" | jq -r '.message // "Update"') ;;
esac

# Debug log so we can see what events actually fire
printf '%s [%s] urgency=%s msg=%s\n' "$(date -Iseconds)" "$event" "$urgency" "$msg" >> /tmp/claude-notify.log

# Use the matching VSCode window's title (minus " - Visual Studio Code") as
# the notification title, so the user can tell which chat it came from.
win=$(swaymsg -t get_tree 2>/dev/null | jq -r --arg s "$suffix" '[.. | objects | select(.window_properties?.class? == "Code" and ((.name // "") | endswith($s))) | .name] | first // ""')
title=${win:-Claude · $proj}
title=${title% - Visual Studio Code}

id=$(notify-send -p -u "$urgency" -a 'Claude Code' -i utilities-terminal "$title" "$msg")

# Remember id→cwd so the click handler can focus the right workspace
m=/tmp/claude-notify-map
touch "$m"
{ awk -v id="$id" -F: '$1 != id' "$m"; printf '%s:%s\n' "$id" "$cwd"; } > "$m.t" && mv "$m.t" "$m"
