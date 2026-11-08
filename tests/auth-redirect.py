"""Verify the real URLSession delegate never forwards an authentication body."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import subprocess
import sys
import threading

received = []
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        received.append((self.path, self.rfile.read(int(self.headers.get('Content-Length', '0')))))
        self.send_response(307 if self.path == '/start' else 200)
        if self.path == '/start':
            self.send_header('Location', '/unexpected-destination')
        self.send_header('Content-Length', '0')
        self.end_headers()

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    subprocess.run([sys.argv[1], f'http://127.0.0.1:{server.server_port}/start'], check=True, timeout=20)
    assert received == [('/start', b'test-credential')], 'Authentication body reached redirect destination'
    print('PASS: fixture received one initial request and no redirected credentials')
finally:
    server.shutdown()
    server.server_close()
