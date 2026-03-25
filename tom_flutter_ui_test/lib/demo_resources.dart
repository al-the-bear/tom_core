/// Demo resources adapter for tom_flutter_ui_test.
///
/// Provides text and icon resources for the demo widgets via tomId lookup.
/// This demonstrates how a real application would configure resources.
library;

import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Demo resource adapter providing texts for all demo widgets.
///
/// Resource keys follow the pattern: `<tomId>.<suffix>`
/// - `demo.elevated.basic.label` → "Basic"
/// - `demo.elevated.icon.save.icon` → "save"
class DemoResourceAdapter implements TomUIResourceAdapter {
  /// All text resources for the demo app.
  ///
  /// Keys are `<tomId>.<suffix>` where suffix is typically:
  /// - `label` - button/widget label text
  /// - `icon` - icon name for lookup via TomUIIcons
  /// - `hint` - hint text for inputs
  /// - `tooltip` - tooltip text
  /// - `alt` - semantic label for icons/images
  static final Map<String, String> _resources = {
    // ==========================================================================
    // Section Headers
    // ==========================================================================
    'section.elevated.title.label': 'TomElevatedButton',
    'section.elevated.subtitle.label':
        'Primary action buttons with elevation and shadow',
    'section.filled.title.label': 'TomFilledButton',
    'section.filled.subtitle.label':
        'High-emphasis buttons with filled background (M3)',
    'section.outlined.title.label': 'TomOutlinedButton',
    'section.outlined.subtitle.label':
        'Medium-emphasis buttons with outline border',
    'section.text.title.label': 'TomTextButton',
    'section.text.subtitle.label':
        'Low-emphasis buttons for less prominent actions',
    'section.icon.title.label': 'TomIconButton',
    'section.icon.subtitle.label': 'Buttons that display a single icon',
    'section.fab.title.label': 'TomFloatingActionButton',
    'section.fab.subtitle.label':
        'Circular floating buttons for primary actions',

    // ==========================================================================
    // TomElevatedButton Demo
    // ==========================================================================
    'demo.elevated.basic.label': 'Basic',
    'demo.elevated.label.label': 'With Label',
    'demo.elevated.disabled.label': 'Disabled',
    'demo.elevated.icon.save.label': 'Save',
    'demo.elevated.icon.save.icon': 'mSave',
    'demo.elevated.icon.send.label': 'Send',
    'demo.elevated.icon.send.icon': 'mSend',
    'demo.elevated.icon.download.label': 'Download',
    'demo.elevated.icon.download.icon': 'mDownload',
    'demo.elevated.style.error.label': 'Delete',
    'demo.elevated.style.error.icon': 'mDelete',
    'demo.elevated.style.rounded.label': 'Rounded',
    'demo.elevated.style.large.label': 'Large',

    // ==========================================================================
    // TomFilledButton Demo
    // ==========================================================================
    'demo.filled.basic.label': 'Filled',
    'demo.filled.label.label': 'With Label',
    'demo.filled.disabled.label': 'Disabled',
    'demo.filled.tonal.label': 'Tonal',
    'demo.filled.tonal.icon.label': 'Settings',
    'demo.filled.tonal.icon.icon': 'mSettings',
    'demo.filled.tonal.disabled.label': 'Disabled Tonal',
    'demo.filled.icon.add.label': 'Add',
    'demo.filled.icon.add.icon': 'mAdd',
    'demo.filled.icon.share.label': 'Share',
    'demo.filled.icon.share.icon': 'mShare',

    // ==========================================================================
    // TomOutlinedButton Demo
    // ==========================================================================
    'demo.outlined.basic.label': 'Outlined',
    'demo.outlined.label.label': 'With Label',
    'demo.outlined.disabled.label': 'Disabled',
    'demo.outlined.icon.edit.label': 'Edit',
    'demo.outlined.icon.edit.icon': 'mEdit',
    'demo.outlined.icon.cancel.label': 'Cancel',
    'demo.outlined.icon.cancel.icon': 'mCancel',
    'demo.outlined.style.thick.label': 'Thick Border',
    'demo.outlined.style.dashed.label': 'Secondary',

    // ==========================================================================
    // TomTextButton Demo
    // ==========================================================================
    'demo.text.basic.label': 'Text Button',
    'demo.text.label.label': 'With Label',
    'demo.text.disabled.label': 'Disabled',
    'demo.text.icon.link.label': 'Link',
    'demo.text.icon.link.icon': 'mLink',
    'demo.text.icon.more.label': 'More',
    'demo.text.icon.more.icon': 'mMoreHoriz',
    'demo.text.dialog.cancel.label': 'Cancel',
    'demo.text.dialog.ok.label': 'OK',

    // ==========================================================================
    // TomIconButton Demo
    // ==========================================================================
    'demo.icon.favorite.icon': 'mFavorite',
    'demo.icon.favorite.tooltip': 'Favorite',
    'demo.icon.share.icon': 'mShare',
    'demo.icon.share.tooltip': 'Share',
    'demo.icon.more.icon': 'mMoreVert',
    'demo.icon.more.tooltip': 'More options',
    'demo.icon.disabled.icon': 'mDelete',
    'demo.icon.disabled.tooltip': 'Delete (disabled)',
    'demo.icon.filled.icon': 'mAdd',
    'demo.icon.filled.tooltip': 'Add (filled)',
    'demo.icon.tonal.icon': 'mEdit',
    'demo.icon.tonal.tooltip': 'Edit (tonal)',
    'demo.icon.outlined.icon': 'mSearch',
    'demo.icon.outlined.tooltip': 'Search (outlined)',
    'demo.icon.small.icon': 'mStar',
    'demo.icon.small.tooltip': 'Small',
    'demo.icon.medium.icon': 'mStar',
    'demo.icon.medium.tooltip': 'Medium',
    'demo.icon.large.icon': 'mStar',
    'demo.icon.large.tooltip': 'Large',
    'demo.icon.xlarge.icon': 'mStar',
    'demo.icon.xlarge.tooltip': 'Extra Large',

    // ==========================================================================
    // TomFloatingActionButton Demo
    // ==========================================================================
    'demo.fab.basic.icon': 'mAdd',
    'demo.fab.basic.tooltip': 'Add',
    'demo.fab.small.icon': 'mEdit',
    'demo.fab.small.tooltip': 'Small FAB',
    'demo.fab.large.icon': 'mCameraAlt',
    'demo.fab.large.tooltip': 'Large FAB',
    'demo.fab.extended.compose.icon': 'mEdit',
    'demo.fab.extended.compose.label': 'Compose',
    'demo.fab.extended.add.icon': 'mAdd',
    'demo.fab.extended.add.label': 'Create New',
    'demo.fab.color.tertiary.icon': 'mStar',
    'demo.fab.color.tertiary.tooltip': 'Tertiary color',
    'demo.fab.color.error.icon': 'mDelete',
    'demo.fab.color.error.tooltip': 'Error color',

    // ==========================================================================
    // TomSegmentedButton Demo
    // ==========================================================================
    'demo.segmented.day.label': 'Day',
    'demo.segmented.day.icon': 'mCalendarViewDay',
    'demo.segmented.week.label': 'Week',
    'demo.segmented.week.icon': 'mCalendarViewWeek',
    'demo.segmented.month.label': 'Month',
    'demo.segmented.month.icon': 'mCalendarViewMonth',
    'demo.segmented.bold.label': 'Bold',
    'demo.segmented.bold.icon': 'mFormatBold',
    'demo.segmented.italic.label': 'Italic',
    'demo.segmented.italic.icon': 'mFormatItalic',
    'demo.segmented.underline.label': 'Underline',
    'demo.segmented.underline.icon': 'mFormatUnderline',
    'demo.segmented.list.icon': 'mViewList',
    'demo.segmented.grid.icon': 'mGridView',
    'demo.segmented.module.icon': 'mViewModule',

    // ==========================================================================
    // TomMenuAnchor & TomMenuItemButton Demo
    // ==========================================================================
    'demo.menu.trigger.label': 'Open Menu',
    'demo.menu.trigger.icon': 'mMenu',
    'demo.menu.item.cut.label': 'Cut',
    'demo.menu.item.cut.icon': 'mContentCut',
    'demo.menu.item.copy.label': 'Copy',
    'demo.menu.item.copy.icon': 'mContentCopy',
    'demo.menu.item.paste.label': 'Paste',
    'demo.menu.item.paste.icon': 'mContentPaste',
    'demo.menu.item.selectall.label': 'Select All',
    'demo.menu.item.selectall.icon': 'mSelectAll',
    'demo.submenu.trigger.label': 'File Menu',
    'demo.submenu.trigger.icon': 'mMenuOpen',
    'demo.submenu.new.label': 'New',
    'demo.submenu.new.icon': 'mAdd',
    'demo.submenu.open.label': 'Open',
    'demo.submenu.open.icon': 'mFolderOpen',
    'demo.submenu.open.recent.label': 'Recent Files',
    'demo.submenu.open.browse.label': 'Browse...',
    'demo.submenu.export.label': 'Export',
    'demo.submenu.export.icon': 'mIosShare',
    'demo.submenu.export.pdf.label': 'Export as PDF',
    'demo.submenu.export.csv.label': 'Export as CSV',
    'demo.submenu.export.json.label': 'Export as JSON',

    // ==========================================================================
    // TomPopupMenuButton Demo
    // ==========================================================================
    'demo.popup.item.view.label': 'View',
    'demo.popup.item.edit.label': 'Edit',
    'demo.popup.item.delete.label': 'Delete',
    'demo.popup.icons.icon': 'mMoreVert',
    'demo.popup.icons.share.label': 'Share',
    'demo.popup.icons.share.icon': 'mShare',
    'demo.popup.icons.link.label': 'Copy Link',
    'demo.popup.icons.link.icon': 'mLink',
    'demo.popup.icons.report.label': 'Report',
    'demo.popup.icons.report.icon': 'mFlag',
    'demo.popup.checked.images.label': 'Images',
    'demo.popup.checked.videos.label': 'Videos',
    'demo.popup.checked.documents.label': 'Documents',
    'demo.popup.filter.icon': 'mFilterList',
    'demo.popup.filter.label': 'Filter',

    // ==========================================================================
    // Navigation Buttons Demo
    // ==========================================================================
    'demo.back.default.tooltip': 'Go back',
    'demo.close.default.tooltip': 'Close',
    'demo.context.back.tooltip': 'Back',
    'demo.context.more.icon': 'mMoreVert',

    // ==========================================================================
    // Group Visibility Demo
    // ==========================================================================
    'demo.group.btn.delete.label': 'Delete All',
    'demo.group.btn.delete.icon': 'mDeleteForever',
    'demo.group.btn.settings.label': 'Admin Settings',
    'demo.group.btn.settings.icon': 'mAdminPanelSettings',
    'demo.group.btn.edit.label': 'Edit',
    'demo.group.btn.edit.icon': 'mEdit',
    'demo.group.btn.publish.label': 'Publish',
    'demo.group.btn.publish.icon': 'mPublish',
    'demo.group.btn.view.label': 'View',
    'demo.group.btn.view.icon': 'mVisibility',
    'demo.group.btn.download.label': 'Download',
    'demo.group.btn.download.icon': 'mDownload',

    // ==========================================================================
    // Inputs Demo (demo_02_inputs.dart)
    // ==========================================================================
    // TextField demos
    'demo.input.basic.label': 'Basic Input',
    'demo.input.basic.hint': 'Enter text here',
    'demo.input.username.label': 'Username',
    'demo.input.username.hint': 'Enter your username',
    'demo.input.email.label': 'Email',
    'demo.input.email.hint': 'Enter your email',
    'demo.input.website.label': 'Website',
    'demo.input.website.hint': 'Enter website URL',
    'demo.input.search.label': 'Search',
    'demo.input.search.hint': 'Search...',
    'demo.input.enabled.label': 'Enabled',
    'demo.input.disabled.label': 'Disabled',
    'demo.input.readonly.label': 'Read Only',
    // TextFormField demos
    'demo.form.email.label': 'Email',
    'demo.form.email.hint': 'example@email.com',
    'demo.form.phone.label': 'Phone',
    'demo.form.phone.hint': '1234567890',
    'demo.form.submit.label': 'Submit',
    'demo.form.success.label': 'Success State',
    'demo.form.error.label': 'Error State',
    'demo.form.warning.label': 'Warning State',
    // Decoration demos
    'demo.deco.outline.label': 'Outline Border',
    'demo.deco.underline.label': 'Underline Border (Default)',
    'demo.deco.noborder.label': 'No Border',
    'demo.deco.stadium.label': 'Custom Stadium Border',
    'demo.deco.counter.label': 'With Counter',
    'demo.deco.counter.hint': 'Max 50 characters',
    'demo.deco.maxlength.label': 'Enforced Max Length',
    'demo.deco.maxlength.hint': 'Cannot exceed 100 characters',
    'demo.deco.customcounter.label': 'Custom Counter',
    'demo.deco.customcounter.hint': 'Tweet-style counter',
    // Password demos
    'demo.password.basic.label': 'Password',
    'demo.password.basic.hint': 'Enter password',

    // ==========================================================================
    // Selection Demo (demo_03_selection.dart)
    // ==========================================================================
    // TomDropdownButton demos
    'demo.select.dropdown.fruit.hint': 'Select a fruit',
    'demo.select.dropdown.country.hint': 'Select a country',
    'demo.select.dropdown.priority.hint': 'Select priority',
    'demo.select.formfield.fruit.label': 'Favorite Fruit',
    // TomDropdownMenu demos
    'demo.select.menu.color.hint': 'Select a color',
    'demo.select.menu.color.label': 'Color',
    'demo.select.menu.icon.hint': 'Search and select',
    'demo.select.menu.icon.label': 'Icon',
    'demo.select.menu.category.hint': 'Select category',
    'demo.select.menu.category.label': 'Category',
    // TomAutocomplete demos
    'demo.select.autocomplete.language.label': 'Programming Language',
    'demo.select.autocomplete.language.hint': 'Start typing...',
    'demo.select.autocomplete.language.field.label': 'Language',
    'demo.select.autocomplete.custom.label': 'Select Language',
    'demo.select.autocomplete.custom.field.label': 'Language',
    'demo.select.autocomplete.async.label': 'City',
    'demo.select.autocomplete.async.hint': 'Search cities...',
    'demo.select.autocomplete.async.field.label': 'City',
    // TomActionChip demos
    'demo.chip.action.cart.label': 'Add to Cart',
    'demo.chip.action.cart.tooltip': 'Add item to shopping cart',
    'demo.chip.action.share.label': 'Share',
    'demo.chip.action.share.tooltip': 'Share this item',
    'demo.chip.action.bookmark.label': 'Bookmark',
    'demo.chip.action.bookmark.tooltip': 'Save to bookmarks',
    // TomInputChip demos
    'demo.chip.input.field.hint': 'Add a tag',
    'demo.chip.input.add.tooltip': 'Add tag',
    // TomFilterChip demos
    'demo.chip.filter.Electronics.label': 'Electronics',
    'demo.chip.filter.Clothing.label': 'Clothing',
    'demo.chip.filter.Books.label': 'Books',
    'demo.chip.filter.Food.label': 'Food',
    // TomChoiceChip demos
    'demo.chip.choice.XS.label': 'XS',
    'demo.chip.choice.S.label': 'S',
    'demo.chip.choice.M.label': 'M',
    'demo.chip.choice.L.label': 'L',
    'demo.chip.choice.XL.label': 'XL',
    // Selection Examples section
    'demo.select.example.sort.label': 'Sort By',
    'demo.select.example.clear.label': 'Clear All',
    'demo.select.example.apply.label': 'Apply Filters',
    // Tag input demo
    'demo.select.tag.input.label': 'Tags',
    'demo.select.tag.field.hint': 'Add tags...',
    'demo.select.tag.add.tooltip': 'Add tag',
  };

  @override
  String resolveText(String basePath, String suffix) {
    // Remove widget prefix (w-) for lookup
    final cleanPath = basePath.replaceFirst(RegExp(r'^w-'), '');
    final key = '$cleanPath.$suffix';
    return _resources[key] ?? '$basePath.$suffix';
  }

  @override
  bool resourceExists(String basePath, String suffix) {
    final cleanPath = basePath.replaceFirst(RegExp(r'^w-'), '');
    final key = '$cleanPath.$suffix';
    return _resources.containsKey(key);
  }
}

/// Initializes the Tom UI resource and icon adapters for the demo app.
///
/// Call this in `main()` before `runApp()`.
void initializeDemoResources() {
  TomUIResources.adapter = DemoResourceAdapter();
  TomUIIcons.adapter = AllIconsAdapter();
}
