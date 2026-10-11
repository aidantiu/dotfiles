#!/usr/bin/env python3
"""OpenAI-compatible chat.completions stub on 127.0.0.1. Appends each requested
model id to LOG (argv[2]) and streams a one-word reply. argv[1] = port file.
If the last message is a user message containing SPAWN_TASK and the request offers
the `task` tool, it answers with a `task` tool call instead (drives a sub-agent spawn)."""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = sys.argv[2]

def text_of(msg):
    c = msg.get("content")
    if isinstance(c, str): return c
    return " ".join(p.get("text", "") for p in c or [] if isinstance(p, dict))

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        with open(LOG, "a") as f: f.write(body.get("model", "?") + "\n")
        self.send_response(200); self.send_header("content-type", "text/event-stream"); self.end_headers()
        msgs = body.get("messages") or [{}]
        tools = [t.get("function", {}).get("name") for t in body.get("tools") or []]
        base = {"id": "x", "object": "chat.completion.chunk", "model": body.get("model")}
        if msgs[-1].get("role") == "user" and "SPAWN_TASK" in text_of(msgs[-1]) and "task" in tools:
            args = {"i": "spawn", "context": "# Goal\nreply ok", "tasks": [{"task": "Reply with the word ok.", "solutionSpace": "none", "name": "Child"}]}
            delta = {"role": "assistant", "tool_calls": [{"index": 0, "id": "call_1", "type": "function",
                     "function": {"name": "task", "arguments": json.dumps(args)}}]}
            finish = "tool_calls"
        else:
            delta, finish = {"role": "assistant", "content": "ok"}, "stop"
        chunk = {**base, "choices": [{"index": 0, "delta": delta, "finish_reason": None}]}
        done = {**base, "choices": [{"index": 0, "delta": {}, "finish_reason": finish}],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}}
        for c in (chunk, done): self.wfile.write(f"data: {json.dumps(c)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")

srv = HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(srv.server_address[1]))
srv.serve_forever()
