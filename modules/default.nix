# Main modules entry point
{ ... }:
{
  imports = [
    ./apps
    ./core
    ./hosting
    ./scripts
    ./services
    ../secrets
  ];
}
