let
  names = {
    terminal = "1:";
    web = "2:";
    files = "3:";
    personal = "4:";
    chat = "5:";
    gaming = "6:";
    seven = "7";
    eight = "8";
    nine = "9";
    music = "10:";
  };
in
{
  inherit names;

  outputAssign = [
    {
      output = "DP-0";
      workspace = names.terminal;
    }
    {
      output = "HDMI-0";
      workspace = names.web;
    }
    {
      output = "DP-0";
      workspace = names.files;
    }
    {
      output = "HDMI-0";
      workspace = names.chat;
    }
    {
      output = "HDMI-0";
      workspace = names.music;
    }
  ];
}
