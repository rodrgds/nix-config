# Main modules entry point
{ ... }:
{
  imports = [
    ./apps
    ./core
    ./scripts
    ../secrets
  ];
}
