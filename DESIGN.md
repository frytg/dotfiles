# DESIGN.md

How my interfaces should look. Use this when building UI for me — site, dashboard, tools, anything on the green canvas.

Canonical implementations: [frytg.digital](https://github.com/frytg/frytg), [dashy](https://github.com/frytg/dashy). Editor and terminal themes in this repo share the same palette (Zed / Ghostty / Moshi “Dark Greeny”).

## How it should feel

Modern and current — sharp, calm, high-contrast dark UI that reads state-of-the-art without looking trendy or over-designed.
Utilitarian editorial: a builder’s notebook, not a marketing landing page. Confidence comes from clarity and restraint, not glow, gradients, or chrome.

Dense tools stay scannable; long-form stays readable. Nothing cute, nothing skeuomorphic, nothing “AI brochure.” Gradients should mostly be avoided — flat color keeps the system simple.

## Vercel-like craft

Borrow composition discipline from [Vercel’s design.md](https://vercel.com/design.md): precise, calm, direct, evidence-led interfaces where the first viewport carries the argument and hierarchy beats decoration.

Apply that craft on _my_ palette and flush geometry — not Vercel’s light/dark product chrome, and not a clone of their report templates.

## The look

Dark forest-green canvas. Off-off-white type. One electric yellow for every interactive moment. Flat and flush — no shadows, no pills, no decorative cards.
Yellow means hover, active, selection, and focus. Greeny text sits on yellow fills. Everything else stays quiet.

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

Corner radius is `0`. Rectangles only. `rounded-full` is reserved for avatars, status dots, and count badges.
No rounded buttons or card pills.

## Type

Sans for UI, mono for handles / paths / counts / timestamps. Site: Inter Variable. Dashboard: Geist Sans + Geist Mono.
Prefer weight and size for hierarchy — lowercase headings are fine where the existing apps already do that.

Long-form: comfortable body, tight tracking on big titles, generous reading measure.
Dense tools: override down to smaller sizes locally — don’t import blog margins into a control panel.

## Interaction

- Rest: transparent / quiet
- Hover or active: yellow fill, `greeny` text — or yellow text alone on plain links
- Selection: yellow background, greeny text
- Nav: text-first; colour carries state. Site uses filled yellow nav buttons; dashy uses muted → white → yellow text with a sticky blurred bar. Same family, different density.

## Depth (without elevation)

No box shadows. Hierarchy comes from tint, opacity, and the yellow inversion — not stacked cards.
Hairline borders (`greeny` / `fake-gray` mixes) are fine for lists and tool chrome; don’t box every block.

## Do / don’t

Do: keep the green canvas; spend yellow only on interaction; stay flush; name colors `greeny` / `dark-greeny` / `yellow` / `off-white` / `off-off-white` / `fake-gray` in conversation and docs; use pure `white` sparingly.

Don’t: purple-on-white themes, cream+serif brochure looks, pure-white page backgrounds, pill CTAs, drop shadows, decorative gradients, extra accent colors fighting yellow, or generic SaaS card grids when a flat list would do.
