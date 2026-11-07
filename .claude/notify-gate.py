#!/usr/bin/env python3
# Stop hook helper for notify.sh: does this stopped turn need the user?
#   notify-gate.py <transcript>   prints "needs <line>" or "done <line>", or nothing to stay silent.
# A reply asking something always notifies. Otherwise silent while background work the session
# started still runs, and for a request answered within LONG_RUN seconds of being typed.
import json
import re
import sys
from datetime import datetime

LONG_RUN = 300
ASKS = re.compile(r"^`[a-zA-Z][a-zA-Z ]*`:|\bwaits? on `|\b(?:say|type|send) [`\"]|\btell me to\b|\?\s*(?:\n+TL;DR.*)?\Z", re.M)
FENCE = re.compile(r"```.*?```", re.S)
LAUNCHED = ("Async agent launched", "Workflow launched", "running in background with ID")
ENDED = re.compile(r"<tool-use-id>(.*?)</tool-use-id>")


def when(row):
    try:
        return datetime.fromisoformat(row["timestamp"].replace("Z", "+00:00")).timestamp()
    except (KeyError, ValueError, AttributeError):
        return None


def typed(content):
    """The prompt's text where a person sent it, or None for a tool result or a harness notice."""
    if isinstance(content, list):
        content = " ".join(x.get("text", "") for x in content if isinstance(x, dict) and x.get("type") == "text")
    if not isinstance(content, str) or not content.strip() or content.lstrip().startswith("<"):
        return None
    return content


class Turn:
    def __init__(self):
        self.reply, self.ask, self.asked_at, self.now = "", None, None, None
        self.running = set()

    def feed(self, row):
        """Takes one transcript row; a notice carrying a tool-use id ends that background task."""
        kind = row.get("type")
        if row.get("isSidechain"):
            return
        if kind == "queue-operation" or (kind == "attachment" and (row.get("attachment") or {}).get("type") == "queued_command"):
            if row.get("operation") != "remove":
                self.running.difference_update(ENDED.findall(json.dumps(row)))
            return
        if kind not in ("user", "assistant"):
            return
        self.now = when(row) or self.now
        content = (row.get("message") or {}).get("content")
        if kind == "assistant" and isinstance(content, list):
            blocks = [x for x in content if isinstance(x, dict)]
            self.reply = "\n".join(x.get("text", "") for x in blocks if x.get("type") == "text") or self.reply
            for b in blocks:
                if b.get("type") == "tool_use" and b.get("name", "").endswith("wrap_up"):
                    self.ask = (b.get("input") or {}).get("ask") or None
        elif kind == "user":
            self.running.difference_update(ENDED.findall(content if isinstance(content, str) else json.dumps(content)))
            for x in content if isinstance(content, list) else []:
                if isinstance(x, dict) and x.get("type") == "tool_result":
                    result = x.get("content")
                    result = result if isinstance(result, str) else json.dumps(result)
                    if any(s in result[:300] for s in LAUNCHED):
                        self.running.add(x.get("tool_use_id"))
            if typed(content) is not None:
                self.asked_at, self.ask = when(row), None

    def verdict(self):
        text = FENCE.sub("", self.reply).strip()
        tldr = next((l[6:].strip() for l in reversed(text.splitlines()) if l.startswith("TL;DR:")), "")
        if self.ask:
            return f"needs {self.ask}"
        if ASKS.search(text):
            return f"needs {tldr or text.splitlines()[-1]}"
        if self.running or not (self.now and self.asked_at) or self.now - self.asked_at < LONG_RUN:
            return None
        ended = next((l for l in text.splitlines() if l.startswith(("Done:", "Not done:"))), tldr)
        return f"done {ended}".rstrip()


if __name__ == "__main__":
    turn = Turn()
    try:
        for raw in open(sys.argv[1], encoding="utf-8", errors="replace"):
            try:
                turn.feed(json.loads(raw))
            except ValueError:
                continue
        print(turn.verdict() or "")
    except (OSError, IndexError):
        print("needs Check the session")
