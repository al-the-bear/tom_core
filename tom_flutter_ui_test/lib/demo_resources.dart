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
    // Section headers (slug-based resource IDs from demo_02_inputs.dart)
    'section.inputs.tomtextfield.label': 'TomTextField',
    'section.inputs.tomtextfield.subtitle.label': 'Tom-wrapped text input fields with resource resolution',
    'section.inputs.tomtextformfield.label': 'TomTextFormField',
    'section.inputs.tomtextformfield.subtitle.label': 'Tom-wrapped form fields with validation support',
    'section.inputs.input_decorations.label': 'Input Decorations',
    'section.inputs.input_decorations.subtitle.label': 'Styling and decorating text inputs',
    'section.inputs.password_fields.label': 'Password Fields',
    'section.inputs.password_fields.subtitle.label': 'Secure text entry with visibility toggle',
    'section.inputs.multi_line_text.label': 'Multi-line Text',
    'section.inputs.multi_line_text.subtitle.label': 'TextFields for longer text content',
    'section.inputs.input_formatters.label': 'Input Formatters',
    'section.inputs.input_formatters.subtitle.label': 'Restricting and formatting input text',
    'section.inputs.search_fields.label': 'Search Fields',
    'section.inputs.search_fields.subtitle.label': 'Optimized inputs for search functionality',
    'section.inputs.date_time_pickers.label': 'Date & Time Pickers',
    'section.inputs.date_time_pickers.subtitle.label': 'Specialized inputs for date and time selection',
    'section.inputs.form_examples.label': 'Form Examples',
    'section.inputs.form_examples.subtitle.label': 'Complete form implementations with validation',
    // Demo card headers (slug-based resource IDs from demo_02_inputs.dart)
    'demo.input.card.basic_tomtextfield.label': 'Basic TomTextField',
    'demo.input.card.basic_tomtextfield.description.label': 'Simple text input with optional controller.',
    'demo.input.card.tomtextfield_with_label.label': 'TomTextField with Label',
    'demo.input.card.tomtextfield_with_label.description.label': 'Floating label that animates when focused.',
    'demo.input.card.tomtextfield_with_prefix_suffix.label': 'TomTextField with Prefix & Suffix',
    'demo.input.card.tomtextfield_with_prefix_suffix.description.label': 'Add icons or text before/after the input.',
    'demo.input.card.tomtextfield_states.label': 'TomTextField States',
    'demo.input.card.tomtextfield_states.description.label': 'Enabled, disabled, and read-only states.',
    'demo.input.card.basic_validation.label': 'Basic Validation',
    'demo.input.card.basic_validation.description.label': 'TomTextFormField with validator function.',
    'demo.input.card.validation_states.label': 'Validation States',
    'demo.input.card.validation_states.description.label': 'Visual feedback for different validation states.',
    'demo.input.card.border_styles.label': 'Border Styles',
    'demo.input.card.border_styles.description.label': 'Different border variants for text fields.',
    'demo.input.card.fill_colors.label': 'Fill Colors',
    'demo.input.card.fill_colors.description.label': 'Customize the background fill of text fields.',
    'demo.input.card.counter_max_length.label': 'Counter & Max Length',
    'demo.input.card.counter_max_length.description.label': 'Character counting and length limits.',
    'demo.input.card.basic_password_field.label': 'Basic Password Field',
    'demo.input.card.basic_password_field.description.label': 'Toggle visibility with suffix icon.',
    'demo.input.card.password_with_strength_indicator.label': 'Password with Strength Indicator',
    'demo.input.card.password_with_strength_indicator.description.label': 'Real-time password strength feedback.',
    'demo.input.card.multi_line_textfield.label': 'Multi-line TextField',
    'demo.input.card.multi_line_textfield.description.label': 'Expandable text area for longer content.',
    'demo.input.card.rich_text_area.label': 'Rich Text Area',
    'demo.input.card.rich_text_area.description.label': 'Text area with character count and helper text.',
    'demo.input.card.digit_only_input.label': 'Digit Only Input',
    'demo.input.card.digit_only_input.description.label': 'Using FilteringTextInputFormatter for numbers.',
    'demo.input.card.uppercase_input.label': 'Uppercase Input',
    'demo.input.card.uppercase_input.description.label': 'Auto-convert input to uppercase.',
    'demo.input.card.phone_number_formatter.label': 'Phone Number Formatter',
    'demo.input.card.phone_number_formatter.description.label': 'Auto-format input as phone number.',
    'demo.input.card.credit_card_formatter.label': 'Credit Card Formatter',
    'demo.input.card.credit_card_formatter.description.label': 'Format input as credit card number with spaces.',
    'demo.input.card.basic_search_field.label': 'Basic Search Field',
    'demo.input.card.basic_search_field.description.label': 'TextField styled for search functionality.',
    'demo.input.card.searchbar_material_3.label': 'SearchBar (Material 3)',
    'demo.input.card.searchbar_material_3.description.label': 'Material 3 search bar with suggestions.',
    'demo.input.card.date_picker.label': 'Date Picker',
    'demo.input.card.date_picker.description.label': 'TextField that triggers date picker dialog.',
    'demo.input.card.time_picker.label': 'Time Picker',
    'demo.input.card.time_picker.description.label': 'TextField that triggers time picker dialog.',
    'demo.input.card.date_range_picker.label': 'Date Range Picker',
    'demo.input.card.date_range_picker.description.label': 'Select a start and end date.',
    'demo.input.card.login_form.label': 'Login Form',
    'demo.input.card.login_form.description.label': 'Complete form with validation.',
    'demo.input.card.registration_form.label': 'Registration Form',
    'demo.input.card.registration_form.description.label': 'Complete signup form with multiple fields.',
    // Shared code snippet labels
    'demo.code.show.label': 'Show code',
    'demo.code.hide.label': 'Hide code',

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
    // ==========================================================================
    // Auto Text Resources (demo_02..demo_06)
    // ==========================================================================
    'demo.02.auto.text.1': 'Form is valid!',
    'demo.02.auto.text.2': 'Forgot Password?',
    'demo.02.auto.text.3': 'Login successful!',
    'demo.02.auto.text.4': 'Login',
    'demo.02.auto.text.5': 'Account created!',
    'demo.02.auto.text.6': 'Create Account',
    'demo.03.auto.text.1': 'High',
    'demo.03.auto.text.10': 'With Avatar',
    'demo.03.auto.text.11': 'Deletable',
    'demo.03.auto.text.12': 'Added!',
    'demo.03.auto.text.13': 'Elevated',
    'demo.03.auto.text.14': 'Select Hobbies',
    'demo.03.auto.text.15': 'Filters applied!',
    'demo.03.auto.text.16': '#\$tag',
    'demo.03.auto.text.17': 'Auto text 17',
    'demo.03.auto.text.18': 'With Icon',
    'demo.03.auto.text.19': 'Rounded',
    'demo.03.auto.text.2': 'Medium',
    'demo.03.auto.text.20': 'Outlined',
    'demo.03.auto.text.21': 'Gradient',
    'demo.03.auto.text.22': 'Cancel',
    'demo.03.auto.text.23': 'Confirm',
    'demo.03.auto.text.3': 'Low',
    'demo.03.auto.text.4': 'Basic Chip',
    'demo.03.auto.text.5': 'A',
    'demo.03.auto.text.6': 'With Avatar',
    'demo.03.auto.text.7': 'Deletable',
    'demo.03.auto.text.8': 'Basic',
    'demo.03.auto.text.9': 'A',
    'demo.04.auto.text.1': 'Dark Mode',
    'demo.04.auto.text.10': 'Grid',
    'demo.04.auto.text.11': 'Table',
    'demo.04.auto.text.12': 'List',
    'demo.04.auto.text.13': 'Grid',
    'demo.04.auto.text.14': 'M',
    'demo.04.auto.text.15': 'T',
    'demo.04.auto.text.16': 'W',
    'demo.04.auto.text.17': 'T',
    'demo.04.auto.text.18': 'F',
    'demo.04.auto.text.19': 'S',
    'demo.04.auto.text.2': 'Use dark theme',
    'demo.04.auto.text.20': 'S',
    'demo.04.auto.text.21': 'XS',
    'demo.04.auto.text.22': 'S',
    'demo.04.auto.text.23': 'M',
    'demo.04.auto.text.24': 'L',
    'demo.04.auto.text.25': 'XL',
    'demo.04.auto.text.26': 'Bold',
    'demo.04.auto.text.27': 'Italic',
    'demo.04.auto.text.28': 'Strike',
    'demo.04.auto.text.29': 'Day',
    'demo.04.auto.text.3': 'Dark Mode',
    'demo.04.auto.text.30': 'Week',
    'demo.04.auto.text.31': 'Favorite:',
    'demo.04.auto.text.32': 'Email Updates',
    'demo.04.auto.text.33': 'SMS Alerts',
    'demo.04.auto.text.34': 'Critical alerts via SMS',
    'demo.04.auto.text.35': 'Public',
    'demo.04.auto.text.36': 'Private',
    'demo.04.auto.text.37': 'Light',
    'demo.04.auto.text.38': 'Dark',
    'demo.04.auto.text.39': 'System',
    'demo.04.auto.text.4': 'Use dark theme',
    'demo.04.auto.text.40': 'Auto text 40',
    'demo.04.auto.text.41': 'Auto text 41',
    'demo.04.auto.text.42': 'Airplane Mode',
    'demo.04.auto.text.43': 'Disable all wireless connections',
    'demo.04.auto.text.44': 'Email notifications',
    'demo.04.auto.text.45': 'Email notifications',
    'demo.04.auto.text.46': 'Option 1',
    'demo.04.auto.text.47': 'Option 2',
    'demo.04.auto.text.48': 'Option 3',
    'demo.04.auto.text.49': 'Basic Plan',
    'demo.04.auto.text.5': 'Wi-Fi',
    'demo.04.auto.text.50': '\$9.99/month',
    'demo.04.auto.text.51': 'Pro Plan',
    'demo.04.auto.text.52': '\$19.99/month',
    'demo.04.auto.text.53': 'Enterprise Plan',
    'demo.04.auto.text.54': '\$49.99/month',
    'demo.04.auto.text.55': 'Basic Plan',
    'demo.04.auto.text.56': '\$9.99/month',
    'demo.04.auto.text.57': 'Underline',
    'demo.04.auto.text.58': 'Month',
    'demo.04.auto.text.59': 'Push Notifications',
    'demo.04.auto.text.6': 'Agree to terms: \${_check1 ? "Yes" : "No"}',
    'demo.04.auto.text.60': 'Receive instant notifications',
    'demo.04.auto.text.61': 'Weekly digest and important updates',
    'demo.04.auto.text.62': 'Anyone can see your profile',
    'demo.04.auto.text.63': 'Friends Only',
    'demo.04.auto.text.64': 'Only friends can see your profile',
    'demo.04.auto.text.65': 'No one can see your profile',
    'demo.04.auto.text.66': 'Location Services',
    'demo.04.auto.text.67': 'Usage Analytics',
    'demo.04.auto.text.7': 'Receive updates via email',
    'demo.04.auto.text.8': 'Receive updates via email',
    'demo.04.auto.text.9': 'List',
    'demo.05.auto.text.1': '16°C',
    'demo.05.auto.text.10': 'downloading_file.zip',
    'demo.05.auto.text.11': 'Price Range',
    'demo.05.auto.text.12': '\$0',
    'demo.05.auto.text.13': 'Auto text 13',
    'demo.05.auto.text.14': 'Large Round Thumb',
    'demo.05.auto.text.15': 'Elevated on Press',
    'demo.05.auto.text.16': 'Small & Minimal',
    'demo.05.auto.text.17': 'Thin Track (2px)',
    'demo.05.auto.text.2': '30°C',
    'demo.05.auto.text.3': 'Thick Track (12px)',
    'demo.05.auto.text.4': '10:00',
    'demo.05.auto.text.5': 'H',
    'demo.05.auto.text.6': 'S',
    'demo.05.auto.text.7': 'L',
    'demo.05.auto.text.8': 'Reset',
    'demo.05.auto.text.9': 'Bass Boost',
    'demo.06.auto.text.1': 'With shadow',
    'demo.06.auto.text.10': 'Utilities',
    'demo.06.auto.text.11': 'What is Flutter?',
    'demo.06.auto.text.12': 'What is Dart?',
    'demo.06.auto.text.13': 'What are widgets?',
    'demo.06.auto.text.14': 'Swipe to dismiss',
    'demo.06.auto.text.15': 'All items dismissed!',
    'demo.06.auto.text.16': 'Auto text 16',
    'demo.06.auto.text.17': 'Auto text 17',
    'demo.06.auto.text.18': 'Auto text 18',
    'demo.06.auto.text.19': 'Auto text 19',
    'demo.06.auto.text.2': 'ACTION 1',
    'demo.06.auto.text.20': 'This is a basic card with some content inside.',
    'demo.06.auto.text.21': 'This is an outlined card without elevation.',
    'demo.06.auto.text.22': 'Card description goes here with some text.',
    'demo.06.auto.text.23': 'Rounded',
    'demo.06.auto.text.24': 'Basic ExpansionTile',
    'demo.06.auto.text.25': 'Tap to expand',
    'demo.06.auto.text.26': 'Styled ExpansionTile',
    'demo.06.auto.text.27': 'Appearance',
    'demo.06.auto.text.28': 'Language',
    'demo.06.auto.text.29': 'Initially Expanded',
    'demo.06.auto.text.3': 'ACTION 2',
    'demo.06.auto.text.30': 'Nested ExpansionTiles',
    'demo.06.auto.text.31': 'Documentation',
    'demo.06.auto.text.32': 'Getting Started',
    'demo.06.auto.text.33': 'Installation',
    'demo.06.auto.text.34': 'Configuration',
    'demo.06.auto.text.35': 'API Reference',
    'demo.06.auto.text.36': 'Components',
    'demo.06.auto.text.4': 'Square',
    'demo.06.auto.text.5': 'Stadium',
    'demo.06.auto.text.6': 'Item 1',
    'demo.06.auto.text.7': 'Item 2',
    'demo.06.auto.text.8': 'Item 3',
    'demo.06.auto.text.9': 'User Profile',
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
