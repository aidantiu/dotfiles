#!/usr/bin/env python3
"""OpenAI-compatible chat.completions stub on 127.0.0.1. Appends each requested
model id to LOG (argv[2]) and streams a one-word reply. argv[1] = port file."""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = sys.argv[2]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        with open(LOG, "a") as f: f.write(body.get("model", "?") + "\n")
        self.send_response(200); self.send_header("content-type", "text/event-stream"); self.end_headers()
        chunk = {"id": "x", "object": "chat.completion.chunk", "model": body.get("model"),
                 "choices": [{"index": 0, "delta": {"role": "assistant", "content": "ok"}, "finish_reason": None}]}
        done = {**chunk, "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}}
        for c in (chunk, done): self.wfile.write(f"data: {json.dumps(c)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")

srv = HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(srv.server_address[1]))
srv.serve_forever()
