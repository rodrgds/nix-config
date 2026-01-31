{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.bumblebee-status;
in
{
  options.apps.bumblebee-status = {
    enable = lib.mkEnableOption "Enable bumblebee-status with custom stopwatch module";
  };

  config = lib.mkIf cfg.enable {
    # The bumblebee-status package is already included in i3 module
    # This module handles the custom stopwatch script

    home-manager.users.${username} =
      { ... }:
      {
        home.file.".config/bumblebee-status/modules/stopwatch.py".text = ''
          import os
          import time
          import threading

          import core.module
          import core.widget
          import core.input

          class Module(core.module.Module):
              def __init__(self, config, theme):
                  super().__init__(config, theme, core.widget.Widget(self.get_time))
                  self._start_time = None
                  self._elapsed = 0
                  self._running = False
                  self._lock = threading.Lock()

                  core.input.register(
                      self,
                      button=core.input.LEFT_MOUSE,
                      cmd=self.toggle
                  )
                  core.input.register(
                      self,
                      button=core.input.RIGHT_MOUSE,
                      cmd=self.reset
                  )

              def toggle(self, event):
                  with self._lock:
                      if self._running:
                          self._elapsed += time.time() - self._start_time
                          self._running = False
                      else:
                          self._start_time = time.time()
                          self._running = True

              def reset(self, event):
                  with self._lock:
                      self._start_time = None
                      self._elapsed = 0
                      self._running = False

              def get_time(self, widget):
                  with self._lock:
                      if self._running:
                          total = self._elapsed + (time.time() - self._start_time)
                      else:
                          total = self._elapsed

                      hours = int(total // 3600)
                      minutes = int((total % 3600) // 60)
                      seconds = int(total % 60)

                      if hours > 0:
                          return f"{hours}:{minutes:02d}:{seconds:02d}"
                      else:
                          return f"{minutes}:{seconds:02d}"

              def update(self):
                  pass

              def state(self, widget):
                  if self._running:
                      return ["running"]
                  return []
        '';
      };
  };
}
