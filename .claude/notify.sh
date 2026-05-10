#!/bin/sh
# Hook payload on stdin → categorized desktop notification via mako.
input=$(cat)
g() { printf '%s' "$input" | jq -r ".${1} // \"\""; }
event=$(g hook_event_name); cwd=$(g cwd); tool=$(g tool_name); msg=$(g message)
proj=$(basename "$cwd")

# Dedupe: silence overlapping fires within 2s for the same project.
f="/tmp/claude-notify-last-${proj:-_}"
[ -f "$f" ] && [ $(($(date +%s) - $(cat "$f"))) -lt 2 ] && exit 0
date +%s > "$f"

# Event → urgency + category (per-event mako color) + body.
case "$event" in
    Stop)         u=low;      c=claude-done;      body="" ;;
    StopFailure)  u=critical; c=claude-error;     body="${msg:-Claude crashed — check the chat}" ;;
    Notification) u=critical; c=claude-waiting;   body="${msg:-Waiting for your input}" ;;
    Elicitation)  u=critical; c=claude-elicit;    body="MCP server needs input" ;;
    PermissionRequest)
        u=critical
        case "$tool" in
            AskUserQuestion) c=claude-question;   body="Question — pick an option" ;;
            *)               c=claude-permission; body="Approve ${tool:-tool}?" ;;
        esac ;;
    *)            u=normal;   c=claude-other;     body="${msg:-Update}" ;;
esac

# Title = matching VSCode window's title (minus suffix), fallback to "Claude · proj".
title=$(swaymsg -t get_tree 2>/dev/null | jq -r --arg p "$proj" \
    '[.. | objects | select(.window_properties?.class?=="Code" and ((.name//"")|endswith(" - "+$p+" - Visual Studio Code"))) | .name] | first // ""')
title=${title%" - Visual Studio Code"}
title=${title:-Claude · $proj}

# Fire and remember id→cwd so the click handler can focus the right workspace.
id=$(notify-send -p -u "$u" -c "$c" -a 'Claude Code' -i utilities-terminal "$title" "$body")
m=/tmp/claude-notify-map; touch "$m"
{ awk -v i="$id" -F: '$1!=i' "$m"; printf '%s:%s\n' "$id" "$cwd"; } > "$m.t" && mv "$m.t" "$m"
