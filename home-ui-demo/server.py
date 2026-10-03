"""Serves this folder as the sandbox home page."""
import functools
import http.server
import pathlib

# Hard-coded port the home page URL is forwarded to; keep it unchanged.
PORT = 8089

handler = functools.partial(
    http.server.SimpleHTTPRequestHandler,
    directory=pathlib.Path(__file__).parent,
)
# 0.0.0.0, because the forwarded traffic comes from outside this container.
http.server.ThreadingHTTPServer(('0.0.0.0', PORT), handler).serve_forever()
