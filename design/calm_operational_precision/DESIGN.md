---
name: Calm Operational Precision
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#3d4947'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#6d7a77'
  outline-variant: '#bcc9c6'
  surface-tint: '#006a61'
  primary: '#00685f'
  on-primary: '#ffffff'
  primary-container: '#008378'
  on-primary-container: '#f4fffc'
  inverse-primary: '#6bd8cb'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#006194'
  on-tertiary: '#ffffff'
  tertiary-container: '#007bb9'
  on-tertiary-container: '#fdfcff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#89f5e7'
  primary-fixed-dim: '#6bd8cb'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#005049'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#cce5ff'
  tertiary-fixed-dim: '#93ccff'
  on-tertiary-fixed: '#001d31'
  on-tertiary-fixed-variant: '#004b73'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.015em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.03em
  tabular-clock:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.25rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system serves frontline small business managers, owners, and shift workers across tight-knit teams of 2 to 15 people. The brand identity balances crisp, operational utility with a human, reassuring tone. It removes administrative dread, replacing complex enterprise bureaucracy with transparent, quiet reliability.

The design movement combines **Modern Corporate Precision** with **Warm Functional Minimalism**:
- **Utilitarian Clarity**: High visual legibility, immediate spatial orientation, and zero noise. Time logs, clock-in triggers, shift swaps, and payroll tallies are front-and-center without visual clutter.
- **Tactile Softness**: Crisp surfaces rely on soft slate containers, gentle outline structures, and approachable corner radii to avoid the cold detachment typical of enterprise human resource suites.
- **Trust & Autonomy**: The UI emphasizes respectful employee privacy and managerial confidence through clear status indications, non-surveillant language, and transparent state changes.

## Colors

The palette grounds the interface in deep, stabilizing dark neutrals while deploying an energetic, reassuring teal for active tasks, positive states, and primary actions.

- **Primary (`#0D9488` - Teal)**: Represents affirmation, active shifts, successful actions, and key calls-to-action. It conveys freshness without sounding the alarms of generic electric blue.
- **Secondary (`#0F172A` - Deep Slate Navy)**: Acts as the root color for high-emphasis typography, critical structural headers, navigation headers, and grounding layout surfaces.
- **Tertiary (`#0284C7` - Oceanic Sky)**: Reserved for informational notices, shift swap requests, scheduling markers, and secondary analytical points.
- **Neutral (`#64748B` - Slate)**: Drives medium-contrast borders, inactive labels, and secondary body details.
- **Base Canvas & Surfaces**: Backgrounds rely on cool slate tones:
  - App Canvas: `#F8FAFC`
  - Secondary Containers / Sidebar: `#F1F5F9`
  - High-Contrast Borders: `#E2E8F0`
  - Card & Modal Surfaces: `#FFFFFF`
- **Functional Semantics**:
  - Success / On Time: `#059669`
  - Attention / Running Late: `#D97706`
  - Critical / Absent: `#E11D48`

## Typography

The type hierarchy uses **Plus Jakarta Sans** across all roles to combine geometric precision with human warmth. Its tall x-height and open apertures ensure legible numbers and rosters across small handheld devices, tablet point-of-sale mounts, and desktop admin hubs.

- **Tabular Figures**: Every numeric representation—timesheets, hourly rates, live timers, and staff counts—must use `font-variant-numeric: tabular-nums` to maintain vertical alignment and prevent layout jitter.
- **Visual Weighting**: Reserve bold (`700`) weights for primary numerical readouts and high-level page headlines. Use semi-bold (`600`) for interactive labels, table headers, and badges to ensure scanability at a glance. Regular (`400`) handles instructions, roster notes, and contextual micro-copy.

## Layout & Spacing

The design system relies on a fluid grid anchored to an 8px base rhythm (with 4px substeps for micro-alignments).

- **Mobile Viewports (< 640px)**:
  - Single-column flow with a strict `1rem` margin to optimize screen real estate.
  - Interactive targets conform to a minimum touch target of 44px height.
  - Quick-action buttons (Clock In/Out, Switch Location) anchor to sticky bottom surfaces.
- **Tablet & POS Stations (640px - 1024px)**:
  - 8-column fluid grid with `1.25rem` gutters and `1.5rem` outer canvas padding.
  - Split layout for dual workflows: Roster overview on the left (5 columns), live shift detail on the right (3 columns).
- **Desktop Management (≥ 1024px)**:
  - 12-column layout capped at a maximum width of `1280px` to prevent table rows from over-stretching.
  - Fixed 260px collapsible sidebar for company context, department filtering, and payroll exports.
  - Main administrative content uses `1.5rem` gutters and `2rem` outer margins.

## Elevation & Depth

This system avoids heavy drop shadows and high-contrast drop borders, using **Low-Contrast Outlines** layered with **Tonal Containers** and **Ambient Slate Shadows**.

- **Level 0 (Flat Canvas)**: `#F8FAFC`. Base canvas background. No borders, no shadows.
- **Level 1 (Card & List Tier)**: `#FFFFFF` surface resting on `#F8FAFC`. Enclosed by a 1px border (`#E2E8F0`). Subtle ambient drop shadow: `0 1px 3px 0 rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.04)`.
- **Level 2 (Dropdowns & Popovers)**: `#FFFFFF` with a 1px border (`#CBD5E1`). Diffused shadow: `0 4px 6px -1px rgba(15, 23, 42, 0.07), 0 2px 4px -2px rgba(15, 23, 42, 0.05)`.
- **Level 3 (Modals, Clock-In Action Sheets)**: Elevated focus layer. `#FFFFFF` with an ambient deep shadow: `0 20px 25px -5px rgba(15, 23, 42, 0.08), 0 8px 10px -6px rgba(15, 23, 42, 0.04)`. Paired with a soft backdrop overlay (`rgba(15, 23, 42, 0.4)` with 4px backdrop blur).

## Shapes

The interface balances structure with warmth by establishing a standard corner radius of `0.5rem` (8px) for interactive elements, scaling upwards for larger structural cards:

- **Inputs, Buttons, Dropdowns**: `0.5rem` (8px) border radius. Gives clear, defined interactive boundaries.
- **Cards, Panels, Modals**: `0.75rem` (12px) to `1rem` (16px) border radius. Creates welcoming containers that soften dense tabular rosters.
- **Status Badges & Avatar Anchors**: Fully rounded pill shapes (`9999px`). Status indicators, clock-in timers, and shift tags stand out as lightweight tokens against squared structural cards.

## Components

### Buttons
- **Primary Action (Clock In, Confirm Shift)**: Background `#0D9488`, text `#FFFFFF`, font weight 600. Hover state `#0F766E`. Active state translates scale down by 0.98. Focus ring: 2px solid `#0D9488` offset by 2px.
- **Secondary Action (Manage Timesheet, Export)**: Background `#FFFFFF`, border 1px solid `#E2E8F0`, text `#0F172A`. Hover: Background `#F8FAFC`, border `#CBD5E1`.
- **Ghost/Tertiary (Cancel, Dismiss)**: Transparent background, text `#64748B`. Hover: Background `#F1F5F9`, text `#0F172A`.
- **Destructive (End Shift Early, Delete)**: Background `#FEF2F2`, border 1px solid `#FEE2E2`, text `#B91C1C`. Hover: Background `#FEE2E2`.

### Chips & Pill Badges
- **Live Active Shift**: Pill shape (`9999px`). Background `#CCFBF1`, text `#0F766E`, border 1px solid `#99F6E4`. Accompanied by a 6px pulse dot in `#0D9488`.
- **Scheduled / Pending**: Background `#F0F9FF`, text `#0369A1`, border 1px solid `#BAE6FD`.
- **Off Duty**: Background `#F1F5F9`, text `#475569`, border 1px solid `#E2E8F0`.

### Cards & Staff Rosters
- Flat `#FFFFFF` background encased in a 1px border of `#E2E8F0`.
- Padding: Strict `space-md` (16px) for mobile, `space-lg` (24px) for desktop summary cards.
- Divider lines within cards use 1px solid `#F1F5F9`.

### Input Fields & Controls
- **Text & Time Inputs**: Height 40px (desktop) or 48px (mobile). Background `#FFFFFF`, border 1px solid `#CBD5E1`, text `#0F172A`. Placeholder `#94A3B8`. Focus state shifts border to `#0D9488` with a 3px soft tint ring (`rgba(13, 148, 136, 0.15)`).
- **Checkboxes & Radios**: 18px diameter/box with 4px border radius for checkboxes and full circle for radios. Unchecked border `#CBD5E1`. Checked background `#0D9488` with crisp white check mark icon.

### Additional Product Components
- **Clock Punchpad / Live Counter**: Prominent `#0F172A` banner card displaying active shift duration in `tabular-clock` format, paired with immediate geolocation transparency text: *"Location verified via Shop Wi-Fi — GPS disabled."*
- **Shift Replacement Tray**: Bottom sliding panel on mobile or floating right-side drawer on desktop with one-tap approve/reassign micro-actions.