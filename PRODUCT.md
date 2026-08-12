# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

This is Rodrigo's personal workstation configuration. The primary desktop user moves between software development, everyday communication, media work, and latency-sensitive gaming on a dual-monitor NVIDIA desktop.

## Product Purpose

The repository makes one rebuild produce a complete, repeatable desktop environment. For `rgo-desktop`, success means Hyprland and Wayland can become the daily default without losing the established i3 workflow or an immediate X11 fallback.

## Operating Context

- NixOS desktop with an NVIDIA RTX 2070, Ryzen 7 5700X, and two 1920×1080 144 Hz displays.
- Keyboard-driven tiling with ten task-oriented workspaces, a compact system bar, a launcher, notifications, screenshots, clipboard workflows, and desktop controls.
- Steam and Counter-Strike 2 are first-class workloads; low latency and a reliable fallback matter more than ornamental effects.
- The same repository also configures macOS and VPS hosts, so Linux desktop choices must remain platform-gated.

## Capabilities and Constraints

- Hyprland/Wayland is the default desktop experiment.
- The complete i3/X11/Polybar implementation remains installed and selectable at login.
- Quickshell replaces Polybar only in the Hyprland session and preserves the familiar workspace-left, telemetry-and-controls-right information architecture.
- Native Wayland and XWayland must coexist because the installed application set includes legacy or explicitly X11-bound software.
- NVIDIA, portals, capture, idle handling, wallpapers, display switching, clipboard tools, and gaming launches must be session-aware.
- Existing user-authored application configuration and unrelated working-tree changes are not migration material.

## Brand Commitments

- Preserve the incumbent Flexoki dark palette, JetBrains Mono data typography, compact flat bar, orange focus state, and task-oriented workspace icons.
- Prefer restrained, legible, low-distraction controls over decorative desktop chrome.

## Evidence on Hand

- `screenshot.png` shows the incumbent dual-monitor desktop and compact top-bar treatment.
- `modules/apps/i3/` defines the established keybindings, workspace model, routing, and window behavior.
- `modules/apps/polybar/default.nix` defines the bar's content, order, colors, typography, and click actions.
- No performance benchmark for the new Wayland session exists yet; future work must not claim one until measured on the machine.

## Product Principles

- Preserve muscle memory wherever the compositor model permits it.
- Keep fallback paths real, selectable, and maintained—not merely archived source.
- Make session-specific behavior explicit instead of leaking Wayland settings into X11 or vice versa.
- Establish a conservative, observable baseline before opting into experimental latency or rendering features.
- Keep desktop state useful at a glance without competing with focused work or fullscreen games.

## Accessibility & Inclusion

Status text and inactive controls must maintain readable contrast at the compact 28 px bar height. Every clickable bar control needs a tooltip or clear text label, and state must not rely on color alone.
