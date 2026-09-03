# Tom UI — Flutter Widget Reference

*Part of the [Tom Flutter UI documentation set](README.md).*

Comprehensive listing of all Flutter SDK widgets relevant to the Tom UI framework, organized by family. Scanned from **Flutter 3.41.4** using transitive subclass analysis across `widgets/`, `material/`, and `cupertino/` libraries.

> **This is a snapshot, and the SDK has moved since.** The workspace now builds
> against Flutter 3.44.6; the scan behind these tables has not been re-run, so
> a widget added or deprecated after 3.41.4 will be missing from them. Rows are
> corrected against the source as they are checked — the `Radio` rows carry the
> `RadioGroup` ancestor the 3.41.4 scan predates — but absence from a family
> table is not evidence that the SDK lacks the widget. The one section that is
> *not* a snapshot is [Custom Tom Widgets](#custom-tom-widgets-non-form), which
> describes this package rather than the SDK and is checked against `lib/` by
> `tool/check_unimplemented_claims.py`.

## Column Legend

| Column | Meaning |
|--------|---------|
| **Class Name** | Flutter widget class name |
| **Wrapped** | Whether a `Tom*` wrapper exists in `tom_flutter_ui` |
| **Is Widget** | Whether it's a true `Widget` subclass (vs. data class, span, etc.) |
| **Has Child(ren)** | Whether the widget accepts child widgets — directly (`child`, `children`) or via widget-typed parameters (`leading`, `trailing`, `title`, `icon`, `avatar`, `label`, `actions`, `body`, `bottom`, `floatingActionButton`, `drawer`, `tabs`, `prefix`, `suffix`, `background`, `header`, `footer`, etc.) |
| **Has Text(s)** | Whether the widget accepts text content — directly (`data`, `text`) or via decorator parameters (`decoration.labelText`, `decoration.hintText`, `semanticLabel`, `tooltip`, `message`, `restorationId`, etc.) |
| **Should Wrap** | Recommendation: **Yes** = wrap for auth/resources, **No** = skip (truly internal only), **Migrate** = deprecated but wrap for migration of existing code |
| **Wrapping Problems** | Type constraint issues when wrapping: `—` = none, otherwise describes the Flutter API incompatibility |
| **Resource Migrated** | Phase 2 migration status: **Yes** = uses `param ?? resolveXOrNull(context, 'suffix')` pattern, **No** = not yet migrated |
| **Description & Verdict** | Component purpose and reasoning for the wrap/skip recommendation |

### Wrapping Problem Categories

Tom wrappers use **composition**: `TomFoo extends TomWidgetBase` (a `StatelessWidget`), with `build()` returning the actual `Foo` widget. The wrapper is a `Widget` but NOT a `Foo`. This causes problems when:

1. **Hard type constraint** — Parent constructor parameter expects a specific class (e.g., `NavigationBar(destinations: List<NavigationDestination>)`). A `TomNavigationDestination` is NOT a `NavigationDestination`, so it can't be passed.
2. **Runtime `is`-check** — Parent internally does `child is Foo` (e.g., `TabBar` checks `tab is Tab` to extract icon/text). The wrapper fails this check.
3. **Extends constraint** — Widget extends a specific parent that the wrapping parent checks for (e.g., `Expanded extends Flexible`, and `Flex` checks `child is Flexible` for layout).

For widgets with wrapping problems, the wrapper implementation needs special patterns (e.g., extension types, delegation, or wrapper-aware parent widgets).

---

## I. Core Widgets and Containers

Widgets currently wrapped (or planned as core) in `tom_flutter_ui`.

### Button Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `ElevatedButton` | Yes | Yes | `child` (Widget) | via `style` | Yes | — | Phase 3 | Primary raised button. Auth controls action visibility; resources for label text. |
| `FilledButton` | Yes | Yes | `child` (Widget) | via `style` | Yes | — | Phase 3 | M3 filled button variant. Same auth/resource needs as ElevatedButton. |
| `TextButton` | Yes | Yes | `child` (Widget) | via `style` | Yes | — | Phase 3 | Flat text-only button. Auth controls visibility; resources for label. |
| `OutlinedButton` | Yes | Yes | `child` (Widget) | via `style` | Yes | — | Phase 3 | Outlined variant. Same auth/resource pattern. |
| `IconButton` | Yes | Yes | `icon` (Widget) | `tooltip` | Yes | — | Phase 3 | Icon-only button. Auth on action; resource for tooltip text. |
| `FloatingActionButton` | Yes | Yes | `child` (Widget) | `tooltip`, `heroTag` | Yes | — | Phase 3 | FAB. Auth controls primary action access; resource for tooltip. |
| `MenuItemButton` | Yes | Yes | `child` (Widget), `leadingIcon`, `trailingIcon` | `semanticLabel` | Yes | — | Phase 3 | Menu item with action. Auth controls menu item visibility. |
| `SubmenuButton` | Yes | Yes | `child` (Widget), `menuChildren` (List\<Widget\>), `leadingIcon`, `trailingIcon` | — | Yes | — | Phase 3 | Submenu in menu system. Auth can hide entire submenu sections. |
| `SegmentedButton` | Yes | Yes | `segments` (List\<ButtonSegment\>) | — | Yes | — | Phase 3 | Segmented selector. Auth can control which segments are available. |
| `DropdownMenuEntry` | Yes | Yes | `leadingIcon`, `trailingIcon` | `label` (String) | Yes | **Hard type:** `DropdownMenu(dropdownMenuEntries: List<DropdownMenuEntry<T>>)` — wrapper type won't match | Phase 3 | Entry in DropdownMenu. Auth per entry; resource for label text. |
| `BackButton` | Yes | Yes | — | — | Yes | — | Phase 3 | Platform back button. Auth could hide back navigation. |
| `CloseButton` | Yes | Yes | — | — | Yes | — | Phase 3 | Close button. Auth on close action. |

### Input Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `TextField` | Yes | Yes | `decoration.prefix`, `decoration.suffix`, `decoration.icon`, `decoration.prefixIcon`, `decoration.suffixIcon` (all Widget) | `decoration.labelText`, `decoration.hintText`, `decoration.helperText`, `decoration.errorText`, `decoration.counterText`, `decoration.prefixText`, `decoration.suffixText` | Yes | — | Phase 3 | Primary text input. Auth for readonly/hidden; resources for all label/hint texts. |
| `TextFormField` | Yes | Yes | Same as TextField via `decoration` | Same as TextField | Yes | — | Phase 3 | TextField variant with Form integration. Same auth/resource needs. |
| `EditableText` | Yes | Yes | — | — | Yes | — | Phase 3 | Low-level editable text. Auth for readonly; limited resource use. |
| `Autocomplete` | Yes | Yes | `fieldViewBuilder` (Widget Function), `optionsViewBuilder` (Widget Function) | — | Yes | — | Phase 3 | Autocomplete field. Auth controls whether autocomplete is available. |
| `SearchBar` | Yes | Yes | `leading` (Widget), `trailing` (List\<Widget\>) | `hintText` | Yes | — | Phase 3 | Search input bar. Auth can hide search; resource for hint text. |
| `SearchAnchor` | Yes | Yes | `viewBuilder` (Widget Function), `suggestionsBuilder` | — | Yes | — | Phase 3 | Search with suggestions. Auth controls search access. |
| `CupertinoTextField` | Yes | Yes | `prefix` (Widget), `suffix` (Widget) | `placeholder`, `decoration` | Yes | — | Phase 3 | Cupertino text input. Same auth/resource needs as TextField. |

### Select Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `DropdownButton` | Yes | Yes | `items` (List\<DropdownMenuItem\>), `icon` (Widget), `selectedItemBuilder` | `hint` (Widget) | Yes | — | Phase 3 | Classic dropdown. Auth on selection control; resources for items. |
| `DropdownButtonFormField` | Yes | Yes | Same as DropdownButton | Same + `decoration.*` texts | Yes | — | Phase 3 | Dropdown with Form integration. Auth for readonly/hidden. |
| `DropdownMenu` | Yes | Yes | `leadingIcon`, `trailingIcon`, `dropdownMenuEntries` | `label` (Widget), `hintText`, `helperText`, `errorText` | Yes | — | Phase 3 | M3 dropdown menu. Auth/resource-rich. |
| `PopupMenuButton` | Yes | Yes | `child` (Widget), `itemBuilder` (List\<PopupMenuEntry\>) | `tooltip` | Yes | — | Phase 3 | Popup menu trigger. Auth controls menu access. |
| `MenuAnchor` | Yes | Yes | `child` (Widget), `menuChildren` (List\<Widget\>) | — | Yes | — | Phase 3 | Menu anchor point. Auth on menu system. |
| `CupertinoSlidingSegmentedControl` | Yes | Yes | `children` (Map\<T, Widget\>) | — | Yes | — | Phase 3 | Cupertino segmented control. Auth per segment. |

### Toggle Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `Switch` | Yes | Yes | `thumbIcon` (WidgetStateProperty\<Icon?\>) | `semanticLabel` (planned) | Yes | — | Phase 3 | On/off toggle. Auth for readonly/hidden. |
| `SwitchListTile` | Yes | Yes | `secondary` (Widget) | `title` (Widget), `subtitle` (Widget) | Yes | — | Phase 3 | Switch with list tile. Auth/resources for label texts. |
| `Checkbox` | Yes | Yes | — | `semanticLabel` | Yes | — | Phase 3 | Boolean checkbox. Auth for readonly/hidden. |
| `CheckboxListTile` | Yes | Yes | `secondary` (Widget) | `title` (Widget), `subtitle` (Widget) | Yes | — | Phase 3 | Checkbox with list tile. Auth/resources for labels. |
| `Radio` | Yes | Yes | — | — | Yes | — | Phase 3 | Radio option. Auth for readonly/hidden. Selection comes from an enclosing `RadioGroup<T>`, not from a `groupValue` of its own — without that ancestor `TomRadio` renders but cannot be selected, which is Flutter's behaviour and not a Tom restriction. |
| `RadioListTile` | Yes | Yes | `secondary` (Widget) | `title` (Widget), `subtitle` (Widget) | Yes | — | Phase 3 | Radio with list tile. Auth/resources for labels. |
| `CupertinoSwitch` | Yes | Yes | — | — | Yes | — | Phase 3 | Cupertino switch. Same auth needs as Material Switch. |
| `ToggleButtons` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Row of toggle buttons. Auth per button visibility. |

### Slider Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `Slider` | Yes | Yes | — | `label` (String), `semanticLabel` | Yes | — | Phase 3 | Single-value slider. Auth for readonly; resource for label. |
| `RangeSlider` | Yes | Yes | — | `semanticLabel` | Yes | — | Phase 3 | Dual-value range slider. Auth for readonly. |
| `CupertinoSlider` | Yes | Yes | — | — | Yes | — | Phase 3 | Cupertino slider. Same auth needs as Material Slider. |

### Container Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `Container` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | General-purpose container. Auth hides content sections. |
| `Card` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Material card. Auth on card content sections. |
| `ExpansionTile` | Yes | Yes | `children` (List\<Widget\>), `leading` (Widget), `trailing` (Widget) | `title` (Widget), `subtitle` (Widget) | Yes | — | Phase 3 | Expandable section. Auth on expand access; resources for title. |
| `ExpansionPanelList` | Yes | Yes | `children` (List\<ExpansionPanel\>) | — | Yes | — | Phase 3 | List of expansion panels. Auth per panel. |
| `Column` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Vertical layout. Auth on column content. |
| `Row` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Horizontal layout. Auth on row content. |
| `Wrap` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Wrapping flow layout. Auth on wrap sections. |
| `Stack` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Layered layout. Auth on stack layers. |
| `IndexedStack` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Single-child stack (pager). Auth per indexed child. |
| `SizedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Fixed-size box. Auth on content. |
| `ConstrainedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Constrained sizing. Auth on content. |
| `Padding` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Padding wrapper. Auth on content. |
| `Center` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Center alignment. Auth on content. |
| `Align` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Alignment wrapper. Auth on content. |
| `AspectRatio` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Aspect ratio enforcer. Auth on content. |
| `FittedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Scale-to-fit wrapper. Auth on content. |
| `FractionallySizedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Fractional sizing. Auth on content. |
| `IntrinsicHeight` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Intrinsic height constraint. Auth on content. |
| `IntrinsicWidth` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Intrinsic width constraint. Auth on content. |
| `Material` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Material surface. Auth on surface content. |
| `Ink` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Ink decoration on Material. Auth on decorated content. |
| `DecoratedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Decorated wrapper. Auth on content. |
| `ClipRRect` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Rounded rectangle clip. Auth on clipped content. |
| `ClipOval` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Oval clip. Auth on content. |
| `ClipRect` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Rectangle clip. Auth on content. |
| `Divider` | Yes | Yes | — | — | Yes | — | Phase 3 | Horizontal divider. Auth-based visibility (auto-hide when adjacent items hidden). |
| `Spacer` | Yes | Yes | — | — | Yes | **Runtime `is`-check:** `Flex` checks `child is Flexible` — `Spacer` extends `Flexible`, wrapper fails | Phase 3 | Flex spacer. Auth-based visibility. |
| `Scaffold` | Yes | Yes | `body` (Widget), `appBar` (PreferredSize), `drawer` (Widget), `endDrawer` (Widget), `bottomNavigationBar` (Widget), `floatingActionButton` (Widget), `bottomSheet` (Widget), `persistentFooterButtons` (List\<Widget\>) | — | Yes | — | Phase 3 | App page scaffold. Auth on page regions. |
| `AppBar` | Yes | Yes | `leading` (Widget), `title` (Widget), `actions` (List\\<Widget\\>), `bottom` (PreferredSize), `flexibleSpace` (Widget) | — | Yes | — | Phase 3 | Top app bar. Auth on bar sections; resources for title. |
| `SliverAppBar` | Yes | Yes | Same as AppBar + `expandedHeight` | `title` (Widget) | Yes | — | Phase 3 | Scrollable app bar. Same auth/resource needs. |
| `BottomAppBar` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Bottom app bar. Auth on bottom bar content. |
| `SliverToBoxAdapter` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Box widget in sliver. Auth on embedded content. |
| `SliverList` | Yes | Yes | `delegate` (SliverChildDelegate) | — | Yes | — | Phase 3 | Sliver-based list. Auth on list content. |
| `SliverGrid` | Yes | Yes | `delegate` (SliverChildDelegate) | — | Yes | — | Phase 3 | Sliver-based grid. Auth on grid content. |
| `SliverFillRemaining` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Remaining sliver space. Auth on content. |
| `CustomScrollView` | Yes | Yes | `slivers` (List\<Widget\>) | — | Yes | — | Phase 3 | Custom scroll container. Auth on scroll regions. |

### Dialog Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `AlertDialog` | Yes | Yes | `content` (Widget), `actions` (List\<Widget\>), `icon` (Widget) | `title` (Widget), `semanticLabel` | Yes | — | Phase 3 | Alert dialog. Auth on dialog display; resources for title/content. |
| `SimpleDialog` | Yes | Yes | `children` (List\<Widget\>) | `title` (Widget) | Yes | — | Phase 3 | Simple choice dialog. Auth on dialog; resources for title. |
| `Dialog` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Base dialog. Auth on dialog display. |
| `BottomSheet` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Bottom sheet. Auth on sheet access. |
| `SnackBar` | Yes | Yes | `content` (Widget), `action` (SnackBarAction) | — | Yes | — | Phase 3 | Snack bar notification. Auth on notification display. |
| `MaterialBanner` | Yes | Yes | `content` (Widget), `leading` (Widget), `actions` (List\<Widget\>) | — | Yes | — | Phase 3 | Material banner. Auth on banner display. |
| `Tooltip` | Yes | Yes | `child` (Widget) | `message` (String), `richMessage` (InlineSpan) | Yes | — | Phase 3 | Hover/long-press tooltip. Auth on tooltip; resource for message. |
| `CupertinoAlertDialog` | Yes | Yes | `content` (Widget), `actions` (List\<Widget\>) | `title` (Widget) | Yes | — | Phase 3 | Cupertino alert. Same auth needs as AlertDialog. |
| `CupertinoActionSheet` | Yes | Yes | `actions` (List\<Widget\>), `cancelButton` (Widget) | `title` (Widget), `message` (Widget) | Yes | — | Phase 3 | Cupertino action sheet. Auth per action; resources for title/message. |

### Table Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `DataTable` | Yes | Yes | `columns` (List\<DataColumn\>), `rows` (List\<DataRow\>) | — | Yes | — | Phase 3 | Data table. Auth on columns/rows; resources for headers. |
| `PaginatedDataTable` | Yes | Yes | `columns` (List\<DataColumn\>), `header` (Widget), `actions` (List\<Widget\>) | — | Yes | — | Phase 3 | Paginated table. Auth on table access; resources for header. |
| `Table` | Yes | Yes | `children` (List\<TableRow\>) | — | Yes | — | Phase 3 | Layout table. Auth on table regions. |
| `GridView` | Yes | Yes | `children` (List\<Widget\>) or `delegate` | — | Yes | — | Phase 3 | Grid layout. Auth on grid items. |
| `ReorderableListView` | Yes | Yes | `children` (List\<Widget\>), `header` (Widget), `footer` (Widget) | — | Yes | — | Phase 3 | Reorderable list. Auth on reorder capability. |

### Label Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `Text` | Yes | Yes | — | `data` (String), `semanticsLabel` | Yes | — | Phase 3 | Primary text display. Auth on visibility; resource for text content. |
| `RichText` | Yes | Yes | `text` (InlineSpan with embedded WidgetSpans possible) | — | Yes | — | Phase 3 | Rich styled text. Auth on visibility; complex text structure. |
| `SelectableText` | Yes | Yes | — | `data` (String), `semanticsLabel` | Yes | — | Phase 3 | Selectable text. Auth on visibility; resource for text. |
| `DefaultTextStyle` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Text style inheritor. Auth on styled content regions. |
| `Badge` | Yes | Yes | `child` (Widget) | `label` (Widget) | Yes | — | Phase 3 | Badge indicator. Auth on badge display; resource for label. |
| `ListTile` | Yes | Yes | `leading` (Widget), `trailing` (Widget) | `title` (Widget), `subtitle` (Widget) | Yes | — | Phase 3 | List item with slots. Auth on list item; resources for title/subtitle. |
| `Chip` | Yes | Yes | `avatar` (Widget), `deleteIcon` (Widget) | `label` (Widget) | Yes | — | Phase 3 | Information chip. Auth on chip; resource for label. |

### Image Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `Image` | Yes | Yes | — | `semanticLabel` | Yes | — | Phase 3 | Image display. Auth on image visibility; resource for semantic label. |
| `CircleAvatar` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Circular avatar. Auth on avatar display. |
| `Icon` | Yes | Yes | — | `semanticLabel` | Yes | — | Phase 3 | Material icon. Auth on icon visibility; resource for semantic label. |
| `ImageIcon` | Yes | Yes | — | `semanticLabel` | Yes | — | Phase 3 | Image-based icon. Same as Icon. |
| `FadeInImage` | Yes | Yes | — | — | Yes | — | Phase 3 | Placeholder-to-image fade. Auth on image display. |

### Navigation Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `TabBar` | Yes | Yes | `tabs` (List\<Widget\>) | — | Yes | — | Phase 3 | Tab strip. Auth per tab. |
| `TabBarView` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Tab content pages. Auth per tab content. |
| `NavigationBar` | Yes | Yes | `destinations` (List\<NavigationDestination\>) | — | Yes | — | Phase 3 | M3 bottom nav. Auth per destination. |
| `NavigationRail` | Yes | Yes | `destinations` (List\<NavigationRailDestination\>), `leading` (Widget), `trailing` (Widget) | — | Yes | — | Phase 3 | Side nav rail. Auth per rail destination. |
| `NavigationDrawer` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Nav drawer. Auth on drawer sections. |
| `Drawer` | Yes | Yes | `child` (Widget) | `semanticLabel` | Yes | — | Phase 3 | App drawer. Auth on drawer access. |
| `BottomNavigationBar` | Yes | Yes | `items` (List\<BottomNavigationBarItem\>) | — | Yes | — | Phase 3 | Bottom nav bar. Auth per nav item. |
| `Stepper` | Yes | Yes | `steps` (List\<Step\>) | — | Yes | — | Phase 3 | Step wizard. Auth per step; resources for step titles. |
| `PageView` | Yes | Yes | `children` (List\<Widget\>) or `delegate` | — | Yes | — | Phase 3 | Swipeable pages. Auth per page. |
| `CupertinoTabBar` | Yes | Yes | `items` (List\<BottomNavigationBarItem\>) | — | Yes | — | Phase 3 | Cupertino tab bar. Auth per tab. |
| `CupertinoNavigationBar` | Yes | Yes | `leading` (Widget), `middle` (Widget), `trailing` (Widget) | — | Yes | — | Phase 3 | Cupertino nav bar. Auth on nav regions; resources for title. |

### Progress Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CircularProgressIndicator` | Yes | Yes | — | `semanticsLabel`, `semanticsValue` | Yes | — | Phase 3 | Circular spinner. Auth on progress display. |
| `LinearProgressIndicator` | Yes | Yes | — | `semanticsLabel`, `semanticsValue` | Yes | — | Phase 3 | Linear bar. Auth on progress display. |
| `RefreshIndicator` | Yes | Yes | `child` (Widget) | `semanticsLabel`, `semanticsValue` | Yes | — | Phase 3 | Pull-to-refresh. Auth on refresh capability. |
| `CupertinoActivityIndicator` | Yes | Yes | — | — | Yes | — | Phase 3 | Cupertino spinner. Auth on activity display. |

### Chip Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `FilterChip` | Yes | Yes | `avatar` (Widget), `deleteIcon` (Widget) | `label` (Widget), `tooltip` | Yes | — | Phase 3 | Filter chip. Auth on filter option; resource for label/tooltip. |
| `ChoiceChip` | Yes | Yes | `avatar` (Widget) | `label` (Widget), `tooltip` | Yes | — | Phase 3 | Choice chip. Auth on choice option; resource for label. |
| `ActionChip` | Yes | Yes | `avatar` (Widget) | `label` (Widget), `tooltip` | Yes | — | Phase 3 | Action chip. Auth on action; resource for label. |
| `InputChip` | Yes | Yes | `avatar` (Widget), `deleteIcon` (Widget) | `label` (Widget), `tooltip` | Yes | — | Phase 3 | Input chip. Auth on input; resource for label. |
| `RawChip` | Yes | Yes | `avatar` (Widget), `deleteIcon` (Widget) | `label` (Widget), `tooltip` | Yes | — | Phase 3 | Base chip. Auth on chip; resource for label. |

### List Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `ListView` | Yes | Yes | `children` (List\<Widget\>) or `delegate` | — | Yes | — | Phase 3 | Scrollable list. Auth on list content. |
| `AnimatedList` | Yes | Yes | `itemBuilder` (Widget Function) | — | Yes | — | Phase 3 | Animated list additions/removals. Auth on list. |
| `Dismissible` | Yes | Yes | `child` (Widget), `background` (Widget), `secondaryBackground` (Widget) | — | Yes | — | Phase 3 | Swipe-to-dismiss. Auth on dismiss capability. |
| `ListWheelScrollView` | Yes | Yes | `children` (List\<Widget\>) or `delegate` | — | Yes | — | Phase 3 | Wheel-style scroll list. Auth on items. |
| `CupertinoListTile` | Yes | Yes | `leading` (Widget), `trailing` (Widget), `additionalInfo` (Widget) | `title` (Widget), `subtitle` (Widget) | Yes | — | Phase 3 | Cupertino list tile. Auth/resources for title/subtitle. |

### Tree Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `TreeView` | Yes (custom) | Yes | Children via `TomTreeNode` | — | Yes | — | Phase 3 | Custom tree view. Auth per tree node. |

---

## II. Extended Widget Set

Remaining Flutter SDK widgets not yet wrapped, sorted by family. Scanned using transitive subclass analysis.

**Wrapping philosophy:** Wrap everything that could reasonably be used directly in app code. Only truly internal framework widgets used indirectly by other already-wrapped components are skipped. Individual actions inside dialogs, action sheets, and context menus need per-action auth (e.g., "Edit" for all users, "Delete" for admin only). Dividers need wrapping to auto-hide when adjacent items are hidden, avoiding ugly double-dividers or leading/trailing orphans.

### Button Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CupertinoButton` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Primary Cupertino button. Cupertino parity with ElevatedButton — same auth needs for visibility and action control. |
| `CheckboxMenuButton` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Menu item with checkbox toggle. Auth controls which menu options are visible; per-item authorization in menus. |
| `RadioMenuButton` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Menu item with radio selection. Same per-item auth reasoning as CheckboxMenuButton. |
| `MenuBar` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Top-level menu bar container. Auth can hide entire menu bar sections; wrapping enables group-level control. |
| `SnackBarAction` | Yes | Yes | — | `label` (String) | Yes | **Hard type:** `SnackBar(action: SnackBarAction?)` — must be `SnackBarAction`, wrapper won't match | Phase 3 | Action button within a SnackBar. Auth controls whether the action is offered; resource for label text. |
| `CupertinoActionSheetAction` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Individual action inside CupertinoActionSheet. Per-action auth: "Share" for all users, "Delete" for admin only. Different actions need different permission levels. |
| `CupertinoDialogAction` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Individual button inside CupertinoAlertDialog. Per-action auth: e.g., "View" always visible, "Approve" only for managers. Each action needs independent auth gating. |
| `CupertinoContextMenuAction` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Individual action inside CupertinoContextMenu. Per-action auth: e.g., "Copy" for all, "Transfer Ownership" for superadmin only. |
| `ExpandIcon` | Yes | Yes | — | — | Yes | — | Phase 3 | Animated expand/collapse chevron. Auth can hide expand capability on restricted sections. |
| `MaterialButton` | No | Yes | `child` (Widget) | — | No | — | — | **Deprecated by Flutter.** Replaced by ElevatedButton/TextButton/OutlinedButton. Not wrapped: nothing in this workspace is published, so there is no codebase to migrate. |
| `ButtonBar` | No | Yes | `children` (List\<Widget\>) | — | No | — | — | **Deprecated by Flutter.** Replaced by OverflowBar, which *is* wrapped. Not wrapped, for the same reason as `MaterialButton`. |

### Input Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CalendarDatePicker` | Yes | Yes | — | — | Yes | — | Phase 3 | Inline calendar date selector. Auth makes it readonly or hidden; important for date-restricted fields. |
| `CupertinoDatePicker` | Yes | Yes | — | — | Yes | — | Phase 3 | Cupertino date wheel picker. Auth for readonly/hidden; Cupertino parity with CalendarDatePicker. |
| `CupertinoSearchTextField` | Yes | Yes | `prefix` (Widget), `suffix` (Widget) | `placeholder` | Yes | — | Phase 3 | Cupertino search input. Auth can restrict search; resource for placeholder text. |
| `CupertinoTimerPicker` | Yes | Yes | — | — | Yes | — | Phase 3 | Duration/timer picker wheel. Auth for readonly/hidden; used in time-constrained input forms. |
| `CupertinoTextFormFieldRow` | Yes | Yes | `prefix` (Widget) | `placeholder`, via `decoration` | Yes | — | Phase 3 | Cupertino form field row. Auth for readonly/hidden in Cupertino forms; resource for placeholder/label. Extends FormField. |
| `DropdownMenuFormField` | Yes | Yes | Same as DropdownMenu | `label`, `hintText`, `helperText`, `errorText` | Yes | — | Phase 3 | DropdownMenu with Form integration. Auth for readonly; resources for all text labels. Extends FormField. |
| `InputDatePickerFormField` | Yes | Yes | — | `fieldLabelText`, `fieldHintText`, `errorFormatText`, `errorInvalidText` | Yes | — | Phase 3 | Text-based date entry with format validation. Auth for readonly/hidden; resource for label/hint/error texts. |
| `Form` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Form container managing validation state. Auth can hide entire form sections; wrapping enables form-level group control. |
| `YearPicker` | Yes | Yes | — | — | Yes | — | Phase 3 | Year selection widget. CAN be used standalone (birth year, fiscal year, academic year selection). Auth for readonly/hidden. |

### Select Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CupertinoPicker` | Yes | Yes | `children` (List\<Widget\>) via delegate | — | Yes | — | Phase 3 | Cupertino scroll wheel picker. Auth controls selection access; Cupertino parity for selection controls. |
| `CupertinoSegmentedControl` | Yes | Yes | `children` (Map\<T, Widget\>) | — | Yes | — | Phase 3 | Classic (pre-sliding) Cupertino segmented control. Auth per segment; Cupertino parity. |
| `PopupMenuItem` | Yes | Yes | `child` (Widget) | — | Yes | **Hard type:** `showMenu(items: List<PopupMenuEntry<T>>)` — wrapper is Widget, not PopupMenuEntry | Phase 3 | Single item in popup menu. Auth controls which menu items appear — critical for permission-based menus. |
| `CheckedPopupMenuItem` | Yes | Yes | `child` (Widget) | — | Yes | **Hard type:** extends `PopupMenuEntry<T>` — same constraint as PopupMenuItem | Phase 3 | Popup menu item with check mark. Same per-item auth reasoning. Extends PopupMenuItem. |
| `PopupMenuDivider` | Yes | Yes | — | — | Yes | **Hard type:** extends `PopupMenuEntry<Never>` — same constraint as PopupMenuItem | Phase 3 | Divider in popup menu. Must be wrapped to auto-hide when adjacent menu items are hidden — avoids ugly double-dividers or leading/trailing orphans. |

### Toggle Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CupertinoCheckbox` | Yes | Yes | — | `semanticLabel` | Yes | — | Phase 3 | Cupertino-styled checkbox. Auth for readonly/hidden; Cupertino parity with Material Checkbox. |
| `CupertinoRadio` | Yes | Yes | — | — | Yes | — | Phase 3 | Cupertino-styled radio button. Auth for readonly/hidden; Cupertino parity with Material Radio, including the `RadioGroup<T>` ancestor that carries its selection. |

### Container Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `SafeArea` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Insets child to avoid system intrusions (notch, status bar). Auth can hide entire safe-area content section. |
| `SingleChildScrollView` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Scrollable container for a single child. Auth on scrollable content region; commonly used for scrollable forms and pages. |
| `CarouselView` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Horizontal carousel/slider. Auth on carousel sections; commonly used for feature highlights. |
| `Visibility` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Logical visibility control. Natural fit for auth — `visible` property aligns directly with authorization show/hide. |
| `Offstage` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Keeps widget in tree but hidden. Natural auth fit — hides content while maintaining state. |
| `CupertinoPageScaffold` | Yes | Yes | `child` (Widget), `navigationBar` (CupertinoNavigationBar) | — | Yes | — | Phase 3 | Cupertino page scaffold. Cupertino parity with Material Scaffold — auth on page regions. |
| `CupertinoTabScaffold` | Yes | Yes | `tabBar` (CupertinoTabBar), `tabBuilder` (Widget Function) | — | Yes | — | Phase 3 | Cupertino tab scaffold. Auth can control tab access; Cupertino parity. |
| `CupertinoFormRow` | Yes | Yes | `child` (Widget), `prefix` (Widget) | `helper` (Widget), `error` (Widget) | Yes | — | Phase 3 | Cupertino form layout row. Auth on form field regions; resource for helper/error text. |
| `CupertinoFormSection` | Yes | Yes | `children` (List\<Widget\>), `header` (Widget), `footer` (Widget) | — | Yes | — | Phase 3 | Cupertino form section. Auth can hide entire form sections; resources for header/footer. |
| `CupertinoExpansionTile` | Yes | Yes | `children` (List\<Widget\>) | `title` (Widget), `subtitle` (Widget) | Yes | — | Phase 3 | Cupertino expansion tile. Cupertino parity with ExpansionTile — auth on expand access; resources for title. |
| `NestedScrollView` | Yes | Yes | `body` (Widget), `headerSliverBuilder` (List\<Widget\> Function) | — | Yes | — | Phase 3 | Scroll coordination between header slivers and body. Auth can control scrollable content regions; commonly used in app pages. |
| `Scrollbar` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Visual scroll position indicator. Auth enables hiding scrollbar together with scrollable content region. |
| `CupertinoScrollbar` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Cupertino-styled scrollbar. Same reasoning — Cupertino parity with Scrollbar. |
| `DraggableScrollableSheet` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Bottom sheet with drag-to-expand. Auth controls sheet access; commonly used for modal bottom sheets in app code. |
| `InteractiveViewer` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Pan/zoom viewport for child content. Auth can restrict zoom/pan access on protected content (images, documents). |
| `Expanded` | Yes | Yes | `child` (Widget) | — | Yes | **Runtime `is`-check:** `Flex` does `child is Flexible` — `Expanded extends Flexible`, wrapper fails this check | Phase 3 | Flex child that expands to fill. Auth can hide expanded section from layout. |
| `Flexible` | Yes | Yes | `child` (Widget) | — | Yes | **Runtime `is`-check:** `Flex` does `child is Flexible` — wrapper fails | Phase 3 | Flex child with flex factor. Auth on flexible content section. |
| `ClipPath` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Clips child to arbitrary path. Auth on clipped content region. |
| `ClipRSuperellipse` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Clips to superellipse (squircle). Auth on clipped content. |
| `ColoredBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Single solid-color background with child. Auth on content; lighter alternative to Container. |
| `Opacity` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Visual opacity 0.0–1.0. Auth on content; can make content invisible while keeping in tree. |
| `Transform` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | 2D/3D matrix transform with child. Auth on transformed content section. |
| `RotatedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Quarter-turn rotation with child. Auth on rotated content. |
| `Positioned` | Yes | Yes | `child` (Widget) | — | Yes | **Runtime `is`-check:** `RenderStack` checks `child is Positioned` for layout — wrapper fails | Phase 3 | Position child inside Stack. Auth can hide positioned elements from stack layout. |
| `PositionedDirectional` | Yes | Yes | `child` (Widget) | — | Yes | **Runtime `is`-check:** extends `Positioned` — same Stack check fails | Phase 3 | RTL-aware position inside Stack. Auth on positioned content. |
| `OverflowBar` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Phase 3 | Wrapping row that overflows to column (ButtonBar replacement). Auth on children group; commonly used for action button rows. |
| `OverflowBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Allows child to exceed parent constraints. Auth on unconstrained content. |
| `SizedOverflowBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Fixed size with unconstrained child. Auth on content. |
| `UnconstrainedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Removes parent constraints from child. Auth on unconstrained content. |
| `ConstraintsTransformBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Transforms incoming constraints. Auth on content. |
| `LimitedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Limits child size when unconstrained. Auth on content. |
| `Baseline` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Aligns child by text baseline. Auth on content. |
| `ListBody` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Yes | Linear layout for dialog body lists. Auth on list content. |
| `Flow` | Yes | Yes | `children` (List\<Widget\>) | — | Yes | — | Yes | Delegate-based custom flow layout. Auth on flow children. |
| `CustomMultiChildLayout` | Yes | Yes | `children` (List\<LayoutId\>) | — | Yes | — | Yes | Delegate-based positioned layout. Auth on positioned children. |
| `CustomSingleChildLayout` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Delegate-based single-child layout. Auth on content. |
| `CustomPaint` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Custom painting with optional child. Auth on painted content region. |
| `PhysicalModel` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Box with shadow/elevation and child. Auth on elevated content. |
| `PhysicalShape` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Custom-shaped shadow/elevation with child. Auth on shaped content. |
| `FractionalTranslation` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Fractional offset translation with child. Auth on translated content. |
| `GridTile` | Yes | Yes | `child` (Widget), `header` (Widget), `footer` (Widget) | — | Yes | — | Yes | Cell container for GridView items with header/footer. Auth on grid tile content; resources for header/footer. |
| `GridTileBar` | Yes | Yes | `leading` (Widget), `trailing` (Widget) | `title` (Widget), `subtitle` (Widget) | Yes | — | Yes | Header/footer bar inside GridTile. Auth on bar content; resources for title/subtitle. |
| `TableCell` | Yes | Yes | `child` (Widget) | — | Yes | **Possible `is`-check:** `Table` may check `child is TableCell` for vertical alignment | Yes | Cell within a Table with child. Auth on cell content. |
| `CupertinoTabView` | Yes | Yes | `builder` (Widget Function) | — | Yes | **Possible `is`-check:** `CupertinoTabScaffold` may check internally | Yes | Tab content view inside CupertinoTabScaffold. Auth on tab content region. |
| `Flex` | No | Yes | `children` (List\<Widget\>) | — | No | — | — | Abstract base class for Row/Column. Never instantiated directly — always use Row or Column (both wrapped). |
| `Expansible` | No | Yes | — | — | No | — | — | Internal expand/collapse animation helper. Framework plumbing — not used directly in app code. |
| `MergeableMaterial` | No | Yes | `children` (List\<MergeableMaterialItem\>) | — | No | — | — | Animated merging Material slices. Internal to ExpansionPanelList (wrapped) — not used directly. |

### Dialog Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `AboutDialog` | Yes | Yes | `children` (List\<Widget\>) | `applicationName`, `applicationVersion`, `applicationLegalese` | Yes | — | Yes | App About dialog. Auth on about access; resources for app name, version, legalese strings. |
| `CupertinoContextMenu` | Yes | Yes | `child` (Widget), `actions` (List\<Widget\>) | — | Yes | — | Yes | Long-press context menu. Auth controls context menu access; individual actions have per-action auth via CupertinoContextMenuAction wrappers. |
| `DatePickerDialog` | Yes | Yes | — | `helpText`, `cancelText`, `confirmText`, `errorFormatText`, `errorInvalidText`, `fieldHintText`, `fieldLabelText` | Yes | — | Yes | Date picker dialog. Auth for readonly/hidden; resource for all seven text strings. |
| `DateRangePickerDialog` | Yes | Yes | — | `helpText`, `cancelText`, `confirmText`, `saveText`, `errorFormatText`, `errorInvalidText`, `fieldStartHintText`, `fieldEndHintText`, `fieldStartLabelText`, `fieldEndLabelText` | Yes | — | Yes | Date range picker dialog. Auth for readonly; resource for ten text strings — high resource value. |
| `TimePickerDialog` | Yes | Yes | — | `helpText`, `cancelText`, `confirmText`, `hourLabelText`, `minuteLabelText`, `errorInvalidText` | Yes | — | Yes | Time picker dialog. Auth for readonly; resource for six text strings. |
| `SimpleDialogOption` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Option item within SimpleDialog. Auth controls which dialog options appear — permission-based option filtering. |
| `DialogWindow` | No | Yes | `child` (Widget) | `title` (Widget) | No | — | — | **@internal** desktop windowing widget. Part of Flutter's experimental multi-window API — not for direct app use. |
| `PopupWindow` | No | Yes | `child` (Widget) | — | No | — | — | **@internal** desktop windowing widget. Part of Flutter's experimental multi-window API — not for direct app use. |
| `LicensePage` | Yes | Yes | — | `applicationName`, `applicationVersion`, `applicationLegalese` | Yes | — | Yes | License listing page. Auth on access; resources for app name/version/legalese strings. |

### Label Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `AboutListTile` | Yes | Yes | `child` (Widget), `icon` (Widget) | `applicationName`, `applicationVersion`, `applicationLegalese` | Yes | — | Yes | List tile that opens About dialog. Auth on about access; resources for app name and version strings. |
| `VerticalDivider` | Yes | Yes | — | — | Yes | — | Yes | Vertical separator line. Auth-based visibility — auto-hide when adjacent items hidden, avoiding orphan dividers. |
| `MenuAcceleratorLabel` | Yes | Yes | — | `label` (String) | Yes | — | Yes | Keyboard accelerator underline display. Auth controls menu label visibility; resource for label text. |
| `Banner` | Yes | Yes | `child` (Widget) | `message` (String) | Yes | — | Yes | Diagonal banner overlay with child. Auth on banner display; resource for message text. Can be used for production banners (e.g., "Beta", "Preview"). |
| `CupertinoListTileChevron` | No | Yes | — | — | No | — | — | Chevron ">" icon for list tiles. Purely decorative indicator inside CupertinoListTile (wrapped) — no content, no text. |
| `FlutterLogo` | No | Yes | — | — | No | — | — | Flutter logo widget. Purely decorative branding — no child, no text, no auth target. |
| `Placeholder` | No | Yes | — | — | No | — | — | Colored rectangle placeholder. Development/debug widget — not used in production UIs. |

### Image Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `AnimatedIcon` | Yes | Yes | — | `semanticLabel` | Yes | — | Yes | Animated material icon transitions (e.g., menu↔close). Auth on icon visibility; resource for semantic label. |
| `ImageFiltered` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Applies ImageFilter (blur, matrix) to child. Auth on filtered content region. |

### Navigation Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CupertinoSliverNavigationBar` | Yes | Yes | `leading` (Widget), `middle` (Widget), `trailing` (Widget) | `largeTitle` (Widget) | Yes | — | Yes | Cupertino large-title scrollable nav bar. Cupertino parity with SliverAppBar; auth on nav regions. |
| `FlexibleSpaceBar` | Yes | Yes | `background` (Widget) | `title` (Widget) | Yes | — | Yes | Flexible space content for SliverAppBar. Auth on flex space content; resource for title text. |
| `NavigationDestination` | Yes | Yes | `icon` (Widget), `selectedIcon` (Widget) | `label` (String), `tooltip` | Yes | **Hard type:** `NavigationBar(destinations: List<NavigationDestination>)` — wrapper type won't match | Yes | Single destination in NavigationBar. Auth per destination; resource for label/tooltip. |
| `NavigationDrawerDestination` | Yes | Yes | `icon` (Widget), `selectedIcon` (Widget) | `label` (Widget) | Yes | **Runtime `is`-check:** `NavigationDrawer` checks `child is NavigationDrawerDestination` internally | Yes | Single destination in NavigationDrawer. Auth per drawer destination; resource for label. |
| `Tab` | Yes | Yes | `child` (Widget), `icon` (Widget) | `text` (String) | Yes | **Runtime `is`-check:** `TabBar._TabBarState` does `tab is Tab` to extract icon/text properties — wrapper fails | Yes | Single tab in TabBar. Auth per individual tab; resource for tab text. |
| `DrawerHeader` | Yes | Yes | `child` (Widget) | — | Yes | — | Yes | Header area of a Drawer. Auth on header content; often shows user info that needs auth gating. |
| `UserAccountsDrawerHeader` | Yes | Yes | `currentAccountPicture` (Widget), `otherAccountsPictures` (List\<Widget\>) | `accountName` (Widget), `accountEmail` (Widget) | Yes | — | Yes | User account header in Drawer. Auth on user info display; resources for account name/email. |
| `CupertinoNavigationBarBackButton` | Yes | Yes | — | `previousPageTitle` | Yes | — | Yes | Back button inside CupertinoNavigationBar. Auth can hide back navigation; resource for previous page title. |
| `TabPageSelector` | Yes | Yes | — | — | Yes | — | Yes | Dot indicator showing current tab page. Auth can hide page indicator when tabs restricted. |
| `TabPageSelectorIndicator` | No | Yes | — | — | No | — | — | Single dot in TabPageSelector. Internal sub-component — never used outside TabPageSelector. |

### Progress Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CupertinoLinearActivityIndicator` | Yes | Yes | — | — | Yes | — | Yes | Cupertino linear progress bar. Cupertino parity with LinearProgressIndicator — auth on progress display. |
| `CupertinoSliverRefreshControl` | Yes | Yes | — | — | Yes | — | Yes | Pull-to-refresh in Cupertino scroll views. Auth can disable refresh capability. |
| `RefreshProgressIndicator` | Yes | Yes | — | `semanticsLabel`, `semanticsValue` | Yes | **Extends constraint:** extends `CircularProgressIndicator` — if parent checks `is CircularProgressIndicator`, wrapper fails | Yes | Circular indicator used by RefreshIndicator. Auth controls refresh progress display. |

### List Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `CupertinoListSection` | Yes | Yes | `children` (List\<Widget\>), `header` (Widget), `footer` (Widget) | — | Yes | — | Phase 3 | Cupertino grouped list section. Auth on section visibility; resources for header/footer. |
| `ReorderableList` | Yes | Yes | `children` via delegate | — | Yes | — | Phase 3 | Reorderable list implementation. Auth on list content and reorder capability. |
| `SliverReorderableList` | Yes | Yes | `children` via delegate | — | Yes | — | Phase 3 | Sliver variant of ReorderableList. Auth on list content and reorder capability. |

### Tree Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `TreeSliver` | Yes | Yes | `tree` (List\<TreeSliverNode\>) | — | Yes | — | Phase 3 | High-performance sliver-based tree with lazy loading. Auth per tree node; modern tree for large datasets. |

### Sliver Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `DecoratedSliver` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Decoration around a sliver with sliver child. Auth on decorated sliver content. |
| `PinnedHeaderSliver` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Pinned header in scroll view. Auth on pinned header content. |
| `SliverConstrainedCrossAxis` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Constrains sliver cross-axis size. Auth on constrained sliver content. |
| `SliverCrossAxisExpanded` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Expands sliver in cross axis. Auth on expanded sliver section. |
| `SliverCrossAxisGroup` | Yes | Yes | `slivers` (List\<Widget\>) | — | Yes | — | Phase 3 | Groups slivers on cross axis. Auth on sliver group. |
| `SliverFillViewport` | Yes | Yes | `delegate` (SliverChildDelegate) | — | Yes | — | Phase 3 | Fills viewport with each child. Auth on viewport children. |
| `SliverFixedExtentList` | Yes | Yes | `delegate` (SliverChildDelegate) | — | Yes | — | Phase 3 | Fixed-height items in sliver. Auth on list content. |
| `SliverFloatingHeader` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Floating header in scroll. Auth on header content. |
| `SliverMainAxisGroup` | Yes | Yes | `slivers` (List\<Widget\>) | — | Yes | — | Phase 3 | Groups slivers sequentially. Auth on sliver group. |
| `SliverOffstage` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Hides sliver (keeps in tree). Auth on offstage sliver — natural visibility control. |
| `SliverOpacity` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Opacity for slivers. Auth on sliver content; can make sliver invisible. |
| `SliverPadding` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Padding around a sliver. Auth on padded sliver content. |
| `SliverPersistentHeader` | Yes | Yes | `delegate` (SliverPersistentHeaderDelegate) | — | Yes | — | Phase 3 | Persistent/pinned header in scroll. Auth on persistent header content. |
| `SliverPrototypeExtentList` | Yes | Yes | `delegate` (SliverChildDelegate), `prototypeItem` (Widget) | — | Yes | — | Phase 3 | List with prototype-based extent. Auth on list content. |
| `SliverResizingHeader` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Resizing header in scroll. Auth on header content. |
| `SliverSafeArea` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Safe area insets for slivers. Auth on safe-area sliver content. |
| `SliverVariedExtentList` | Yes | Yes | `delegate` (SliverChildDelegate) | — | Yes | — | Phase 3 | Variable-height items in sliver. Auth on list content. |
| `SliverVisibility` | Yes | Yes | `sliver` (Widget) | — | Yes | — | Phase 3 | Visibility control for slivers. Natural auth fit — hides sliver content. |

### Animated Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `AnimatedAlign` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates alignment changes. Auth on animated content region. |
| `AnimatedBuilder` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Rebuilds on Listenable changes. Auth on rebuilt content. Extends ListenableBuilder. |
| `AnimatedContainer` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates Container property changes. Auth on animated content region. |
| `AnimatedCrossFade` | Yes | Yes | `firstChild` (Widget), `secondChild` (Widget) | — | Yes | — | Phase 3 | Cross-fades between two children. Auth on both fade children. |
| `AnimatedDefaultTextStyle` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates text style changes. Auth on styled content. |
| `AnimatedFractionallySizedBox` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates fractional sizing. Auth on sized content. |
| `AnimatedOpacity` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates opacity changes. Auth on content being faded. |
| `AnimatedPadding` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates padding changes. Auth on padded content. |
| `AnimatedPhysicalModel` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates elevation/shadow. Auth on elevated content. |
| `AnimatedPositioned` | Yes | Yes | `child` (Widget) | — | Yes | **Runtime `is`-check:** extends `Positioned` — `Stack` checks `child is Positioned`, wrapper fails | Phase 3 | Animates position in Stack. Auth on positioned content. |
| `AnimatedPositionedDirectional` | Yes | Yes | `child` (Widget) | — | Yes | **Runtime `is`-check:** extends `Positioned` — same Stack check fails | Phase 3 | RTL-aware animated position. Auth on positioned content. |
| `AnimatedRotation` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates rotation. Auth on rotated content. |
| `AnimatedScale` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates scale. Auth on scaled content. |
| `AnimatedSize` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates size changes. Auth on resizing content. |
| `AnimatedSlide` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates position offset. Auth on sliding content. |
| `AnimatedSwitcher` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Animates child swap with transition. Auth on switched content. |
| `Hero` | Yes | Yes | `child` (Widget) | `tag` (Object) | Yes | — | Phase 3 | Shared element transition between routes. Auth on hero content across routes. |
| `RotationTransition` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Rotation animation driven by Animation. Auth on rotated content. |
| `ScaleTransition` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Scale animation driven by Animation. Auth on scaled content. |

### Effect Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `BackdropFilter` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Applies blur/filter to everything behind the child. Auth on filtered content region. |
| `ColorFiltered` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Applies color matrix filter. Auth on color-filtered content. |
| `ShaderMask` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Applies shader as mask on child. Auth on masked content. |
| `SelectableRegion` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Defines selectable text/widget region. Auth can restrict text selection on sensitive content. |
| `SelectionArea` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Convenience wrapper for SelectableRegion. Auth on selectable content. |
| `SensitiveContent` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Flags content as sensitive to OS. Auth on sensitive content; natural fit for auth-controlled sensitivity. |
| `BackdropGroup` | No | Yes | `child` (Widget) | — | No | — | — | Groups BackdropFilters for performance. Internal optimization — always paired with BackdropFilter (wrapped). |

### Interaction Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `GestureDetector` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Detects taps, drags, long-press, etc. Auth can disable interactions on protected content. |
| `InkWell` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Material tap target with ink splash. Auth can control tap access. Extends InkResponse. |
| `InkResponse` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Low-level ink splash response area. Auth on interactive content; base for InkWell. |
| `Draggable` | Yes | Yes | `child` (Widget), `feedback` (Widget), `childWhenDragging` (Widget) | — | Yes | — | Phase 3 | Drag source for drag-and-drop. Auth controls who can initiate drags. |
| `DragTarget` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Drop target for drag-and-drop. Auth controls who can receive drops. |
| `LongPressDraggable` | Yes | Yes | `child` (Widget), `feedback` (Widget), `childWhenDragging` (Widget) | — | Yes | — | Phase 3 | Long-press-triggered drag. Auth controls long-press drag initiation. |
| `AbsorbPointer` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Absorbs (blocks) pointer events. Auth can add/remove pointer blocking based on permissions. |
| `IgnorePointer` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Ignores pointer events (pass-through). Auth on pointer passthrough control. |
| `MouseRegion` | Yes | Yes | `child` (Widget) | — | Yes | — | Phase 3 | Mouse hover/exit/cursor tracking. Auth on hover-tracked content region. |
| `TableRowInkWell` | No | Yes | `child` (Widget) | — | No | — | — | InkWell variant for DataTable rows. Internal to DataTable (wrapped) — row interaction handled by the table. |
| `ReorderableDragStartListener` | No | Yes | `child` (Widget) | — | No | — | — | Drag handle for ReorderableListView. Internal to ReorderableListView (wrapped) — the list handles reorder auth. |
| `ReorderableDelayedDragStartListener` | No | Yes | `child` (Widget) | — | No | — | — | Delayed drag handle variant. Internal to ReorderableListView. Extends ReorderableDragStartListener. |

### Builder Family

| Class Name | Wrapped | Is Widget | Has Child(ren) | Has Text(s) | Should Wrap | Wrapping Problems | Resource Migrated | Description & Verdict |
|-----------|---------|-----------|----------------|-------------|-------------|-------------------|-------------------|----------------------|
| `StatefulBuilder` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Inline stateful widget via builder. Auth on builder content region — can wrap entire stateful sections. |
| `StreamBuilder` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Rebuilds on Stream events. Auth on stream-driven content. Extends StreamBuilderBase. |
| `FutureBuilder` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Rebuilds when Future completes. Auth on async-loaded content region. |
| `ValueListenableBuilder` | Yes | Yes | `builder` (Widget Function), `child` (Widget) | — | Yes | — | Phase 3 | Rebuilds on ValueListenable changes. Auth on reactive content. |
| `ListenableBuilder` | Yes | Yes | `builder` (Widget Function), `child` (Widget) | — | Yes | — | Phase 3 | Rebuilds on Listenable changes. Auth on reactive content. |
| `TweenAnimationBuilder` | Yes | Yes | `builder` (Widget Function), `child` (Widget) | — | Yes | — | Phase 3 | Animates a tween and rebuilds. Auth on animated content. |
| `OrientationBuilder` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Rebuilds on orientation changes. Auth on orientation-responsive content. |
| `LayoutBuilder` | Yes | Yes | `builder` (Widget Function) | — | Yes | — | Phase 3 | Rebuilds with parent constraints. Auth on constraint-responsive content. |

---

## Summary

### Wrapped vs. Candidate Counts

| Section | Already Wrapped | Recommended to Wrap | Migrate | Skip |
|---------|:-:|:-:|:-:|:-:|
| **I. Core** | 131 | — | — | — |
| **II. Extended — Button** | 9 | — | — | 2 |
| **II. Extended — Input** | 9 | — | — | 0 |
| **II. Extended — Select** | 5 | — | — | 0 |
| **II. Extended — Toggle** | 2 | — | — | 0 |
| **II. Extended — Container** | 45 | — | — | 3 |
| **II. Extended — Dialog** | 7 | — | — | 2 |
| **II. Extended — Label** | 4 | — | — | 3 |
| **II. Extended — Image** | 2 | — | — | 0 |
| **II. Extended — Navigation** | 9 | — | — | 1 |
| **II. Extended — Progress** | 3 | — | — | 0 |
| **II. Extended — List** | 3 | — | — | 0 |
| **II. Extended — Tree** | 1 | — | — | 0 |
| **II. Extended — Sliver** | 18 | — | — | 0 |
| **II. Extended — Animated** | 19 | — | — | 0 |
| **II. Extended — Effect** | 6 | — | — | 1 |
| **II. Extended — Interaction** | 9 | — | — | 3 |
| **II. Extended — Builder** | 8 | — | — | 0 |
| **Totals** | **290** | **0** | **0** | **15** |

### Widgets with Wrapping Problems

These widgets need special wrapper patterns (extension types, delegation, or wrapper-aware parents) because standard composition wrappers break Flutter's type expectations:

| Widget | Problem Type | Detail | Implemented | Implementation |
|--------|-------------|--------|-------------|----------------|
| `DropdownMenuEntry` (Core) | Hard type constraint | `DropdownMenu(dropdownMenuEntries: List<DropdownMenuEntry<T>>)` | Yes | Composition — `toEntry()` method converts to `DropdownMenuEntry<T>` |
| `Spacer` (Core) | Runtime is-check | `Flex` checks `child is Flexible`; Spacer extends Flexible | Yes | Extension — `extends Spacer with TomWidgetMixin` |
| `SnackBarAction` | Hard type constraint | `SnackBar(action: SnackBarAction?)` | Yes | Extension — `extends SnackBarAction with TomWidgetMixin` |
| `PopupMenuItem` | Hard type constraint | `showMenu(items: List<PopupMenuEntry<T>>)` | Yes | Extension — `extends PopupMenuItem<T> with TomWidgetMixin` |
| `CheckedPopupMenuItem` | Hard type constraint | Extends `PopupMenuEntry<T>` | Yes | Extension — `extends CheckedPopupMenuItem<T> with TomWidgetMixin` |
| `PopupMenuDivider` | Hard type constraint | Extends `PopupMenuEntry<Never>` | Yes | Extension — `extends PopupMenuDivider with TomWidgetMixin` |
| `Expanded` | Runtime is-check | `Flex` checks `child is Flexible` | Yes | Extension — `extends Expanded with TomWidgetMixin` |
| `Flexible` | Runtime is-check | `Flex` checks `child is Flexible` | Yes | Extension — `extends Flexible with TomWidgetMixin` |
| `Positioned` | Runtime is-check | `RenderStack` checks `child is Positioned` | Yes | Extension — `extends Positioned with TomWidgetMixin` |
| `PositionedDirectional` | Runtime is-check | Extends `Positioned` | Yes | Extension — `extends PositionedDirectional with TomWidgetMixin` |
| `TableCell` | Possible is-check | `Table` may check `child is TableCell` | Yes | Extension — `extends TableCell with TomWidgetMixin` |
| `CupertinoTabView` | Possible is-check | `CupertinoTabScaffold` may check internally | Yes | Extension — `extends CupertinoTabView with TomWidgetMixin` |
| `NavigationDestination` | Hard type constraint | `NavigationBar(destinations: List<NavigationDestination>)` | Yes | Extension — `extends NavigationDestination with TomWidgetMixin` |
| `NavigationDrawerDestination` | Runtime is-check | `NavigationDrawer` checks `is NavigationDrawerDestination` | Yes | Extension — `extends NavigationDrawerDestination with TomWidgetMixin` |
| `Tab` | Runtime is-check | `TabBar` checks `tab is Tab` to extract icon/text | Yes | Extension — `extends Tab with TomWidgetMixin` |
| `RefreshProgressIndicator` | Extends constraint | Extends `CircularProgressIndicator` | Yes | Extension — `extends RefreshProgressIndicator with TomWidgetMixin` |
| `AnimatedPositioned` | Runtime is-check | Extends `Positioned`; Stack checks apply | Yes | Extension — `extends AnimatedPositioned with TomWidgetMixin` |
| `AnimatedPositionedDirectional` | Runtime is-check | Extends `Positioned`; Stack checks apply | Yes | Extension — `extends AnimatedPositionedDirectional with TomWidgetMixin` |

### Wrap Decision Principles

1. **Wrap everything used directly** — If a developer could reasonably use the widget in app code, wrap it. Only truly internal framework widgets skip.
2. **Per-action auth in dialogs/sheets/menus** — Individual actions in action sheets, dialogs, and context menus each need independent auth control (e.g., "Edit" for all users, "Delete" for admin only).
3. **Dividers need auto-hide** — Wrapping dividers (horizontal, vertical, popup menu) enables auto-hiding when adjacent items disappear, avoiding ugly orphan dividers.
4. **Deprecated → skip** — A wrapper for a Flutter-deprecated widget only earns its place if somebody is migrating off it. Nothing in this workspace is published, so nobody is: `MaterialButton` and `ButtonBar` are not wrapped, and their replacements (`ElevatedButton`, `OverflowBar`) are.
5. **Cupertino parity** — Cupertino equivalents of wrapped Material widgets must be wrapped for consistent cross-platform authorization.
6. **Resource value** — Widgets with text properties benefit from resource lookup (DatePickerDialog has 7, DateRangePickerDialog has 10 text strings).
7. **Type constraints require special patterns** — 18 widgets have wrapping problems due to hard type constraints or runtime `is`-checks. These need extension types, delegation, or wrapper-aware parent implementations.

---

## Custom Tom Widgets (Non-Form)

Custom widgets that don't wrap Flutter SDK classes. Form-related custom widgets (e.g., `FormRadioGroup`, `FormTextField`) are tracked separately in form field documentation.

Unlike the survey above, **this table is not a plan**: every row states what is
in `lib/` today and names the document that owns the detail. It is deliberately
thin, because a fuller description here would be a second, unchecked copy of
[custom.md](custom.md) and [widgets.md](widgets.md).

Nine of the eleven widgets proposed in the original version of this table now
ship. The two that do not are kept as rows rather than deleted, because each was
**subsumed** by something that does ship — and a proposal that is quietly
removed is a proposal that gets made again.

| Widget | Ships | Documented in | What it is |
|--------|-------|---------------|------------|
| `TomRadioGroup` / `TomRadioGroupItem` | Yes — `lib/src/custom/tom_radio_group.dart` | [custom.md](custom.md) | Radio selection whose **whole** group is gated by one resource key. It renders `Radio<T>` + `InkWell` rows beneath a `RadioGroup<T>` ancestor; it does not group `TomRadio` widgets, and never did. |
| `TomTreeView` / `TomTreeNode` | Yes — `lib/src/widgets/trees/tom_trees.dart` | [widgets.md](widgets.md) | Hierarchical tree with expand/collapse state, authorized at the widget level. `TomTreeNode` is its plain data model. This is the pair the Tree Family row in section I already records as `Yes (custom)`. |
| `TomAuthTreeView` / `TomAuthTreeNode` | Yes — `lib/src/custom/tom_auth_tree.dart` | [custom.md](custom.md) | The **per-node**-auth tree: each node resolves its own `TomAuthState`, and a `disabled` node caps its entire subtree. Reach for it when the grant varies *within* the tree, and for `TomTreeView` when it does not. |
| `TomAuthGuard` | Yes — `lib/src/custom/tom_auth_guard.dart` | [custom.md](custom.md) | Hides or disables a `child` by the auth state resolved from a `tomId`. |
| `TomLoadingOverlay` | Yes — `lib/src/custom/tom_loading_overlay.dart` | [custom.md](custom.md) | Translucent scrim and spinner, with an optional message, layered over a subtree. |
| `TomErrorBoundary` | Yes — `lib/src/custom/tom_error_boundary.dart` | [custom.md](custom.md) | Catches build errors raised inside a subtree and renders a fallback instead of propagating. |
| `TomEmptyState` | Yes — `lib/src/custom/tom_empty_state.dart` | [custom.md](custom.md) | Icon, title, description and optional action for "no data" surfaces. Resolves its strings through the resource provider when given a `tomId`. |
| `TomSkeletonLoader` | Yes — `lib/src/custom/tom_skeleton_loader.dart` | [custom.md](custom.md) | Shimmer placeholder for a loading surface; static when `enabled: false`. |
| `TomInfiniteScroll` | Yes — `lib/src/custom/tom_infinite_scroll.dart` | [custom.md](custom.md) | Paginated list over a `PageFetcher`, reusing the three placeholders above for its empty / loading / error states. |
| `TomResourceText` | **No — subsumed by `TomText`** | [widgets.md](widgets.md) | Proposed as "text with built-in resource lookup by key", which is what `TomText` already is: `TomText(tomId: 'app.greeting')` resolves its content, style, `maxLines` and semantics from resources. Resource lookup is a property every `Tom*` widget gets from its `tomId`, not the distinguishing feature of one text class, so a second one would only duplicate `TomText`. |
| `TomPermissionBadge` | **No — application content** | [widgets.md](widgets.md) | Proposed as a "badge indicating permission level or role". The badge itself ships as `TomBadge` (Label Family, section I). What remains is deciding which role maps to which colour and wording — and the framework has no permission vocabulary to render, because roles are named by the application. |

---

## Related Documents

- [tom_ui_design_architecture.md](tom_ui_design_architecture.md) — Full UI architecture (wrapping patterns, families, scope system)
- [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) — Form widgets specification (custom, not wrapped)
- [actions.md](actions.md) — Action system and button authorization
