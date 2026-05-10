#!/bin/sh
# Hook payload on stdin: { hook_event_name, message, cwd, ... }
input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
proj=$(basename "$cwd")
suffix=" - $proj - Visual Studio Code"

# Dedupe: skip if a notification for this project fired in the last 2 seconds.
# Catches Stop+Notification and similar overlaps that target the same moment.
last_file="/tmp/claude-notify-last-${proj:-_}"
now=$(date +%s)
if [ -f "$last_file" ] && [ "$((now - $(cat "$last_file" 2>/dev/null || echo 0)))" -lt 2 ]; then
    printf '%s [%s] DEDUPED\n' "$(date -Iseconds)" "$event" >> /tmp/claude-notify.log
    exit 0
fi
echo "$now" > "$last_file"

# Event → urgency + category (per-event mako color) + body.
tool=$(printf '%s' "$input" | jq -r '.tool_name // .tool // ""')
case "$event" in
    Stop)              urgency=low;      cat=claude-done;       body="" ;;
    StopFailure)       urgency=critical; cat=claude-error;      body=$(printf '%s' "$input" | jq -r '.message // .error // "Claude crashed — check the chat"') ;;
    Notification)      urgency=critical; cat=claude-waiting;    body=$(printf '%s' "$input" | jq -r '.message // "Waiting for your input"') ;;
    PermissionRequest)
        # AskUserQuestion isn't really a permission ask — render it as a question
        if [ "$tool" = "AskUserQuestion" ]; then
            urgency=critical; cat=claude-question; body="Question — pick an option"
        else
            urgency=critical; cat=claude-permission; body="Approve ${tool:-tool}?"
        fi
        ;;
    Elicitation)       urgency=critical; cat=claude-elicit;     body="MCP server needs input" ;;
    *)                 urgency=normal;   cat=claude-other;      body=$(printf '%s' "$input" | jq -r '.message // "Update"') ;;
esac

printf '%s [%s] cat=%s body=%s\n' "$(date -Iseconds)" "$event" "$cat" "$body" >> /tmp/claude-notify.log

# Use the matching VSCode window's title (minus " - Visual Studio Code") as
# the notification title, so the user can tell which chat it came from.
win=$(swaymsg -t get_tree 2>/dev/null | jq -r --arg s "$suffix" '[.. | objects | select(.window_properties?.class? == "Code" and ((.name // "") | endswith($s))) | .name] | first // ""')
title=${win:-Claude · $proj}
title=${title% - Visual Studio Code}

id=$(notify-send -p -u "$urgency" -c "$cat" -a 'Claude Code' -i utilities-terminal "$title" "$body")

# Remember id→cwd so the click handler can focus the right workspace
m=/tmp/claude-notify-map
touch "$m"
{ awk -v id="$id" -F: '$1 != id' "$m"; printf '%s:%s\n' "$id" "$cwd"; } > "$m.t" && mv "$m.t" "$m"
