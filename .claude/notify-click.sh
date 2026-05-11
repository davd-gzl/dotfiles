#!/bin/sh
# Invoked by mako on left-click. mako passes the notification id as $1.
id=$1
m=/tmp/claude-notify-map

makoctl dismiss -n "$id" 2>/dev/null

cwd=$(awk -v id="$id" -F: '$1 == id { sub(/^[^:]*:/, ""); print; exit }' "$m" 2>/dev/null)
[ -z "$cwd" ] && exit 0

proj=$(basename "$cwd")
swaymsg "[class=\"Code\" title=\" - $proj - Visual Studio Code\$\"]" focus >/dev/null 2>&1
