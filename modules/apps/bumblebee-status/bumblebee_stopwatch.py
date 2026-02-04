#!/usr/bin/env python3

import core.module
import core.widget
import core.input
import time
import os
import json

class Module(core.module.Module):
    def __init__(self, config, theme):
        super().__init__(config, theme, [core.widget.Widget(self.full_text)])
        
        self._state_file = os.path.expanduser("~/.cache/bumblebee-stopwatch.json")
        self._running = False
        self._start_time = None
        self._elapsed = 0
        
        core.input.register(self, button=core.input.LEFT_MOUSE, cmd=self.toggle)
        core.input.register(self, button=core.input.RIGHT_MOUSE, cmd=self.reset)
        
        self.load_state()

    def load_state(self):
        try:
            with open(self._state_file, 'r') as f:
                state = json.load(f)
                self._running = state.get("running", False)
                self._start_time = state.get("start_time")
                self._elapsed = state.get("elapsed", 0)
        except (FileNotFoundError, json.JSONDecodeError):
            self.reset()

    def save_state(self):
        with open(self._state_file, 'w') as f:
            json.dump({
                "running": self._running,
                "start_time": self._start_time,
                "elapsed": self._elapsed
            }, f)

    def toggle(self, event):
        if self._running:
            self._elapsed += time.time() - self._start_time
            self._running = False
            self._start_time = None
        else:
            self._running = True
            self._start_time = time.time()
        self.save_state()

    def reset(self, event=None):
        self._running = False
        self._start_time = None
        self._elapsed = 0
        self.save_state()

    def full_text(self, widget):
        if self._running:
            current_elapsed = self._elapsed + (time.time() - self._start_time)
            icon = ""
        else:
            current_elapsed = self._elapsed
            icon = ""
            
        m, s = divmod(int(current_elapsed), 60)
        h, m = divmod(m, 60)
        return f"{icon} {h:02}:{m:02}:{s:02}"

    # FIXED: Removed 'widgets' parameter
    def update(self):
        widget = self.widget()
        widget.set("state", "running" if self._running else "paused")

    def state(self, widget):
        return ["running" if self._running else "paused"]
