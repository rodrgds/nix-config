{ constants }:
{
  # Shared behavior and design tokens for the platform-native bar renderers.
  # Quickshell (Linux) and SketchyBar (macOS) intentionally keep their own
  # implementation code; this file is the small contract they agree on.
  geometry = {
    barHeight = 28;
    controlHeight = 24;
    controlMinWidth = 26;
    outerGutter = 4;
    itemGap = 2;
    cornerRadius = 3;
  };

  inherit (constants) colors fonts;

  foregroundMuted = "#878580";

  workspaces = [
    {
      id = 1;
      icon = "";
      name = "Terminal";
    }
    {
      id = 2;
      icon = "";
      name = "Web";
    }
    {
      id = 3;
      icon = "";
      name = "Files";
    }
    {
      id = 4;
      icon = "";
      name = "Personal";
    }
    {
      id = 5;
      icon = "";
      name = "Chat";
    }
    {
      id = 6;
      icon = "";
      name = "Gaming";
    }
    {
      id = 7;
      icon = "";
      name = "Workspace 7";
    }
    {
      id = 8;
      icon = "";
      name = "Workspace 8";
    }
    {
      id = 9;
      icon = "";
      name = "Workspace 9";
    }
  ];

}
