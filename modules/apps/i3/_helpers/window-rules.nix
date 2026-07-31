_: [
  {
    command = "floating enable";
    criteria = {
      title = "video0 - mpv";
    };
  }
  {
    command = "sticky enable";
    criteria = {
      title = "video0 - mpv";
    };
  }
  {
    command = "floating enable, move position center";
    criteria = {
      class = "(?i)vicinae";
    };
  }
  {
    command = "border pixel 2";
    criteria = {
      class = "^.*";
    };
  }
]
