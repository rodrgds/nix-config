#!/usr/bin/env python3
"""
CS2 Game State Integration (GSI) Server
Listens for HTTP POST requests from CS2 and writes K/D to /tmp/cs2_score
"""

import json
import http.server
import socketserver
from datetime import datetime

SCORE_FILE = "/tmp/cs2_score"
PORT = 3013


class GSIHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length == 0:
            self.send_response(400)
            self.end_headers()
            return
            
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data)
            self.process_game_state(data)
            self.send_response(200)
        except json.JSONDecodeError:
            self.send_response(400)
        
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'OK')
    
    def process_game_state(self, data):
        import sys
        player = data.get('player', {})
        activity = player.get('activity', 'unknown')
        
        # Debug logging
        sys.stderr.write(f"[DEBUG] Activity: {activity}\n")
        
        # Not in a game or just in menu
        if activity != 'playing':
            if activity == 'menu':
                self.write_score("in menu")
            else:
                self.write_score("not playing")
            return
        
        # Check if match_stats exists (only available when in a live match)
        match_stats = player.get('match_stats')
        if not match_stats:
            self.write_score("not in game")
            return
        
        kills = match_stats.get('kills', 0)
        deaths = match_stats.get('deaths', 0)
        
        kd_str = f"{kills}-{deaths}"
        self.write_score(kd_str)
    
    def write_score(self, score_str):
        with open(SCORE_FILE, 'w') as f:
            f.write(score_str)
            f.write('\n')
            f.write(str(datetime.now().isoformat()))
    
    def log_message(self, format, *args):
        # Log to stderr so it appears in systemd journal
        import sys
        sys.stderr.write(f"[{datetime.now().isoformat()}] {format % args}\n")


def main():
    with open(SCORE_FILE, 'w') as f:
        f.write("not in game\n")
    
    with socketserver.TCPServer(("", PORT), GSIHandler) as httpd:
        print(f"CS2 GSI server running on port {PORT}")
        print(f"Writing K/D to {SCORE_FILE}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down...")


if __name__ == "__main__":
    main()
