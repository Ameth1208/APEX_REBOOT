"""Servidor local para la exportación Web; requiere Python 3 en el ordenador."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SimpleHTTPRequestHandler.extensions_map['.wasm'] = 'application/wasm'
handler = partial(SimpleHTTPRequestHandler, directory=str(Path(__file__).resolve().parent))
with ThreadingHTTPServer(('127.0.0.1', 8765), handler) as server:
    print('Abre http://127.0.0.1:8765/index.html — Ctrl+C para cerrar.', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
