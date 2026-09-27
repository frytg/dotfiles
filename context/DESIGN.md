# DESIGN.md

How my interfaces should look. Use this when building UI for me — site, dashboard, tools, and native iOS.

The palette and the feel are shared. Geometry is not. Web and dashboards stay flush on the green canvas. iOS follows Apple’s Human Interface Guidelines: system chrome, grouped lists, continuous corners, 44pt targets. Do not flatten an iPhone screen into a site.

Canonical implementations: [frytg.digital](https://github.com/frytg/frytg), [dashy](https://github.com/frytg/dashy). Editor and terminal themes in this repo share the same palette (Zed / Ghostty / Moshi “Dark Greeny”).

## How it should feel

Modern and current — sharp, calm, high-contrast dark UI that reads state-of-the-art without looking trendy or over-designed.
Utilitarian editorial: a builder’s notebook, not a marketing landing page. Confidence comes from clarity and restraint, not glow, gradients, or chrome.

Dense tools stay scannable; long-form stays readable. Nothing cute, nothing skeuomorphic, nothing “AI brochure.” Gradients should mostly be avoided — flat color keeps the system simple.

## Vercel-like craft

Borrow composition discipline from [Vercel’s design.md](https://vercel.com/design.md): precise, calm, direct, evidence-led interfaces where the first viewport carries the argument and hierarchy beats decoration.

Apply that craft on _my_ palette. Web stays flush. iOS uses Apple’s geometry — not Vercel’s light/dark product chrome, and not a clone of their report templates.

## The look

Dark forest-green canvas. Off-off-white type. One electric yellow for every interactive moment. Greeny text sits on yellow fills. Everything else stays quiet.

Web: flat and flush — no shadows, no pills, no decorative cards. Yellow means hover, active, selection, and focus.

iOS: the same colours on system chrome. No hover. Yellow means tint, selected, pressed, and the live control. See [iOS](#ios).

## Colors (use these names)

| Name              | Hex       | Role                                             |
| ----------------- | --------- | ------------------------------------------------ |
| `dark-greeny`     | `#181D16` | Deepest surface — page bg, code chips, editor bg |
| `mid-dark-greeny` | `#293126` | Ambient page / theme color                       |
| `greeny`          | `#3E4939` | Borders, text on yellow, selection text          |
| `yellow`          | `#FFFF11` | The interaction accent — only one                |
| `orange`          | `#F09139` | Secondary press/focus; don’t compete with yellow |
| `off-off-white`   | `#DDD9C0` | Warm body text for long reading                  |
| `off-white`       | `#ECEBE3` | Slightly brighter warm text / UI foreground      |
| `fake-gray`       | `#D7E2CC` | Muted/sage text via opacity                      |
| `white`           | `#FFFFFF` | Hard contrast only                               |

`white` (pure `#FFFFFF`) should be used sparsely — prefer `off-white` or `off-off-white` for type and surfaces.
Pure white is for rare hard contrast, not the default foreground.

Semantic extras (`red`, `purple`, `green`, `blue`, …) exist for status — not brand accents.

Prefer opacity mixes (`border-greeny/20`, `bg-white/5`, `hover:bg-yellow`) over new hex values.
In Tailwind themes, warmer text tokens may still be named `white` / `gray` in code — keep the human names (`off-white`, `off-off-white`, `fake-gray`) in docs and conversation.

## Shapes

Web and dashboards: corner radius is `0`. Rectangles only. `rounded-full` is reserved for avatars, status dots, and count badges. No rounded buttons or card pills.

iOS: do not apply that rule. Use the system continuous radii in [iOS](#ios).

## Type

Sans for UI, mono for handles / paths / counts / timestamps. Site: Inter Variable. Dashboard: Geist Sans + Geist Mono. iOS: SF Pro.
Prefer weight and size for hierarchy — lowercase headings are fine where the existing apps already do that.

Long-form: comfortable body, tight tracking on big titles, generous reading measure.
Dense tools: override down to smaller sizes locally — don’t import blog margins into a control panel.

## Interaction

- Rest: transparent / quiet
- Hover or active: yellow fill, `greeny` text — or yellow text alone on plain links
- Selection: yellow background, greeny text
- Nav: text-first; colour carries state. Site uses filled yellow nav buttons; dashy uses muted → white → yellow text with a sticky blurred bar. iOS uses system nav and tabs with a yellow tint. Same family, different density.

## Depth (without elevation)

No box shadows. Hierarchy comes from tint, opacity, and the yellow inversion — not stacked cards.
Hairline borders (`greeny` / `fake-gray` mixes) are fine for lists and tool chrome; don’t box every block.

## Do / don’t

Do: keep the green canvas; spend yellow only on interaction; stay flush on the web; name colors `greeny` / `dark-greeny` / `yellow` / `off-white` / `off-off-white` / `fake-gray` in conversation and docs; use pure `white` sparingly.

Don’t: purple-on-white themes, cream+serif brochure looks, pure-white page backgrounds, pill CTAs, drop shadows, decorative gradients, extra accent colors fighting yellow, or generic SaaS card grids when a flat list would do.

On iOS, also don’t: radius-0 settings rows, custom tab bars, or `systemBackground` black leaking next to the canvas.

## iOS

Same names, same yellow-for-interaction rule, same refusal of glow and brochure chrome. Different structure. An iOS app should feel like a current Apple app that happens to live on the green canvas — not a port of frytg.digital.

Follow [Apple’s Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/). When this file and HIG disagree on controls, layout, or chrome, HIG wins. This file still owns colour and tone.

### Platform

- SwiftUI. Default chrome is `NavigationStack` plus the system tab bar (`TabView` / `Tab`) on iPhone and iPad. Same binary; compact vs regular is padding and type, not a different shell.
- A sidebar (`NavigationSplitView`) is only for complex, multi-section apps with a persistent source list. Two or three top-level screens stay on tabs. Do not add a sidebar because the device is an iPad.
- Settings-style screens: inset grouped `List`, large title, section headers and footers. Destructive actions use a confirmation dialog and system red.
- Binary preferences are toggles, not a two-segment picker. Use a picker when there are three or more choices.
- SF Symbols for tab and nav icons. Short tab labels.
- Hit targets at least 44pt. Primary controls stay put — reserve space for secondary chrome so it fades in instead of shifting the layout. Docks use `safeAreaInset`.
- VoiceOver labels on controls; don’t hide a disabled primary button. Honour Reduce Motion: no bounce-for-delight.

### Surfaces

`preferredColorScheme(.dark)` and `UIUserInterfaceStyle: Dark`. Never let system dark black (`systemBackground`) show through.

- `dark-greeny` — window, nav, tab bar, grouped-list page
- `mid-dark-greeny` — inset-grouped rows (the iOS secondary-grouped lift)
- `yellow` — tint, selected, pressed, prominent fill. There is no hover on iPhone.
- `greeny` — text on yellow, hairlines
- `orange` — warning / thermal / permission, not a second brand
- `off-white` / `off-off-white` — labels and reading; `fake-gray` at opacity for secondary

Paint the screen (`containerBackground`, list `scrollContentBackground(.hidden)`, row fills). Do not set `UIView.appearance().backgroundColor` or a global `UITableViewCell` background — those square off grouped cells and leak into alerts.

### Shapes (iOS)

Use system continuous corners. Typical radii: **10** grouped list (and sidebar highlight if you have one), **12** buttons and standalone rows, **24** a large primary control. Capsules only for avatars, status dots, and count badges — not for settings rows or CTAs.

- Inset-grouped sections are one card: first row rounds the top, last row the bottom, middle rows are square.
- `listRowBackground` with a plain colour lets the list clip. If you draw the card yourself, use `UnevenRoundedRectangle` from the row index — first / middle / last / only.
- Do not use `ContainerRelativeShape` as a section-wide row background. It stamps the section card onto every row (a stray bottom-right corner on a middle row).
- If a sidebar exists: selection is a 10pt continuous rounded rect, inset (~8pt horizontal), yellow fill + `greeny` text. Unselected rows are clear, not a full-bleed rectangle.
- Nav and tab bars stay system chrome on the canvas: opaque, no shadow, yellow tint, muted unselected tab items. Don’t replace them with a flush custom bar.

### Type

SF Pro (system sans). Mono for counts, paths, timestamps, hardware shortcuts. No Inter, Geist, or serif display — those are site/dashboard. Weight and size for hierarchy; lowercase titles are fine where the product already uses them.

### Controls

- Rest: quiet, transparent or grouped-row fill.
- Pressed: yellow text, or yellow fill + `greeny` text.
- Selected: yellow + `greeny`, or a yellow checkmark on a grouped row.
- Disabled: opacity, still in the tree for VoiceOver.
- Text fields: `.plain` on the canvas; caret is yellow. Don’t ship the default dark rounded field.
- Segmented controls (3+ options): yellow selected segment, `greeny` selected title.
- Prominent onboarding actions: 50pt-min filled button, 12pt continuous, yellow + `greeny`. Back stays a text button.

### Do / don’t (iOS)

Do: native lists and tabs; reserved layout so the primary control never jumps; name the same colours; keep yellow for interaction only.

Don’t: restyle Settings into a web tool; square primary controls against rounded lists; glow or drop shadows on the main action; serif “editorial” titles; extra accents; cards-on-cards.
