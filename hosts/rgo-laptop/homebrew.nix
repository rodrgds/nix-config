# MacBook Pro M4 Homebrew configuration
# Host-specific Homebrew additions (optional)
{ config, pkgs, ... }:
{
  # Add any host-specific Homebrew packages here
  # Most apps are managed by their respective modules in modules/apps/
  homebrew = {
    # Example: host-specific taps, brews, or casks
    # taps = [ "some/tap" ];
    # brews = [ "some-cli-tool" ];
    # casks = [ "some-app" ];
  };
}
