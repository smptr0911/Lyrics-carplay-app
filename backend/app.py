"""Loopback-only development server, not a production HTTP or auth server."""
import argparse
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from threading import Lock
import time
from urllib.parse import parse_qs, urlsplit

from .providers import DemoProvider, LyricsProvider, ProviderUnavailable


class RateLimit:
    def __init__(self, limit=60, window=60):
        self.limit, self.window = limit, window
        self.requests = deque()
        self.lock = Lock()

    def allow(self, now=None):
        now = time.monotonic() if now is None else now
        with self.lock:
            while self.requests and self.requests[0] <= now - self.window:
                self.requests.popleft()
            if len(self.requests) >= self.limit:
                return False
            self.requests.append(now)
            return True


def make_server(port=8787, provider: LyricsProvider | None = None, limiter=None):
    provider = provider if provider is not None else DemoProvider()
    limiter = limiter if limiter is not None else RateLimit()

    class Handler(BaseHTTPRequestHandler):
        server_version = "LyricsDevelopment"
        sys_version = ""

        def log_message(self, *_):
            # Never log URLs, track IDs, provider bodies, or future credentials.
            pass

        def respond(self, status, body, extra_headers=None):
            payload = json.dumps(body, ensure_ascii=False, allow_nan=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            for key, value in (extra_headers or {}).items():
                self.send_header(key, value)
            self.end_headers()
            self.wfile.write(payload)

        def do_GET(self):
            if len(self.path) > 2048:
                self.respond(414, {"error": "request_too_long"})
                return
            try:
                url = urlsplit(self.path)
                query = parse_qs(url.query, keep_blank_values=True, max_num_fields=4)
            except ValueError:
                self.respond(400, {"error": "invalid_request"})
                return
            if url.path == "/health" and not url.query:
                self.respond(200, {"status": "ok", "mode": "local-development"})
                return
            if url.path != "/v1/lyrics":
                self.respond(404, {"error": "not_found"})
                return
            values = query.get("trackID", [])
            if set(query) != {"trackID"} or len(values) != 1 or not values[0].strip() or len(values[0]) > 256:
                self.respond(400, {"error": "invalid_track_id"})
                return
            if not limiter.allow():
                self.respond(429, {"error": "rate_limited"}, {"Retry-After": str(limiter.window)})
                return
            # Enforce the source policy at both client and server boundaries.
            if values[0].startswith("spotify:"):
                self.respond(403, {"error": "source_not_supported"})
                return
            try:
                document = provider.lyrics(values[0])
                if document is None:
                    self.respond(404, {"error": "lyrics_unavailable"})
                    return
                self.respond(200, document)
            except ProviderUnavailable:
                self.respond(503, {"error": "provider_unavailable"})
            except Exception:
                # No vendor errors, secrets, or restricted payloads in public failures.
                self.respond(502, {"error": "provider_failure"})

        def do_POST(self):
            self.respond(405, {"error": "method_not_allowed"}, {"Allow": "GET"})

    # Fixed loopback binding: never expose the dev fixture service on a public interface.
    return ThreadingHTTPServer(("localhost", port), Handler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("port must be between 1 and 65535")
    server = make_server(args.port)
    print(f"Local demo server: http://localhost:{args.port}/v1/lyrics")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
