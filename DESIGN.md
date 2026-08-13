---
name: RGO Quickshell Instrument Rail
description: A compact, flat Flexoki system rail for workspace motion, machine health, and desktop controls.
colors:
  rail-black: "#100F0F"
  raised-black: "#1C1B1A"
  hover-black: "#282726"
  warm-foreground: "#CECDC3"
  muted-foreground: "#878580"
  danger-bright: "#D14D41"
  warning-bright: "#D0A215"
  telemetry-orange: "#BC5215"
  focus-bright: "#DA702C"
typography:
  label:
    fontFamily: "JetBrainsMono Nerd Font"
    fontSize: "12px"
  tooltip:
    fontFamily: "Bricolage Grotesque"
    fontSize: "11px"
rounded:
  interactive: "3px"
  tooltip: "4px"
spacing:
  control-gap: "2px"
  rail-gutter: "4px"
  content-inset: "5px"
  action-inset: "6px"
components:
  workspace-button:
    backgroundColor: "transparent"
    textColor: "{colors.muted-foreground}"
    typography: "{typography.label}"
    rounded: "{rounded.interactive}"
    padding: "0 5px"
    height: "24px"
  workspace-button-focused:
    backgroundColor: "{colors.focus-bright}"
    textColor: "{colors.rail-black}"
    typography: "{typography.label}"
    rounded: "{rounded.interactive}"
    padding: "0 5px"
    height: "24px"
  workspace-button-urgent:
    backgroundColor: "{colors.raised-black}"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.label}"
    rounded: "{rounded.interactive}"
    padding: "0 5px"
    height: "24px"
  metric-widget:
    backgroundColor: "transparent"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.label}"
    padding: "0 5px"
    height: "24px"
  tool-button:
    backgroundColor: "transparent"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.label}"
    rounded: "{rounded.interactive}"
    padding: "0 6px"
    height: "24px"
  tool-button-hover:
    backgroundColor: "{colors.hover-black}"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.label}"
    rounded: "{rounded.interactive}"
    padding: "0 6px"
    height: "24px"
  tool-button-danger-hover:
    backgroundColor: "{colors.raised-black}"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.label}"
    rounded: "{rounded.interactive}"
    padding: "0 6px"
    height: "24px"
  tray-item:
    backgroundColor: "transparent"
    textColor: "{colors.muted-foreground}"
    rounded: "{rounded.interactive}"
    height: "24px"
    width: "26px"
  clock-widget:
    backgroundColor: "transparent"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.label}"
    padding: "0 5px"
    height: "24px"
  audio-control:
    backgroundColor: "transparent"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.label}"
    rounded: "{rounded.interactive}"
    padding: "0 6px"
    height: "24px"
  tooltip:
    backgroundColor: "{colors.raised-black}"
    textColor: "{colors.warm-foreground}"
    typography: "{typography.tooltip}"
    rounded: "{rounded.tooltip}"
    padding: "5px 6px"
---

# Design System: RGO Quickshell Instrument Rail

## Overview

**Creative North Star: "The Operational Instrument Rail"**

The rail behaves like a narrow hardware readout rather than an application surface: continuously available, information-dense, and quiet until state demands attention. Its opaque Flexoki dark field preserves focus on windows beneath it, while warm mono data and rare orange signals make the active workspace and system pressure immediately legible.

Its visual hierarchy follows the workstation task: orient on the left, scan health on the right, then act through compact controls without leaving the rail. Ornament, atmospheric effects, and decorative movement are intentionally absent; every visible mark identifies state, reports a value, or offers an action.

**Key Characteristics:**

- A 28 px opaque rail on every monitor
- Task-oriented workspaces anchored left
- Flexible quiet space through the center
- Dense telemetry, controls, tray, clock, and power anchored right
- Restrained Flexoki dark neutrals with rare orange, red, and yellow signals
- Compact mono labels, hairline meters, and accessible state beyond color

## Colors

The palette is a warm-black Flexoki field with stone text and a deliberately small vocabulary of operational accents.

### Primary

- **Focused Orange** (`focus-bright`, #DA702C): fills the focused workspace beneath its dark state line, marks keyboard focus, drives the CPU meter, and confirms ordinary presses.
- **Memory Orange** (`telemetry-orange`, #BC5215): gives the RAM meter a lower-intensity orange distinct from focus.

### Secondary

- **Urgent Red** (`danger-bright`, #D14D41): outlines urgent workspaces and destructive hover states, and supplies the persistent marker for attention-seeking tray items.

### Tertiary

- **Telemetry Yellow** (`warning-bright`, #D0A215): distinguishes disk utilization from the orange CPU and memory meters.

### Neutral

- **Rail Black** (`rail-black`, #100F0F): the opaque edge-to-edge bar and the text color on bright focused states.
- **Raised Black** (`raised-black`, #1C1B1A): hover, active, urgent, and tooltip surfaces one tonal step above the rail.
- **Hover Black** (`hover-black`, #282726): the strongest neutral pressed or hover response.
- **Warm Foreground** (`warm-foreground`, #CECDC3): live values, clock text, icons, and primary operational labels.
- **Muted Foreground** (`muted-foreground`, #878580): metric names, inactive workspaces, and fallback tray marks.

**The Signal Rarity Rule.** Orange identifies focus and live measurement, red identifies urgency or danger, and yellow identifies disk pressure; accents never become general decoration.

## Typography

**Label/Mono Font:** JetBrainsMono Nerd Font

**Tooltip Font:** Bricolage Grotesque

**Character:** The rail uses a compact monospaced voice for numbers, task glyphs, control icons, and time so changing values retain a stable rhythm. Tooltips shift to the softer UI face for readable explanatory copy outside the instrument line.

### Hierarchy

- **Label** (12 px): the sole rail-level hierarchy for workspace identifiers, telemetry names and values, controls, audio, and clock.
- **Tooltip** (11 px): delayed explanatory text for hover and keyboard focus.
- **Fallback Icon** (15 px): used only when a tray item cannot provide its own image.

**The Monospace Telemetry Rule.** Any value or label that participates in the rail's scanning rhythm uses the mono label role; prose exists only inside tooltips.

## Layout

Each connected screen receives its own full-width 28 px top rail and reserves the same amount of compositor space. A 4 px outer gutter contains a single 24 px control row with 2 px gaps. Workspaces and the music scratchpad remain left-aligned, an elastic empty region absorbs all surplus width, and CPU, RAM, disk, audio, tools, tray, clock, and power terminate against the right edge in that order.

Controls grow only enough to hold their content while preserving a 26 px minimum action target. There are no responsive breakpoints: per-monitor replication and the elastic center provide the adaptation model. Metric width follows its label and value, with a 2 px progress line pinned to the bottom edge.

## Elevation & Depth

The system is flat and opaque. It uses no shadows, blur, transparency, gradients, or lifted animation; depth comes only from stepping between the three warm-black tones and drawing a one-pixel border when focus or urgency needs an explicit edge.

**The Flat at Rest Rule.** Every component is flush with the rail until hover, press, focus, attention, or explanatory context warrants a tonal step or border.

## Shapes

The form language is nearly square: the rail itself has no radius, interactive controls use a restrained 3 px corner, and detached tooltips use a slightly softer 4 px corner. One-pixel borders and two-pixel meter lines preserve the instrument-like geometry; silhouettes never become pills.

**The Almost-Square Rule.** Keep rail controls at a 3 px radius and reserve the 4 px radius for detached tooltip surfaces.

## Components

### Workspace Button

Compact task markers show the task icon when one exists and fall back to the workspace number otherwise. Every visible workspace gains a two-pixel underline; the focused workspace becomes bright orange with dark text and a Rail Black underline, while other visible workspaces use orange or muted underlines according to monitor location. Occupied workspaces retain a persistent corner marker. Urgency uses a red border plus a leading `!`, ensuring the state is not color-only. Hover, pointer press, keyboard focus, and activation are all explicit.

### Music Scratchpad

The music scratchpad replaces workspace 10 immediately after the numbered workspace strip. Its music glyph is always present so the overlay remains discoverable; an occupied corner marker shows that a music window is waiting, and an orange underline shows that the scratchpad is open. When an MPRIS player exposes metadata, the control expands up to 360 px to show `artist — title` with middle elision. Primary activation toggles the scratchpad, secondary activation toggles playback, and the tooltip states both actions explicitly.

### Metric Widget

CPU, RAM, and disk each pair a muted uppercase name with a warm live value. A two-pixel bottom meter carries the metric accent and clamps to the component width. Memory and disk shift to urgent red at 90 percent. CPU and RAM tooltips disclose the five heaviest aggregated processes so detail remains available on demand rather than occupying the rail.

### Tool Button

Utility and power actions share a transparent 24 px-high, 26 px-minimum control with 6 px horizontal inset. Neutral tools rise to Hover Black; keyboard focus draws an orange border, and an ordinary press becomes bright orange with dark text. The power action instead uses a red edge over Raised Black on hover and Hover Black while pressed. Hover or focus reveals a delayed tooltip, while Enter, Space, arrows, pointer buttons, and wheel input retain complete operability.

### Tray Item

Tray entries occupy a consistent 26 × 24 px slot and preserve the application's own 16 px icon. Attention adds a persistent 6 × 2 px red marker at the bottom-right, a red border at rest, and a red fallback mark when no icon resolves; keyboard focus may therefore replace the border with orange without hiding the attention state. The accessible name and description both state “needs attention.” Primary, secondary, menu, scroll, and keyboard interactions remain available without adding unrelated chrome.

### Audio Control

Audio extends the Tool Button with a volume-dependent glyph and percentage. Primary activation moves current playback between the configured headset and speakers, secondary activation opens the mixer, and the wheel adjusts volume by five percent. The separate output-device button is intentionally absent because the audio readout owns that action.

### Contextual Tools

The language control labels the layout that a click will produce—`PT` while English is active and `EN` while Portuguese is active. Display control similarly shows a compress icon while two outputs are active and an expand icon while one is active. These controls describe the next action rather than duplicating current state.

### Clock Widget

The clock is a single mono line—time, abbreviated weekday, day, and month—with 5 px horizontal inset. Its tooltip expands to the full weekday, date, year, and time without introducing a second visible hierarchy.

### Bar Tooltip

Tooltips appear after a 450 ms delay, four pixels below their anchor. They use Raised Black, a one-pixel Hover Black border, the 4 px tooltip radius, and compact Bricolage Grotesque text. They disappear immediately when hover or keyboard focus leaves.

**The State Beyond Color Rule.** Pair focused orange with a dark underline, pair urgent workspaces with an exclamation mark or explicit edge, underline every visible workspace, and pair tray attention with a persistent marker plus explicit accessible text.

## Do's and Don'ts

### Do:

- Do preserve the 28 px rail, 24 px control row, 2 px gaps, and left-orient/right-operate information order.
- Do use Warm Foreground for live data and Muted Foreground for supporting labels and inactive state.
- Do keep orange focused states paired with dark text and a dark two-pixel underline, and urgent states paired with a border or ! marker.
- Do keep each clickable control keyboard-focusable and give it a specific tooltip or clear text label.
- Do let the flexible center remain visually empty so operational groups stay distinct.

### Don't:

- Don't add shadows, blur, transparency, gradients, ornamental animation, or floating-card treatment to the rail.
- Don't turn compact controls into pills or increase their corner radius beyond the established near-square language.
- Don't use accent colors as decoration or rely on color alone to communicate focus, visibility, urgency, or danger.
- Don't insert prose, headings, or stacked content into the 28 px instrument line.
- Don't reorder workspaces, telemetry, controls, tray, clock, and power without a corresponding workflow reason.
