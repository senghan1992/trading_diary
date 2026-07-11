# Design System Inspired by Slate Charcoal

## 1. Visual Theme & Atmosphere

The app uses Slate Charcoal as its commanding brand color. The design operates on white/cool backgrounds with Slate Charcoal (`#1E293B`, `#E2E8F0`, `#0F172A`) creating a distinctive, professional identity. The proprietary headings with bold (700) weight and negative tracking, while IBM Plex Sans serves as the UI workhorse.

**Key Characteristics:**
- Slate Charcoal (`#1E293B`) as primary brand with variants (`#E2E8F0`, `#0F172A`)
- Kraken-Brand (display) + Kraken-Product (UI) dual font system
- Near-black (`#101114`) text with cool blue-gray neutral scale
- 12px radius buttons (rounded but not pill)
- Subtle shadows (`rgba(0,0,0,0.03) 0px 4px 24px`) — whisper-level
- Green accent (`#149e61`) for positive/success states

## 2. Color Palette & Roles

### Primary
- **Slate Charcoal** (`#1E293B`): Primary CTA, brand accent, links
- **Charcoal Dark** (`#0F172A`): Button borders, outlined variants
- **Charcoal Light** (`#E2E8F0`): Light variant / dark mode primary
- **Charcoal Subtle** (`rgba(30,41,59,0.06)`): Charcoal at 6% — subtle button backgrounds
- **Near Black** (`#101114`): Primary text

### Neutral
- **Cool Gray** (`#686b82`): Primary neutral, borders at 24% opacity
- **Silver Blue** (`#9497a9`): Secondary text, muted elements
- **White** (`#ffffff`): Primary surface
- **Border Gray** (`#dedee5`): Divider borders

### Semantic
- **Green** (`#149e61`): Success/positive at 16% opacity for badges
- **Green Dark** (`#026b3f`): Badge text

## 3. Typography Rules

### Font Families
- **Display**: `Kraken-Brand`, fallbacks: `IBM Plex Sans, Helvetica, Arial`
- **UI / Body**: `Kraken-Product`, fallbacks: `Helvetica Neue, Helvetica, Arial`

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing |
|------|------|------|--------|-------------|----------------|
| Display Hero | Kraken-Brand | 48px | 700 | 1.17 | -1px |
| Section Heading | Kraken-Brand | 36px | 700 | 1.22 | -0.5px |
| Sub-heading | Kraken-Brand | 28px | 700 | 1.29 | -0.5px |
| Feature Title | Kraken-Product | 22px | 600 | 1.20 | normal |
| Body | Kraken-Product | 16px | 400 | 1.38 | normal |
| Body Medium | Kraken-Product | 16px | 500 | 1.38 | normal |
| Button | Kraken-Product | 16px | 500–600 | 1.38 | normal |
| Caption | Kraken-Product | 14px | 400–700 | 1.43–1.71 | normal |
| Small | Kraken-Product | 12px | 400–500 | 1.33 | normal |
| Micro | Kraken-Product | 7px | 500 | 1.00 | uppercase |

## 4. Component Stylings

### Buttons

**Primary Charcoal**
- Background: `#1E293B`
- Text: `#ffffff`
- Padding: 13px 16px
- Radius: 12px

**Charcoal Outlined**
- Background: `#ffffff`
- Text: `#1E293B`
- Border: `1px solid #1E293B`
- Radius: 12px

**Charcoal Subtle**
- Background: `rgba(30,41,59,0.06)`
- Text: `#1E293B`
- Padding: 8px
- Radius: 12px

**White Button**
- Background: `#ffffff`
- Text: `#101114`
- Radius: 10px
- Shadow: `rgba(0,0,0,0.03) 0px 4px 24px`

**Secondary Gray**
- Background: `rgba(148,151,169,0.08)`
- Text: `#101114`
- Radius: 12px

### Badges
- Success: `rgba(20,158,97,0.16)` bg, `#026b3f` text, 6px radius
- Neutral: `rgba(104,107,130,0.12)` bg, `#484b5e` text, 8px radius

## 5. Layout Principles

### Spacing: 1px, 2px, 3px, 4px, 5px, 6px, 8px, 10px, 12px, 13px, 15px, 16px, 20px, 24px, 25px
### Border Radius: 3px, 6px, 8px, 10px, 12px, 16px, 9999px, 50%

## 6. Depth & Elevation
- Subtle: `rgba(0,0,0,0.03) 0px 4px 24px`
- Micro: `rgba(16,24,40,0.04) 0px 1px 4px`

## 7. Do's and Don'ts

### Do
- Use Slate Charcoal (#1E293B) for CTAs and links
- Apply 12px radius on all buttons
- Use display font for headings, UI font for body

### Don't
- Don't use pill buttons — 12px is the max radius for buttons
- Don't use other colors outside the defined scale

## 8. Responsive Behavior
Breakpoints: 375px, 425px, 640px, 768px, 1024px, 1280px, 1536px

## 9. Agent Prompt Guide

### Quick Color Reference
- Brand: Slate Charcoal (`#1E293B`)
- Dark variant: `#0F172A`
- Text: Near Black (`#101114`)
- Secondary text: `#9497a9`
- Background: White (`#ffffff`)

### Example Component Prompts
- "Create hero: white background. Display Font 48px weight 700, letter-spacing -1px. Charcoal CTA (#1E293B, 12px radius, 13px 16px padding)."
