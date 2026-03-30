# Tom Flutter UI — Widget Demo Views

**Date:** 2026-03-24
**Status:** Specification
**Package:** tom_flutter_ui

This document specifies 20 comprehensive demo views that showcase all 292 wrapped Flutter widgets using Tom containers. Each demo is designed to be instructive, visually appealing, and help developers select appropriate components for their use cases.

---

## Table of Contents

1. [Demo Architecture](#demo-architecture)
2. [Demo Views Overview](#demo-views-overview)
3. [Demo 1: Button Showcase](#demo-1-button-showcase)
4. [Demo 2: Text Input Gallery](#demo-2-text-input-gallery)
5. [Demo 3: Selection Controls](#demo-3-selection-controls)
6. [Demo 4: Toggle & Switch Suite](#demo-4-toggle--switch-suite)
7. [Demo 5: Slider & Range Controls](#demo-5-slider--range-controls)
8. [Demo 6: Card & Panel Layouts](#demo-6-card--panel-layouts)
9. [Demo 7: Layout Containers](#demo-7-layout-containers)
10. [Demo 8: Scrollable Containers](#demo-8-scrollable-containers)
11. [Demo 9: Dialog & Modal Gallery](#demo-9-dialog--modal-gallery)
12. [Demo 10: Data Tables](#demo-10-data-tables)
13. [Demo 11: Text & Label Display](#demo-11-text--label-display)
14. [Demo 12: Image & Icon Gallery](#demo-12-image--icon-gallery)
15. [Demo 13: Navigation Patterns](#demo-13-navigation-patterns)
16. [Demo 14: Progress Indicators](#demo-14-progress-indicators)
17. [Demo 15: List Views](#demo-15-list-views)
18. [Demo 16: Tree & Hierarchy](#demo-16-tree--hierarchy)
19. [Demo 17: Sliver Compositions](#demo-17-sliver-compositions)
20. [Demo 18: Animated Transitions](#demo-18-animated-transitions)
21. [Demo 19: Effects & Filters](#demo-19-effects--filters)
22. [Demo 20: Interactions & Gestures](#demo-20-interactions--gestures)
23. [Implementation Guidelines](#implementation-guidelines)

---

## Demo Architecture

### File Structure

```
tom_flutter_ui/
├── example/
│   ├── lib/
│   │   ├── main.dart                    # Demo app entry point
│   │   ├── demo_scaffold.dart           # Common scaffold with navigation
│   │   └── demos/
│   │       ├── demo_01_buttons.dart     # ~2000 lines
│   │       ├── demo_02_inputs.dart      # ~2000 lines
│   │       ├── demo_03_selection.dart   # ~2000 lines
│   │       └── ... (20 demo files)
│   └── pubspec.yaml
```

### Common Demo Structure

Each demo file follows a consistent structure:

```dart
/// Demo file: demo_XX_<name>.dart
/// 
/// Showcases: <Widget Family>
/// Widgets covered: <List of Tom widget classes>
/// Lines: ~2000

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class DemoXXPage extends StatefulWidget {
  const DemoXXPage({super.key});
  
  @override
  State<DemoXXPage> createState() => _DemoXXPageState();
}

class _DemoXXPageState extends State<DemoXXPage> {
  // State for interactive demos
  
  @override
  Widget build(BuildContext context) {
    return TomScaffold(
      tomId: 'demoXX',
      appBar: TomAppBar(
        tomId: 'demoXXAppBar',
        title: TomText(tomId: 'demoXXTitle'), // actual title must be in resources!
      ),
      body: _buildDemoContent(),
    );
  }
  
  Widget _buildDemoContent() {
    return TomSingleChildScrollView(
      tomId: 'demoXXScroll',
      child: TomPadding(
        tomId: 'demoXXPadding',
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          tomId: 'demoXXColumn',
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection1(),
            const SizedBox(height: 32),
            _buildSection2(),
            // ...
          ],
        ),
      ),
    );
  }
}
```

### Demo Card Pattern

Individual widget showcases use a consistent card layout:

```dart
class DemoCard extends StatelessWidget {
  final String id;
  final Widget child;
  final String? code;
  
  Widget build(BuildContext context) {
    return TomCard(
      tomId: '$id_demoCard',
      child: TomColumn(
        tomId: '$id_demoCardColumn',
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon
          TomRow(
            tomId: '$id_demoCardTitleRow',
            children: [
              TomIcon(tomId: '$id_demoCardIcon', icon: Icons.widgets),
              const SizedBox(width: 12),
              TomText(tomId: '$id_demoCardTitle', style: TextStyle(...)), // actual text must be in resources, will be retrieved by TomText, place text with right key in resources
            ],
          ),
          // Description
          TomText(tomId: '$id_demoCardDesc'), // actual text must be in resources, will be retrieved by TomText, place text with right key in resources
          const Divider(),
          // Widget showcase area
          child,
          // Optional code snippet
          if (code != null) ...[
            const Divider(),
            _CodeSnippet(code: code!),
          ],
        ],
      ),
    );
  }
}
```

---

## Demo Views Overview

| # | Demo Name | Widget Family | Widgets Covered | Key Features | Done | Implemented on |
|---|-----------|--------------|-----------------|--------------|:----:|----------------|
| 1 | Button Showcase | Button | 12 | All button variants, states, sizes, icons | ✅ | 2026-03-24 |
| 2 | Text Input Gallery | Input | 7 | Text fields, search, autocomplete, Cupertino | ✅ | 2026-03-24 |
| 3 | Selection Controls | Select | 6 | Dropdowns, menus, pickers, segments | ✅ | 2026-03-24 |
| 4 | Toggle & Switch Suite | Toggle | 8 | Switches, checkboxes, radios, toggle buttons | ✅ | 2026-03-30 |
| 5 | Slider & Range Controls | Slider | 3 | Sliders, range, Cupertino, custom tracks | ✅ | 2026-03-30 |
| 6 | Card & Panel Layouts | Container | 5 | Cards, expansion tiles/panels, Material | ✅ | 2026-03-30 |
| 7 | Layout Containers | Container | 25 | Column, Row, Stack, Wrap, constraints | ✅ | 2026-03-30 |
| 8 | Scrollable Containers | Container | 10 | Scroll views, interactive viewer, draggable | ✅ | 2026-03-30 |
| 9 | Dialog & Modal Gallery | Dialog | 10 | Dialogs, sheets, snackbars, tooltips | ✅ | 2026-03-30 |
| 10 | Data Tables | Table | 5 | DataTable, paginated, Table, GridView | | |
| 11 | Text & Label Display | Label | 6 | Text styles, badges, list tiles, chips | | |
| 12 | Image & Icon Gallery | Image | 5 | Images, icons, avatars, animated icons | | |
| 13 | Navigation Patterns | Navigation | 11 | Tabs, bars, rails, drawers, steppers | | |
| 14 | Progress Indicators | Progress | 4 | Circular, linear, refresh, Cupertino | | |
| 15 | List Views | List | 5 | ListView, animated, reorderable, dismissible | | |
| 16 | Tree & Hierarchy | Tree | 2 | TreeSliver, nested expansion tiles | | |
| 17 | Sliver Compositions | Sliver | 18 | All sliver widgets, complex layouts | | |
| 18 | Animated Transitions | Animated | 19 | Implicit animations, heroes, transitions | | |
| 19 | Effects & Filters | Effect | 6 | Backdrop, color filters, shaders, selection | | |
| 20 | Interactions & Gestures | Interaction | 9 | Gestures, ink, drag-drop, pointer handling | | |

---

## Demo 1: Button Showcase

**File:** `demo_01_buttons.dart`
**Lines:** ~2000
**Widgets Covered:** 12 button widgets

### Overview

A comprehensive showcase of all button types with interactive states, customization options, and best practice examples.

### Sections

#### 1.1 Primary Buttons (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  PRIMARY BUTTONS                                            │
│  The main action buttons in Material Design 3               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  TomElevatedButton                                   │   │
│  │  For primary actions requiring visual emphasis       │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │                                                     │   │
│  │  [  Default  ]  [  Disabled  ]  [  Loading  ]       │   │
│  │                                                     │   │
│  │  [  With Icon  ]  [  Full Width  ]                  │   │
│  │                                                     │   │
│  │  Customization:                                     │   │
│  │  • Custom colors    • Border radius                 │   │
│  │  • Elevation        • Padding                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  TomFilledButton                                    │   │
│  │  M3 filled variant - highest emphasis               │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │                                                     │   │
│  │  [  Filled  ]  [  Filled Tonal  ]                  │   │
│  │                                                     │   │
│  │  Variants:                                          │   │
│  │  • FilledButton - full color fill                   │   │
│  │  • FilledButton.tonal - muted container color       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomElevatedButton` — default, disabled, loading states
- `TomFilledButton` — filled and tonal variants
- Size variations (small, medium, large)
- Icon positioning (leading, trailing, icon-only)

#### 1.2 Secondary Buttons (~300 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SECONDARY BUTTONS                                          │
│  Lower emphasis actions and alternatives                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomTextButton ──────────────────────────────────────┐ │
│  │  For low-emphasis actions, often in dialogs           │ │
│  │                                                       │ │
│  │  [Cancel]  [Learn More]  [Skip]                      │ │
│  │                                                       │ │
│  │  [🔗 Link Style]  [Destructive]                      │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomOutlinedButton ──────────────────────────────────┐ │
│  │  For medium-emphasis, providing structure             │ │
│  │                                                       │ │
│  │  [  Outlined  ]  [  With Icon  ]  [  Disabled  ]     │ │
│  │                                                       │ │
│  │  Custom border: color, width, style (solid/dashed)   │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomTextButton` — text-only, with icon, link styles
- `TomOutlinedButton` — outlined variants, custom borders

#### 1.3 Icon & FAB Buttons (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  ICON BUTTONS & FLOATING ACTION BUTTONS                     │
│  Compact and prominent action buttons                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomIconButton ──────────────────────────────────────┐ │
│  │  Icon-only buttons for compact UI                     │ │
│  │                                                       │ │
│  │  [🔔]  [⭐]  [🗑️]  [📎]  [⚙️]  [✏️]  [🔍]         │ │
│  │                                                       │ │
│  │  Variants:                                            │ │
│  │  • Standard   [🔍]                                    │ │
│  │  • Filled     [🔍]  (with background)                │ │
│  │  • Outlined   [🔍]  (with border)                    │ │
│  │  • Tonal      [🔍]  (subtle background)              │ │
│  │                                                       │ │
│  │  Sizes: Small (24)  Medium (40)  Large (60)          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomFloatingActionButton ────────────────────────────┐ │
│  │  Primary action buttons, typically one per screen     │ │
│  │                                                       │ │
│  │  Standard:    [+]         Extended:  [+ Add Item]    │ │
│  │  Small:       [+]         Large:     [ + ]           │ │
│  │                                                       │ │
│  │  Position demo: (shows FAB in different positions)   │ │
│  │  • Bottom right (default)                             │ │
│  │  • Bottom center (docked)                             │ │
│  │  • Custom positioned                                  │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomIconButton` — all variants (standard, filled, outlined, tonal)
- `TomFloatingActionButton` — regular, small, large, extended

#### 1.4 Menu & Segment Buttons (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  MENU & SEGMENTED BUTTONS                                   │
│  Grouped selections and menu interactions                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomSegmentedButton ─────────────────────────────────┐ │
│  │  Single or multi-select from a small set of options   │ │
│  │                                                       │ │
│  │  Single select:  [ Day ][ Week ][ Month ][ Year ]    │ │
│  │  Multi-select:   [ Bold ][ Italic ][ Underline ]     │ │
│  │                                                       │ │
│  │  With icons:     [📅 Day][📆 Week][🗓️ Month]         │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomMenuItemButton ──────────────────────────────────┐ │
│  │  Individual menu item buttons                         │ │
│  │                                                       │ │
│  │  ┌────────────────────┐                              │ │
│  │  │ 📋 Copy            │                              │ │
│  │  │ 📎 Paste           │                              │ │
│  │  │ ✂️ Cut             │                              │ │
│  │  │ ────────────────── │                              │ │
│  │  │ 🗑️ Delete          │                              │ │
│  │  └────────────────────┘                              │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomSubmenuButton ───────────────────────────────────┐ │
│  │  Nested menu structures                               │ │
│  │                                                       │ │
│  │  ┌─────────────────┐                                 │ │
│  │  │ File        ▸   │───┐                             │ │
│  │  │ Edit        ▸   │   │  ┌───────────────┐          │ │
│  │  │ View        ▸   │   └──│ New           │          │ │
│  │  └─────────────────┘      │ Open          │          │ │
│  │                           │ Save      ▸   │──────    │ │
│  │                           └───────────────┘          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomSegmentedButton` — single/multi select, icons
- `TomMenuItemButton` — menu items with icons
- `TomSubmenuButton` — nested submenus
- `TomMenuBar` — full menu bar composition

#### 1.5 Specialized Buttons (~300 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SPECIALIZED BUTTONS                                        │
│  Context-specific button widgets                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Navigation:                                                │
│  ┌───────────────────────────────────────────────────┐     │
│  │ [← Back]  TomBackButton                           │     │
│  │ [✕ Close] TomCloseButton                          │     │
│  │ [▼ Expand] TomExpandIcon (animated)               │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  Cupertino (iOS-style):                                    │
│  ┌───────────────────────────────────────────────────┐     │
│  │ [ Cupertino Button ]  TomCupertinoButton          │     │
│  │ [ Filled ]  TomCupertinoButton.filled             │     │
│  │ [ Action Sheet Actions ]  Interactive demo        │     │
│  │ [ Dialog Actions ]  Interactive demo              │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  Action buttons in context:                                │
│  ┌───────────────────────────────────────────────────┐     │
│  │ TomSnackBarAction demo (shows in snackbar)        │     │
│  │ TomCupertinoActionSheetAction demo                │     │
│  │ TomCupertinoDialogAction demo                     │     │
│  │ TomCupertinoContextMenuAction demo                │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomBackButton`, `TomCloseButton` — navigation controls
- `TomExpandIcon` — animated expand/collapse
- `TomCupertinoButton` — iOS-style buttons
- Context-specific action buttons

#### 1.6 Button States & Interactions (~200 lines)

Interactive demo showing:
- Hover states
- Press/tap feedback
- Focus indicators
- Disabled appearance
- Loading states with progress

---

## Demo 2: Text Input Gallery

**File:** `demo_02_inputs.dart`
**Lines:** ~2000
**Widgets Covered:** 9 input widgets

### Sections

#### 2.1 Standard Text Fields (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  STANDARD TEXT FIELDS                                       │
│  Core text input components for forms and data entry        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomTextField ───────────────────────────────────────┐ │
│  │  Single-line text input with full decoration support  │ │
│  │                                                       │ │
│  │  Basic:                                               │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ Label                               │             │ │
│  │  │ ________________________________    │             │ │
│  │  │ Helper text                         │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │                                                       │ │
│  │  With prefix/suffix:                                  │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ Price                               │             │ │
│  │  │ $ _____________.00 │ USD            │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │                                                       │ │
│  │  With icons:                                          │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ 🔒 Password                 👁️      │             │ │
│  │  │ ________________________________    │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │                                                       │ │
│  │  Variants: Outlined | Filled | Underline             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomTextFormField ───────────────────────────────────┐ │
│  │  TextField with Form integration and validation       │ │
│  │                                                       │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ Email *                             │             │ │
│  │  │ [invalid-email                    ] │             │ │
│  │  │ ❌ Please enter a valid email       │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │                                                       │ │
│  │  Validation states: Valid ✓ | Error ❌ | Warning ⚠️   │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomTextField` — all decoration variants
- `TomTextFormField` — form validation integration
- Input decorations, prefix/suffix icons and widgets

#### 2.2 Special Input Types (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SPECIAL INPUT TYPES                                        │
│  Numeric, password, and constrained inputs                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Password Input:                                            │
│  ┌─────────────────────────────────────┐                   │
│  │ Password                     [👁️]   │                   │
│  │ ••••••••••••                        │                   │
│  │ Strength: ████████░░ Strong         │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Numeric Input:                                             │
│  ┌─────────────────────────────────────┐                   │
│  │ Quantity                [-] 5 [+]   │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Phone Number (formatted):                                  │
│  ┌─────────────────────────────────────┐                   │
│  │ Phone                               │                   │
│  │ +1 (555) 123-4567                   │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Credit Card (formatted):                                   │
│  ┌─────────────────────────────────────┐                   │
│  │ Card Number                💳       │                   │
│  │ 4532 •••• •••• 1234                 │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Features demonstrated:**
- Password visibility toggle
- Password strength indicator
- Input formatters (phone, credit card)
- Numeric input with steppers

#### 2.3 Search & Autocomplete (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SEARCH & AUTOCOMPLETE                                      │
│  Smart input with suggestions and search functionality      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomSearchBar ───────────────────────────────────────┐ │
│  │  Material 3 search bar with actions                   │ │
│  │                                                       │ │
│  │  ┌─────────────────────────────────────────────┐     │ │
│  │  │ 🔍 Search products...           [🎤] [📷]  │     │ │
│  │  └─────────────────────────────────────────────┘     │ │
│  │                                                       │ │
│  │  Expanded search view:                                │ │
│  │  ┌─────────────────────────────────────────────┐     │ │
│  │  │ ← | 🔍 iphone                         [✕]   │     │ │
│  │  ├─────────────────────────────────────────────┤     │ │
│  │  │  📱 iPhone 15 Pro                           │     │ │
│  │  │  📱 iPhone 15                               │     │ │
│  │  │  📱 iPhone 14 Pro Max                       │     │ │
│  │  │  📱 iPhone SE                               │     │ │
│  │  └─────────────────────────────────────────────┘     │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomSearchAnchor ────────────────────────────────────┐ │
│  │  Search with custom suggestions builder               │ │
│  │                                                       │ │
│  │  [🔍 Search] → expands to full screen search view    │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomAutocomplete ────────────────────────────────────┐ │
│  │  Type-ahead with custom option builder                │ │
│  │                                                       │ │
│  │  Country:                                             │ │
│  │  ┌─────────────────────────────┐                     │ │
│  │  │ United                      │                     │ │
│  │  ├─────────────────────────────┤                     │ │
│  │  │ 🇺🇸 United States           │                     │ │
│  │  │ 🇬🇧 United Kingdom          │                     │ │
│  │  │ 🇦🇪 United Arab Emirates    │                     │ │
│  │  └─────────────────────────────┘                     │ │
│  │                                                       │ │
│  │  Variants:                                            │ │
│  │  • Simple string autocomplete                         │ │
│  │  • Object autocomplete with custom display            │ │
│  │  • Async autocomplete with loading                    │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomSearchBar` — M3 search bar with trailing actions
- `TomSearchAnchor` — expandable search view
- `TomAutocomplete` — type-ahead suggestions

#### 2.4 Cupertino Text Inputs (~350 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  CUPERTINO TEXT INPUTS                                      │
│  iOS-style input components                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomCupertinoTextField ──────────────────────────────┐ │
│  │  iOS-style text field                                 │ │
│  │                                                       │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │         Enter your name             │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │                                                       │ │
│  │  With prefix/suffix:                                  │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ 🔍 | Search...               | ✕    │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoSearchTextField ────────────────────────┐ │
│  │  iOS search bar style                                 │ │
│  │                                                       │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │  🔍 Search                     ✕     │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoTextFormFieldRow ───────────────────────┐ │
│  │  iOS form row with label and text field               │ │
│  │                                                       │ │
│  │  Name      │ John Appleseed                          │ │
│  │  ──────────┼─────────────────────────────────────────│ │
│  │  Email     │ john@example.com                        │ │
│  │  ──────────┼─────────────────────────────────────────│ │
│  │  Password  │ ••••••••                                │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCupertinoTextField` — iOS text fields
- `TomCupertinoSearchTextField` — iOS search bar
- `TomCupertinoTextFormFieldRow` — iOS form row style

#### 2.5 Date & Time Pickers (~350 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  DATE & TIME PICKERS                                        │
│  Date and time input components                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomCalendarDatePicker ──────────────────────────────┐ │
│  │  Inline calendar picker                               │ │
│  │                                                       │ │
│  │      ◀  March 2026  ▶                                │ │
│  │  Su  Mo  Tu  We  Th  Fr  Sa                          │ │
│  │   1   2   3   4   5   6   7                          │ │
│  │   8   9  10  11  12  13  14                          │ │
│  │  15  16  17  18  19  20  21                          │ │
│  │  22  23 [24] 25  26  27  28                          │ │
│  │  29  30  31                                          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomInputDatePickerFormField ────────────────────────┐ │
│  │  Text-based date entry with format validation         │ │
│  │                                                       │ │
│  │  Date of Birth:                                       │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │  03/24/2026                    📅   │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomYearPicker ──────────────────────────────────────┐ │
│  │  Year selection for birth year, fiscal year, etc.     │ │
│  │                                                       │ │
│  │  Select Year:                                         │ │
│  │  ┌─────┬─────┬─────┬─────┐                           │ │
│  │  │2020 │2021 │2022 │2023 │                           │ │
│  │  ├─────┼─────┼─────┼─────┤                           │ │
│  │  │2024 │2025 │[2026]│2027│                           │ │
│  │  └─────┴─────┴─────┴─────┘                           │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── Cupertino Date/Time Pickers ────────────────────────┐ │
│  │  iOS-style wheel pickers                              │ │
│  │                                                       │ │
│  │  TomCupertinoDatePicker:                              │ │
│  │  ┌─────────────────────────────────┐                 │ │
│  │  │  March      23      2026        │                 │ │
│  │  │  March      24      2026        │                 │ │
│  │  │  March      25      2026        │                 │ │
│  │  └─────────────────────────────────┘                 │ │
│  │                                                       │ │
│  │  TomCupertinoTimerPicker:                             │ │
│  │  ┌─────────────────────────────────┐                 │ │
│  │  │    2    :    30    :    00      │                 │ │
│  │  │    3    :    31    :    01      │                 │ │
│  │  │    4    :    32    :    02      │                 │ │
│  │  └─────────────────────────────────┘                 │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCalendarDatePicker` — inline calendar
- `TomInputDatePickerFormField` — text date entry
- `TomYearPicker` — year grid selection
- `TomCupertinoDatePicker` — iOS date wheel
- `TomCupertinoTimerPicker` — iOS timer wheel

---

## Demo 3: Selection Controls

**File:** `demo_03_selection.dart`
**Lines:** ~2000
**Widgets Covered:** 6 select widgets + related menu items

### Sections

#### 3.1 Dropdown Menus (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  DROPDOWN MENUS                                             │
│  Selection from a list of options                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomDropdownButton ──────────────────────────────────┐ │
│  │  Classic dropdown selection                           │ │
│  │                                                       │ │
│  │  Category:  [Electronics           ▼]                │ │
│  │                                                       │ │
│  │  ┌──────────────────────────────┐                    │ │
│  │  │ Electronics           ✓      │                    │ │
│  │  │ Clothing                     │                    │ │
│  │  │ Home & Garden                │                    │ │
│  │  │ Books                        │                    │ │
│  │  │ Sports                       │                    │ │
│  │  └──────────────────────────────┘                    │ │
│  │                                                       │ │
│  │  With custom items:                                   │ │
│  │  ┌──────────────────────────────┐                    │ │
│  │  │ 🏠 Home                      │                    │ │
│  │  │ 💼 Work                      │                    │ │
│  │  │ ➕ Add new address...        │                    │ │
│  │  └──────────────────────────────┘                    │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomDropdownButtonFormField ─────────────────────────┐ │
│  │  Dropdown with Form integration                       │ │
│  │                                                       │ │
│  │  Country *                                            │ │
│  │  [Select a country              ▼]                   │ │
│  │  ❌ This field is required                           │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomDropdownMenu ────────────────────────────────────┐ │
│  │  Material 3 dropdown menu with text field             │ │
│  │                                                       │ │
│  │  Color                                                │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ 🔴 Red                         ▼    │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │  Helper text for this selection                      │ │
│  │                                                       │ │
│  │  Expanded:                                            │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ 🔴 Red                ✓             │             │ │
│  │  │ 🟢 Green                            │             │ │
│  │  │ 🔵 Blue                             │             │ │
│  │  │ 🟡 Yellow                           │             │ │
│  │  │ ⚫ Black                            │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomDropdownMenuFormField ───────────────────────────┐ │
│  │  M3 dropdown with Form integration                    │ │
│  │                                                       │ │
│  │  Size *                                               │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │ Select size...                 ▼    │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │  ❌ Please select a size                             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomDropdownButton` — classic dropdown
- `TomDropdownButtonFormField` — form integration
- `TomDropdownMenu` — M3 dropdown with text field
- `TomDropdownMenuFormField` — M3 dropdown form field
- `TomDropdownMenuEntry` — custom menu entries

#### 3.2 Popup Menus (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  POPUP MENUS                                                │
│  Context menus and action menus                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomPopupMenuButton ─────────────────────────────────┐ │
│  │  Button that shows a popup menu                       │ │
│  │                                                       │ │
│  │  [ ⋮ ]  →  ┌────────────────────┐                    │ │
│  │            │ 📋 Copy             │                    │ │
│  │            │ ✂️ Cut              │                    │ │
│  │            │ 📎 Paste            │                    │ │
│  │            │ ────────────────── │                    │ │
│  │            │ 🗑️ Delete           │                    │ │
│  │            └────────────────────┘                    │ │
│  │                                                       │ │
│  │  Custom trigger:                                      │ │
│  │  [More Options ▼]  →  menu appears                   │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomPopupMenuItem ───────────────────────────────────┐ │
│  │  Individual menu items                                │ │
│  │                                                       │ │
│  │  Standard:         │ Copy                 │          │ │
│  │  With icon:        │ 📋 Copy              │          │ │
│  │  With shortcut:    │ 📋 Copy       ⌘C    │          │ │
│  │  Disabled:         │ ▤ Paste (disabled)  │          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCheckedPopupMenuItem ────────────────────────────┐ │
│  │  Menu items with checkmarks                           │ │
│  │                                                       │ │
│  │  View:                                                │ │
│  │  ┌────────────────────┐                              │ │
│  │  │ ✓ Show preview     │                              │ │
│  │  │   Show details     │                              │ │
│  │  │ ✓ Show sidebar     │                              │ │
│  │  └────────────────────┘                              │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomPopupMenuDivider ────────────────────────────────┐ │
│  │  Dividers in popup menus                              │ │
│  │                                                       │ │
│  │  Demonstrates auto-hiding when adjacent items hidden  │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomPopupMenuButton` — popup trigger
- `TomPopupMenuItem` — menu items
- `TomCheckedPopupMenuItem` — checkable items
- `TomPopupMenuDivider` — dividers with auto-hide

#### 3.3 Menu Anchors (~300 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  MENU ANCHORS                                               │
│  Flexible menu positioning                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomMenuAnchor ──────────────────────────────────────┐ │
│  │  Anchor point for menus with custom positioning       │ │
│  │                                                       │ │
│  │  Right-click demo area:                               │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │                                     │             │ │
│  │  │    Right-click for context menu     │             │ │
│  │  │                                     │             │ │
│  │  └───────────────┬─────────────────────┘             │ │
│  │                  │ ┌────────────────┐                │ │
│  │                  └►│ New           │                 │ │
│  │                    │ Edit          │                 │ │
│  │                    │ Delete        │                 │ │
│  │                    └────────────────┘                │ │
│  │                                                       │ │
│  │  Programmatic control:                                │ │
│  │  [Open Menu] ─► Opens menu programmatically          │ │
│  │  [Close Menu] ─► Closes menu programmatically        │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomMenuAnchor` — menu positioning
- `TomCheckboxMenuButton` — checkbox in menu
- `TomRadioMenuButton` — radio in menu

#### 3.4 Segmented Controls (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SEGMENTED CONTROLS                                         │
│  Grouped selection options                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomCupertinoSlidingSegmentedControl ────────────────┐ │
│  │  iOS-style sliding segments                           │ │
│  │                                                       │ │
│  │  [ Day      ][ Week     ][█Month███][ Year     ]     │ │
│  │                                                       │ │
│  │  Variants:                                            │ │
│  │  • Text only                                          │ │
│  │  • With icons: [📅][📆][🗓️][📈]                       │ │
│  │  • Custom colors                                      │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoSegmentedControl ───────────────────────┐ │
│  │  Classic iOS segmented control                        │ │
│  │                                                       │ │
│  │  ┌────────┬────────┬────────┐                        │ │
│  │  │ First  │ Second │ Third  │                        │ │
│  │  └────────┴────────┴────────┘                        │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoPicker ─────────────────────────────────┐ │
│  │  iOS-style wheel picker                               │ │
│  │                                                       │ │
│  │  Select fruit:                                        │ │
│  │  ┌─────────────────────────┐                         │ │
│  │  │        Apple            │                         │ │
│  │  │        Banana           │                         │ │
│  │  │       [Orange]          │                         │ │
│  │  │        Mango            │                         │ │
│  │  │        Grape            │                         │ │
│  │  └─────────────────────────┘                         │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCupertinoSlidingSegmentedControl` — iOS sliding segments
- `TomCupertinoSegmentedControl` — classic iOS segments
- `TomCupertinoPicker` — iOS wheel picker

---

## Demo 4: Toggle & Switch Suite

**File:** `demo_04_toggles.dart`
**Lines:** ~2000
**Widgets Covered:** 8 toggle widgets

### Sections

#### 4.1 Switch Controls (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SWITCH CONTROLS                                            │
│  Binary on/off toggles                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomSwitch ──────────────────────────────────────────┐ │
│  │  Material switch control                              │ │
│  │                                                       │ │
│  │  Default state:                                       │ │
│  │  Off  [═══○     ]  On   [     ●═══]                  │ │
│  │                                                       │ │
│  │  With thumb icon:                                     │ │
│  │  Off  [═══✕     ]  On   [     ✓═══]                  │ │
│  │                                                       │ │
│  │  Disabled:                                            │ │
│  │  [░░░░░░░░░]  Cannot toggle                          │ │
│  │                                                       │ │
│  │  Custom colors:                                       │ │
│  │  [═══🟢═════]  Active track color: green             │ │
│  │  [═════🔴══]   Active track color: orange            │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomSwitchListTile ──────────────────────────────────┐ │
│  │  Switch integrated in a list tile                     │ │
│  │                                                       │ │
│  │  ┌────────────────────────────────────────────┐      │ │
│  │  │ 🔔 Notifications                    [══●══]│      │ │
│  │  │    Receive push notifications              │      │ │
│  │  ├────────────────────────────────────────────┤      │ │
│  │  │ 🌙 Dark Mode                        [══○══]│      │ │
│  │  │    Enable dark theme                       │      │ │
│  │  ├────────────────────────────────────────────┤      │ │
│  │  │ 📍 Location Services               [══●══]│      │ │
│  │  │    Allow location tracking                 │      │ │
│  │  └────────────────────────────────────────────┘      │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoSwitch ─────────────────────────────────┐ │
│  │  iOS-style switch                                     │ │
│  │                                                       │ │
│  │  Off  [════○    ]  On   [    ●════]                  │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomSwitch` — Material switch variants
- `TomSwitchListTile` — switch in list context
- `TomCupertinoSwitch` — iOS switch

#### 4.2 Checkbox Controls (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  CHECKBOX CONTROLS                                          │
│  Multi-select and boolean options                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomCheckbox ────────────────────────────────────────┐ │
│  │  Boolean checkbox                                     │ │
│  │                                                       │ │
│  │  States:                                              │ │
│  │  [✓] Checked     [ ] Unchecked     [-] Indeterminate │ │
│  │                                                       │ │
│  │  Variants:                                            │ │
│  │  [✓] Default                                         │ │
│  │  [✓] Custom color (green checkmark)                  │ │
│  │  [✓] Rounded shape                                   │ │
│  │  [▤] Disabled                                        │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCheckboxListTile ────────────────────────────────┐ │
│  │  Checkbox integrated in list tile                     │ │
│  │                                                       │ │
│  │  Select categories:                                   │ │
│  │  ┌────────────────────────────────────────────┐      │ │
│  │  │ [✓] Technology                             │      │ │
│  │  │     Latest tech news and reviews            │      │ │
│  │  ├────────────────────────────────────────────┤      │ │
│  │  │ [ ] Science                                │      │ │
│  │  │     Scientific discoveries and research    │      │ │
│  │  ├────────────────────────────────────────────┤      │ │
│  │  │ [✓] Business                               │      │ │
│  │  │     Market updates and analysis            │      │ │
│  │  └────────────────────────────────────────────┘      │ │
│  │                                                       │ │
│  │  Leading vs Trailing checkbox position               │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoCheckbox ───────────────────────────────┐ │
│  │  iOS-style checkbox                                   │ │
│  │                                                       │ │
│  │  [✓] Cupertino checked                               │ │
│  │  [ ] Cupertino unchecked                             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCheckbox` — standard checkbox
- `TomCheckboxListTile` — checkbox list tile
- `TomCupertinoCheckbox` — iOS checkbox

#### 4.3 Radio Controls (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  RADIO CONTROLS                                             │
│  Single selection from multiple options                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomRadio ───────────────────────────────────────────┐ │
│  │  Mutually exclusive selection                         │ │
│  │                                                       │ │
│  │  Payment method:                                      │ │
│  │  (●) Credit Card                                     │ │
│  │  ( ) PayPal                                          │ │
│  │  ( ) Bank Transfer                                   │ │
│  │  ( ) Cash on Delivery                                │ │
│  │                                                       │ │
│  │  Horizontal layout:                                   │ │
│  │  (●) Small   ( ) Medium   ( ) Large                  │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomRadioListTile ───────────────────────────────────┐ │
│  │  Radio integrated in list tile                        │ │
│  │                                                       │ │
│  │  Shipping method:                                     │ │
│  │  ┌────────────────────────────────────────────┐      │ │
│  │  │ (●) Standard Shipping                      │      │ │
│  │  │     5-7 business days • Free               │      │ │
│  │  ├────────────────────────────────────────────┤      │ │
│  │  │ ( ) Express Shipping                       │      │ │
│  │  │     2-3 business days • $9.99              │      │ │
│  │  ├────────────────────────────────────────────┤      │ │
│  │  │ ( ) Next Day Delivery                      │      │ │
│  │  │     1 business day • $19.99                │      │ │
│  │  └────────────────────────────────────────────┘      │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoRadio ──────────────────────────────────┐ │
│  │  iOS-style radio button                               │ │
│  │                                                       │ │
│  │  (●) Option A   ( ) Option B   ( ) Option C          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomRadio` — standard radio button
- `TomRadioListTile` — radio list tile
- `TomCupertinoRadio` — iOS radio

#### 4.4 Toggle Button Groups (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  TOGGLE BUTTON GROUPS                                       │
│  Grouped toggle selections                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomToggleButtons ───────────────────────────────────┐ │
│  │  Row of selectable buttons                            │ │
│  │                                                       │ │
│  │  Single select (exclusive):                           │ │
│  │  ┌─────┬─────┬─────┬─────┐                           │ │
│  │  │ 📅  │[📆] │ 🗓️  │ 📈  │                           │ │
│  │  │ Day │Week │Month│Year │                           │ │
│  │  └─────┴─────┴─────┴─────┘                           │ │
│  │                                                       │ │
│  │  Multi select (non-exclusive):                        │ │
│  │  ┌─────┬─────┬─────┬─────┐                           │ │
│  │  │[B  ]│ I   │[U  ]│ S   │                           │ │
│  │  │Bold │Ital │Under│Strk │                           │ │
│  │  └─────┴─────┴─────┴─────┘                           │ │
│  │                                                       │ │
│  │  Vertical layout:                                     │ │
│  │  ┌─────────┐                                         │ │
│  │  │  Left   │                                         │ │
│  │  ├─────────┤                                         │ │
│  │  │ [Center]│                                         │ │
│  │  ├─────────┤                                         │ │
│  │  │  Right  │                                         │ │
│  │  └─────────┘                                         │ │
│  │                                                       │ │
│  │  Custom styling:                                      │ │
│  │  • Border radius                                      │ │
│  │  • Fill colors                                        │ │
│  │  • Border colors                                      │ │
│  │  • Selected/unselected states                         │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomToggleButtons` — grouped toggle selection
- Single and multi-select modes
- Vertical and horizontal layouts
- Custom styling options

---

## Demo 5: Slider & Range Controls

**File:** `demo_05_sliders.dart`
**Lines:** ~2000
**Widgets Covered:** 3 slider widgets

### Sections

#### 5.1 Basic Sliders (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  BASIC SLIDERS                                              │
│  Single-value continuous selection                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomSlider ──────────────────────────────────────────┐ │
│  │  Standard Material slider                             │ │
│  │                                                       │ │
│  │  Basic:                                               │ │
│  │  0 ════════════●════════════════ 100                 │ │
│  │                42                                     │ │
│  │                                                       │ │
│  │  With label:                                          │ │
│  │  Volume                                    [42]       │ │
│  │  ════════════●════════════════                       │ │
│  │                                                       │ │
│  │  With divisions (discrete):                           │ │
│  │  ═══○═══○═══●═══○═══○═══                             │ │
│  │  0   20  40  60  80  100                              │ │
│  │                                                       │ │
│  │  With value label:                                    │ │
│  │      ╭──────╮                                         │ │
│  │      │  60  │                                         │ │
│  │      ╰──●───╯                                         │ │
│  │  ═══════●════════════════                            │ │
│  │                                                       │ │
│  │  Custom track/thumb:                                  │ │
│  │  ▓▓▓▓▓▓▓▓▓▓◉░░░░░░░░░░░░░░                           │ │
│  │  (Custom colors, shapes)                              │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomSlider` — all variants
- Continuous vs. discrete (divisions)
- Value labels
- Custom track and thumb styling

#### 5.2 Range Sliders (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  RANGE SLIDERS                                              │
│  Dual-value range selection                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomRangeSlider ─────────────────────────────────────┐ │
│  │  Select a value range                                 │ │
│  │                                                       │ │
│  │  Price range:                                         │ │
│  │  $0       $200       $400       $600       $800      │ │
│  │  ═════════●═════════════════●══════════              │ │
│  │           $150             $580                       │ │
│  │                                                       │ │
│  │  With value labels:                                   │ │
│  │  ╭────╮                   ╭────╮                     │ │
│  │  │$150│                   │$580│                     │ │
│  │  ╰─●──╯                   ╰─●──╯                     │ │
│  │  ═══●═══════════════════════●════                    │ │
│  │                                                       │ │
│  │  Age range (discrete):                                │ │
│  │  18  25  35  45  55  65  75+                         │ │
│  │  ════●═══════════●════════════                       │ │
│  │     25          55                                    │ │
│  │                                                       │ │
│  │  Time range:                                          │ │
│  │  00:00  06:00  12:00  18:00  24:00                   │ │
│  │  ══════════●═══════●════════════                     │ │
│  │         09:00   17:00 (Work hours)                   │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomRangeSlider` — dual-thumb range selection
- Price, age, time range examples
- Value labels and overlays

#### 5.3 Cupertino Sliders (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  CUPERTINO SLIDERS                                          │
│  iOS-style slider controls                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomCupertinoSlider ─────────────────────────────────┐ │
│  │  iOS-style slider                                     │ │
│  │                                                       │ │
│  │  Brightness:                                          │ │
│  │  🔅 ════════════●════════════════ 🔆                 │ │
│  │                                                       │ │
│  │  Volume:                                              │ │
│  │  🔈 ════════════════●════════════ 🔊                 │ │
│  │                                                       │ │
│  │  Custom colors:                                       │ │
│  │  ▓▓▓▓▓▓▓▓▓▓▓▓▓●░░░░░░░░░░░░░░                       │ │
│  │  (Active: blue, Track: gray)                          │ │
│  │                                                       │ │
│  │  With value display:                                  │ │
│  │  ════════●════════════════   72%                     │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCupertinoSlider` — iOS slider
- With min/max icons
- Custom active/inactive colors

#### 5.4 Slider Applications (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SLIDER APPLICATIONS                                        │
│  Real-world slider use cases                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Audio Player:                                              │ │
│  ┌────────────────────────────────────────────────────┐   │
│  │  Now Playing: Song Title - Artist                   │   │
│  │  1:42 ══════════●══════════════════════════ 4:20   │   │
│  │                                                     │   │
│  │  Volume: 🔈 ════════●════════════ 🔊               │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│  Color Picker:                                              │
│  ┌────────────────────────────────────────────────────┐   │
│  │  R: 0 ═══════════●═════════ 255  [██ 156 ██]       │   │
│  │  G: 0 ═════●═══════════════ 255  [██  89 ██]       │   │
│  │  B: 0 ════════════════●════ 255  [██ 234 ██]       │   │
│  │                                                     │   │
│  │  Preview: [████████████████]                        │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│  Image Adjustments:                                         │
│  ┌────────────────────────────────────────────────────┐   │
│  │  Brightness:  ═════●═════════════  +20             │   │
│  │  Contrast:    ════════●══════════   0              │   │
│  │  Saturation:  ═══════════●═══════  -10             │   │
│  │  Exposure:    ════●══════════════  +5              │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Applications demonstrated:**
- Audio player progress/volume
- RGB color picker
- Image adjustments
- Filter settings

---

## Demo 6: Card & Panel Layouts

**File:** `demo_06_cards_panels.dart`
**Lines:** ~2000
**Widgets Covered:** 5 container widgets

### Sections

#### 6.1 Cards (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  MATERIAL CARDS                                             │
│  Content containers with elevation                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomCard ────────────────────────────────────────────┐ │
│  │  Standard card variants                               │ │
│  │                                                       │ │
│  │  Elevated:                                            │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │                                                 │ │ │
│  │  │  Card content with shadow elevation             │ │ │
│  │  │                                                 │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  │  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀   │ │
│  │                                                       │ │
│  │  Outlined:                                            │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  Card with border outline                     ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │                                                       │ │
│  │  Filled:                                              │ │
│  │  ████████████████████████████████████████████████████ │ │
│  │  █  Card with filled surface color                 █ │ │
│  │  ████████████████████████████████████████████████████ │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── Product Card Example ───────────────────────────────┐ │
│  │  ┌───────────────────────────────────────┐           │ │
│  │  │         ┌───────────────────┐         │           │ │
│  │  │         │    [Product       │         │           │ │
│  │  │         │     Image]        │         │           │ │
│  │  │         └───────────────────┘         │           │ │
│  │  │  Product Name                 $99.99  │           │ │
│  │  │  Short description here               │           │ │
│  │  │  ⭐⭐⭐⭐☆ (4.2)                      │           │ │
│  │  │                                       │           │ │
│  │  │  [Add to Cart]        [♡ Wishlist]   │           │ │
│  │  └───────────────────────────────────────┘           │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCard` — elevated, outlined, filled variants
- Product card composition
- Action cards with buttons
- Media cards with images

#### 6.2 Expansion Tiles (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  EXPANSION TILES                                            │
│  Expandable content sections                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomExpansionTile ───────────────────────────────────┐ │
│  │  Collapsible list tile sections                       │ │
│  │                                                       │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │ 📦 Order Details                          ▼   │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │                                                       │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │ 📍 Shipping Address                       △   │   │ │
│  │  ├───────────────────────────────────────────────┤   │ │
│  │  │  John Doe                                     │   │ │
│  │  │  123 Main Street                              │   │ │
│  │  │  New York, NY 10001                           │   │ │
│  │  │  United States                                │   │ │
│  │  │                                               │   │ │
│  │  │  [Edit Address]                               │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │                                                       │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │ 💳 Payment Method                         ▼   │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │                                                       │ │
│  │  Customization:                                       │ │
│  │  • Leading icons                                      │ │
│  │  • Subtitle text                                      │ │
│  │  • Custom expansion icon                              │ │
│  │  • Icon color                                         │ │
│  │  • Background color                                   │ │
│  │  • Children padding                                   │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomCupertinoExpansionTile ──────────────────────────┐ │
│  │  iOS-style expansion tile                             │ │
│  │                                                       │ │
│  │  (Similar layout with Cupertino styling)              │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomExpansionTile` — expandable sections
- `TomCupertinoExpansionTile` — iOS variant
- Nested expansion tiles
- Controlled expansion state

#### 6.3 Expansion Panel Lists (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  EXPANSION PANEL LISTS                                      │
│  Accordion-style panel groups                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomExpansionPanelList ──────────────────────────────┐ │
│  │  Grouped expandable panels                            │ │
│  │                                                       │ │
│  │  FAQ Section:                                         │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │ ▼ What is your return policy?                 │   │ │
│  │  ├───────────────────────────────────────────────┤   │ │
│  │  │ We offer a 30-day return policy on all        │   │ │
│  │  │ products. Items must be in original           │   │ │
│  │  │ packaging and unused condition.               │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │ ▶ How do I track my order?                    │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │ ▶ Do you ship internationally?                │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │ ▶ What payment methods do you accept?         │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │                                                       │ │
│  │  Expansion options:                                   │ │
│  │  • Single expansion (accordion mode)                  │ │
│  │  • Multiple expansion                                 │ │
│  │  • Radio mode (one open at a time)                    │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomExpansionPanelList` — grouped panels
- Accordion behavior
- Custom expand/collapse callbacks

#### 6.4 Material & Ink (~300 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  MATERIAL & INK                                             │
│  Material Design surface widgets                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌── TomMaterial ────────────────────────────────────────┐ │
│  │  Material surface with elevation and shape            │ │
│  │                                                       │ │
│  │  Elevation levels:                                    │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │ │
│  │  │  0dp    │ │  1dp    │ │  3dp    │ │  6dp    │    │ │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘    │ │
│  │      ░          ▒          ▓          █             │ │
│  │                                                       │ │
│  │  Material types:                                      │ │
│  │  • Canvas - background surface                        │ │
│  │  • Card - raised content card                         │ │
│  │  • Circle - circular clipping                         │ │
│  │  • Button - rounded corners                           │ │
│  │  • Transparency                                       │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌── TomInk ─────────────────────────────────────────────┐ │
│  │  Ink splash effects on Material                       │ │
│  │                                                       │ │
│  │  ┌─────────────────────────────────────┐             │ │
│  │  │      Tap to see ink splash          │             │ │
│  │  │         ○ ← ripple effect           │             │ │
│  │  └─────────────────────────────────────┘             │ │
│  │                                                       │ │
│  │  Ink.image for decorated images                      │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomMaterial` — surface properties
- `TomInk` — ink decorations
- Elevation and shadow effects

---

## Demo 7: Layout Containers

**File:** `demo_07_layout.dart`
**Lines:** ~2000
**Widgets Covered:** 25 layout container widgets

### Sections

#### 7.1 Flex Layouts (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  FLEX LAYOUTS                                               │
│  Column, Row, and flex children                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomColumn:                                                 │
│  ┌────────────────────┐    Alignment options:               │
│  │ ┌────────────────┐ │    • start                         │
│  │ │    Item 1      │ │    • center                        │
│  │ └────────────────┘ │    • end                           │
│  │ ┌────────────────┐ │    • spaceBetween                  │
│  │ │    Item 2      │ │    • spaceAround                   │
│  │ └────────────────┘ │    • spaceEvenly                   │
│  │ ┌────────────────┐ │                                    │
│  │ │    Item 3      │ │                                    │
│  │ └────────────────┘ │                                    │
│  └────────────────────┘                                     │
│                                                             │
│  TomRow:                                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐     │    │
│  │ │Item 1│    │Item 2│    │Item 3│    │Item 4│     │    │
│  │ └──────┘    └──────┘    └──────┘    └──────┘     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  TomExpanded / TomFlexible:                                │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ┌──────┐ ┌───────────────────────────────────┐    │    │
│  │ │Fixed │ │           Expanded              │    │    │
│  │ └──────┘ └───────────────────────────────────┘    │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  Flex ratios:                                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ┌─────────┐ ┌──────────────────────────────────┐ │    │
│  │ │ flex: 1 │ │           flex: 2              │ │    │
│  │ └─────────┘ └──────────────────────────────────┘ │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  TomSpacer:                                                 │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ┌──────┐           SPACER           ┌──────┐     │    │
│  │ │ Left │                            │Right │     │    │
│  │ └──────┘                            └──────┘     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomColumn`, `TomRow` — flex layouts
- `TomExpanded`, `TomFlexible` — flex children
- `TomSpacer` — flexible spacer
- `TomWrap` — wrapping flow
- Alignment and spacing options

#### 7.2 Stack & Positioned (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  STACK LAYOUTS                                              │
│  Layered positioning                                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomStack:                                                  │
│  ┌─────────────────────────────────────┐                   │
│  │ ████████████████████████████████████│ ← Background      │
│  │ ████████████████████████████████████│                   │
│  │ ████████┌─────────────┐██████████████│ ← Middle layer   │
│  │ ████████│  Centered   │██████████████│                   │
│  │ ████████└─────────────┘██████████████│                   │
│  │ ████████████████████████████████████│                   │
│  │ ┌───┐███████████████████████████████│ ← Top layer       │
│  │ │ 🔔│███████████████████████████████│   (Positioned)    │
│  │ └───┘███████████████████████████████│                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  TomPositioned:                                             │
│  ┌─────────────────────────────────────┐                   │
│  │┌────┐                         ┌────┐│                   │
│  ││TL  │                         │ TR ││  top-left,        │
│  │└────┘                         └────┘│  top-right        │
│  │                                     │                   │
│  │              ┌─────────┐            │                   │
│  │              │ CENTER  │            │  centered         │
│  │              └─────────┘            │                   │
│  │                                     │                   │
│  │┌────┐                         ┌────┐│                   │
│  ││BL  │                         │ BR ││  bottom-left,     │
│  │└────┘                         └────┘│  bottom-right     │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  TomIndexedStack:                                           │
│  Index: [ 0 ][ 1 ][ 2 ][ 3 ]                               │
│  ┌─────────────────────────────────────┐                   │
│  │                                     │                   │
│  │     Currently showing child 1       │                   │
│  │     (others are offstage)           │                   │
│  │                                     │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomStack` — layered children
- `TomPositioned`, `TomPositionedDirectional` — absolute positioning
- `TomIndexedStack` — single visible child

#### 7.3 Size & Constraint Widgets (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  SIZE & CONSTRAINT WIDGETS                                  │
│  Controlling widget dimensions                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomSizedBox:                                               │
│  ┌───100x50───┐  ┌────────────────────────────────────┐    │
│  │            │  │          expand: full width         │    │
│  └────────────┘  └────────────────────────────────────┘    │
│                                                             │
│  TomConstrainedBox:                                         │
│  minWidth: 100, maxWidth: 300, minHeight: 50               │
│  ┌───────────────────────────────────────┐                 │
│  │   Constrained to min/max bounds       │                 │
│  └───────────────────────────────────────┘                 │
│                                                             │
│  TomFractionallySizedBox:                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ┌────────────────────────────────────────────┐      │  │
│  │  │          80% of parent width               │      │  │
│  │  └────────────────────────────────────────────┘      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  TomAspectRatio:                                            │
│  Ratio 16:9                Ratio 1:1                        │
│  ┌─────────────────┐      ┌───────────┐                    │
│  │                 │      │           │                    │
│  │    Video        │      │  Square   │                    │
│  │                 │      │           │                    │
│  └─────────────────┘      └───────────┘                    │
│                                                             │
│  TomIntrinsicHeight / TomIntrinsicWidth:                    │
│  ┌───────────────────────────────────────────────────┐     │
│  │ ┌──────────────┐ ┌──────────────────────────────┐│     │
│  │ │  Short       │ │ Tall content that sets the  ││     │
│  │ │  content     │ │ intrinsic height for row    ││     │
│  │ │              │ │                              ││     │
│  │ │              │ │                              ││     │
│  │ └──────────────┘ └──────────────────────────────┘│     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomSizedBox`, `TomConstrainedBox` — explicit sizing
- `TomFractionallySizedBox` — percentage sizing
- `TomAspectRatio` — maintain aspect ratio
- `TomFittedBox` — scale-to-fit
- `TomIntrinsicHeight`, `TomIntrinsicWidth` — intrinsic measuring
- `TomLimitedBox`, `TomUnconstrainedBox`, `TomOverflowBox`

#### 7.4 Alignment & Spacing (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  ALIGNMENT & SPACING                                        │
│  Positioning and spacing utilities                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomCenter:                                                 │
│  ┌─────────────────────────────────────┐                   │
│  │                                     │                   │
│  │             ┌───────┐               │                   │
│  │             │Centered│               │                   │
│  │             └───────┘               │                   │
│  │                                     │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  TomAlign (various alignments):                             │
│  ┌─────────────────────────────────────┐                   │
│  │topLeft            topCenter   topRight│                   │
│  │                                     │                   │
│  │centerLeft        center    centerRight│                   │
│  │                                     │                   │
│  │bottomLeft     bottomCenter bottomRight│                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  TomPadding:                                                │
│  ┌──────────────────────────────────────────┐              │
│  │  ╔════════════════════════════════════╗  │  all: 16     │
│  │  ║                                    ║  │              │
│  │  ║         Padded content             ║  │              │
│  │  ║                                    ║  │              │
│  │  ╚════════════════════════════════════╝  │              │
│  └──────────────────────────────────────────┘              │
│                                                             │
│  EdgeInsets patterns:                                       │
│  • all(16) — uniform padding                                │
│  • symmetric(horizontal: 24, vertical: 8)                   │
│  • only(left: 16, top: 8)                                   │
│  • fromLTRB(16, 8, 16, 8)                                   │
│                                                             │
│  TomDivider / TomVerticalDivider:                           │
│  ┌───────────────────────────────────────────────────┐     │
│  │ Section 1  │  Section 2  │  Section 3              │     │
│  │────────────────────────────────────────────────────│     │
│  │ Row 1                                              │     │
│  │────────────────────────────────────────────────────│     │
│  │ Row 2                                              │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCenter`, `TomAlign` — alignment wrappers
- `TomPadding` — spacing wrapper
- `TomBaseline` — text baseline alignment
- `TomDivider`, `TomVerticalDivider` — separators

---

## Demo 8: Scrollable Containers

**File:** `demo_08_scrollable.dart`
**Lines:** ~2000
**Widgets Covered:** 10 scrollable container widgets

### Sections

#### 8.1 Basic Scroll Views (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  BASIC SCROLL VIEWS                                         │
│  Single-child scrollable containers                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomSingleChildScrollView:                                  │
│  ┌─────────────────────────────────────┐ ▲                 │
│  │  Long content that exceeds the       │ │                 │
│  │  available vertical space.           │ ║                 │
│  │                                      │ ║                 │
│  │  Scroll indicator visible on the     │ ║                 │
│  │  right side shows position.          │ ║                 │
│  │                                      │ ║                 │
│  │  Can scroll in either direction      │ ║                 │
│  │  or both directions.                 │ ▼                 │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Horizontal scroll:                                         │
│  ◀ ┌─────────────────────────────────────────────────┐ ▶  │
│    │ Item 1 │ Item 2 │ Item 3 │ Item 4 │ Item 5 │ → │     │
│    └─────────────────────────────────────────────────┘     │
│                                                             │
│  TomScrollbar / TomCupertinoScrollbar:                      │
│  ┌─────────────────────────────────────┐░                  │
│  │  Content with visible scrollbar     │█                  │
│  │  on the side. Can customize:        │█                  │
│  │  • Thickness                        │░                  │
│  │  • Radius                           │░                  │
│  │  • Always visible                   │░                  │
│  │  • Interactive (draggable)          │░                  │
│  └─────────────────────────────────────┘░                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomSingleChildScrollView` — basic scrolling
- `TomScrollbar`, `TomCupertinoScrollbar` — scroll indicators
- Scroll physics customization



#### 8.2 Nested Scroll Views (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  NESTED SCROLL VIEWS                                        │
│  Coordinated scrolling between header and body              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomNestedScrollView:                                       │
│  ┌─────────────────────────────────────┐                   │
│  │ ╔═══════════════════════════════╗   │  ← Header slivers │
│  │ ║     Expandable Header         ║   │    (collapse on   │
│  │ ║                               ║   │     scroll)       │
│  │ ╚═══════════════════════════════╝   │                   │
│  │ ┌───────────────────────────────┐   │  ← Pinned tab bar │
│  │ │ Tab 1  │  Tab 2  │  Tab 3     │   │                   │
│  │ └───────────────────────────────┘   │                   │
│  │ ┌───────────────────────────────┐   │  ← Scrollable body│
│  │ │  Tab content scrolls          │   │                   │
│  │ │  independently but coordinates│   │                   │
│  │ │  with header collapse         │   │                   │
│  │ └───────────────────────────────┘   │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Scroll states:                                             │
│  • Header fully expanded                                    │
│  • Header partially collapsed                               │
│  • Header fully collapsed (tab bar pinned)                  │
│  • Body scrolling (tab content)                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomNestedScrollView` — header/body coordination
- Pinned tab bar with scrollable content

#### 8.3 Draggable & Interactive (~500 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  DRAGGABLE & INTERACTIVE CONTAINERS                         │
│  User-resizable and zoomable containers                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomDraggableScrollableSheet:                               │
│  ┌─────────────────────────────────────┐                   │
│  │     Main content area               │                   │
│  │                                     │                   │
│  │                                     │                   │
│  ├─══════════════════════════════════─┤ ← Drag handle      │
│  │ ┌───────────────────────────────┐  │                   │
│  │ │  Draggable sheet content      │  │                   │
│  │ │                               │  │                   │
│  │ │  Drag up to expand            │  │                   │
│  │ │  Drag down to minimize        │  │                   │
│  │ └───────────────────────────────┘  │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Snap points: 0.25 (collapsed), 0.5 (half), 1.0 (expanded) │
│                                                             │
│  TomInteractiveViewer:                                      │
│  ┌─────────────────────────────────────┐                   │
│  │  ╔═══════════════════════════════╗  │                   │
│  │  ║                               ║  │  ← Pan and zoom   │
│  │  ║    Large image or content     ║  │    with gestures  │
│  │  ║                               ║  │                   │
│  │  ║    Pinch to zoom              ║  │                   │
│  │  ║    Drag to pan                ║  │                   │
│  │  ║                               ║  │                   │
│  │  ╚═══════════════════════════════╝  │                   │
│  │                                     │                   │
│  │  Zoom: [100%] ───●─────── [400%]   │                   │
│  │  [Fit] [Fill] [Reset]               │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Min/max scale, boundary constraints, constrained panning   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomDraggableScrollableSheet` — resizable bottom sheet
- `TomInteractiveViewer` — pan and zoom

#### 8.4 Carousel & Visibility (~400 lines)

```
┌─────────────────────────────────────────────────────────────┐
│  CAROUSEL & VISIBILITY                                      │
│  Content carousels and visibility control                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TomCarouselView:                                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │   ◀  ┌────────────────────────────────┐  ▶          │   │
│  │      │                                │              │   │
│  │      │       Featured Item 2          │              │   │
│  │      │                                │              │   │
│  │      └────────────────────────────────┘              │   │
│  │                  ○  ●  ○  ○  ○                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  TomVisibility:                                             │
│  visible: true                 visible: false               │
│  ┌────────────────────────┐   ┌────────────────────────┐   │
│  │  Content is visible    │   │  (space maintained     │   │
│  │  and occupies space    │   │   but content hidden)  │   │
│  └────────────────────────┘   └────────────────────────┘   │
│                                                             │
│  maintainSize:     true → space maintained when invisible   │
│  maintainState:    true → state preserved when invisible    │
│  maintainAnimation: true → animations continue              │
│                                                             │
│  TomOffstage:                                               │
│  offstage: true → widget not rendered at all, no space     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Widgets demonstrated:**
- `TomCarouselView` — horizontal carousel
- `TomVisibility`, `TomOffstage` — show/hide control
- `TomSafeArea` — device safe area insets

---

## Demo 9: Dialog & Modal Gallery

**File:** `demo_09_dialogs.dart`
**Lines:** ~2000
**Widgets Covered:** 10 dialog widgets

### Sections

(Dialog demos with AlertDialog, SimpleDialog, BottomSheet, SnackBar, Tooltip, DatePicker, TimePicker, Cupertino dialogs, etc.)

---

## Demo 10: Data Tables

**File:** `demo_10_tables.dart`
**Lines:** ~2000
**Widgets Covered:** 5 table widgets

### Sections

(Data tables with DataTable, PaginatedDataTable, sorting, selection, Table layout, GridView, ReorderableListView)

---

## Demo 11: Text & Label Display

**File:** `demo_11_labels.dart`
**Lines:** ~2000
**Widgets Covered:** 6 label widgets

### Sections

(Text styles, RichText, SelectableText, Badge, ListTile, Chip variants)

---

## Demo 12: Image & Icon Gallery

**File:** `demo_12_images.dart`
**Lines:** ~2000
**Widgets Covered:** 5 image widgets

### Sections

(Image sources, CircleAvatar, Icon, ImageIcon, FadeInImage, AnimatedIcon)

---

## Demo 13: Navigation Patterns

**File:** `demo_13_navigation.dart`
**Lines:** ~2000
**Widgets Covered:** 11 navigation widgets

### Sections

(TabBar/TabBarView, NavigationBar, NavigationRail, NavigationDrawer, Drawer, BottomNavigationBar, Stepper, PageView, CupertinoTabBar, CupertinoNavigationBar)

---

## Demo 14: Progress Indicators

**File:** `demo_14_progress.dart`
**Lines:** ~2000
**Widgets Covered:** 4 progress widgets

### Sections

(CircularProgressIndicator, LinearProgressIndicator, RefreshIndicator, CupertinoActivityIndicator with various states and customizations)

---

## Demo 15: List Views

**File:** `demo_15_lists.dart`
**Lines:** ~2000
**Widgets Covered:** 5 list widgets

### Sections

(ListView variants, AnimatedList, ReorderableListView, Dismissible, ListWheelScrollView)

---

## Demo 16: Tree & Hierarchy

**File:** `demo_16_trees.dart`
**Lines:** ~2000
**Widgets Covered:** 2 tree widgets

### Sections

(TreeSliver for large datasets, nested ExpansionTile patterns, file explorer pattern, organizational hierarchy)

---

## Demo 17: Sliver Compositions

**File:** `demo_17_slivers.dart`
**Lines:** ~2000
**Widgets Covered:** 18 sliver widgets

### Sections

(CustomScrollView, SliverAppBar, SliverList, SliverGrid, SliverToBoxAdapter, SliverFillRemaining, pinned headers, floating headers, sliver groups, decorated slivers)

---

## Demo 18: Animated Transitions

**File:** `demo_18_animated.dart`
**Lines:** ~2000
**Widgets Covered:** 19 animated widgets

### Sections

(Implicit animations: AnimatedContainer, AnimatedOpacity, AnimatedCrossFade, AnimatedSwitcher, AnimatedPositioned, AnimatedAlign, AnimatedPadding, AnimatedScale, AnimatedSlide, AnimatedRotation, Hero transitions)

---

## Demo 19: Effects & Filters

**File:** `demo_19_effects.dart`
**Lines:** ~2000
**Widgets Covered:** 6 effect widgets

### Sections

(BackdropFilter, ColorFiltered, ImageFiltered, ShaderMask, SelectableRegion/SelectionArea, SensitiveContent)

---

## Demo 20: Interactions & Gestures

**File:** `demo_20_interactions.dart`
**Lines:** ~2000
**Widgets Covered:** 9 interaction widgets

### Sections

(GestureDetector, InkWell/InkResponse, Draggable/DragTarget, LongPressDraggable, AbsorbPointer, IgnorePointer, MouseRegion)

---

## Implementation Guidelines

### Code Organization

Each demo file should:

1. **Import necessary packages**
2. **Define constants** (colors, spacing, sample data)
3. **Create section builder methods** (~200-300 lines each)
4. **Use consistent card/section patterns**
5. **Include interactive state management**

### Sample Data

```dart
// Sample data for demos
const sampleProducts = [...];
const sampleUsers = [...];
const sampleCountries = [...];
const sampleColors = [...];
```

### Accessibility

- Include semantic labels
- Ensure sufficient contrast
- Test with screen readers
- Support keyboard navigation

### Documentation

Each widget showcase should include:
- Widget name and class
- Brief description
- Key properties demonstrated
- Use case guidance

### Testing

Create corresponding test files:
- `demo_01_buttons_test.dart`
- Widget tests for interactive elements
- Golden tests for visual regression

---

## Related Documents

- [tom_ui_flutter_widgets.md](../_doc/tom/tom_ui_flutter_widgets.md) — Complete widget reference
- [tom_ui_widgets_forms.md](../_doc/tom/tom_ui_widgets_forms.md) — Custom widgets and forms
- [tom_ui_design_architecture.md](../_doc/tom/tom_ui_design_architecture.md) — UI architecture
