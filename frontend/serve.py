import http.server
import socketserver
import os

PORT = 3000
DIRECTORY = "build/web"

class SPADirectoryHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # Try to serve the file
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path):
            # If file does not exist, serve index.html
            self.path = '/index.html'
        return super().do_GET()

with socketserver.TCPServer(("", PORT), SPADirectoryHandler) as httpd:
    print(f"Serving SPA at port {PORT}")
    httpd.serve_forever()
