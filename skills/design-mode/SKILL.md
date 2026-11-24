---
name: design-mode
description: >-
  Design or restyle UI with an agent without the default AI look: replace vague style words with decisions, enforce a
  ban list, use semantic tokens instead of hex codes, start from a reference instead of a blank page, cap motion with
  real numbers, screenshot the result, and finish with a cutting pass. Use when the user asks to "design a page",
  "build a component", "make this look better", "restyle this", "unslop the UI", "this looks AI-generated", "design
  mode", or starts any frontend or visual UI work.
license: MIT
metadata:
  author: frytg
  agent: claude-code
  category: engineering
---

# Design mode

Style adjectives give an agent nothing to act on. It resolves "modern" or "polished" to the most common pattern it
knows, and the result looks like every other generated page. The output of this mode is a quiet screen where every
visual choice traces back to a written rule: a ban, a token, a number, or a reference.

## Workflow

1. **Load the rules.** Before touching UI, look for a design file in the repo: `DESIGN.md`, `DESIGN_RULES.md`, or a
   design section in `AGENTS.md`. If none exists, use the defaults below and offer to create `DESIGN.md`. Every rule is
   a ban or a number, never an adjective.
2. **Start from a reference.** Use an existing component, the project's best screen, or a screenshot the user names.
   If there is none, ask for one before building from zero.
3. **Use tokens only.** No raw hex values. Use `background`, `surface`, `foreground`, `text-secondary`, `border`,
   `accent`. Surfaces stay neutral. The accent appears only on active or selected state. One type scale, three weights.
4. **Build, then look.** Screenshot light, dark, and phone width (headless Playwright or `agent-browser`). Check each
   against the rules. Fix clipped text, broken dark mode, and banned patterns before saying done.
5. **Cut.** Remove the subtitle that repeats the heading, the unasked badge, the second shadow, the icon next to every
   label. Keep one good interaction, not five effects.

## Default bans

- Title case or all caps. Use sentence case. No eyebrow labels above headings.
- Weights other than regular, medium, and bold.
- Icons in rounded or glowing boxes. Letter-in-a-square fake logos.
- Gradients, glow, nested cards. Shadows only on elements that float.
- Colored left bar on selected rows. Green check-in-circle on every status. `01 02 03` numbered lists.
- Avatar stacks that fan out on hover.
- Sparkle emoji in headlines.

Add a ban every time a pattern annoys the user once, with the reason next to it.

## Motion numbers

- Interface motion under 300ms. Exits faster than entries.
- No bounce. No staggered entrance animations.
- Pressed buttons scale to `0.97`.
- Keyboard highlight moves instantly. Only the mouse gets a glide.

## Done when

- [ ] No raw hex, no off-scale font size or weight.
- [ ] No banned pattern in the screenshots.
- [ ] Light, dark, and phone width checked.
- [ ] Cutting pass done; say what was removed.
