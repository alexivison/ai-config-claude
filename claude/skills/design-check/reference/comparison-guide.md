# Design Check Comparison Guide

Detailed criteria for comparing Figma designs against implemented components.

## Figma-to-CSS Mapping

### Layout

| Figma Property | CSS Equivalent |
|---------------|----------------|
| `layoutMode: HORIZONTAL` | `flex-direction: row` |
| `layoutMode: VERTICAL` | `flex-direction: column` |
| `primaryAxisAlignItems` | `justify-content` |
| `counterAxisAlignItems` | `align-items` |
| `layoutWrap: WRAP` | `flex-wrap: wrap` |
| `itemSpacing` | `gap` |
| `paddingTop/Right/Bottom/Left` | `padding` (prefer logical properties) |

### Sizing

| Figma Sizing | CSS Equivalent |
|-------------|----------------|
| `fixed` | Explicit `width`/`height` value |
| `fill` | `flex: 1` or `width: 100%` |
| `hug` | No explicit size (content-driven) |

### Fills

Figma fills map to CSS `background-color`, `color`, or `background`. Extract the hex/RGBA value and match against design system tokens in the codebase.

### Effects

| Figma Effect | CSS Property |
|-------------|-------------|
| Drop shadow | `box-shadow` |
| Inner shadow | `box-shadow` (inset) |
| Layer blur | `filter: blur()` |
| Background blur | `backdrop-filter: blur()` |

## Comparison Dimensions

### 1. Layout Structure

Compare Figma auto-layout against the rendered CSS layout:
- Flex direction (row vs column)
- Alignment (main axis and cross axis)
- Wrap behavior
- Nesting depth (Figma layers vs React component tree)
- **Child order within flex rows** — Figma's child array order defines visual order (first child = start, last child = end). Compare against the DOM order in the a11y snapshot. A chevron on the right in Figma but rendered on the left is a `[must]` finding.

Flag `[must]` if the flex direction is wrong, alignment causes visible misplacement, or child order is reversed.

### 2. Spacing

Map Figma `itemSpacing` and `padding` values to design system spacing tokens.

**Token resolution strategy** — Do not hardcode token values. Instead:
1. Extract the pixel value from Figma data
2. In Chrome DevTools, call `mcp__chrome-devtools__evaluate_script` with `getComputedStyle` on the element to read actual computed values
3. Compare the Figma value against the computed value
4. If they differ, check whether a different spacing token would be closer

Flag `[must]` if spacing is off by more than 4px. Flag `[nit]` for 1-2px differences.

### 3. Colors

Compare Figma fill colors against CSS color/background tokens:
1. Extract hex from Figma fill data
2. Read the `.module.css` file for the corresponding property
3. Token existence is verified by the Token Audit step (Step 5 in SKILL.md) — do not duplicate that check here
4. If a raw hex is used instead of a token, flag as `[must]`
5. If a token is used but maps to a different hex, flag as `[must]`
6. Account for opacity — Figma may separate opacity from fill color

### 4. Typography

Compare Figma text styles against the implementation:
- Font family
- Font size (px)
- Font weight (numeric or named)
- Line height (px or ratio)
- Letter spacing

Check whether a design system typography component is used. If raw CSS is used for text styling, verify token usage.

Flag `[must]` for wrong font weight or size. Flag `[nit]` for minor line-height differences.

### 5. Border Radius

Map Figma `cornerRadius` to design system radius tokens. Check for asymmetric radius (per-corner values in Figma). Flag `[must]` if the radius is visually different (e.g., square vs rounded).

### 6. Component Hierarchy

Compare Figma layer nesting against the React component tree:
- Missing structural elements present in Figma (especially icons — Figma `IMAGE-SVG` or `Icon-Aegis` nodes indicate icons that must exist in the implementation)
- Extra wrapper elements absent from Figma
- Incorrect component choice (e.g., `div` where Figma shows a card-like container)
- Leading vs trailing placement of icons and interactive elements

Flag `[must]` for missing or extra visible elements, or icons placed on the wrong side. Ignore purely structural wrappers that have no visual impact.

## Severity Classification

| Severity | Criteria | Examples |
|----------|----------|---------|
| `[must]` | Visually different from design | Wrong flex direction, missing element, wrong background color, wrong font weight |
| `[q]` | Ambiguous or could be intentional | Value maps to two possible tokens, truncation behavior unclear, responsive intent unknown |
| `[nit]` | Cosmetically negligible | 1-2px rounding, token alias preference, property order |

**Verdict rules:**
- **APPROVE** — No `[must]` findings
- **REQUEST_CHANGES** — One or more `[must]` findings with file:line references
- **NEEDS_DISCUSSION** — Design intent unclear, Figma incomplete, or multiple valid interpretations

## Known Exceptions

Do not flag these as discrepancies:

- **Design system internal spacing** — Design system components may have built-in padding/margins not visible in Figma
- **Storybook decorators** — The Provider wrapper and Storybook chrome add extra DOM layers; ignore in hierarchy comparison
- **MSW mock data** — Mock Service Worker may produce different text content than Figma placeholder text; compare structure, not data values
- **Viewport differences** — Compare at the viewport matching the Figma frame dimensions; check the frame's width/height before flagging responsive issues
- **Anti-aliasing** — Slight rendering differences between Figma's renderer and the browser are expected; do not flag unless clearly wrong
- **Component size props** — Design system components often control padding AND border-radius from a single `size` prop. When both diverge from Figma, flag as one root issue (the size prop), not separate findings
