# Widget Optional Parameters: Resource Discovery Proposal

This document proposes extensions to the Tom Flutter UI resource system to support:

1. **Optional parameter discovery** — Try to obtain all optional parameters from resources
2. **List-based resources** — Obtain lists (countries, locales, options) from resources
3. **Auto-assembling components** — Generate menu items/dropdown options automatically from resource lists

## Current State

### Existing Resource Resolution

The current resource system provides:

```dart
// TomNodeBase methods
String resolveResource(context, suffix)           // Returns key as fallback
String? resolveResourceOrNull(context, suffix)    // Returns null if missing
String resolveResourceOrFail(context, suffix)     // Throws if no tomId
IconData? resolveIcon(context)                    // Icon lookup via TomUIIcons
```

### Current Adapter Interface

```dart
abstract class TomUIResourceAdapter {
  String resolveText(String basePath, String suffix);
  bool resourceExists(String basePath, String suffix);
}
```

## Proposed Extensions

### 1. Extended Resource Adapter API

```dart
abstract class TomUIResourceAdapter {
  // Existing
  String resolveText(String basePath, String suffix);
  bool resourceExists(String basePath, String suffix);
  
  // NEW: Type-aware resolution
  T? resolveValue<T>(String basePath, String suffix);
  
  // NEW: List resolution for arrays
  List<T>? resolveList<T>(String basePath, String suffix);
  
  // NEW: Map resolution for nested structures
  Map<String, dynamic>? resolveMap(String basePath, String suffix);
  
  // NEW: Typed resolution helpers
  Color? resolveColor(String basePath, String suffix);
  IconData? resolveIcon(String basePath, String suffix);
  double? resolveDouble(String basePath, String suffix);
  int? resolveInt(String basePath, String suffix);
  bool? resolveBool(String basePath, String suffix);
  EdgeInsets? resolveEdgeInsets(String basePath, String suffix);
  BorderRadius? resolveBorderRadius(String basePath, String suffix);
}
```

### 2. TomNodeBase Extensions

Add new resolution methods to `TomNodeBase`:

```dart
abstract class TomNodeBase extends StatelessWidget {
  // NEW: Try to resolve optional color
  Color? resolveColorOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveColor(basePath, suffix);
  }
  
  // NEW: Try to resolve optional double
  double? resolveDoubleOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveDouble(basePath, suffix);
  }
  
  // NEW: Resolve list of items
  List<T>? resolveListOrNull<T>(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveList<T>(basePath, suffix);
  }
  
  // NEW: Resolve map structure
  Map<String, dynamic>? resolveMapOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveMap(basePath, suffix);
  }
}
```

### 3. TomUIResources Singleton Extensions

```dart
class TomUIResources {
  // NEW: Typed resolution
  static Color? resolveColor(String basePath, String suffix) {
    return _adapter?.resolveColor(basePath, suffix);
  }
  
  static IconData? resolveIcon(String basePath, String suffix) {
    return _adapter?.resolveIcon(basePath, suffix);
  }
  
  static double? resolveDouble(String basePath, String suffix) {
    return _adapter?.resolveDouble(basePath, suffix);
  }
  
  static int? resolveInt(String basePath, String suffix) {
    return _adapter?.resolveInt(basePath, suffix);
  }
  
  static bool? resolveBool(String basePath, String suffix) {
    return _adapter?.resolveBool(basePath, suffix);
  }
  
  static List<T>? resolveList<T>(String basePath, String suffix) {
    return _adapter?.resolveList<T>(basePath, suffix);
  }
  
  static Map<String, dynamic>? resolveMap(String basePath, String suffix) {
    return _adapter?.resolveMap(basePath, suffix);
  }
}
```

---

## Parameter Classification

### Classification Categories

| Category | Description | Resource-Backed | Notes |
|----------|-------------|-----------------|-------|
| **Text** | Labels, hints, tooltips | ✅ Already supported | `label`, `hint`, `tooltip` suffixes |
| **Icon** | IconData values | ✅ Already supported | Via `TomUIIcons` lookup |
| **Color** | Color values | 🆕 Proposed | Via `TomUIColors` lookup |
| **Numeric** | double, int values | 🆕 Proposed | Elevation, padding, sizes |
| **Boolean** | true/false flags | 🆕 Proposed | Dense, autofocus, enabled |
| **Widget** | Arbitrary widgets | ❌ Code only | Cannot serialize widgets |
| **Callback** | Functions | ❌ Code only | Cannot serialize functions |
| **Complex** | ButtonStyle, TextStyle | 🔶 Partial | Map-based decomposition |
| **List** | Item collections | 🆕 Proposed | Countries, options, items |

### Widget Parameter Analysis by Family

#### Button Family (`TomButtonBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomElevatedButton | label | String | `label` | ✅ Existing |
| TomElevatedButton | icon | Widget/IconData | `icon` | ✅ Existing |
| TomFilledButton | foregroundColor | Color | `foregroundColor` | 🆕 Proposed |
| TomFilledButton | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomTextButton | style.textStyle | TextStyle | `textStyle` | 🔶 Via map |
| TomOutlinedButton | tonal | bool | `tonal` | 🆕 Proposed |
| TomIconButton | tooltip | String | `tooltip` | ✅ Existing |
| TomIconButton | iconSize | double | `iconSize` | 🆕 Proposed |
| TomIconButton | color | Color | `color` | 🆕 Proposed |

#### Select Family (`TomSelectBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomDropdownButton | hint | String | `hint` | ✅ Existing |
| TomDropdownButton | items | List<T> | `items` | 🆕 Auto-generate |
| TomDropdownButton | icon | Widget | `icon` | 🆕 Proposed |
| TomDropdownButton | dropdownColor | Color | `dropdownColor` | 🆕 Proposed |
| TomDropdownButton | iconEnabledColor | Color | `iconEnabledColor` | 🆕 Proposed |
| TomDropdownButton | iconDisabledColor | Color | `iconDisabledColor` | 🆕 Proposed |
| TomDropdownButton | elevation | int | `elevation` | 🆕 Proposed |
| TomDropdownButton | isDense | bool | `isDense` | 🆕 Proposed |
| TomDropdownMenu | label | String | `label` | ✅ Existing |
| TomDropdownMenu | helperText | String | `helperText` | 🆕 Proposed |
| TomDropdownMenu | entries | List | `entries` | 🆕 Auto-generate |
| TomPopupMenuButton | tooltip | String | `tooltip` | ✅ Existing |
| TomPopupMenuButton | items | List | `items` | 🆕 Auto-generate |
| TomPopupMenuButton | color | Color | `color` | 🆕 Proposed |
| TomPopupMenuButton | elevation | double | `elevation` | 🆕 Proposed |
| TomPopupMenuButton | iconSize | double | `iconSize` | 🆕 Proposed |

#### Toggle Family (`TomToggleBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomSwitch | activeColor | Color | `activeColor` | 🆕 Proposed |
| TomSwitch | activeTrackColor | Color | `activeTrackColor` | 🆕 Proposed |
| TomSwitch | inactiveThumbColor | Color | `inactiveThumbColor` | 🆕 Proposed |
| TomSwitch | inactiveTrackColor | Color | `inactiveTrackColor` | 🆕 Proposed |
| TomSwitch | splashRadius | double | `splashRadius` | 🆕 Proposed |
| TomCheckbox | activeColor | Color | `activeColor` | 🆕 Proposed |
| TomCheckbox | checkColor | Color | `checkColor` | 🆕 Proposed |
| TomCheckbox | focusColor | Color | `focusColor` | 🆕 Proposed |
| TomCheckbox | hoverColor | Color | `hoverColor` | 🆕 Proposed |
| TomCheckbox | splashRadius | double | `splashRadius` | 🆕 Proposed |
| TomRadio | activeColor | Color | `activeColor` | 🆕 Proposed |
| TomRadio | focusColor | Color | `focusColor` | 🆕 Proposed |
| TomRadio | hoverColor | Color | `hoverColor` | 🆕 Proposed |
| TomRadio | splashRadius | double | `splashRadius` | 🆕 Proposed |

#### Slider Family (`TomSliderBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomSlider | activeColor | Color | `activeColor` | 🆕 Proposed |
| TomSlider | inactiveColor | Color | `inactiveColor` | 🆕 Proposed |
| TomSlider | thumbColor | Color | `thumbColor` | 🆕 Proposed |
| TomSlider | overlayColor | Color | `overlayColor` | 🆕 Proposed |
| TomSlider | secondaryActiveColor | Color | `secondaryActiveColor` | 🆕 Proposed |
| TomSlider | min | double | `min` | 🆕 Proposed |
| TomSlider | max | double | `max` | 🆕 Proposed |
| TomSlider | divisions | int | `divisions` | 🆕 Proposed |
| TomSlider | label | String | `label` | ✅ Existing |
| TomRangeSlider | activeColor | Color | `activeColor` | 🆕 Proposed |
| TomRangeSlider | inactiveColor | Color | `inactiveColor` | 🆕 Proposed |

#### Container Family (`TomContainerBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomCard | color | Color | `color` | 🆕 Proposed |
| TomCard | shadowColor | Color | `shadowColor` | 🆕 Proposed |
| TomCard | surfaceTintColor | Color | `surfaceTintColor` | 🆕 Proposed |
| TomCard | elevation | double | `elevation` | 🆕 Proposed |
| TomCard | margin | EdgeInsets | `margin` | 🔶 Via map |
| TomExpansionTile | title | String | `label` | ✅ Existing |
| TomExpansionTile | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomExpansionTile | collapsedBackgroundColor | Color | `collapsedBackgroundColor` | 🆕 Proposed |
| TomExpansionTile | textColor | Color | `textColor` | 🆕 Proposed |
| TomExpansionTile | collapsedTextColor | Color | `collapsedTextColor` | 🆕 Proposed |
| TomExpansionTile | iconColor | Color | `iconColor` | 🆕 Proposed |
| TomExpansionTile | collapsedIconColor | Color | `collapsedIconColor` | 🆕 Proposed |
| TomExpansionTile | dense | bool | `dense` | 🆕 Proposed |

#### Label Family (`TomLabelBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomText | data/text | String | `label` | ✅ Existing |
| TomText | style | TextStyle | `textStyle` | 🔶 Via map |
| TomText | maxLines | int | `maxLines` | 🆕 Proposed |
| TomText | overflow | TextOverflow | `overflow` | 🔶 Enum mapping |
| TomText | textAlign | TextAlign | `textAlign` | 🔶 Enum mapping |
| TomSelectableText | data/text | String | `label` | ✅ Existing |
| TomSelectableText | style | TextStyle | `textStyle` | 🔶 Via map |

#### Navigation Family (`TomNavigationBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomNavigationRail | destinations | List | `destinations` | 🆕 Auto-generate |
| TomNavigationRail | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomNavigationRail | indicatorColor | Color | `indicatorColor` | 🆕 Proposed |
| TomNavigationRail | elevation | double | `elevation` | 🆕 Proposed |
| TomNavigationBar | destinations | List | `destinations` | 🆕 Auto-generate |
| TomNavigationBar | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomNavigationBar | indicatorColor | Color | `indicatorColor` | 🆕 Proposed |
| TomNavigationBar | elevation | double | `elevation` | 🆕 Proposed |
| TomNavigationBar | shadowColor | Color | `shadowColor` | 🆕 Proposed |
| TomNavigationBar | surfaceTintColor | Color | `surfaceTintColor` | 🆕 Proposed |
| TomNavigationBar | height | double | `height` | 🆕 Proposed |
| TomTabBar | tabs | List | `tabs` | 🆕 Auto-generate |
| TomTabBar | labelColor | Color | `labelColor` | 🆕 Proposed |
| TomTabBar | unselectedLabelColor | Color | `unselectedLabelColor` | 🆕 Proposed |
| TomTabBar | indicatorColor | Color | `indicatorColor` | 🆕 Proposed |

#### Dialog Family (`TomDialogBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomDialog | title | String | `title` | ✅ Existing |
| TomDialog | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomDialog | surfaceTintColor | Color | `surfaceTintColor` | 🆕 Proposed |
| TomDialog | elevation | double | `elevation` | 🆕 Proposed |
| TomAlertDialog | title | String | `title` | ✅ Existing |
| TomAlertDialog | content | String | `content` | ✅ Existing |
| TomAlertDialog | confirmLabel | String | `confirmLabel` | ✅ Existing |
| TomAlertDialog | cancelLabel | String | `cancelLabel` | ✅ Existing |
| TomBottomSheet | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomBottomSheet | elevation | double | `elevation` | 🆕 Proposed |

#### Progress Family (`TomProgressBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomProgressIndicator | color | Color | `color` | 🆕 Proposed |
| TomProgressIndicator | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomCircularProgressIndicator | color | Color | `color` | 🆕 Proposed |
| TomCircularProgressIndicator | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomCircularProgressIndicator | strokeWidth | double | `strokeWidth` | 🆕 Proposed |
| TomLinearProgressIndicator | color | Color | `color` | 🆕 Proposed |
| TomLinearProgressIndicator | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomLinearProgressIndicator | minHeight | double | `minHeight` | 🆕 Proposed |

#### Input Family (`TomInputBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomTextField | label | String | `label` | ✅ Existing |
| TomTextField | hint | String | `hint` | ✅ Existing |
| TomTextField | helperText | String | `helperText` | 🆕 Proposed |
| TomTextField | errorText | String | `errorText` | 🆕 Proposed |
| TomTextField | prefixText | String | `prefixText` | 🆕 Proposed |
| TomTextField | suffixText | String | `suffixText` | 🆕 Proposed |
| TomTextField | cursorColor | Color | `cursorColor` | 🆕 Proposed |
| TomTextField | fillColor | Color | `fillColor` | 🆕 Proposed |
| TomTextField | prefixIcon | IconData | `prefixIcon` | 🆕 Proposed |
| TomTextField | suffixIcon | IconData | `suffixIcon` | 🆕 Proposed |
| TomTextField | cursorWidth | double | `cursorWidth` | 🆕 Proposed |
| TomTextField | cursorHeight | double | `cursorHeight` | 🆕 Proposed |
| TomTextField | maxLines | int | `maxLines` | 🆕 Proposed |
| TomTextField | maxLength | int | `maxLength` | 🆕 Proposed |
| TomTextField | obscureText | bool | `obscureText` | 🆕 Proposed |
| TomTextField | enabled | bool | `enabled` | 🆕 Proposed |
| TomTextField | readOnly | bool | `readOnly` | 🆕 Proposed |

#### Chip Family (`TomChipBase`)

| Widget | Parameter | Type | Resource Suffix | Notes |
|--------|-----------|------|-----------------|-------|
| TomChip | label | String | `label` | ✅ Existing |
| TomChip | avatar | Widget/Icon | `avatar` | 🆕 Proposed |
| TomChip | deleteIcon | Widget/Icon | `deleteIcon` | 🆕 Proposed |
| TomChip | backgroundColor | Color | `backgroundColor` | 🆕 Proposed |
| TomChip | labelStyle | TextStyle | `labelStyle` | 🔶 Via map |
| TomActionChip | label | String | `label` | ✅ Existing |
| TomChoiceChip | label | String | `label` | ✅ Existing |
| TomFilterChip | label | String | `label` | ✅ Existing |
| TomInputChip | label | String | `label` | ✅ Existing |

---

## Resource JSON Structures

### Simple Value Resources

```json
{
  "w-myButton.label": "Click Me",
  "w-myButton.icon": "mAdd",
  "w-myButton.tooltip": "Performs the action",
  "w-myButton.backgroundColor": "mBlue500",
  "w-myButton.foregroundColor": "#FFFFFF",
  "w-myButton.elevation": 4,
  "w-myButton.isDense": true
}
```

### Complex Structure Resources (TextStyle)

```json
{
  "w-myText.textStyle": {
    "fontSize": 16,
    "fontWeight": "bold",
    "color": "mGrey900",
    "letterSpacing": 0.5
  }
}
```

### EdgeInsets Resources

```json
{
  "w-myCard.margin": {
    "top": 8,
    "bottom": 8,
    "left": 16,
    "right": 16
  },
  "w-myCard.padding": [16, 8, 16, 8]
}
```

### List-Based Resources (Countries)

```json
{
  "data.countries": [
    { "value": "us", "label": "🇺🇸 United States", "icon": "mFlag" },
    { "value": "uk", "label": "🇬🇧 United Kingdom", "icon": "mFlag" },
    { "value": "de", "label": "🇩🇪 Germany", "icon": "mFlag" },
    { "value": "fr", "label": "🇫🇷 France", "icon": "mFlag" },
    { "value": "jp", "label": "🇯🇵 Japan", "icon": "mFlag" }
  ]
}
```

### Navigation Destinations Resources

```json
{
  "nav.main.destinations": [
    { "icon": "mHome", "selectedIcon": "mHomeFilled", "label": "Home" },
    { "icon": "mSearch", "selectedIcon": "mSearchFilled", "label": "Search" },
    { "icon": "mPerson", "selectedIcon": "mPersonFilled", "label": "Profile" },
    { "icon": "mSettings", "selectedIcon": "mSettingsFilled", "label": "Settings" }
  ]
}
```

### Dropdown/Menu Items Resources

```json
{
  "w-categoryDropdown.items": [
    { "value": "electronics", "label": "Electronics", "icon": "mDevices" },
    { "value": "clothing", "label": "Clothing", "icon": "mCheckroom" },
    { "value": "books", "label": "Books", "icon": "mMenuBook" },
    { "value": "sports", "label": "Sports", "icon": "mSportsBaseball" }
  ]
}
```

### Popup Menu Items Resources

```json
{
  "w-actionsMenu.items": [
    { "value": "edit", "label": "Edit", "icon": "mEdit" },
    { "value": "duplicate", "label": "Duplicate", "icon": "mContentCopy" },
    { "divider": true },
    { "value": "delete", "label": "Delete", "icon": "mDelete", "destructive": true }
  ]
}
```

---

## Auto-Assembling Components

### TomResourceDropdown

A new widget that auto-generates items from resources:

```dart
/// Auto-assembles dropdown items from a resource list.
class TomResourceDropdown<T> extends TomSelectBase {
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? itemsKey;  // Resource key for items list
  
  const TomResourceDropdown({
    super.key,
    super.tomId,
    super.tomGroup,
    this.value,
    this.onChanged,
    this.itemsKey,
  });
  
  @override
  Widget buildContent(BuildContext context) {
    // Resolve items from resource list
    final itemsList = _resolveItemsList(context);
    
    return TomDropdownButton<T>(
      tomId: tomId,
      value: value,
      items: itemsList.map((item) => _buildItem(item)).toList(),
      onChanged: onChanged,
    );
  }
  
  List<Map<String, dynamic>> _resolveItemsList(BuildContext context) {
    // Try explicit itemsKey first
    if (itemsKey != null) {
      return TomUIResources.resolveList<Map<String, dynamic>>(itemsKey!, 'items') ?? [];
    }
    
    // Fall back to widget's own tomId
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return [];
    return TomUIResources.resolveList<Map<String, dynamic>>(basePath, 'items') ?? [];
  }
  
  DropdownMenuItem<T> _buildItem(Map<String, dynamic> item) {
    final value = item['value'] as T;
    final label = item['label'] as String? ?? value.toString();
    final iconName = item['icon'] as String?;
    
    Widget child;
    if (iconName != null) {
      final iconData = TomUIIcons.resolveIcon(iconName);
      child = Row(
        children: [
          if (iconData != null) ...[Icon(iconData), const SizedBox(width: 8)],
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }
    
    return TomDropdownMenuItem<T>(
      value: value,
      child: child,
    );
  }
}
```

### TomResourcePopupMenu

```dart
/// Auto-assembles popup menu items from a resource list.
class TomResourcePopupMenu<T> extends TomSelectBase {
  final PopupMenuItemSelected<T>? onSelected;
  
  @override
  Widget buildContent(BuildContext context) {
    final itemsList = _resolveItemsList(context);
    
    return TomPopupMenuButton<T>(
      tomId: tomId,
      itemBuilder: (context) => _buildItems(itemsList),
      onSelected: onSelected,
    );
  }
  
  List<PopupMenuEntry<T>> _buildItems(List<Map<String, dynamic>> items) {
    final result = <PopupMenuEntry<T>>[];
    
    for (final item in items) {
      if (item['divider'] == true) {
        result.add(const PopupMenuDivider());
        continue;
      }
      
      final value = item['value'] as T;
      final label = item['label'] as String? ?? value.toString();
      final iconName = item['icon'] as String?;
      final destructive = item['destructive'] as bool? ?? false;
      
      result.add(TomPopupMenuItem<T>(
        value: value,
        child: Row(
          children: [
            if (iconName != null) ...[
              Icon(
                TomUIIcons.resolveIcon(iconName),
                color: destructive ? Colors.red : null,
              ),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: destructive ? const TextStyle(color: Colors.red) : null,
            ),
          ],
        ),
      ));
    }
    
    return result;
  }
}
```

### TomResourceNavigationRail

```dart
/// Auto-assembles navigation destinations from resources.
class TomResourceNavigationRail extends TomNavigationBase {
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  
  @override
  Widget buildContent(BuildContext context) {
    final destinations = _resolveDestinations(context);
    
    return TomNavigationRail(
      tomId: tomId,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    );
  }
  
  List<NavigationRailDestination> _resolveDestinations(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return [];
    
    final destList = TomUIResources.resolveList<Map<String, dynamic>>(basePath, 'destinations');
    if (destList == null) return [];
    
    return destList.map((dest) {
      final iconName = dest['icon'] as String?;
      final selectedIconName = dest['selectedIcon'] as String?;
      final label = dest['label'] as String? ?? '';
      
      return NavigationRailDestination(
        icon: Icon(TomUIIcons.resolveIcon(iconName ?? '')),
        selectedIcon: selectedIconName != null
            ? Icon(TomUIIcons.resolveIcon(selectedIconName))
            : null,
        label: Text(label),
      );
    }).toList();
  }
}
```

---

## Implementation Strategy

### Phase 1: Core API Extensions

1. Extend `TomUIResourceAdapter` with typed resolution methods
2. Add `resolveColor`, `resolveDouble`, `resolveInt`, `resolveBool` to `TomUIResources`
3. Add `resolveList<T>` and `resolveMap` for complex structures
4. Update `TomNodeBase` with new helper methods

### Phase 2: Widget Updates

1. Update all widgets to try resource resolution for optional parameters
2. **Follow the 3-way resolution pattern** (see "Default Value Preservation" below):
   ```dart
   param ?? resolveXOrNull(context, 'suffix') ?? flutterDefault
   ```
3. Make constructor parameters nullable when they have Flutter defaults
4. Apply defaults in buildContent(), not in constructor defaults
5. For values that were historically `required` but should support resource override:
  - make constructor param nullable
  - resolve with explicit fail-fast check after `resolveXOrNull`
  - this preserves explicit-param priority and fails fast when both are missing

#### Default Value Preservation (CRITICAL)

When implementing Phase 2 resource resolution, you **MUST** preserve Flutter's original default values. The resolution pattern has three tiers:

```dart
// BUILD METHOD — resolves in priority order:
// 1. Explicit parameter (if user passed a value) → use it
// 2. Resource value (if defined in resources) → use it
// 3. Flutter default (if neither above) → use Flutter's original default

@override
Widget buildContent(BuildContext context) {
  return CupertinoPicker(
    // NO default — backgroundColor has no Flutter default (null is valid)
    backgroundColor: backgroundColor ?? resolveColorOrNull(context, 'backgroundColor'),
    
    // WITH default — diameterRatio defaults to 1.07 in Flutter
    diameterRatio: diameterRatio ?? resolveDoubleOrNull(context, 'diameterRatio') ?? 1.07,
    
    // WITH default — itemExtent defaults to 32.0 in Flutter
    itemExtent: itemExtent ?? resolveDoubleOrNull(context, 'itemExtent') ?? 32.0,
    ...
  );
}
```

**Constructor parameters** should be nullable without defaults:

```dart
class TomCupertinoPicker extends TomSelectBase {
  final double? diameterRatio;  // nullable, NO default
  final Color? backgroundColor; // nullable, NO default
  final double? itemExtent;     // nullable, NO default
  
  const TomCupertinoPicker({
    this.diameterRatio,    // ✅ No default — applied in buildContent
    this.backgroundColor,  // ✅ Nullable, no default
    this.itemExtent,       // ✅ No default — applied in buildContent
    ...
  });
}
```

**Why this matters:**
- Without the 3-way pattern, if no explicit param AND no resource → param becomes null
- Null breaks widgets that require a value (like `itemExtent` in CupertinoPicker)
- Flutter widgets expect their documented defaults when user passes nothing

**Anti-patterns to avoid:**

```dart
// ❌ WRONG — loses Flutter default if neither param nor resource exists
itemExtent: itemExtent ?? resolveDoubleOrNull(context, 'itemExtent'),

// ❌ WRONG — default in constructor prevents resource override
const TomCupertinoPicker({ this.itemExtent = 32.0, ... });

// ❌ WRONG — resource wins over explicit parameter
itemExtent: resolveDoubleOrNull(context, 'itemExtent') ?? itemExtent,

// ✅ CORRECT — 3-way pattern preserves Flutter defaults
itemExtent: itemExtent ?? resolveDoubleOrNull(context, 'itemExtent') ?? 32.0,

// ✅ CORRECT — formerly required value, now nullable with fail-fast
final resolvedItemExtent =
    itemExtent ?? resolveDoubleOrNull(context, 'itemExtent');
if (resolvedItemExtent == null) {
  throw StateError(
    'TomWidget requires itemExtent either as explicit param or resource value.',
  );
}
```

### Phase 3: Complex Structure Support

1. Implement `TextStyle` parsing from maps
2. Implement `EdgeInsets` parsing from maps/arrays
3. Implement `BorderRadius` parsing from maps/arrays
4. Add enum mapping support (TextAlign, TextOverflow, etc.)

### Phase 4: Auto-Assembling Components

1. Create `TomResourceDropdown` for dropdown menus
2. Create `TomResourcePopupMenu` for popup menus
3. Create `TomResourceNavigationRail` and `TomResourceNavigationBar`
4. Create `TomResourceTabBar` for tabs

---

## Design Principles

### 1. Explicit Value Priority

Code-provided values always take precedence over resource values:

```dart
// In widget implementation
final resolvedColor = this.color ?? resolveColorOrNull(context, 'color');
```

### 2. Silent Fallback

If no resource exists AND no explicit param, use Flutter's default:

```dart
// 3-way resolution pattern:
// param → resource → flutter default
itemExtent: itemExtent ?? resolveDoubleOrNull(context, 'itemExtent') ?? 32.0,
```

### 3. Type Safety

All resolution methods are type-safe and return null for type mismatches:

```dart
Color? resolveColor(String basePath, String suffix) {
  final value = _adapter?.resolveValue<dynamic>(basePath, suffix);
  if (value == null) return null;
  if (value is String) return TomUIColors.resolveColor(value);
  if (value is int) return Color(value);
  return null;
}
```

### 4. Deep Structure Support

JSON resources can contain nested structures for complex parameters:

```json
{
  "w-myWidget.config": {
    "colors": {
      "primary": "mBlue500",
      "secondary": "mGrey300"
    },
    "dimensions": {
      "padding": [16, 8],
      "margin": { "all": 8 }
    }
  }
}
```

---

## Summary Statistics

| Category | Total Parameters | Resource-Backable | Implementation Status |
|----------|------------------|-------------------|----------------------|
| Text | ~50 | 50 (100%) | ✅ Mostly implemented |
| Icon | ~30 | 30 (100%) | ✅ Implemented |
| Color | ~120 | 120 (100%) | 🆕 Proposed |
| Numeric (double/int) | ~80 | 80 (100%) | 🆕 Proposed |
| Boolean | ~60 | 60 (100%) | 🆕 Proposed |
| Widget | ~40 | 0 (0%) | ❌ Not serializable |
| Callback | ~100 | 0 (0%) | ❌ Not serializable |
| Complex (Style/Insets) | ~50 | ~40 (80%) | 🔶 Via map decomposition |
| List/Collection | ~25 | 25 (100%) | 🆕 Proposed |
| **Total** | **~555** | **~405 (~73%)** | |

---

## Next Steps

1. Review this proposal with stakeholders
2. Prioritize Phase 1 (Core API) implementation
3. Create test resources for validation
4. Implement incrementally with backward compatibility
5. Update documentation and developer guides
