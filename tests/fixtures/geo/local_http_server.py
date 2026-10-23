"""Bounded local fixture server; all coordinates/heights/images are synthetic."""
import json
import os
import struct
import threading
import time
import urllib.parse
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPORT = Path(os.environ["APEX_GEO_MOCK_REPORT"]) if "APEX_GEO_MOCK_REPORT" in os.environ else None
REQUESTS = []
LOCK = threading.Lock()


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


PNG = (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0))
       + png_chunk(b"IDAT", zlib.compress(b"\0\x80\xa0\x80\x80\xa0\x80" * 2)) + png_chunk(b"IEND", b""))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        conditional = self.headers.get("If-None-Match") == '"synthetic-tile-v1"'
        with LOCK:
            REQUESTS.append({"path": parsed.path, "conditional": conditional,
                             "query": query, "user_agent": self.headers.get("User-Agent", "")})
            if REPORT is not None:
                REPORT.write_text(json.dumps(REQUESTS, indent=2))
        if parsed.path.startswith("/tiles/"):
            self.send_response(304 if conditional else 200)
            self.send_header("Content-Type", "image/png")
            self.send_header("ETag", '"synthetic-tile-v1"')
            self.send_header("Last-Modified", "Tue, 20 Oct 2026 00:00:00 GMT")
            self.send_header("Cache-Control", "max-age=60")
            self.send_header("Content-Length", "0" if conditional else str(len(PNG)))
            self.end_headers()
            if not conditional:
                self.wfile.write(PNG)
            return
        if parsed.path == "/slow":
            time.sleep(0.5)
        if "locations" in query:
            coordinates = [[float(value) for value in pair.split(",")]
                           for pair in query["locations"][0].split("|")]
        else:
            coordinates = list(zip(map(float, query.get("latitude", [""])[0].split(",")),
                                   map(float, query.get("longitude", [""])[0].split(","))))
        elevations = [round(2000.0 + lat * 5.0 + abs(lon) * 2.0, 3) for lat, lon in coordinates]
        if parsed.path == "/missing":
            elevations[-1] = None
        elif parsed.path == "/bad-count":
            elevations = elevations[:-1]
        payload = ({"elevation": elevations} if "latitude" in query else
                   {"status": "OK", "results": [{"elevation": value} for value in elevations]})
        body = json.dumps(payload).encode()
        try:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Cancellation is an intentional fixture action.


if __name__ == "__main__":
    print("GEO_MOCK listening on http://127.0.0.1:8782", flush=True)
    try:
        ThreadingHTTPServer(("127.0.0.1", 8782), Handler).serve_forever()
    except KeyboardInterrupt:
        pass
