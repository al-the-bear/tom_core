/// Demo resources for tom_flutter_ui_test.
///
/// Provides text and icon resources for the demo widgets via tomId lookup.
/// This demonstrates how a real application would configure resources
/// using [TomTextResourceProvider] from tom_core_kernel.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Demo resource container providing texts for all demo widgets.
///
/// Resource keys follow the pattern: `<basePath>.<suffix>`
/// - `demo01.elevated.basic.label` → "Basic"
/// - `demo01.elevated.save.icon` → "mSave"
class _DemoResources {
  /// All text resources for the demo app.
  ///
  /// Keys are `<basePath>.<suffix>` where suffix is typically:
  /// - `label` - button/widget label text
  /// - `icon` - icon name for lookup via TomUIIcons
  /// - `title` - section/card title
  /// - `subtitle` - section subtitle  
  /// - `description` - card description
  /// - `tooltip` - tooltip text
  /// - `alt` - semantic label for icons/images
  static final Map<String, String> _resources = {
    // ==========================================================================
    // Demo 01: Buttons - Section Headers
    // ==========================================================================
    'demo01.section.primary.title.label': 'Primary Buttons',
    'demo01.section.primary.subtitle.label':
        'High-emphasis buttons for primary actions',
    'demo01.section.secondary.title.label': 'Secondary Buttons',
    'demo01.section.secondary.subtitle.label':
        'Lower emphasis buttons for secondary actions',
    'demo01.section.iconFab.title.label': 'Icon & FAB Buttons',
    'demo01.section.iconFab.subtitle.label':
        'Compact icon buttons and floating action buttons',
    'demo01.section.segmentedMenu.title.label': 'Segmented & Menu Buttons',
    'demo01.section.segmentedMenu.subtitle.label':
        'Selection groups and menu interactions',
    'demo01.section.navigation.title.label': 'Navigation Buttons',
    'demo01.section.navigation.subtitle.label':
        'Navigation controls and context buttons',

    // ==========================================================================
    // Demo 01: TomElevatedButton Card
    // ==========================================================================
    'demo01.elevated.icon': 'mSmartButton',
    'demo01.elevated.title.label': 'TomElevatedButton',
    'demo01.elevated.description.label':
        'Primary action buttons with elevation and shadow effect.',
    'demo01.elevated.basic.label': 'Basic',
    'demo01.elevated.disabled.label': 'Disabled',
    'demo01.elevated.save.label': 'Save',
    'demo01.elevated.save.icon': 'mSave',
    'demo01.elevated.send.label': 'Send',
    'demo01.elevated.send.icon': 'mSend',
    'demo01.elevated.download.label': 'Download',
    'demo01.elevated.download.icon': 'mDownload',
    'demo01.elevated.error.label': 'Delete',
    'demo01.elevated.error.icon': 'mDelete',
    'demo01.elevated.rounded.label': 'Rounded',
    'demo01.elevated.large.label': 'Large Button',

    // ==========================================================================
    // Demo 01: TomFilledButton Card
    // ==========================================================================
    'demo01.filled.icon': 'mRectangle',
    'demo01.filled.title.label': 'TomFilledButton',
    'demo01.filled.description.label':
        'Material 3 filled buttons with highest visual emphasis.',
    'demo01.filled.basic.label': 'Filled',
    'demo01.filled.disabled.label': 'Disabled',
    'demo01.filled.tonal.label': 'Tonal',
    'demo01.filled.tonalSettings.label': 'Settings',
    'demo01.filled.tonalSettings.icon': 'mSettings',
    'demo01.filled.tonalDisabled.label': 'Disabled Tonal',
    'demo01.filled.add.label': 'Add',
    'demo01.filled.add.icon': 'mAdd',
    'demo01.filled.share.label': 'Share',
    'demo01.filled.share.icon': 'mShare',

    // ==========================================================================
    // Demo 01: TomTextButton Card
    // ==========================================================================
    'demo01.text.icon': 'mTextFields',
    'demo01.text.title.label': 'TomTextButton',
    'demo01.text.description.label':
        'Low-emphasis buttons for less prominent actions.',
    'demo01.text.basic.label': 'Text Button',
    'demo01.text.disabled.label': 'Disabled',
    'demo01.text.link.label': 'Link',
    'demo01.text.link.icon': 'mLink',
    'demo01.text.more.label': 'More',
    'demo01.text.more.icon': 'mMoreHoriz',
    'demo01.text.cancel.label': 'Cancel',
    'demo01.text.ok.label': 'OK',

    // ==========================================================================
    // Demo 01: TomOutlinedButton Card
    // ==========================================================================
    'demo01.outlined.icon': 'mRectangle',
    'demo01.outlined.title.label': 'TomOutlinedButton',
    'demo01.outlined.description.label':
        'Medium-emphasis buttons with outline border.',
    'demo01.outlined.basic.label': 'Outlined',
    'demo01.outlined.disabled.label': 'Disabled',
    'demo01.outlined.edit.label': 'Edit',
    'demo01.outlined.edit.icon': 'mEdit',
    'demo01.outlined.cancel.label': 'Cancel',
    'demo01.outlined.cancel.icon': 'mCancel',
    'demo01.outlined.thick.label': 'Thick Border',
    'demo01.outlined.secondary.label': 'Secondary',

    // ==========================================================================
    // Demo 01: TomIconButton Card
    // ==========================================================================
    'demo01.icon.icon': 'mTouchApp',
    'demo01.icon.title.label': 'TomIconButton',
    'demo01.icon.description.label': 'Compact icon-only buttons for actions.',
    'demo01.icon.favorite.icon': 'mFavorite',
    'demo01.icon.favorite.tooltip': 'Favorite',
    'demo01.icon.share.icon': 'mShare',
    'demo01.icon.share.tooltip': 'Share',
    'demo01.icon.more.icon': 'mMoreVert',
    'demo01.icon.more.tooltip': 'More options',
    'demo01.icon.disabled.icon': 'mDelete',
    'demo01.icon.disabled.tooltip': 'Delete (disabled)',
    'demo01.icon.filled.icon': 'mAdd',
    'demo01.icon.filled.tooltip': 'Add (filled)',
    'demo01.icon.tonal.icon': 'mEdit',
    'demo01.icon.tonal.tooltip': 'Edit (tonal)',
    'demo01.icon.outlined.icon': 'mSearch',
    'demo01.icon.outlined.tooltip': 'Search (outlined)',
    'demo01.icon.small.icon': 'mStar',
    'demo01.icon.small.tooltip': 'Small',
    'demo01.icon.medium.icon': 'mStar',
    'demo01.icon.medium.tooltip': 'Medium',
    'demo01.icon.large.icon': 'mStar',
    'demo01.icon.large.tooltip': 'Large',
    'demo01.icon.xlarge.icon': 'mStar',
    'demo01.icon.xlarge.tooltip': 'Extra Large',

    // ==========================================================================
    // Demo 01: TomFloatingActionButton Card
    // ==========================================================================
    'demo01.fab.icon': 'mAddCircle',
    'demo01.fab.title.label': 'TomFloatingActionButton',
    'demo01.fab.description.label':
        'Circular floating buttons for primary actions.',
    'demo01.fab.basic.icon': 'mAdd',
    'demo01.fab.basic.tooltip': 'Add',
    'demo01.fab.small.icon': 'mEdit',
    'demo01.fab.small.tooltip': 'Small FAB',
    'demo01.fab.large.icon': 'mCameraAlt',
    'demo01.fab.large.tooltip': 'Large FAB',
    'demo01.fab.compose.icon': 'mEdit',
    'demo01.fab.compose.label': 'Compose',
    'demo01.fab.create.icon': 'mAdd',
    'demo01.fab.create.label': 'Create New',
    'demo01.fab.tertiary.icon': 'mStar',
    'demo01.fab.tertiary.tooltip': 'Tertiary color',
    'demo01.fab.error.icon': 'mDelete',
    'demo01.fab.error.tooltip': 'Error color',

    // ==========================================================================
    // Demo 01: TomSegmentedButton Card
    // ==========================================================================
    'demo01.segmented.icon': 'mSegment',
    'demo01.segmented.title.label': 'TomSegmentedButton',
    'demo01.segmented.description.label':
        'Single or multi-select from a set of options.',
    'demo01.segmented.day.label': 'Day',
    'demo01.segmented.day.icon': 'mCalendarViewDay',
    'demo01.segmented.week.label': 'Week',
    'demo01.segmented.week.icon': 'mCalendarViewWeek',
    'demo01.segmented.month.label': 'Month',
    'demo01.segmented.month.icon': 'mCalendarViewMonth',
    'demo01.segmented.bold.label': 'Bold',
    'demo01.segmented.bold.icon': 'mFormatBold',
    'demo01.segmented.italic.label': 'Italic',
    'demo01.segmented.italic.icon': 'mFormatItalic',
    'demo01.segmented.underline.label': 'Underline',
    'demo01.segmented.underline.icon': 'mFormatUnderline',
    'demo01.segmented.list.icon': 'mViewList',
    'demo01.segmented.grid.icon': 'mGridView',
    'demo01.segmented.module.icon': 'mViewModule',

    // ==========================================================================
    // Demo 01: Menu Buttons Card
    // ==========================================================================
    'demo01.menu.icon': 'mMenu',
    'demo01.menu.title.label': 'Menu Buttons',
    'demo01.menu.description.label':
        'Menu anchors and submenu button examples.',
    'demo01.menu.trigger.label': 'Open Menu',
    'demo01.menu.trigger.icon': 'mMenu',
    'demo01.menu.cut.label': 'Cut',
    'demo01.menu.cut.icon': 'mContentCut',
    'demo01.menu.copy.label': 'Copy',
    'demo01.menu.copy.icon': 'mContentCopy',
    'demo01.menu.paste.label': 'Paste',
    'demo01.menu.paste.icon': 'mContentPaste',
    'demo01.menu.selectAll.label': 'Select All',
    'demo01.menu.selectAll.icon': 'mSelectAll',
    'demo01.submenu.trigger.label': 'File Menu',
    'demo01.submenu.trigger.icon': 'mMenuOpen',
    'demo01.submenu.file.label': 'File',
    'demo01.submenu.new.label': 'New',
    'demo01.submenu.new.icon': 'mAdd',
    'demo01.submenu.open.label': 'Open',
    'demo01.submenu.open.icon': 'mFolderOpen',
    'demo01.submenu.openRecent.label': 'Recent Files',
    'demo01.submenu.openBrowse.label': 'Browse...',
    'demo01.submenu.export.label': 'Export',
    'demo01.submenu.export.icon': 'mIosShare',
    'demo01.submenu.exportPdf.label': 'Export as PDF',
    'demo01.submenu.exportCsv.label': 'Export as CSV',
    'demo01.submenu.exportJson.label': 'Export as JSON',
    'demo01.popup.view.label': 'View',
    'demo01.popup.edit.label': 'Edit',
    'demo01.popup.delete.label': 'Delete',

    // ==========================================================================
    // Demo 01: Navigation Buttons Card
    // ==========================================================================
    'demo01.navigation.icon': 'mNavigation',
    'demo01.navigation.title.label': 'Navigation Buttons',
    'demo01.navigation.description.label':
        'Back, close, and expand buttons for navigation.',
    'demo01.navigation.back.tooltip': 'Go back',
    'demo01.navigation.close.tooltip': 'Close',
    'demo01.expand.expand.label': 'Click to expand',
    'demo01.expand.collapse.label': 'Click to collapse',
    'demo01.context.back.tooltip': 'Back',
    'demo01.context.title.label': 'Context Bar Title',
    'demo01.context.more.icon': 'mMoreVert',
    'demo01.context.more.tooltip': 'More options',

    // ==========================================================================
    // Demo 01: ACL Layout Section (RTL/LTR)
    // ==========================================================================
    'demo01.section.acl.title.label': 'ACL Layout',
    'demo01.section.acl.subtitle.label':
        'AclBuilder-based button layouts that respond to RTL/LTR switching',
    'demo01.aclButtons.icon': 'mViewColumn',
    'demo01.aclButtons.title.label': 'ACL Button Layout',
    'demo01.aclButtons.description.label':
        'Buttons laid out with AclBuilder for automatic RTL support.',
    'demo01.aclButtons.primaryLabel.label': 'Primary Action:',
    'demo01.aclButtons.primary.label': 'Submit',
    'demo01.aclButtons.primary.icon': 'mSend',
    'demo01.aclButtons.secondaryLabel.label': 'Secondary Action:',
    'demo01.aclButtons.secondary.label': 'Edit',
    'demo01.aclButtons.secondary.icon': 'mEdit',
    'demo01.aclButtons.cancel.label': 'Cancel',
    'demo01.aclButtons.save.label': 'Save',
    'demo01.aclButtons.save.icon': 'mSave',
    'demo01.aclIconRow.icon': 'mViewHeadline',
    'demo01.aclIconRow.title.label': 'ACL Icon Row',
    'demo01.aclIconRow.description.label':
        'Icon buttons in a toolbar-style layout with ACL.',
    'demo01.aclIconRow.back.icon': 'mArrowBack',
    'demo01.aclIconRow.back.tooltip': 'Go back',
    'demo01.aclIconRow.pageTitle.label': 'Page Title',
    'demo01.aclIconRow.settings.icon': 'mSettings',
    'demo01.aclIconRow.settings.tooltip': 'Settings',
    'demo01.aclIconRow.menu.icon': 'mMoreVert',
    'demo01.aclIconRow.menu.tooltip': 'Menu',
    'demo01.aclIconRow.fabLabel.label': 'Quick action:',
    'demo01.aclIconRow.fab.icon': 'mAdd',
    'demo01.aclIconRow.fab.tooltip': 'Add new item',

    // ==========================================================================
    // Demo 02: Text Inputs - Section Headers
    // ==========================================================================
    'demo02.section.standard.title.label': 'Standard Text Fields',
    'demo02.section.standard.subtitle.label':
        'TomTextField and TomTextFormField for basic text input',
    'demo02.section.search.title.label': 'Search & Autocomplete',
    'demo02.section.search.subtitle.label':
        'Search bars, anchors, and type-ahead suggestions',
    'demo02.section.cupertino.title.label': 'Cupertino Text Inputs',
    'demo02.section.cupertino.subtitle.label':
        'iOS-style text fields and search inputs',
    'demo02.section.datetime.title.label': 'Date & Time Pickers',
    'demo02.section.datetime.subtitle.label':
        'Calendar, date and time selection widgets',

    // ==========================================================================
    // Demo 02: TomTextField Card
    // ==========================================================================
    'demo02.textfield.icon': 'mTextFields',
    'demo02.textfield.title.label': 'TomTextField',
    'demo02.textfield.description.label':
        'Standard Material text input field with label and hint support.',
    'demo02.textfield.basic.label': 'Full Name',
    'demo02.textfield.basic.hint': 'Enter your full name',
    'demo02.textfield.price.label': 'Price',
    'demo02.textfield.price.hint': 'Enter amount',
    'demo02.textfield.password.label': 'Password',
    'demo02.textfield.password.hint': 'Enter your password',
    'demo02.textfield.passwordToggle.icon': 'mVisibility',
    'demo02.textfield.passwordToggle.tooltip': 'Toggle password visibility',
    'demo02.textfield.multiline.label': 'Notes',
    'demo02.textfield.multiline.hint': 'Enter additional notes',
    'demo02.textfield.disabled.label': 'Disabled Field',
    'demo02.textfield.disabled.hint': 'This field is disabled',
    'demo02.textfield.readonly.label': 'Read-Only Field',
    'demo02.textfield.readonly.hint': 'This value cannot be changed',

    // ==========================================================================
    // Demo 02: TomTextFormField Card
    // ==========================================================================
    'demo02.formfield.icon': 'mAssignment',
    'demo02.formfield.title.label': 'TomTextFormField',
    'demo02.formfield.description.label':
        'Form-integrated text field with validation support.',
    'demo02.formfield.email.label': 'Email Address',
    'demo02.formfield.email.hint': 'you@example.com',
    'demo02.formfield.required.label': 'Required Field',
    'demo02.formfield.required.hint': 'This field is required',
    'demo02.formfield.phone.label': 'Phone Number',
    'demo02.formfield.phone.hint': '+1 (555) 000-0000',
    'demo02.formfield.validate.label': 'Validate Form',
    'demo02.formfield.validate.icon': 'mCheck',

    // ==========================================================================
    // Demo 02: TomSearchBar Card
    // ==========================================================================
    'demo02.searchbar.icon': 'mSearch',
    'demo02.searchbar.title.label': 'TomSearchBar & TomSearchAnchor',
    'demo02.searchbar.description.label':
        'Material 3 search bars with suggestion support.',
    'demo02.searchbar.basic.hint': 'Search...',
    'demo02.searchbar.mic.icon': 'mMic',
    'demo02.searchbar.mic.tooltip': 'Voice search',
    'demo02.searchbar.anchor.hint': 'Search countries...',
    'demo02.searchbar.anchorBar.hint': 'Search countries...',

    // ==========================================================================
    // Demo 02: TomAutocomplete Card
    // ==========================================================================
    'demo02.autocomplete.icon': 'mAutoAwesome',
    'demo02.autocomplete.title.label': 'TomAutocomplete',
    'demo02.autocomplete.description.label':
        'Type-ahead text field with suggestions.',
    'demo02.autocomplete.country.label': 'Country',
    'demo02.autocomplete.country.hint': 'Start typing a country name',

    // ==========================================================================
    // Demo 02: Country Data (for Autocomplete)
    // ==========================================================================
    'demo02.countries.us': 'United States',
    'demo02.countries.uk': 'United Kingdom',
    'demo02.countries.ca': 'Canada',
    'demo02.countries.au': 'Australia',
    'demo02.countries.de': 'Germany',
    'demo02.countries.fr': 'France',
    'demo02.countries.jp': 'Japan',
    'demo02.countries.br': 'Brazil',
    'demo02.countries.in': 'India',
    'demo02.countries.cn': 'China',

    // ==========================================================================
    // Demo 02: TomCupertinoTextField Card
    // ==========================================================================
    'demo02.cupertino.icon': 'mApple',
    'demo02.cupertino.title.label': 'Cupertino Text Fields',
    'demo02.cupertino.description.label':
        'iOS-style text inputs using TomCupertinoTextField.',
    'demo02.cupertino.basic.label': 'Name',
    'demo02.cupertino.basic.hint': 'Enter your name',
    'demo02.cupertino.decorated.label': 'Email',
    'demo02.cupertino.decorated.hint': 'Enter your email',
    'demo02.cupertino.formrow.label': 'Username',
    'demo02.cupertino.formrow.hint': 'Enter username',
    'demo02.cupertino.formrowPrefix.label': 'Username',

    // ==========================================================================
    // Demo 02: TomCupertinoSearchTextField Card
    // ==========================================================================
    'demo02.cupertinoSearch.icon': 'mSearch',
    'demo02.cupertinoSearch.title.label': 'Cupertino Search Fields',
    'demo02.cupertinoSearch.description.label':
        'iOS-style search inputs with TomCupertinoSearchTextField.',
    'demo02.cupertinoSearch.basic.hint': 'Search',
    'demo02.cupertinoSearch.styled.hint': 'Search with custom style',

    // ==========================================================================
    // Demo 02: Calendar & Date Pickers Card
    // ==========================================================================
    'demo02.calendar.icon': 'mCalendarToday',
    'demo02.calendar.title.label': 'Calendar & Date Pickers',
    'demo02.calendar.description.label':
        'Calendar view and date input fields.',
    'demo02.calendar.picker.label': 'Select Date',
    'demo02.calendar.selectedIcon': 'mEvent',
    'demo02.calendar.inputField.label': 'Date',
    'demo02.calendar.inputField.hint': 'MM/DD/YYYY',
    'demo02.calendar.yearPicker.label': 'Select Year',

    // ==========================================================================
    // Demo 02: Cupertino Date & Time Pickers Card
    // ==========================================================================
    'demo02.cupertinoDateTime.icon': 'mSchedule',
    'demo02.cupertinoDateTime.title.label': 'Cupertino Date & Time',
    'demo02.cupertinoDateTime.description.label':
        'iOS-style date and timer wheel pickers.',
    'demo02.cupertinoDateTime.dateLabel.label': 'Select Date',
    'demo02.cupertinoDateTime.datePicker.label': 'Date Picker',
    'demo02.cupertinoDateTime.timerLabel.label': 'Select Duration',
    'demo02.cupertinoDateTime.timerPicker.label': 'Timer Picker',
    'demo02.cupertinoDateTime.durationIcon': 'mTimer',

    // ==========================================================================
    // Demo 02: Duration Format Units
    // ==========================================================================
    'demo02.duration.hours': 'h',
    'demo02.duration.minutes': 'm',
    'demo02.duration.seconds': 's',

    // ==========================================================================
    // Demo 02: ACL Layout Section
    // ==========================================================================
    'demo02.section.acl.title.label': 'ACL Layout (RTL/LTR)',
    'demo02.section.acl.subtitle.label':
        'Using AclBuilder — toggle LTR/RTL in the app bar to see layout direction change',

    // ACL Text Fields Card
    'demo02.aclTextField.icon': 'mViewQuilt',
    'demo02.aclTextField.title.label': 'ACL Text Field Layout',
    'demo02.aclTextField.description.label':
        'Form fields using AclBuilder for responsive left-to-right/right-to-left layout.',
    'demo02.aclTextField.nameLabel.label': 'Name:',
    'demo02.aclTextField.name.label': 'Full Name',
    'demo02.aclTextField.name.hint': 'Enter your full name',
    'demo02.aclTextField.emailLabel.label': 'Email:',
    'demo02.aclTextField.email.label': 'Email',
    'demo02.aclTextField.email.hint': 'you@example.com',
    'demo02.aclTextField.city.label': 'City',
    'demo02.aclTextField.city.hint': 'City name',
    'demo02.aclTextField.zip.label': 'ZIP',
    'demo02.aclTextField.zip.hint': 'ZIP code',

    // ACL Date Picker Card
    'demo02.aclDatePicker.icon': 'mCalendarMonth',
    'demo02.aclDatePicker.title.label': 'ACL Date Picker Layout',
    'demo02.aclDatePicker.description.label':
        'Date and duration display using AclBuilder for directional layout.',
    'demo02.aclDatePicker.label.label': 'Selected Date:',
    'demo02.aclDatePicker.durationLabel.label': 'Duration:',
    'demo02.aclDatePicker.timerIcon': 'mTimer',
    'demo02.aclDatePicker.calendar.label': 'Calendar',

    // ==========================================================================
    // Demo 03: Selection Controls - Section Headers
    // ==========================================================================
    'demo03.section.dropdown.title.label': 'Dropdown Menus',
    'demo03.section.dropdown.subtitle.label':
        'TomDropdownButton, TomDropdownMenu, and form field variants',
    'demo03.section.popup.title.label': 'Popup Menus',
    'demo03.section.popup.subtitle.label':
        'TomPopupMenuButton with dividers and checked items',
    'demo03.section.anchor.title.label': 'Menu Anchors',
    'demo03.section.anchor.subtitle.label':
        'TomMenuAnchor with checkbox and radio menu buttons',
    'demo03.section.cupertino.title.label': 'Cupertino Segmented Controls',
    'demo03.section.cupertino.subtitle.label':
        'iOS-style sliding and classic segmented controls',
    'demo03.section.acl.title.label': 'ACL Layout (RTL/LTR)',
    'demo03.section.acl.subtitle.label':
        'Using AclBuilder — toggle LTR/RTL in the app bar to see layout direction change',

    // ==========================================================================
    // Demo 03: TomDropdownButton Card
    // ==========================================================================
    'demo03.dropdownButton.icon': 'mArrowDropDown',
    'demo03.dropdownButton.title.label': 'TomDropdownButton',
    'demo03.dropdownButton.description.label':
        'Classic dropdown button with form field support.',
    'demo03.dropdownButton.categoryLabel.label': 'Category:',
    'demo03.dropdownButton.category.hint': 'Select a category',
    'demo03.dropdownButton.colorLabel.label': 'Select a color:',
    'demo03.dropdownButton.color.hint': 'Choose color',
    'demo03.dropdownButton.countryForm.label': 'Country',
    'demo03.dropdownButton.countryForm.hint': 'Select your country',
    'demo03.dropdownButton.validate.label': 'Validate',
    'demo03.dropdownButton.validate.icon': 'mCheck',

    // ==========================================================================
    // Demo 03: TomDropdownMenu Card
    // ==========================================================================
    'demo03.dropdownMenu.icon': 'mMenu',
    'demo03.dropdownMenu.title.label': 'TomDropdownMenu',
    'demo03.dropdownMenu.description.label':
        'Material 3 dropdown menus with search and icons.',
    'demo03.dropdownMenu.size.label': 'Size',
    'demo03.dropdownMenu.size.hint': 'Select size',
    'demo03.dropdownMenu.colorWithIcon.label': 'Color',
    'demo03.dropdownMenu.colorWithIcon.hint': 'Select color',
    'demo03.dropdownMenu.expanded.label': 'Category',
    'demo03.dropdownMenu.expanded.hint': 'Select category',

    // ==========================================================================
    // Demo 03: TomPopupMenuButton Card
    // ==========================================================================
    'demo03.popupMenu.icon': 'mMoreVert',
    'demo03.popupMenu.title.label': 'TomPopupMenuButton',
    'demo03.popupMenu.description.label':
        'Popup menus with icons, dividers, and custom triggers.',
    'demo03.popupMenu.basicLabel.label': 'Edit menu:',
    'demo03.popupMenu.basic.tooltip': 'Open edit menu',
    'demo03.popupMenu.copy.label': 'Copy',
    'demo03.popupMenu.copy.icon': 'mContentCopy',
    'demo03.popupMenu.cut.label': 'Cut',
    'demo03.popupMenu.cut.icon': 'mContentCut',
    'demo03.popupMenu.paste.label': 'Paste',
    'demo03.popupMenu.paste.icon': 'mContentPaste',
    'demo03.popupMenu.delete.label': 'Delete',
    'demo03.popupMenu.delete.icon': 'mDelete',
    'demo03.popupMenu.moreOptions.label': 'More Options',
    'demo03.popupMenu.customTrigger.tooltip': 'Open options menu',
    'demo03.popupMenu.view.label': 'View',
    'demo03.popupMenu.edit.label': 'Edit',
    'demo03.popupMenu.share.label': 'Share',

    // ==========================================================================
    // Demo 03: TomCheckedPopupMenuItem Card
    // ==========================================================================
    'demo03.checkedPopup.icon': 'mChecklist',
    'demo03.checkedPopup.title.label': 'Checked Popup Menu',
    'demo03.checkedPopup.description.label':
        'Popup menu items with checkmarks for toggle options.',
    'demo03.checkedPopup.viewLabel.label': 'View options:',
    'demo03.checkedPopup.viewIcon.icon': 'mVisibility',
    'demo03.checkedPopup.viewText.label': 'View',
    'demo03.checkedPopup.view.tooltip': 'Toggle view options',
    'demo03.checkedPopup.preview.label': 'Show Preview',
    'demo03.checkedPopup.details.label': 'Show Details',
    'demo03.checkedPopup.sidebar.label': 'Show Sidebar',

    // ==========================================================================
    // Demo 03: TomMenuAnchor Card
    // ==========================================================================
    'demo03.menuAnchor.icon': 'mMenuOpen',
    'demo03.menuAnchor.title.label': 'TomMenuAnchor',
    'demo03.menuAnchor.description.label':
        'Menu anchors with checkbox and radio menu buttons.',
    'demo03.menuAnchor.checkboxLabel.label': 'View toggles (checkbox menu):',
    'demo03.menuAnchor.checkboxTrigger.label': 'View Options',
    'demo03.menuAnchor.checkboxTrigger.icon': 'mChecklist',
    'demo03.menuAnchor.checkPreview.label': 'Show Preview',
    'demo03.menuAnchor.checkDetails.label': 'Show Details',
    'demo03.menuAnchor.checkSidebar.label': 'Show Sidebar',
    'demo03.menuAnchor.radioLabel.label': 'Select option (radio menu):',
    'demo03.menuAnchor.radioTrigger.label': 'Select Option',
    'demo03.menuAnchor.radioTrigger.icon': 'mRadioButtonChecked',
    'demo03.menuAnchor.radioOption1.label': 'Option One',
    'demo03.menuAnchor.radioOption2.label': 'Option Two',
    'demo03.menuAnchor.radioOption3.label': 'Option Three',

    // ==========================================================================
    // Demo 03: Cupertino Segmented Controls Card
    // ==========================================================================
    'demo03.cupertinoSegmented.icon': 'mSegment',
    'demo03.cupertinoSegmented.title.label': 'Cupertino Segmented Controls',
    'demo03.cupertinoSegmented.description.label':
        'iOS-style sliding and classic segmented controls.',
    'demo03.cupertinoSegmented.slidingLabel.label': 'Sliding Segmented Control:',
    'demo03.cupertinoSegmented.day.label': 'Day',
    'demo03.cupertinoSegmented.week.label': 'Week',
    'demo03.cupertinoSegmented.month.label': 'Month',
    'demo03.cupertinoSegmented.year.label': 'Year',
    'demo03.cupertinoSegmented.classicLabel.label': 'Classic Segmented Control:',
    'demo03.cupertinoSegmented.first.label': 'First',
    'demo03.cupertinoSegmented.second.label': 'Second',
    'demo03.cupertinoSegmented.third.label': 'Third',

    // ==========================================================================
    // Demo 03: Cupertino Picker Card
    // ==========================================================================
    'demo03.cupertinoPicker.icon': 'mUnfoldMore',
    'demo03.cupertinoPicker.title.label': 'Cupertino Picker',
    'demo03.cupertinoPicker.description.label':
        'iOS-style wheel picker for scrolling selection.',
    'demo03.cupertinoPicker.fruitLabel.label': 'Select a fruit:',
    'demo03.cupertinoPicker.selectedIcon.icon': 'mChecklist',

    // ==========================================================================
    // Demo 03: ACL Dropdown Layout Card
    // ==========================================================================
    'demo03.aclDropdown.icon': 'mViewColumn',
    'demo03.aclDropdown.title.label': 'ACL Dropdown Layout',
    'demo03.aclDropdown.description.label':
        'Dropdown fields using AclBuilder for responsive RTL/LTR layout.',
    'demo03.aclDropdown.categoryLabel.label': 'Category:',
    'demo03.aclDropdown.category.hint': 'Select category',
    'demo03.aclDropdown.category.label': 'Category',
    'demo03.aclDropdown.sizeLabel.label': 'Size:',
    'demo03.aclDropdown.size.hint': 'Select size',
    'demo03.aclDropdown.size.label': 'Size',

    // ==========================================================================
    // Demo 03: ACL Segmented Layout Card
    // ==========================================================================
    'demo03.aclSegmented.icon': 'mViewHeadline',
    'demo03.aclSegmented.title.label': 'ACL Segmented Layout',
    'demo03.aclSegmented.description.label':
        'Segmented controls with action buttons using AclBuilder.',
    'demo03.aclSegmented.periodLabel.label': 'Period:',
    'demo03.aclSegmented.day.label': 'Day',
    'demo03.aclSegmented.week.label': 'Week',
    'demo03.aclSegmented.month.label': 'Month',
    'demo03.aclSegmented.reset.label': 'Reset',
    'demo03.aclSegmented.reset.icon': 'mRefresh',
    'demo03.aclSegmented.apply.label': 'Apply',
    'demo03.aclSegmented.apply.icon': 'mCheck',

    // ==========================================================================
    // Demo 03: Sample Data - Categories
    // ==========================================================================
    'demo03.data.category.electronics.label': 'Electronics',
    'demo03.data.category.clothing.label': 'Clothing',
    'demo03.data.category.homeGarden.label': 'Home & Garden',
    'demo03.data.category.books.label': 'Books',
    'demo03.data.category.sports.label': 'Sports',

    // ==========================================================================
    // Demo 03: Sample Data - Colors (with emoji and color values)
    // ==========================================================================
    'demo03.data.color.red.label': 'Red',
    'demo03.data.color.red.emoji': '🔴',
    'demo03.data.color.red.color': 'mRed',
    'demo03.data.color.green.label': 'Green',
    'demo03.data.color.green.emoji': '🟢',
    'demo03.data.color.green.color': 'mGreen',
    'demo03.data.color.blue.label': 'Blue',
    'demo03.data.color.blue.emoji': '🔵',
    'demo03.data.color.blue.color': 'mBlue',
    'demo03.data.color.yellow.label': 'Yellow',
    'demo03.data.color.yellow.emoji': '🟡',
    'demo03.data.color.yellow.color': 'mAmber',
    'demo03.data.color.black.label': 'Black',
    'demo03.data.color.black.emoji': '⚫',
    'demo03.data.color.black.color': 'mBlack',

    // ==========================================================================
    // Demo 03: Sample Data - Sizes
    // ==========================================================================
    'demo03.data.size.xs.label': 'XS',
    'demo03.data.size.s.label': 'S',
    'demo03.data.size.m.label': 'M',
    'demo03.data.size.l.label': 'L',
    'demo03.data.size.xl.label': 'XL',
    'demo03.data.size.xxl.label': 'XXL',

    // ==========================================================================
    // Demo 03: Sample Data - Fruits
    // ==========================================================================
    'demo03.data.fruit.apple.label': 'Apple',
    'demo03.data.fruit.banana.label': 'Banana',
    'demo03.data.fruit.orange.label': 'Orange',
    'demo03.data.fruit.mango.label': 'Mango',
    'demo03.data.fruit.grape.label': 'Grape',
    'demo03.data.fruit.strawberry.label': 'Strawberry',
    'demo03.data.fruit.pineapple.label': 'Pineapple',
    'demo03.data.fruit.watermelon.label': 'Watermelon',

    // ==========================================================================
    // Demo 03: Sample Data - Countries
    // ==========================================================================
    'demo03.data.country.us.label': '🇺🇸 United States',
    'demo03.data.country.uk.label': '🇬🇧 United Kingdom',
    'demo03.data.country.de.label': '🇩🇪 Germany',
    'demo03.data.country.fr.label': '🇫🇷 France',
    'demo03.data.country.jp.label': '🇯🇵 Japan',

    // ==========================================================================
    // Demo 03: Status Display Labels
    // ==========================================================================
    'demo03.status.preview.label': 'Preview',
    'demo03.status.details.label': 'Details',
    'demo03.status.sidebar.label': 'Sidebar',
    'demo03.status.on.label': 'ON',
    'demo03.status.off.label': 'OFF',
    'demo03.status.selected.label': 'Selected',
    'demo03.status.sliding.label': 'Sliding',
    'demo03.status.classic.label': 'Classic',
    // ==========================================================================
    // Demo 04: Toggles - Section Headers
    // ==========================================================================
    'demo04.section.switch.title.label': 'Switch Controls',
    'demo04.section.switch.subtitle.label':
        'Binary on/off toggles for settings and preferences',
    'demo04.section.checkbox.title.label': 'Checkbox Controls',
    'demo04.section.checkbox.subtitle.label':
        'Multi-select and boolean option controls',
    'demo04.section.radio.title.label': 'Radio Controls',
    'demo04.section.radio.subtitle.label':
        'Single selection from multiple options',
    'demo04.section.toggleButtons.title.label': 'Toggle Button Groups',
    'demo04.section.toggleButtons.subtitle.label':
        'Grouped toggle selections with single and multi-select modes',
    'demo04.section.acl.title.label': 'ACL Toggle Layout',
    'demo04.section.acl.subtitle.label':
        'Toggle controls with RTL/LTR adaptive layout',

    // ==========================================================================
    // Demo 04: TomSwitch Card
    // ==========================================================================
    'demo04.switch.icon': 'mToggleOn',
    'demo04.switch.title.label': 'TomSwitch',
    'demo04.switch.description.label':
        'Material switch control with customizable colors and thumb icons.',
    'demo04.switch.defaultLabel.label': 'Default state:',
    'demo04.switch.thumbIconLabel.label': 'With thumb icon:',
    'demo04.switch.disabledLabel.label': 'Disabled:',
    'demo04.switch.customColorLabel.label': 'Custom colors:',

    // ==========================================================================
    // Demo 04: TomSwitchListTile Card
    // ==========================================================================
    'demo04.switchListTile.icon': 'mList',
    'demo04.switchListTile.title.label': 'TomSwitchListTile',
    'demo04.switchListTile.description.label':
        'Switch integrated in a list tile with title and subtitle.',
    'demo04.switchListTile.notifications.label': 'Notifications',
    'demo04.switchListTile.notifications.subtitle.label':
        'Receive push notifications',
    'demo04.switchListTile.darkMode.label': 'Dark Mode',
    'demo04.switchListTile.darkMode.subtitle.label': 'Enable dark theme',
    'demo04.switchListTile.location.label': 'Location Services',
    'demo04.switchListTile.location.subtitle.label':
        'Allow location tracking',

    // ==========================================================================
    // Demo 04: TomCupertinoSwitch Card
    // ==========================================================================
    'demo04.cupertinoSwitch.icon': 'mPhoneIphone',
    'demo04.cupertinoSwitch.title.label': 'TomCupertinoSwitch',
    'demo04.cupertinoSwitch.description.label':
        'iOS-style switch control with platform-native appearance.',
    'demo04.cupertinoSwitch.defaultLabel.label': 'Default Cupertino switch:',
    'demo04.cupertinoSwitch.themedLabel.label': 'Themed Cupertino switch:',

    // ==========================================================================
    // Demo 04: TomCheckbox Card
    // ==========================================================================
    'demo04.checkbox.icon': 'mCheckBox',
    'demo04.checkbox.title.label': 'TomCheckbox',
    'demo04.checkbox.description.label':
        'Boolean checkbox with tristate, custom colors, and shapes.',
    'demo04.checkbox.statesLabel.label': 'States:',
    'demo04.checkbox.variantsLabel.label': 'Variants:',
    'demo04.checkbox.customColor.label': 'Custom color',
    'demo04.checkbox.rounded.label': 'Rounded',
    'demo04.checkbox.disabled.label': 'Disabled',

    // ==========================================================================
    // Demo 04: TomCheckboxListTile Card
    // ==========================================================================
    'demo04.checkboxListTile.icon': 'mChecklist',
    'demo04.checkboxListTile.title.label': 'TomCheckboxListTile',
    'demo04.checkboxListTile.description.label':
        'Checkbox integrated in list tile with title and subtitle.',
    'demo04.checkboxListTile.categoriesLabel.label': 'Select categories:',
    'demo04.checkboxListTile.technology.label': 'Technology',
    'demo04.checkboxListTile.technology.subtitle.label':
        'Latest tech news and reviews',
    'demo04.checkboxListTile.science.label': 'Science',
    'demo04.checkboxListTile.science.subtitle.label':
        'Scientific discoveries and research',
    'demo04.checkboxListTile.business.label': 'Business',
    'demo04.checkboxListTile.business.subtitle.label':
        'Market updates and analysis',
    'demo04.checkboxListTile.positionLabel.label':
        'Leading checkbox position:',
    'demo04.checkboxListTile.leading.label': 'Leading checkbox',

    // ==========================================================================
    // Demo 04: TomCupertinoCheckbox Card
    // ==========================================================================
    'demo04.cupertinoCheckbox.icon': 'mCheckBoxOutlineBlank',
    'demo04.cupertinoCheckbox.title.label': 'TomCupertinoCheckbox',
    'demo04.cupertinoCheckbox.description.label':
        'iOS-style checkbox with Cupertino design language.',

    // ==========================================================================
    // Demo 04: TomRadio Card
    // ==========================================================================
    'demo04.radio.icon': 'mRadioButtonChecked',
    'demo04.radio.title.label': 'TomRadio',
    'demo04.radio.description.label':
        'Mutually exclusive radio buttons for single selection.',
    'demo04.radio.paymentLabel.label': 'Payment method:',
    'demo04.radio.payment.credit.label': 'Credit Card',
    'demo04.radio.payment.paypal.label': 'PayPal',
    'demo04.radio.payment.bank.label': 'Bank Transfer',
    'demo04.radio.payment.cash.label': 'Cash on Delivery',
    'demo04.radio.sizeLabel.label': 'Shirt size (horizontal):',

    // ==========================================================================
    // Demo 04: TomRadioListTile Card
    // ==========================================================================
    'demo04.radioListTile.icon': 'mLocalShipping',
    'demo04.radioListTile.title.label': 'TomRadioListTile',
    'demo04.radioListTile.description.label':
        'Radio button integrated in list tile with description.',
    'demo04.radioListTile.shippingLabel.label': 'Shipping method:',
    'demo04.radioListTile.standard.label': 'Standard Shipping',
    'demo04.radioListTile.standard.subtitle.label':
        '5-7 business days \u2022 Free',
    'demo04.radioListTile.express.label': 'Express Shipping',
    'demo04.radioListTile.express.subtitle.label':
        '2-3 business days \u2022 \$9.99',
    'demo04.radioListTile.nextDay.label': 'Next Day Delivery',
    'demo04.radioListTile.nextDay.subtitle.label':
        '1 business day \u2022 \$19.99',

    // ==========================================================================
    // Demo 04: TomCupertinoRadio Card
    // ==========================================================================
    'demo04.cupertinoRadio.icon': 'mRadioButtonUnchecked',
    'demo04.cupertinoRadio.title.label': 'TomCupertinoRadio',
    'demo04.cupertinoRadio.description.label':
        'iOS-style radio button with Cupertino appearance.',

    // ==========================================================================
    // Demo 04: TomToggleButtons Card
    // ==========================================================================
    'demo04.toggleButtons.icon': 'mViewWeek',
    'demo04.toggleButtons.title.label': 'TomToggleButtons',
    'demo04.toggleButtons.description.label':
        'Grouped toggle selection with single/multi-select and custom styling.',
    'demo04.toggleButtons.singleLabel.label':
        'Single select (exclusive):',
    'demo04.toggleButtons.multiLabel.label':
        'Multi select (non-exclusive) \u2014 text formatting:',
    'demo04.toggleButtons.verticalLabel.label': 'Vertical layout:',
    'demo04.toggleButtons.customLabel.label': 'Custom styling:',

    // ==========================================================================
    // Demo 04: ACL Toggle Layout Card
    // ==========================================================================
    'demo04.aclToggle.icon': 'mSwapHoriz',
    'demo04.aclToggle.title.label': 'ACL Toggle Layout',
    'demo04.aclToggle.description.label':
        'Toggle controls with RTL/LTR adaptive layout using AclBuilder.',
    'demo04.aclToggle.enableLabel.label': 'Enable feature:',
    'demo04.aclToggle.agreeLabel.label': 'I agree to terms:',
    'demo04.aclToggle.chooseLabel.label': 'Choose option:',
    'demo04.aclToggle.option1.label': 'Option 1',
    'demo04.aclToggle.option2.label': 'Option 2',
    'demo04.aclToggle.option3.label': 'Option 3',
    'demo04.aclToggle.reset.label': 'Reset',
    'demo04.aclToggle.apply.label': 'Apply',

    // =========================================================================
    // Demo 05: Slider & Range Controls
    // =========================================================================

    // Section headers
    'demo05.section.basic.title.label': 'Basic Sliders',
    'demo05.section.basic.subtitle.label':
        'Single-value continuous and discrete sliders',
    'demo05.section.range.title.label': 'Range Sliders',
    'demo05.section.range.subtitle.label':
        'Dual-value range selection controls',
    'demo05.section.cupertino.title.label': 'Cupertino Sliders',
    'demo05.section.cupertino.subtitle.label':
        'iOS-style slider controls',
    'demo05.section.applications.title.label': 'Slider Applications',
    'demo05.section.applications.subtitle.label':
        'Real-world slider use cases',
    'demo05.section.acl.title.label': 'ACL Layout',
    'demo05.section.acl.subtitle.label':
        'Slider controls with RTL/LTR adaptive layout',

    // Card: Basic Sliders
    'demo05.basicSlider.icon.icon': 'tune',
    'demo05.basicSlider.title.label': 'TomSlider',
    'demo05.basicSlider.description.label':
        'Standard Material slider with continuous and discrete modes.',
    'demo05.basicSlider.basicLabel.label': 'Basic continuous slider:',
    'demo05.basicSlider.volumeLabel.label': 'With label:',
    'demo05.basicSlider.volumeName.label': 'Volume',
    'demo05.basicSlider.discreteLabel.label':
        'With divisions (discrete):',
    'demo05.basicSlider.valueLabelTitle.label':
        'With value label overlay:',
    'demo05.basicSlider.customLabel.label':
        'Custom track and thumb styling:',
    'demo05.basicSlider.disabledLabel.label': 'Disabled slider:',

    // Card: Range Sliders
    'demo05.rangeSlider.icon.icon': 'compare_arrows',
    'demo05.rangeSlider.title.label': 'TomRangeSlider',
    'demo05.rangeSlider.description.label':
        'Dual-thumb range selection for price, age, and time.',
    'demo05.rangeSlider.priceLabel.label': 'Price range:',
    'demo05.rangeSlider.priceRangeLabel.label': 'to',
    'demo05.rangeSlider.ageLabel.label': 'Age range (discrete):',
    'demo05.rangeSlider.timeLabel.label': 'Time range:',
    'demo05.rangeSlider.disabledLabel.label': 'Disabled range slider:',

    // Card: Cupertino Sliders
    'demo05.cupertinoSlider.icon.icon': 'phone_iphone',
    'demo05.cupertinoSlider.title.label': 'TomCupertinoSlider',
    'demo05.cupertinoSlider.description.label':
        'iOS-style slider with min/max icons and custom colors.',
    'demo05.cupertinoSlider.brightnessLabel.label': 'Brightness:',
    'demo05.cupertinoSlider.volumeLabel.label': 'Volume:',
    'demo05.cupertinoSlider.customLabel.label': 'Custom colors:',
    'demo05.cupertinoSlider.displayLabel.label': 'With value display:',

    // Card: Audio Player
    'demo05.audioPlayer.icon.icon': 'music_note',
    'demo05.audioPlayer.title.label': 'Audio Player',
    'demo05.audioPlayer.description.label':
        'Music player with progress and volume sliders.',
    'demo05.audioPlayer.nowPlaying.label': 'Now Playing',
    'demo05.audioPlayer.trackInfo.label':
        'Summer Breeze — The Wanderers',
    'demo05.audioPlayer.volumeName.label': 'Volume:',

    // Card: Color Picker
    'demo05.colorPicker.icon.icon': 'palette',
    'demo05.colorPicker.title.label': 'RGB Color Picker',
    'demo05.colorPicker.description.label':
        'Color selection with individual R, G, B channel sliders.',
    'demo05.colorPicker.previewLabel.label': 'Preview:',

    // Card: Image Adjustments
    'demo05.imageAdjust.icon.icon': 'photo_filter',
    'demo05.imageAdjust.title.label': 'Image Adjustments',
    'demo05.imageAdjust.description.label':
        'Brightness, contrast, saturation, and exposure controls.',
    'demo05.imageAdjust.brightness.label': 'Brightness',
    'demo05.imageAdjust.contrast.label': 'Contrast',
    'demo05.imageAdjust.saturation.label': 'Saturation',
    'demo05.imageAdjust.exposure.label': 'Exposure',
    'demo05.imageAdjust.reset.label': 'Reset All',

    // Card: ACL Slider Layout
    'demo05.aclSlider.icon.icon': 'swap_horiz',
    'demo05.aclSlider.title.label': 'ACL Slider Layout',
    'demo05.aclSlider.description.label':
        'Slider controls with RTL/LTR adaptive layout using AclBuilder.',
    'demo05.aclSlider.sliderLabel.label': 'Value:',
    'demo05.aclSlider.rangeLabel.label': 'Range:',
    'demo05.aclSlider.cupertinoLabel.label': 'iOS:',
    'demo05.aclSlider.reset.label': 'Reset',
    'demo05.aclSlider.apply.label': 'Apply',

    // =========================================================================
    // Demo 06: Card & Panel Layouts
    // =========================================================================

    // Section headers
    'demo06.section.cards.title.label': 'Material Cards',
    'demo06.section.cards.subtitle.label':
        'Content containers with elevation and styling',
    'demo06.section.expansionTiles.title.label': 'Expansion Tiles',
    'demo06.section.expansionTiles.subtitle.label':
        'Expandable content sections',
    'demo06.section.expansionPanels.title.label': 'Expansion Panel Lists',
    'demo06.section.expansionPanels.subtitle.label':
        'Accordion-style panel groups',
    'demo06.section.materialInk.title.label': 'Material & Ink',
    'demo06.section.materialInk.subtitle.label':
        'Material Design surface widgets and ink effects',
    'demo06.section.acl.title.label': 'ACL Layout',
    'demo06.section.acl.subtitle.label':
        'Card controls with RTL/LTR adaptive layout',

    // Card: Card Variants
    'demo06.cardVariants.icon.icon': 'style',
    'demo06.cardVariants.title.label': 'TomCard',
    'demo06.cardVariants.description.label':
        'Standard Material card with elevated, outlined, and filled variants.',
    'demo06.cardVariants.elevatedLabel.label': 'Elevated card:',
    'demo06.cardVariants.elevatedTitle.label': 'Elevated Card',
    'demo06.cardVariants.elevatedDesc.label':
        'Card content with shadow elevation',
    'demo06.cardVariants.outlinedLabel.label': 'Outlined card:',
    'demo06.cardVariants.outlinedTitle.label': 'Outlined Card',
    'demo06.cardVariants.outlinedDesc.label':
        'Card with border outline',
    'demo06.cardVariants.filledLabel.label': 'Filled card:',
    'demo06.cardVariants.filledTitle.label': 'Filled Card',
    'demo06.cardVariants.filledDesc.label':
        'Card with filled surface color',
    'demo06.cardVariants.elevationLabel.label': 'Elevation comparison:',

    // Card: Product Card
    'demo06.productCard.icon.icon': 'shopping_bag',
    'demo06.productCard.title.label': 'Product Card',
    'demo06.productCard.description.label':
        'Composed card layouts with images, text, and actions.',
    'demo06.productCard.imagePlaceholder.label': 'Product Image',
    'demo06.productCard.productName.label': 'Wireless Headphones',
    'demo06.productCard.price.label': '\$99.99',
    'demo06.productCard.productDescription.label':
        'Premium noise-cancelling wireless headphones with 30h battery.',
    'demo06.productCard.rating.label': '(4.2)',
    'demo06.productCard.addToCart.label': 'Add to Cart',
    'demo06.productCard.actionCardLabel.label': 'Action card with horizontal layout:',
    'demo06.productCard.shippingTitle.label': 'Free Shipping',
    'demo06.productCard.shippingDesc.label':
        'Orders over \$50 ship free. Estimated delivery 3-5 days.',

    // Card: Expansion Tiles
    'demo06.expansionTile.icon.icon': 'expand_more',
    'demo06.expansionTile.title.label': 'TomExpansionTile',
    'demo06.expansionTile.description.label':
        'Expandable sections with leading icons and nested tiles.',
    'demo06.expansionTile.addressName.label': 'John Doe',
    'demo06.expansionTile.addressLine1.label': '123 Main Street',
    'demo06.expansionTile.addressLine2.label': 'New York, NY 10001',
    'demo06.expansionTile.addressCountry.label': 'United States',
    'demo06.expansionTile.editAddress.label': 'Edit Address',
    'demo06.expansionTile.cardInfo.label': 'Visa ending in 4242',
    'demo06.expansionTile.cardExpiry.label': 'Expires 12/2027',
    'demo06.expansionTile.nestedLabel.label': 'Nested expansion tiles:',
    'demo06.expansionTile.notifContent.label':
        'Configure push notifications, email alerts, and in-app messages.',
    'demo06.expansionTile.privacyContent.label':
        'Manage data sharing, cookie preferences, and account visibility.',

    // Card: Cupertino Expansion Tiles
    'demo06.cupertinoExpansion.icon.icon': 'phone_iphone',
    'demo06.cupertinoExpansion.title.label': 'TomCupertinoExpansionTile',
    'demo06.cupertinoExpansion.description.label':
        'iOS-style expansion tile with fade transitions.',

    // Card: Expansion Panel Lists
    'demo06.expansionPanel.icon.icon': 'view_agenda',
    'demo06.expansionPanel.title.label': 'TomExpansionPanelList',
    'demo06.expansionPanel.description.label':
        'Grouped expandable panels with accordion behavior.',
    'demo06.expansionPanel.faqTitle.label': 'Frequently Asked Questions:',

    // Card: Material
    'demo06.material.icon.icon': 'layers',
    'demo06.material.title.label': 'TomMaterial',
    'demo06.material.description.label':
        'Material surface with elevation, shape, and type variants.',
    'demo06.material.elevationLabel.label': 'Elevation levels:',
    'demo06.material.typesLabel.label': 'Material types:',
    'demo06.material.shapesLabel.label': 'Material shapes:',

    // Card: Ink
    'demo06.ink.icon.icon': 'water_drop',
    'demo06.ink.title.label': 'TomInk',
    'demo06.ink.description.label':
        'Ink splash effects and decorated surfaces.',
    'demo06.ink.splashLabel.label': 'Ink splash on tap:',
    'demo06.ink.tapHere.label': 'Tap to see ink splash',
    'demo06.ink.decorationLabel.label': 'Ink decoration:',
    'demo06.ink.decoratedInk.label': 'Ink with color decoration',
    'demo06.ink.gradientLabel.label': 'Ink with gradient:',
    'demo06.ink.gradientText.label': 'Gradient Ink Surface',

    // Card: ACL Layout
    'demo06.aclCard.icon.icon': 'swap_horiz',
    'demo06.aclCard.title.label': 'ACL Card Layout',
    'demo06.aclCard.description.label':
        'Card controls with RTL/LTR adaptive layout using AclBuilder.',
    'demo06.aclCard.elevationLabel.label': 'Elevation:',
    'demo06.aclCard.previewText.label': 'Preview Card',
    'demo06.aclCard.moreInfo.label':
        'This section demonstrates cards and expansion tiles within an '
        'AclBuilder layout that adapts automatically for RTL and LTR text '
        'directions.',
    'demo06.aclCard.reset.label': 'Reset',
    'demo06.aclCard.apply.label': 'Apply',

    // =========================================================================
    // Demo 07: Layout Containers
    // =========================================================================

    // Section headers
    'demo07.section.flex.title.label': 'Flex Layouts',
    'demo07.section.flex.subtitle.label':
        'Column, Row, and flex children for linear layouts',
    'demo07.section.stack.title.label': 'Stack & Positioned',
    'demo07.section.stack.subtitle.label':
        'Layered positioning with stacks and absolute placement',
    'demo07.section.size.title.label': 'Size & Constraints',
    'demo07.section.size.subtitle.label':
        'Controlling widget dimensions and layout bounds',
    'demo07.section.alignment.title.label': 'Alignment & Spacing',
    'demo07.section.alignment.subtitle.label':
        'Positioning, padding, and divider utilities',
    'demo07.section.acl.title.label': 'ACL Layout Demo',
    'demo07.section.acl.subtitle.label':
        'Adaptive layout controls with AclBuilder',

    // 7.1 - Column
    'demo07.column.icon.icon': 'view_agenda',
    'demo07.column.title.label': 'TomColumn',
    'demo07.column.description.label':
        'Vertical flex layout with alignment options.',
    'demo07.column.startLabel.label': 'MainAxisAlignment.start',
    'demo07.column.centerLabel.label': 'MainAxisAlignment.center',
    'demo07.column.spaceBetweenLabel.label': 'MainAxisAlignment.spaceBetween',

    // 7.1 - Row
    'demo07.row.icon.icon': 'view_week',
    'demo07.row.title.label': 'TomRow',
    'demo07.row.description.label':
        'Horizontal flex layout with alignment options.',
    'demo07.row.startLabel.label': 'MainAxisAlignment.start',
    'demo07.row.spaceEvenlyLabel.label': 'MainAxisAlignment.spaceEvenly',
    'demo07.row.endLabel.label': 'MainAxisAlignment.end',

    // 7.1 - Expanded / Flexible
    'demo07.expandedFlexible.icon.icon': 'expand',
    'demo07.expandedFlexible.title.label': 'TomExpanded & TomFlexible',
    'demo07.expandedFlexible.description.label':
        'Flex children with expansion and fit controls.',
    'demo07.expandedFlexible.fixedExpandedLabel.label': 'Fixed + Expanded',
    'demo07.expandedFlexible.flexRatioLabel.label': 'Flex ratios (1:2:3)',
    'demo07.expandedFlexible.flexibleLabel.label': 'FlexFit.loose vs .tight',

    // 7.1 - Spacer
    'demo07.spacer.icon.icon': 'space_bar',
    'demo07.spacer.title.label': 'TomSpacer',
    'demo07.spacer.description.label':
        'Flexible spacer that fills available space.',
    'demo07.spacer.demoLabel.label': 'Push items apart',
    'demo07.spacer.ratioLabel.label': 'Spacer ratios (1:2)',

    // 7.1 - Wrap
    'demo07.wrap.icon.icon': 'wrap_text',
    'demo07.wrap.title.label': 'TomWrap',
    'demo07.wrap.description.label':
        'Wrapping flow layout with spacing controls.',
    'demo07.wrap.demoLabel.label': 'Auto-wrapping tags',

    // 7.2 - Stack
    'demo07.stack.icon.icon': 'layers',
    'demo07.stack.title.label': 'TomStack',
    'demo07.stack.description.label':
        'Layered children with z-order stacking.',
    'demo07.stack.layeredLabel.label': 'Layered stack with badge',
    'demo07.stack.centeredText.label': 'Centered Content',

    // 7.2 - Positioned
    'demo07.positioned.icon.icon': 'control_camera',
    'demo07.positioned.title.label': 'TomPositioned',
    'demo07.positioned.description.label':
        'Absolute positioning within a Stack.',
    'demo07.positioned.cornersLabel.label': 'Corner positions',
    'demo07.positioned.directionalLabel.label':
        'PositionedDirectional (RTL-aware)',

    // 7.2 - IndexedStack
    'demo07.indexedStack.icon.icon': 'filter_none',
    'demo07.indexedStack.title.label': 'TomIndexedStack',
    'demo07.indexedStack.description.label':
        'Shows one child at a time, others stay offstage.',
    'demo07.indexedStack.selectorLabel.label': 'Select visible child:',

    // 7.3 - SizedBox
    'demo07.sizedBox.icon.icon': 'crop_free',
    'demo07.sizedBox.title.label': 'TomSizedBox',
    'demo07.sizedBox.description.label':
        'Fixed-size box with explicit dimensions.',
    'demo07.sizedBox.fixedLabel.label': 'Fixed dimensions',
    'demo07.sizedBox.expandLabel.label': 'Full-width expand',
    'demo07.sizedBox.expandText.label': 'Full width (double.infinity)',

    // 7.3 - ConstrainedBox
    'demo07.constrainedBox.icon.icon': 'settings_overscan',
    'demo07.constrainedBox.title.label': 'TomConstrainedBox',
    'demo07.constrainedBox.description.label':
        'Applies min/max width and height constraints.',
    'demo07.constrainedBox.demoLabel.label':
        'minWidth: 100, maxWidth: 300, minHeight: 50',
    'demo07.constrainedBox.contentText.label':
        'Constrained to min/max bounds',

    // 7.3 - FractionallySizedBox
    'demo07.fractionallySized.icon.icon': 'photo_size_select_large',
    'demo07.fractionallySized.title.label': 'TomFractionallySizedBox',
    'demo07.fractionallySized.description.label':
        'Sizes child as fraction of parent.',
    'demo07.fractionallySized.demoLabel.label': 'Percentage-based widths',

    // 7.3 - AspectRatio
    'demo07.aspectRatio.icon.icon': 'aspect_ratio',
    'demo07.aspectRatio.title.label': 'TomAspectRatio',
    'demo07.aspectRatio.description.label':
        'Maintains a fixed width-to-height ratio.',
    'demo07.aspectRatio.demoLabel.label': 'Aspect ratios: 16:9 and 1:1',

    // 7.3 - FittedBox
    'demo07.fittedBox.icon.icon': 'fit_screen',
    'demo07.fittedBox.title.label': 'TomFittedBox',
    'demo07.fittedBox.description.label':
        'Scales child to fit within bounds.',
    'demo07.fittedBox.demoLabel.label': 'BoxFit.contain vs .scaleDown',

    // 7.3 - Intrinsic
    'demo07.intrinsic.icon.icon': 'height',
    'demo07.intrinsic.title.label': 'TomIntrinsicHeight & Width',
    'demo07.intrinsic.description.label':
        'Sizes based on intrinsic child dimensions.',
    'demo07.intrinsic.heightLabel.label': 'IntrinsicHeight (equal row height)',
    'demo07.intrinsic.shortText.label': 'Short',
    'demo07.intrinsic.tallText.label':
        'Taller content that sets the intrinsic height for the entire row',
    'demo07.intrinsic.widthLabel.label':
        'IntrinsicWidth (equal column width)',
    'demo07.intrinsic.wideText.label': 'This is wider content',

    // 7.3 - Misc constraints
    'demo07.miscConstraint.icon.icon': 'tune',
    'demo07.miscConstraint.title.label': 'LimitedBox & OverflowBox',
    'demo07.miscConstraint.description.label':
        'Additional sizing and overflow controls.',
    'demo07.miscConstraint.limitedLabel.label':
        'TomLimitedBox (maxWidth: 100, maxHeight: 40)',
    'demo07.miscConstraint.overflowLabel.label':
        'TomOverflowBox (overflows parent)',
    'demo07.miscConstraint.overflowText.label':
        'I overflow my parent bounds!',

    // 7.4 - Center & Align
    'demo07.centerAlign.icon.icon': 'center_focus_strong',
    'demo07.centerAlign.title.label': 'TomCenter & TomAlign',
    'demo07.centerAlign.description.label':
        'Alignment wrappers for child positioning.',
    'demo07.centerAlign.centerLabel.label': 'TomCenter',
    'demo07.centerAlign.centeredText.label': 'Centered!',
    'demo07.centerAlign.alignLabel.label': 'TomAlign (various positions)',

    // 7.4 - Padding
    'demo07.padding.icon.icon': 'padding',
    'demo07.padding.title.label': 'TomPadding',
    'demo07.padding.description.label':
        'Spacing wrapper using EdgeInsets patterns.',
    'demo07.padding.uniformLabel.label': 'EdgeInsets.all(16)',
    'demo07.padding.symmetricLabel.label':
        'EdgeInsets.symmetric(h: 32, v: 8)',
    'demo07.padding.onlyLabel.label': 'EdgeInsets.only(left: 40, top: 20)',

    // 7.4 - Baseline
    'demo07.baseline.icon.icon': 'format_line_spacing',
    'demo07.baseline.title.label': 'TomBaseline',
    'demo07.baseline.description.label':
        'Text baseline alignment for mixed sizes.',
    'demo07.baseline.demoLabel.label': 'Baseline-aligned text sizes',

    // 7.4 - Divider
    'demo07.divider.icon.icon': 'horizontal_rule',
    'demo07.divider.title.label': 'TomDivider & TomVerticalDivider',
    'demo07.divider.description.label':
        'Horizontal and vertical separator lines.',
    'demo07.divider.horizontalLabel.label': 'Horizontal dividers',
    'demo07.divider.section1.label': 'Section 1 content',
    'demo07.divider.section2.label': 'Section 2 content',
    'demo07.divider.section3.label': 'Section 3 content',
    'demo07.divider.verticalLabel.label': 'Vertical dividers',
    'demo07.divider.col1.label': 'Column A',
    'demo07.divider.col2.label': 'Column B',
    'demo07.divider.col3.label': 'Column C',

    // 7.5 - ACL Layout
    'demo07.aclLayout.icon.icon': 'dashboard_customize',
    'demo07.aclLayout.title.label': 'ACL Layout Explorer',
    'demo07.aclLayout.description.label':
        'Interactive alignment controls with AclBuilder layout.',
    'demo07.aclLayout.mainAxisLabel.label': 'Main Axis:',
    'demo07.aclLayout.crossAxisLabel.label': 'Cross Axis:',
    'demo07.aclLayout.reset.label': 'Reset',
    'demo07.aclLayout.apply.label': 'Apply',

    // =========================================================================
    // Demo 08: Scrollable Containers
    // =========================================================================

    // Section headers
    'demo08.section.basicScroll.title.label': 'Basic Scroll Views',
    'demo08.section.basicScroll.subtitle.label':
        'Single-child scrollable containers and scrollbars',
    'demo08.section.nestedScroll.title.label': 'Nested Scroll Views',
    'demo08.section.nestedScroll.subtitle.label':
        'Coordinated scrolling between header and body',
    'demo08.section.draggable.title.label': 'Draggable & Interactive',
    'demo08.section.draggable.subtitle.label':
        'User-resizable sheets and zoomable viewers',
    'demo08.section.carousel.title.label': 'Carousel & Visibility',
    'demo08.section.carousel.subtitle.label':
        'Content carousels and visibility control widgets',
    'demo08.section.acl.title.label': 'ACL Scroll Demo',
    'demo08.section.acl.subtitle.label':
        'Adaptive scroll controls with AclBuilder',

    // 8.1 - SingleChildScrollView (vertical)
    'demo08.singleChildScroll.icon.icon': 'swap_vert',
    'demo08.singleChildScroll.title.label': 'TomSingleChildScrollView',
    'demo08.singleChildScroll.description.label':
        'Basic vertical scrolling container for long content.',
    'demo08.singleChildScroll.verticalLabel.label': 'Vertical scroll',

    // 8.1 - Horizontal scroll
    'demo08.horizontalScroll.icon.icon': 'swap_horiz',
    'demo08.horizontalScroll.title.label': 'Horizontal Scroll',
    'demo08.horizontalScroll.description.label':
        'Horizontal scrolling with SingleChildScrollView.',
    'demo08.horizontalScroll.label.label': 'Horizontal scroll',

    // 8.1 - Scrollbar
    'demo08.scrollbar.icon.icon': 'view_sidebar',
    'demo08.scrollbar.title.label': 'TomScrollbar',
    'demo08.scrollbar.description.label':
        'Material scrollbar with visible thumb and interactivity.',
    'demo08.scrollbar.label.label': 'Always-visible interactive scrollbar',

    // 8.1 - CupertinoScrollbar
    'demo08.cupertinoScrollbar.icon.icon': 'phone_iphone',
    'demo08.cupertinoScrollbar.title.label': 'TomCupertinoScrollbar',
    'demo08.cupertinoScrollbar.description.label':
        'iOS-style scrollbar with thin thumb.',
    'demo08.cupertinoScrollbar.label.label': 'Cupertino-style scrollbar',

    // 8.2 - NestedScrollView
    'demo08.nestedScroll.icon.icon': 'vertical_split',
    'demo08.nestedScroll.title.label': 'TomNestedScrollView',
    'demo08.nestedScroll.description.label':
        'Coordinated header collapse with tabbed body scrolling.',
    'demo08.nestedScroll.label.label':
        'Collapsible header with pinned tabs',

    // 8.3 - DraggableScrollableSheet
    'demo08.draggableSheet.icon.icon': 'drag_handle',
    'demo08.draggableSheet.title.label': 'TomDraggableScrollableSheet',
    'demo08.draggableSheet.description.label':
        'Bottom sheet that can be dragged to resize with snap points.',
    'demo08.draggableSheet.label.label':
        'Draggable sheet with snap points (20%, 40%, 85%)',
    'demo08.draggableSheet.backgroundText.label':
        'Drag the sheet below to resize',
    'demo08.draggableSheet.sheetTitle.label': 'Draggable Sheet',

    // 8.3 - InteractiveViewer
    'demo08.interactiveViewer.icon.icon': 'zoom_out_map',
    'demo08.interactiveViewer.title.label': 'TomInteractiveViewer',
    'demo08.interactiveViewer.description.label':
        'Pan and zoom viewport with pinch gestures.',
    'demo08.interactiveViewer.label.label':
        'Pinch to zoom, drag to pan (0.5x – 4x)',
    'demo08.interactiveViewer.contentText.label': 'Pan & Zoom Me',
    'demo08.interactiveViewer.hintText.label':
        'Pinch to zoom • Drag to pan',
    'demo08.interactiveViewer.resetButton.label': 'Reset View',

    // 8.4 - CarouselView
    'demo08.carousel.icon.icon': 'view_carousel',
    'demo08.carousel.title.label': 'TomCarouselView',
    'demo08.carousel.description.label':
        'Horizontal carousel with swipe navigation.',
    'demo08.carousel.label.label': 'Swipe carousel with tap handler',

    // 8.4 - Visibility
    'demo08.visibility.icon.icon': 'visibility',
    'demo08.visibility.title.label': 'TomVisibility',
    'demo08.visibility.description.label':
        'Logical visibility control with size maintenance options.',
    'demo08.visibility.label.label': 'Toggle visibility and size behavior',
    'demo08.visibility.beforeText.label': 'Content before',
    'demo08.visibility.targetText.label':
        'This content can be hidden!',
    'demo08.visibility.afterText.label': 'Content after',

    // 8.4 - Offstage
    'demo08.offstage.icon.icon': 'visibility_off',
    'demo08.offstage.title.label': 'TomOffstage',
    'demo08.offstage.description.label':
        'Removes widget from rendering entirely, no space occupied.',
    'demo08.offstage.label.label': 'Toggle offstage (no space when hidden)',
    'demo08.offstage.beforeText.label': 'Content before',
    'demo08.offstage.targetText.label':
        'This content goes completely offstage!',
    'demo08.offstage.afterText.label': 'Content after',

    // 8.4 - SafeArea
    'demo08.safeArea.icon.icon': 'fit_screen',
    'demo08.safeArea.title.label': 'TomSafeArea',
    'demo08.safeArea.description.label':
        'Insets child to avoid system UI (notch, status bar, etc.).',
    'demo08.safeArea.label.label': 'SafeArea insets demonstration',
    'demo08.safeArea.contentText.label': 'Safe area content',
    'demo08.safeArea.hintText.label':
        'On real devices, SafeArea avoids notch and system bars',

    // 8.5 - ACL Scroll
    'demo08.aclScroll.icon.icon': 'dashboard_customize',
    'demo08.aclScroll.title.label': 'ACL Scroll Explorer',
    'demo08.aclScroll.description.label':
        'Interactive scroll sheet controls with AclBuilder layout.',
    'demo08.aclScroll.sheetSizeLabel.label': 'Sheet Size:',
    'demo08.aclScroll.snapLabel.label': 'Snap:',
    'demo08.aclScroll.reset.label': 'Reset',
    'demo08.aclScroll.apply.label': 'Apply',

    // ==========================================================================
    // Demo 09: Dialogs - Section Headers
    // ==========================================================================
    'demo09.section.standard.title.label': 'Standard Dialogs',
    'demo09.section.standard.subtitle.label':
        'Alert and simple dialogs for user confirmation and selection',
    'demo09.section.sheets.title.label': 'Bottom Sheets',
    'demo09.section.sheets.subtitle.label':
        'Persistent and modal bottom sheets for contextual actions',
    'demo09.section.feedback.title.label': 'Feedback Overlays',
    'demo09.section.feedback.subtitle.label':
        'Snack bars, banners, and tooltips for transient feedback',
    'demo09.section.pickers.title.label': 'Pickers & Cupertino',
    'demo09.section.pickers.subtitle.label':
        'Date/time pickers and iOS-style dialogs',
    'demo09.section.acl.title.label': 'ACL Dialog Controls',
    'demo09.section.acl.subtitle.label':
        'Interactive dialog configuration with AclBuilder layout',

    // ==========================================================================
    // Demo 09: TomAlertDialog Card
    // ==========================================================================
    'demo09.alertDialog.icon.icon': 'mDialog',
    'demo09.alertDialog.title.label': 'TomAlertDialog',
    'demo09.alertDialog.description.label':
        'Material alert dialogs with title, content, and action buttons.',
    'demo09.alertDialog.resultLabel.label': 'Last action:',
    'demo09.alertDialog.basic.label': 'Basic Alert',
    'demo09.alertDialog.withIcon.label': 'With Icon',
    'demo09.alertDialog.scrollable.label': 'Scrollable',
    'demo09.alertDialog.cancel.label': 'Cancel',
    'demo09.alertDialog.confirm.label': 'Confirm',
    'demo09.alertDialog.dismiss.label': 'Dismiss',
    'demo09.alertDialog.proceed.label': 'Proceed',
    'demo09.alertDialog.decline.label': 'Decline',
    'demo09.alertDialog.accept.label': 'Accept',

    // ==========================================================================
    // Demo 09: TomSimpleDialog Card
    // ==========================================================================
    'demo09.simpleDialog.icon.icon': 'mList',
    'demo09.simpleDialog.title.label': 'TomSimpleDialog',
    'demo09.simpleDialog.description.label':
        'Simple selection dialog with a list of options.',
    'demo09.simpleDialog.resultLabel.label': 'Selected language:',
    'demo09.simpleDialog.show.label': 'Choose Language',

    // ==========================================================================
    // Demo 09: TomBottomSheet Card
    // ==========================================================================
    'demo09.bottomSheet.icon.icon': 'mDragHandle',
    'demo09.bottomSheet.title.label': 'TomBottomSheet',
    'demo09.bottomSheet.description.label':
        'Persistent bottom sheet that stays until explicitly closed.',
    'demo09.bottomSheet.resultLabel.label': 'Last selection:',
    'demo09.bottomSheet.show.label': 'Show Bottom Sheet',

    // ==========================================================================
    // Demo 09: TomModalBottomSheet Card
    // ==========================================================================
    'demo09.modalSheet.icon.icon': 'mWebAsset',
    'demo09.modalSheet.title.label': 'TomModalBottomSheet',
    'demo09.modalSheet.description.label':
        'Modal bottom sheets with barrier overlay and drag handle.',
    'demo09.modalSheet.resultLabel.label': 'Last action:',
    'demo09.modalSheet.basic.label': 'Basic Modal',
    'demo09.modalSheet.scrollable.label': 'Scrollable',

    // ==========================================================================
    // Demo 09: TomSnackBar Card
    // ==========================================================================
    'demo09.snackBar.icon.icon': 'mNotifications',
    'demo09.snackBar.title.label': 'TomSnackBar',
    'demo09.snackBar.description.label':
        'Transient feedback messages at the bottom of the screen.',
    'demo09.snackBar.countLabel.label': 'Snack bars shown:',
    'demo09.snackBar.basic.label': 'Basic',
    'demo09.snackBar.action.label': 'With Action',
    'demo09.snackBar.floating.label': 'Floating',

    // ==========================================================================
    // Demo 09: TomMaterialBanner Card
    // ==========================================================================
    'demo09.banner.icon.icon': 'mCampaign',
    'demo09.banner.title.label': 'TomMaterialBanner',
    'demo09.banner.description.label':
        'Persistent banner displayed at the top of the screen.',
    'demo09.banner.statusLabel.label': 'Banner status:',
    'demo09.banner.show.label': 'Show Banner',
    'demo09.banner.hide.label': 'Hide Banner',

    // ==========================================================================
    // Demo 09: TomTooltip Card
    // ==========================================================================
    'demo09.tooltip.icon.icon': 'mTooltip',
    'demo09.tooltip.title.label': 'TomTooltip',
    'demo09.tooltip.description.label':
        'Hover or long-press tooltips with plain or rich text.',
    'demo09.tooltip.hintLabel.label':
        'Hover or long-press the icons below to see tooltips.',

    // ==========================================================================
    // Demo 09: TomDatePickerDialog Card
    // ==========================================================================
    'demo09.datePicker.icon.icon': 'mCalendarMonth',
    'demo09.datePicker.title.label': 'TomDatePickerDialog',
    'demo09.datePicker.description.label':
        'Material date and time picker dialogs.',
    'demo09.datePicker.pickDate.label': 'Pick Date',
    'demo09.datePicker.pickTime.label': 'Pick Time',

    // ==========================================================================
    // Demo 09: TomCupertinoAlertDialog Card
    // ==========================================================================
    'demo09.cupertinoAlert.icon.icon': 'mPhoneIphone',
    'demo09.cupertinoAlert.title.label': 'TomCupertinoAlertDialog',
    'demo09.cupertinoAlert.description.label':
        'iOS-style alert dialogs with Cupertino styling.',
    'demo09.cupertinoAlert.infoLabel.label':
        'Cupertino dialogs follow iOS design patterns.',
    'demo09.cupertinoAlert.show.label': 'Standard',
    'demo09.cupertinoAlert.showDestructive.label': 'Destructive',

    // ==========================================================================
    // Demo 09: TomCupertinoActionSheet Card
    // ==========================================================================
    'demo09.cupertinoSheet.icon.icon': 'mViewAgenda',
    'demo09.cupertinoSheet.title.label': 'TomCupertinoActionSheet',
    'demo09.cupertinoSheet.description.label':
        'iOS-style action sheets with cancel button.',
    'demo09.cupertinoSheet.infoLabel.label':
        'Action sheets slide up from the bottom with iOS styling.',
    'demo09.cupertinoSheet.show.label': 'Show Action Sheet',

    // ==========================================================================
    // Demo 09: ACL Dialog Controls Card
    // ==========================================================================
    'demo09.aclDialog.icon.icon': 'dashboard_customize',
    'demo09.aclDialog.title.label': 'ACL Dialog Explorer',
    'demo09.aclDialog.description.label':
        'Interactive dialog controls with AclBuilder layout.',
    'demo09.aclDialog.typeLabel.label': 'Dialog Type:',
    'demo09.aclDialog.barrierLabel.label': 'Barrier Dismissible:',
    'demo09.aclDialog.launch.label': 'Launch Dialog',
    'demo09.aclDialog.reset.label': 'Reset',

    // ==========================================================================
    // Demo 10: Data Tables - Section Headers
    // ==========================================================================
    'demo10.section.dataTable.title.label': 'Data Tables',
    'demo10.section.dataTable.subtitle.label':
        'Sortable and selectable data tables with column headers',
    'demo10.section.paginated.title.label': 'Paginated Tables',
    'demo10.section.paginated.subtitle.label':
        'Large datasets with pagination and row-per-page controls',
    'demo10.section.table.title.label': 'Table Layouts',
    'demo10.section.table.subtitle.label':
        'Low-level table widget for custom grid layouts',
    'demo10.section.grid.title.label': 'Grid Views',
    'demo10.section.grid.subtitle.label':
        'Grid layouts with configurable cross-axis count',
    'demo10.section.acl.title.label': 'Reorderable Lists',
    'demo10.section.acl.subtitle.label':
        'Drag-and-drop reorderable lists with ACL builder layout',

    // ==========================================================================
    // Demo 10: TomDataTable Card
    // ==========================================================================
    'demo10.dataTable.icon.icon': 'mTableChart',
    'demo10.dataTable.title.label': 'TomDataTable',
    'demo10.dataTable.description.label':
        'Material design data table with sorting, selection, and custom cells.',
    'demo10.dataTable.selectedLabel.label': 'Selected:',
    'demo10.dataTable.clearSelection.label': 'Clear',
    'demo10.dataTable.col.id.label': 'ID',
    'demo10.dataTable.col.name.label': 'Name',
    'demo10.dataTable.col.category.label': 'Category',
    'demo10.dataTable.col.price.label': 'Price',
    'demo10.dataTable.col.stock.label': 'Stock',
    'demo10.dataTable.col.status.label': 'Status',

    // ==========================================================================
    // Demo 10: TomPaginatedDataTable Card
    // ==========================================================================
    'demo10.paginatedTable.icon.icon': 'mViewList',
    'demo10.paginatedTable.title.label': 'TomPaginatedDataTable',
    'demo10.paginatedTable.description.label':
        'Paginated data table for large datasets with navigation controls.',
    'demo10.paginatedTable.infoLabel.label':
        'Use pagination controls to navigate through data. Supports row-per-page selection.',
    'demo10.paginatedTable.header.label': 'Product Inventory',
    'demo10.paginatedTable.col.id.label': 'ID',
    'demo10.paginatedTable.col.name.label': 'Product',
    'demo10.paginatedTable.col.category.label': 'Category',
    'demo10.paginatedTable.col.price.label': 'Price',

    // ==========================================================================
    // Demo 10: TomTable Card
    // ==========================================================================
    'demo10.table.icon.icon': 'mGridOn',
    'demo10.table.title.label': 'TomTable',
    'demo10.table.description.label':
        'Low-level table widget for custom grid layouts with borders.',
    'demo10.table.infoLabel.label':
        'TomTable provides fine-grained control over table structure and styling.',

    // ==========================================================================
    // Demo 10: TomGridView Card
    // ==========================================================================
    'demo10.gridView.icon.icon': 'mApps',
    'demo10.gridView.title.label': 'TomGridView',
    'demo10.gridView.description.label':
        'Scrollable grid of widgets with configurable layout.',
    'demo10.gridView.columnsLabel.label': 'Columns:',

    // ==========================================================================
    // Demo 10: TomReorderableListView Card (ACL section)
    // ==========================================================================
    'demo10.reorderable.icon.icon': 'mDragIndicator',
    'demo10.reorderable.title.label': 'TomReorderableListView',
    'demo10.reorderable.description.label':
        'Drag-and-drop reorderable list with AclBuilder controls.',
    'demo10.reorderable.infoLabel.label':
        'Drag items by the handle to reorder. The current order is shown below.',
    'demo10.reorderable.reset.label': 'Reset Order',

    // ==========================================================================
    // Demo 11: Text & Label Display
    // ==========================================================================

    // Section Headers
    'demo11.section.text.title.label': 'Text Styles',
    'demo11.section.text.subtitle.label':
        'TomText widget with various typography styles and text formatting.',
    'demo11.section.rich.title.label': 'Rich & Selectable Text',
    'demo11.section.rich.subtitle.label':
        'TomRichText for styled spans and TomSelectableText for user selection.',
    'demo11.section.badge.title.label': 'Badges',
    'demo11.section.badge.subtitle.label':
        'TomBadge for notification counts and status indicators.',
    'demo11.section.listTile.title.label': 'List Tiles',
    'demo11.section.listTile.subtitle.label':
        'TomListTile for structured list items with icons and actions.',
    'demo11.section.chips.title.label': 'Chips',
    'demo11.section.chips.subtitle.label':
        'Chip variants for tags, filters, choices, and actions with ACL support.',

    // Demo Card: Text Styles
    'demo11.text.icon.icon': 'mTextFields',
    'demo11.text.title.label': 'TomText',
    'demo11.text.description.label':
        'Text widget with tomId-based resource resolution and typography styles.',
    'demo11.text.display.label': 'Display Text',
    'demo11.text.headline.label': 'Headline Text',
    'demo11.text.titleStyle.label': 'Title Text',
    'demo11.text.body.label': 'Body text for paragraphs and general content.',
    'demo11.text.bodySmall.label': 'Smaller body text for captions and hints.',
    'demo11.text.labelLarge.label': 'LABEL LARGE',
    'demo11.text.labelSmall.label': 'LABEL SMALL',
    'demo11.text.primary.label': 'Primary Color',
    'demo11.text.error.label': 'Error Color',
    'demo11.text.italic.label': 'Italic Style',
    'demo11.text.underline.label': 'Underlined',
    'demo11.text.overflow.label':
        'This is a very long text that will be truncated with an ellipsis when it overflows the available width.',

    // Demo Card: Rich Text
    'demo11.richText.icon.icon': 'mFormatColorText',
    'demo11.richText.title.label': 'TomRichText',
    'demo11.richText.description.label':
        'Rich text with multiple styles, colors, and formatting in a single text block.',

    // Demo Card: Selectable Text
    'demo11.selectableText.icon.icon': 'mSelectAll',
    'demo11.selectableText.title.label': 'TomSelectableText',
    'demo11.selectableText.description.label':
        'Text that users can select and copy. Supports custom cursors and styling.',
    'demo11.selectableText.basic.label':
        'This text can be selected and copied. Try highlighting it!',
    'demo11.selectableText.cursor.label':
        'Text with custom cursor color and width for better visibility.',
    'demo11.selectableText.multiline.label':
        'Multi-line selectable text that wraps across multiple lines. This demonstrates how TomSelectableText handles longer content that spans several lines while maintaining selectability throughout the entire block.',

    // Demo Card: Badges
    'demo11.badge.icon.icon': 'mNotifications',
    'demo11.badge.title.label': 'TomBadge',
    'demo11.badge.description.label':
        'Badges for displaying counts, notifications, and status indicators on icons.',
    'demo11.badge.dot.button.icon': 'mAccountCircle',
    'demo11.badge.custom.feature.label': 'Feature',
    'demo11.badge.custom.product.label': 'Product',

    // Demo Card: List Tiles
    'demo11.listTile.icon.icon': 'mList',
    'demo11.listTile.title.label': 'TomListTile',
    'demo11.listTile.description.label':
        'List tiles for displaying items with icons, titles, subtitles, and trailing widgets.',

    // Demo Card: Basic Chip
    'demo11.chip.icon.icon': 'mLabel',
    'demo11.chip.title.label': 'TomChip',
    'demo11.chip.description.label':
        'Basic chips for displaying tags and labels with optional avatars and delete actions.',

    // Demo Card: Filter Chip
    'demo11.filterChip.icon.icon': 'mFilterList',
    'demo11.filterChip.title.label': 'TomFilterChip',
    'demo11.filterChip.description.label':
        'Filter chips for multi-select filtering with checkmark indicators.',
    'demo11.filterChip.instruction.label': 'Select technologies to filter:',

    // Demo Card: Choice Chip
    'demo11.choiceChip.icon.icon': 'mRadioButtonChecked',
    'demo11.choiceChip.title.label': 'TomChoiceChip',
    'demo11.choiceChip.description.label':
        'Choice chips for single-select options like sizes or categories.',
    'demo11.choiceChip.instruction.label': 'Select a size:',

    // Demo Card: Action Chip
    'demo11.actionChip.icon.icon': 'mTouchApp',
    'demo11.actionChip.title.label': 'TomActionChip',
    'demo11.actionChip.description.label':
        'Action chips trigger operations like share, save, or copy.',

    // Demo Card: Input Chip
    'demo11.inputChip.icon.icon': 'mInput',
    'demo11.inputChip.title.label': 'TomInputChip',
    'demo11.inputChip.description.label':
        'Input chips for user-entered tags with select and delete support. ACL-aware layout.',
    'demo11.inputChip.instruction.label': 'Manage your tags (supports RTL):',

    // ==========================================================================
    // Demo 12: Image & Icon Gallery
    // ==========================================================================

    // Section Headers
    'demo12.section.icons.title.label': 'Icons',
    'demo12.section.icons.subtitle.label':
        'TomIcon widget with sizes, colors, and tomId-based resolution.',
    'demo12.section.images.title.label': 'Images',
    'demo12.section.images.subtitle.label':
        'TomNetworkImage for loading images from URLs with fit modes.',
    'demo12.section.avatars.title.label': 'Circle Avatars',
    'demo12.section.avatars.subtitle.label':
        'TomCircleAvatar for user profiles with initials, icons, or images.',
    'demo12.section.fadeIn.title.label': 'FadeIn Images',
    'demo12.section.fadeIn.subtitle.label':
        'TomFadeInImage for smooth placeholder-to-image transitions.',
    'demo12.section.animated.title.label': 'Animated Icons & Effects',
    'demo12.section.animated.subtitle.label':
        'TomAnimatedIcon and TomImageFiltered for dynamic effects with ACL support.',

    // Demo Card: Icons
    'demo12.icon.icon.icon': 'mAutoAwesome',
    'demo12.icon.title.label': 'TomIcon',
    'demo12.icon.description.label':
        'Icon widget with tomId-based resolution, sizes, and colors.',
    'demo12.icon.sizeLabel.label': 'Icon Sizes',
    'demo12.icon.colorLabel.label': 'Colored Icons',
    'demo12.icon.categoriesLabel.label': 'Icon Categories',
    'demo12.icon.resolvedLabel.label': 'TomId-Resolved Icons',
    'demo12.icon.resolved.save.icon': 'mSave',
    'demo12.icon.resolved.edit.icon': 'mEdit',
    'demo12.icon.resolved.delete.icon': 'mDelete',
    'demo12.icon.resolved.settings.icon': 'mSettings',

    // Demo Card: Network Images
    'demo12.networkImage.icon.icon': 'mImage',
    'demo12.networkImage.title.label': 'TomNetworkImage',
    'demo12.networkImage.description.label':
        'Network image loading with placeholder, error handling, and fit modes.',
    'demo12.networkImage.examplesLabel.label': 'Network Image Examples',
    'demo12.networkImage.fitModesLabel.label': 'Image Fit Modes',

    // Demo Card: Circle Avatars
    'demo12.avatar.icon.icon': 'mAccountCircle',
    'demo12.avatar.title.label': 'TomCircleAvatar',
    'demo12.avatar.description.label':
        'Circular avatars with initials, icons, or background images.',
    'demo12.avatar.sizesLabel.label': 'Avatar Sizes',
    'demo12.avatar.initialsLabel.label': 'With Initials',
    'demo12.avatar.iconsLabel.label': 'With Icons',
    'demo12.avatar.imagesLabel.label': 'With Network Images',

    // Demo Card: FadeIn Images
    'demo12.fadeInImage.icon.icon': 'mBlurOn',
    'demo12.fadeInImage.title.label': 'TomFadeInImage',
    'demo12.fadeInImage.description.label':
        'Smooth fade transition from placeholder to loaded image.',
    'demo12.fadeInImage.descriptionLabel.label':
        'Images fade in smoothly from a placeholder as they load from the network.',

    // Demo Card: Animated Icons
    'demo12.animatedIcon.icon.icon': 'mAnimation',
    'demo12.animatedIcon.title.label': 'TomAnimatedIcon',
    'demo12.animatedIcon.description.label':
        'Animated icons that transition between two icon states.',
    'demo12.animatedIcon.toggle.label': 'Animate',

    // Demo Card: Image Filters
    'demo12.imageFilter.icon.icon': 'mFilterBAndW',
    'demo12.imageFilter.title.label': 'TomImageFiltered',
    'demo12.imageFilter.description.label':
        'Apply blur, matrix, and other image filters to child widgets.',
    'demo12.imageFilter.blurLabel.label': 'Blur:',

    // ==========================================================================
    // Demo 13: Navigation - Section Headers
    // ==========================================================================
    'demo13.section.tabs.title.label': 'Tab Navigation',
    'demo13.section.tabs.subtitle.label':
        'Tab bars and tab views for content organization',
    'demo13.section.bottomNav.title.label': 'Bottom Navigation',
    'demo13.section.bottomNav.subtitle.label':
        'Navigation bars for app-level destinations',
    'demo13.section.railDrawer.title.label': 'Rail & Drawer Navigation',
    'demo13.section.railDrawer.subtitle.label':
        'Side navigation patterns for desktop and tablet layouts',
    'demo13.section.sequential.title.label': 'Sequential Navigation',
    'demo13.section.sequential.subtitle.label':
        'Step-by-step and page-based navigation flows',
    'demo13.section.cupertino.title.label': 'iOS Navigation',
    'demo13.section.cupertino.subtitle.label':
        'Cupertino-style navigation components',

    // ==========================================================================
    // Demo 13: TomTabBar Card
    // ==========================================================================
    'demo13.tabBar.icon.icon': 'mTab',
    'demo13.tabBar.title.label': 'TomTabBar & TomTabBarView',
    'demo13.tabBar.description.label':
        'Material tab bars with synchronized content views.',
    'demo13.tabBar.basicLabel.label': 'Basic Tabs',
    'demo13.tabBar.tab.home.label': 'Home',
    'demo13.tabBar.tab.search.label': 'Search',
    'demo13.tabBar.tab.settings.label': 'Settings',
    'demo13.tabBar.iconTabsLabel.label': 'Tabs with Icons',
    'demo13.tabBar.iconTab.photos.label': 'Photos',
    'demo13.tabBar.iconTab.photos.text': 'Photos',
    'demo13.tabBar.iconTab.videos.label': 'Videos',
    'demo13.tabBar.iconTab.videos.text': 'Videos',
    'demo13.tabBar.iconTab.music.label': 'Music',
    'demo13.tabBar.iconTab.music.text': 'Music',

    // ==========================================================================
    // Demo 13: Scrollable TabBar Card
    // ==========================================================================
    'demo13.scrollableTabBar.icon.icon': 'mTabUnselected',
    'demo13.scrollableTabBar.title.label': 'Scrollable TomTabBar',
    'demo13.scrollableTabBar.description.label':
        'Horizontally scrollable tabs for many categories.',
    'demo13.scrollableTabBar.label.label': 'Scrollable Tabs',
    'demo13.scrollableTabBar.tab.all.label': 'All',
    'demo13.scrollableTabBar.tab.documents.label': 'Documents',
    'demo13.scrollableTabBar.tab.images.label': 'Images',
    'demo13.scrollableTabBar.tab.videos.label': 'Videos',
    'demo13.scrollableTabBar.tab.audio.label': 'Audio',
    'demo13.scrollableTabBar.tab.archives.label': 'Archives',

    // ==========================================================================
    // Demo 13: TomNavigationBar Card (Material 3)
    // ==========================================================================
    'demo13.navigationBar.icon.icon': 'mBottomNavigation',
    'demo13.navigationBar.title.label': 'TomNavigationBar',
    'demo13.navigationBar.description.label':
        'Material 3 bottom navigation for primary destinations.',
    'demo13.navigationBar.m3Label.label': 'Material 3 Navigation Bar',

    // ==========================================================================
    // Demo 13: TomBottomNavigationBar Card (Legacy)
    // ==========================================================================
    'demo13.bottomNavBar.icon.icon': 'mCallToAction',
    'demo13.bottomNavBar.title.label': 'TomBottomNavigationBar',
    'demo13.bottomNavBar.description.label':
        'Legacy bottom navigation bar with fixed/shifting modes.',
    'demo13.bottomNavBar.legacyLabel.label': 'Legacy Bottom Navigation',

    // ==========================================================================
    // Demo 13: TomCupertinoTabBar Card
    // ==========================================================================
    'demo13.cupertinoTabBar.icon.icon': 'cTabBarItem',
    'demo13.cupertinoTabBar.title.label': 'TomCupertinoTabBar',
    'demo13.cupertinoTabBar.description.label':
        'iOS-style tab bar for bottom navigation.',
    'demo13.cupertinoTabBar.iosLabel.label': 'iOS Tab Bar',

    // ==========================================================================
    // Demo 13: TomNavigationRail Card
    // ==========================================================================
    'demo13.navigationRail.icon.icon': 'mViewSidebar',
    'demo13.navigationRail.title.label': 'TomNavigationRail',
    'demo13.navigationRail.description.label':
        'Side navigation rail for desktop and tablet layouts.',
    'demo13.navigationRail.sideLabel.label': 'Navigation Rail',
    'demo13.navigationRail.extendedLabel.label': 'Extended',

    // ==========================================================================
    // Demo 13: TomNavigationDrawer Card
    // ==========================================================================
    'demo13.navigationDrawer.icon.icon': 'mMenuOpen',
    'demo13.navigationDrawer.title.label': 'TomNavigationDrawer',
    'demo13.navigationDrawer.description.label':
        'Material 3 navigation drawer with destinations.',
    'demo13.navigationDrawer.m3DrawerLabel.label': 'Navigation Drawer',

    // ==========================================================================
    // Demo 13: TomDrawer Card
    // ==========================================================================
    'demo13.drawer.icon.icon': 'mMenu',
    'demo13.drawer.title.label': 'TomDrawer',
    'demo13.drawer.description.label':
        'Standard Material drawer panel for side navigation.',
    'demo13.drawer.standardLabel.label': 'Standard Drawer',
    'demo13.drawer.openButton.label': 'Open Drawer',
    'demo13.drawer.hint.label': 'Click to open a drawer dialog',

    // ==========================================================================
    // Demo 13: TomStepper Card
    // ==========================================================================
    'demo13.stepper.icon.icon': 'mLinearScale',
    'demo13.stepper.title.label': 'TomStepper',
    'demo13.stepper.description.label':
        'Step-by-step navigation for multi-stage processes.',
    'demo13.stepper.horizontalLabel.label': 'Horizontal Stepper',
    'demo13.stepper.verticalLabel.label': 'Vertical Stepper',

    // ==========================================================================
    // Demo 13: TomPageView Card
    // ==========================================================================
    'demo13.pageView.icon.icon': 'mViewCarousel',
    'demo13.pageView.title.label': 'TomPageView',
    'demo13.pageView.description.label':
        'Swipeable page-based navigation with page indicators.',
    'demo13.pageView.swipeLabel.label': 'Swipeable Pages',

    // ==========================================================================
    // Demo 13: TomCupertinoNavigationBar Card
    // ==========================================================================
    'demo13.cupertinoNavBar.icon.icon': 'cNavArrowBack',
    'demo13.cupertinoNavBar.title.label': 'TomCupertinoNavigationBar',
    'demo13.cupertinoNavBar.description.label':
        'iOS-style navigation bar with leading/trailing actions.',
    'demo13.cupertinoNavBar.iosBarLabel.label': 'iOS Navigation Bar',
    'demo13.cupertinoNavBar.basicLabel.label': 'Basic',
    'demo13.cupertinoNavBar.withActionsLabel.label': 'With Actions',
    'demo13.cupertinoNavBar.backButtonLabel.label': 'With Back Button',

    // ==========================================================================
    // Demo 14: Progress - Section Headers
    // ==========================================================================
    'demo14.section.circular.title.label': 'Circular Progress',
    'demo14.section.circular.subtitle.label':
        'Spinning and determinate circular progress indicators',
    'demo14.section.linear.title.label': 'Linear Progress',
    'demo14.section.linear.subtitle.label':
        'Horizontal bar progress indicators with customization',
    'demo14.section.refresh.title.label': 'Refresh Indicators',
    'demo14.section.refresh.subtitle.label':
        'Pull-to-refresh patterns for list content',
    'demo14.section.cupertino.title.label': 'Cupertino Indicators',
    'demo14.section.cupertino.subtitle.label':
        'iOS-style activity indicators and progress bars',

    // ==========================================================================
    // Demo 14: TomCircularProgressIndicator Card
    // ==========================================================================
    'demo14.circular.icon.icon': 'mRefresh',
    'demo14.circular.title.label': 'TomCircularProgressIndicator',
    'demo14.circular.description.label':
        'Circular spinning and determinate progress indicators.',
    'demo14.circular.indeterminateLabel.label': 'Indeterminate (Spinning)',
    'demo14.circular.default.label': 'Default',
    'demo14.circular.colored.label': 'Colored',
    'demo14.circular.thick.label': 'Thick',
    'demo14.circular.thin.label': 'Thin',
    'demo14.circular.determinateLabel.label': 'Determinate (Progress)',
    'demo14.circular.start.label': 'Start Animation',
    'demo14.circular.start.icon': 'mPlayArrow',
    'demo14.circular.reset.label': 'Reset',
    'demo14.circular.reset.icon': 'mReplay',
    'demo14.circular.strokeCapLabel.label': 'Stroke Cap Styles',
    'demo14.circular.capButt.label': 'Butt',
    'demo14.circular.capRound.label': 'Round',
    'demo14.circular.capSquare.label': 'Square',

    // ==========================================================================
    // Demo 14: TomLinearProgressIndicator Card
    // ==========================================================================
    'demo14.linear.icon.icon': 'mLinearScale',
    'demo14.linear.title.label': 'TomLinearProgressIndicator',
    'demo14.linear.description.label':
        'Horizontal bar indicators for progress visualization.',
    'demo14.linear.indeterminateLabel.label': 'Indeterminate',
    'demo14.linear.default.label': 'Default',
    'demo14.linear.colored.label': 'Custom Colors',
    'demo14.linear.thick.label': 'Thick Bar (12px)',
    'demo14.linear.determinateLabel.label': 'Determinate',
    'demo14.linear.start.label': 'Start Animation',
    'demo14.linear.start.icon': 'mPlayArrow',
    'demo14.linear.reset.label': 'Reset',
    'demo14.linear.reset.icon': 'mReplay',
    'demo14.linear.roundedLabel.label': 'Rounded Corners',
    'demo14.linear.roundedSmall.label': 'Small radius (4px)',
    'demo14.linear.roundedLarge.label': 'Large radius (8px)',
    'demo14.linear.pill.label': 'Pill shape (full)',

    // ==========================================================================
    // Demo 14: TomRefreshIndicator Card
    // ==========================================================================
    'demo14.refresh.icon.icon': 'mSwipeDown',
    'demo14.refresh.title.label': 'TomRefreshIndicator',
    'demo14.refresh.description.label':
        'Pull-to-refresh wrapper for scrollable content.',
    'demo14.refresh.pullLabel.label': 'Pull to Refresh',
    'demo14.refresh.hint.label': 'Pull down on the list to trigger refresh',
    'demo14.refresh.customLabel.label': 'Custom Styling',

    // ==========================================================================
    // Demo 14: TomCupertinoActivityIndicator Card
    // ==========================================================================
    'demo14.cupertinoActivity.icon.icon': 'cActivityIndicator',
    'demo14.cupertinoActivity.title.label': 'TomCupertinoActivityIndicator',
    'demo14.cupertinoActivity.description.label':
        'iOS-style spinning activity indicator.',
    'demo14.cupertinoActivity.spinnerLabel.label': 'Activity Spinner Sizes',
    'demo14.cupertinoActivity.default.label': 'Default',
    'demo14.cupertinoActivity.large.label': 'Large (20)',
    'demo14.cupertinoActivity.small.label': 'Small (8)',
    'demo14.cupertinoActivity.colored.label': 'Colored',
    'demo14.cupertinoActivity.animationLabel.label': 'Animation Control',

    // ==========================================================================
    // Demo 14: TomCupertinoLinearActivityIndicator Card
    // ==========================================================================
    'demo14.cupertinoLinear.icon.icon': 'cTrackpadSlideHorizontal',
    'demo14.cupertinoLinear.title.label': 'TomCupertinoLinearActivityIndicator',
    'demo14.cupertinoLinear.description.label':
        'iOS-style linear progress bar indicator.',
    'demo14.cupertinoLinear.barLabel.label': 'iOS Linear Progress',
    'demo14.cupertinoLinear.indeterminate.label': 'Indeterminate',
    'demo14.cupertinoLinear.determinate.label': 'Determinate Values',
    'demo14.cupertinoLinear.custom.label': 'Custom Colors & Height',

    // ==========================================================================
    // Demo 15: List Views - Section Headers
    // ==========================================================================
    'demo15.section.basic.title.label': 'Basic ListView',
    'demo15.section.basic.subtitle.label':
        'Standard list views with static children, builder pattern, and separators',
    'demo15.section.animated.title.label': 'Animated Lists',
    'demo15.section.animated.subtitle.label':
        'Lists with animated item insertion and removal',
    'demo15.section.interactive.title.label': 'Interactive Lists',
    'demo15.section.interactive.subtitle.label':
        'Reorderable and dismissible list patterns',
    'demo15.section.wheel.title.label': 'Wheel Scroll View',
    'demo15.section.wheel.subtitle.label':
        'iOS-style picker wheels for selection interfaces',

    // ==========================================================================
    // Demo 15: TomListView Card
    // ==========================================================================
    'demo15.listview.icon.icon': 'mList',
    'demo15.listview.title.label': 'TomListView',
    'demo15.listview.description.label':
        'Scrollable list with multiple construction patterns: static children, builder, and separated.',
    'demo15.listview.staticLabel.label': 'Static Children',
    'demo15.listview.builderLabel.label': 'Builder Pattern (Lazy)',
    'demo15.listview.separatedLabel.label': 'Separated with Dividers',
    'demo15.listview.horizontalLabel.label': 'Horizontal Scrolling',

    // ==========================================================================
    // Demo 15: TomAnimatedList Card
    // ==========================================================================
    'demo15.animatedList.icon.icon': 'mAnimation',
    'demo15.animatedList.title.label': 'TomAnimatedList',
    'demo15.animatedList.description.label':
        'List that animates items when they are inserted or removed.',
    'demo15.animatedList.description.text':
        'Add and remove items to see smooth slide and fade animations.',
    'demo15.animatedList.add.label': 'Add Item',
    'demo15.animatedList.add.icon': 'mAdd',
    'demo15.animatedList.removeFirst.label': 'Remove First',
    'demo15.animatedList.removeFirst.icon': 'mRemove',
    'demo15.animatedList.removeLast.label': 'Remove Last',
    'demo15.animatedList.removeLast.icon': 'mRemove',
    'demo15.animatedList.hint.label':
        'Items animate in from the right and out to the left',

    // ==========================================================================
    // Demo 15: TomReorderableListView Card
    // ==========================================================================
    'demo15.reorderable.icon.icon': 'mReorder',
    'demo15.reorderable.title.label': 'TomReorderableListView',
    'demo15.reorderable.description.label':
        'List that allows users to reorder items by dragging.',
    'demo15.reorderable.description.text':
        'Long press and drag items to reorder them in the list.',
    'demo15.reorderable.hint.label':
        'Use the drag handle on the right or long-press the tile',

    // ==========================================================================
    // Demo 15: TomDismissible Card
    // ==========================================================================
    'demo15.dismissible.icon.icon': 'mSwipe',
    'demo15.dismissible.title.label': 'TomDismissible',
    'demo15.dismissible.description.label':
        'List items that can be dismissed by swiping left or right.',
    'demo15.dismissible.description.text':
        'Swipe items horizontally to archive (right) or delete (left).',
    'demo15.dismissible.reset.label': 'Reset Items',
    'demo15.dismissible.reset.icon': 'mRefresh',
    'demo15.dismissible.empty.label': 'All items dismissed!',
    'demo15.dismissible.hint.label':
        'Swipe right for green (archive), left for red (delete)',

    // ==========================================================================
    // Demo 15: TomListWheelScrollView Card
    // ==========================================================================
    'demo15.wheel.icon.icon': 'mTune',
    'demo15.wheel.title.label': 'TomListWheelScrollView',
    'demo15.wheel.description.label':
        'iOS-style wheel picker with 3D cylindrical scroll effect.',
    'demo15.wheel.description.text':
        'Scroll to select items from a cylindrical wheel interface.',
    'demo15.wheel.standard.label': 'Month Selector',
    'demo15.wheel.magnified.label': 'With Magnifier',
    'demo15.wheel.customLabel.label': 'Custom Styled Wheel',

    // ==========================================================================
    // Demo 16: Tree & Hierarchy - Section Headers
    // ==========================================================================
    'demo16.section.simple.title.label': 'Simple Tree View',
    'demo16.section.simple.subtitle.label':
        'Basic tree structure with expand/collapse and custom nodes',
    'demo16.section.sliver.title.label': 'TreeSliver (High Performance)',
    'demo16.section.sliver.subtitle.label':
        'Sliver-based tree for large datasets with lazy loading',
    'demo16.section.expansion.title.label': 'Expansion Tiles',
    'demo16.section.expansion.subtitle.label':
        'Nested expansion patterns for settings and deep hierarchies',
    'demo16.section.fileExplorer.title.label': 'File Explorer Pattern',
    'demo16.section.fileExplorer.subtitle.label':
        'Project structure navigation with file icons and context menus',
    'demo16.section.organization.title.label': 'Organizational Hierarchy',
    'demo16.section.organization.subtitle.label':
        'Company org chart with reporting structure visualization',

    // ==========================================================================
    // Demo 16: TomTreeView Card
    // ==========================================================================
    'demo16.treeView.icon.icon': 'mAccountTree',
    'demo16.treeView.title.label': 'TomTreeView',
    'demo16.treeView.description.label':
        'Simple tree view with recursive nodes, expand/collapse, and custom content.',
    'demo16.treeView.basicLabel.label': 'Basic Tree Structure',
    'demo16.treeView.hint.label':
        'Tap nodes to select, tap expand icons to show/hide children',

    // ==========================================================================
    // Demo 16: TomTreeSliver Card
    // ==========================================================================
    'demo16.treeSliver.icon.icon': 'mLayers',
    'demo16.treeSliver.title.label': 'TomTreeSliver',
    'demo16.treeSliver.description.label':
        'High-performance sliver-based tree for large datasets with lazy loading.',
    'demo16.treeSliver.descriptionText.label':
        'TreeSliver builds nodes on-demand for efficient memory usage with large trees.',
    'demo16.treeSliver.expandAll.label': 'Expand All',
    'demo16.treeSliver.expandAll.icon': 'mUnfoldMore',
    'demo16.treeSliver.collapseAll.label': 'Collapse All',
    'demo16.treeSliver.collapseAll.icon': 'mUnfoldLess',
    'demo16.treeSliver.hint.label':
        'Uses TreeSliverController for programmatic expand/collapse',

    // ==========================================================================
    // Demo 16: TomExpansionTile Card
    // ==========================================================================
    'demo16.expansionTile.icon.icon': 'mExpandMore',
    'demo16.expansionTile.title.label': 'TomExpansionTile',
    'demo16.expansionTile.description.label':
        'Collapsible sections for settings, menus, and nested content hierarchies.',
    'demo16.expansionTile.basicLabel.label': 'Settings Style',
    'demo16.expansionTile.nestedLabel.label': 'Deeply Nested Hierarchy',

    // ==========================================================================
    // Demo 16: File Explorer Card
    // ==========================================================================
    'demo16.fileExplorer.icon.icon': 'mFolderOpen',
    'demo16.fileExplorer.title.label': 'File Explorer Pattern',
    'demo16.fileExplorer.description.label':
        'Project structure tree with file/folder icons and context menus.',
    'demo16.fileExplorer.hint.label':
        'Right-click or use menu button for file actions',

    // ==========================================================================
    // Demo 16: Organization Hierarchy Card
    // ==========================================================================
    'demo16.organization.icon.icon': 'mGroups',
    'demo16.organization.title.label': 'Organizational Hierarchy',
    'demo16.organization.description.label':
        'Visual org chart showing reporting structure and team hierarchy.',
    'demo16.organization.hint.label':
        'Cards can expand to show team members and details',

    // ==========================================================================
    // Demo 17: Sliver Compositions
    // ==========================================================================

    // Section Headers
    'demo17.section.customScroll.title.label': 'CustomScrollView',
    'demo17.section.customScroll.subtitle.label':
        'Foundation for sliver-based scrollable layouts',
    'demo17.section.appBar.title.label': 'SliverAppBar Styles',
    'demo17.section.appBar.subtitle.label':
        'Pinned, floating, and snap behaviors for app bars',
    'demo17.section.listGrid.title.label': 'SliverList & SliverGrid',
    'demo17.section.listGrid.subtitle.label':
        'Efficient scrollable lists and grids within slivers',
    'demo17.section.mixed.title.label': 'Mixed Content',
    'demo17.section.mixed.subtitle.label':
        'Combining different sliver types in one view',
    'demo17.section.headers.title.label': 'Pinned & Floating Headers',
    'demo17.section.headers.subtitle.label':
        'Headers that stay visible or reappear on scroll',
    'demo17.section.groups.title.label': 'Sliver Groups',
    'demo17.section.groups.subtitle.label':
        'Main axis and cross axis sliver grouping',
    'demo17.section.decorated.title.label': 'Decorated Slivers',
    'demo17.section.decorated.subtitle.label':
        'Slivers with decorations, padding, and safe areas',
    'demo17.section.visibility.title.label': 'Sliver Visibility',
    'demo17.section.visibility.subtitle.label':
        'Control sliver visibility and opacity',

    // CustomScrollView Card
    'demo17.customScroll.icon.icon': 'mViewList',
    'demo17.customScroll.title.label': 'CustomScrollView Basics',
    'demo17.customScroll.description.label':
        'CustomScrollView is the foundation for sliver-based scrolling with composable sliver children.',
    'demo17.customScroll.basicLabel.label': 'Basic CustomScrollView with SliverAppBar and SliverList',
    'demo17.customScroll.hint.label':
        'CustomScrollView accepts slivers as children, not regular widgets',

    // Pinned AppBar Card
    'demo17.pinnedAppBar.icon.icon': 'mPushPin',
    'demo17.pinnedAppBar.title.label': 'Pinned SliverAppBar',
    'demo17.pinnedAppBar.description.label':
        'SliverAppBar with pinned=true stays visible at the top when scrolling.',
    'demo17.pinnedAppBar.demoLabel.label': 'Pinned AppBar with gradient and actions',
    'demo17.pinnedAppBar.hint.label':
        'The app bar shrinks but stays pinned at the top',

    // Floating AppBar Card
    'demo17.floatingAppBar.icon.icon': 'mVerticalAlignTop',
    'demo17.floatingAppBar.title.label': 'Floating SliverAppBar',
    'demo17.floatingAppBar.description.label':
        'SliverAppBar with floating=true reappears immediately when scrolling up.',
    'demo17.floatingAppBar.demoLabel.label': 'Floating AppBar - scrolls away, returns on scroll up',
    'demo17.floatingAppBar.hint.label':
        'Scroll down then up quickly to see floating behavior',

    // Snap AppBar Card
    'demo17.snapAppBar.icon.icon': 'mTouchApp',
    'demo17.snapAppBar.title.label': 'Snap SliverAppBar',
    'demo17.snapAppBar.description.label':
        'SliverAppBar with snap=true (requires floating) animates to fully show/hide.',
    'demo17.snapAppBar.demoLabel.label': 'Snap AppBar with stretch effect',
    'demo17.snapAppBar.hint.label':
        'Partial scrolls snap to fully visible or hidden state',

    // SliverList Card
    'demo17.sliverList.icon.icon': 'mList',
    'demo17.sliverList.title.label': 'SliverList Types',
    'demo17.sliverList.description.label':
        'Different SliverList variants for various performance and sizing needs.',
    'demo17.sliverList.typesLabel.label': 'Regular, Fixed Extent, and Prototype Extent lists',
    'demo17.sliverList.hint.label':
        'Use fixed/prototype extent for better performance with uniform items',

    // SliverGrid Card
    'demo17.sliverGrid.icon.icon': 'mGridView',
    'demo17.sliverGrid.title.label': 'SliverGrid Gallery',
    'demo17.sliverGrid.description.label':
        'SliverGrid displays items in a grid within a CustomScrollView.',
    'demo17.sliverGrid.demoLabel.label': 'Grid with fixed cross axis count',
    'demo17.sliverGrid.hint.label':
        'SliverGrid uses gridDelegate like regular GridView',

    // Mixed Content Card
    'demo17.mixedContent.icon.icon': 'mDashboard',
    'demo17.mixedContent.title.label': 'Mixed Sliver Content',
    'demo17.mixedContent.description.label':
        'SliverToBoxAdapter wraps regular widgets for use in sliver contexts.',
    'demo17.mixedContent.demoLabel.label': 'Dashboard with hero, stats, list, and grid sections',
    'demo17.mixedContent.hint.label':
        'Use SliverToBoxAdapter to insert non-sliver widgets',

    // Fill Remaining Card
    'demo17.fillRemaining.icon.icon': 'mExpand',
    'demo17.fillRemaining.title.label': 'SliverFillRemaining',
    'demo17.fillRemaining.description.label':
        'SliverFillRemaining expands to fill remaining viewport space.',
    'demo17.fillRemaining.demoLabel.label': 'Footer that fills remaining space',
    'demo17.fillRemaining.hint.label':
        'Great for centering content or creating footer sections',

    // Pinned/Floating Headers Card
    'demo17.pinnedFloating.icon.icon': 'mVerticalSplit',
    'demo17.pinnedFloating.title.label': 'Pinned & Floating Headers',
    'demo17.pinnedFloating.description.label':
        'PinnedHeaderSliver stays at top; FloatingHeader reappears on scroll up.',
    'demo17.pinnedFloating.demoLabel.label': 'Multiple header types in action',
    'demo17.pinnedFloating.hint.label':
        'Notice how each header type behaves differently on scroll',

    // Groups Card
    'demo17.groups.icon.icon': 'mViewColumn',
    'demo17.groups.title.label': 'Sliver Groups',
    'demo17.groups.description.label':
        'SliverMainAxisGroup for sequential slivers; SliverCrossAxisGroup for side-by-side.',
    'demo17.groups.demoLabel.label': 'Main axis and cross axis group examples',
    'demo17.groups.hint.label':
        'Groups help organize slivers with pinned headers per section',

    // Decorated Card
    'demo17.decorated.icon.icon': 'mAutoAwesome',
    'demo17.decorated.title.label': 'Decorated Slivers',
    'demo17.decorated.description.label':
        'DecoratedSliver adds decorations; SliverPadding adds spacing around slivers.',
    'demo17.decorated.demoLabel.label': 'Gradient, border, and shadow decorations',
    'demo17.decorated.hint.label':
        'Decorations apply to the entire sliver, not individual items',

    // Visibility Card
    'demo17.visibility.icon.icon': 'mVisibility',
    'demo17.visibility.title.label': 'Sliver Visibility Control',
    'demo17.visibility.description.label':
        'SliverVisibility and SliverOpacity control sliver rendering.',
    'demo17.visibility.demoLabel.label': 'Toggle visibility and opacity of slivers',
    'demo17.visibility.hint.label':
        'maintainState keeps widget state even when invisible',

    // ==========================================================================
    // Demo 18: Animated Transitions
    // ==========================================================================

    // Section Headers
    'demo18.section.container.title.label': 'AnimatedContainer',
    'demo18.section.container.subtitle.label':
        'Smoothly animate container property changes',
    'demo18.section.opacity.title.label': 'Opacity & CrossFade',
    'demo18.section.opacity.subtitle.label':
        'Fade animations and smooth content transitions',
    'demo18.section.switcher.title.label': 'AnimatedSwitcher',
    'demo18.section.switcher.subtitle.label':
        'Automatic transitions between child widgets',
    'demo18.section.position.title.label': 'Position & Alignment',
    'demo18.section.position.subtitle.label':
        'Animate widget position and alignment changes',
    'demo18.section.padding.title.label': 'Padding & Size',
    'demo18.section.padding.subtitle.label':
        'Smooth padding and size transitions',
    'demo18.section.transform.title.label': 'Transform Animations',
    'demo18.section.transform.subtitle.label':
        'Scale, slide, and rotation animations',
    'demo18.section.text.title.label': 'Text & Physical Model',
    'demo18.section.text.subtitle.label':
        'Text style and elevation animations',
    'demo18.section.transitions.title.label': 'Transition Widgets',
    'demo18.section.transitions.subtitle.label':
        'Controller-driven transition animations',
    'demo18.section.hero.title.label': 'Hero Transitions',
    'demo18.section.hero.subtitle.label':
        'Shared element transitions between views',

    // AnimatedContainer Card
    'demo18.animatedContainer.icon.icon': 'mAutoAwesome',
    'demo18.animatedContainer.title.label': 'AnimatedContainer',
    'demo18.animatedContainer.description.label':
        'Automatically animates changes to size, color, decoration, padding, and more.',
    'demo18.animatedContainer.demoLabel.label': 'Tap the container to see animated property changes',
    'demo18.animatedContainer.hint.label':
        'AnimatedContainer interpolates between old and new values',

    // AnimatedOpacity Card
    'demo18.animatedOpacity.icon.icon': 'mOpacity',
    'demo18.animatedOpacity.title.label': 'AnimatedOpacity',
    'demo18.animatedOpacity.description.label':
        'Smoothly animates opacity changes over a specified duration.',
    'demo18.animatedOpacity.demoLabel.label': 'Adjust slider to change opacity',
    'demo18.animatedOpacity.hint.label':
        'Use alwaysIncludeSemantics for accessibility',

    // CrossFade Card
    'demo18.crossFade.icon.icon': 'mSwapHoriz',
    'demo18.crossFade.title.label': 'AnimatedCrossFade',
    'demo18.crossFade.description.label':
        'Cross-fades between two children while animating size changes.',
    'demo18.crossFade.demoLabel.label': 'Toggle between day and night mode',
    'demo18.crossFade.hint.label':
        'CrossFadeState determines which child is visible',

    // Switcher Card
    'demo18.switcher.icon.icon': 'mAutorenew',
    'demo18.switcher.title.label': 'AnimatedSwitcher',
    'demo18.switcher.description.label':
        'Automatically animates transitions when child widget changes.',
    'demo18.switcher.demoLabel.label': 'Select an icon to see animated transition',
    'demo18.switcher.hint.label':
        'Use unique keys on children to trigger transitions',

    // Positioned Card
    'demo18.positioned.icon.icon': 'mOpenWith',
    'demo18.positioned.title.label': 'AnimatedPositioned',
    'demo18.positioned.description.label':
        'Animates position changes within a Stack.',
    'demo18.positioned.demoLabel.label': 'Tap widget to animate position',
    'demo18.positioned.hint.label':
        'Must be a descendant of Stack widget',

    // Align Card
    'demo18.align.icon.icon': 'mFormatAlignCenter',
    'demo18.align.title.label': 'AnimatedAlign',
    'demo18.align.description.label':
        'Smoothly animates alignment changes within parent.',
    'demo18.align.demoLabel.label': 'Click grid positions to animate alignment',
    'demo18.align.hint.label':
        'Works with any Alignment value including fractional',

    // Padding Card
    'demo18.padding.icon.icon': 'mPadding',
    'demo18.padding.title.label': 'AnimatedPadding',
    'demo18.padding.description.label':
        'Animates padding changes around child widget.',
    'demo18.padding.demoLabel.label': 'Change padding with preset buttons',
    'demo18.padding.hint.label':
        'Outer border shows container, inner shows content',

    // Size Card
    'demo18.size.icon.icon': 'mAspectRatio',
    'demo18.size.title.label': 'AnimatedSize',
    'demo18.size.description.label':
        'Automatically animates size changes of its child.',
    'demo18.size.demoLabel.label': 'Expand/collapse to see smooth size animation',
    'demo18.size.hint.label':
        'Great for expandable sections and accordions',

    // Scale Card
    'demo18.scale.icon.icon': 'mZoomIn',
    'demo18.scale.title.label': 'AnimatedScale',
    'demo18.scale.description.label':
        'Animates scale transformation of child widget.',
    'demo18.scale.demoLabel.label': 'Adjust slider to scale the widget',
    'demo18.scale.hint.label':
        'Scale uses center alignment by default',

    // Slide Card
    'demo18.slide.icon.icon': 'mSwipeRight',
    'demo18.slide.title.label': 'AnimatedSlide',
    'demo18.slide.description.label':
        'Animates position offset as a fraction of widget size.',
    'demo18.slide.demoLabel.label': 'Use arrows to slide the widget',
    'demo18.slide.hint.label':
        'Offset(1,0) moves widget by its full width',

    // Rotation Card
    'demo18.rotation.icon.icon': 'mRotateRight',
    'demo18.rotation.title.label': 'AnimatedRotation',
    'demo18.rotation.description.label':
        'Animates rotation in turns (1 turn = 360 degrees).',
    'demo18.rotation.demoLabel.label': 'Adjust slider or use preset angles',
    'demo18.rotation.hint.label':
        'Values greater than 1 rotate multiple times',

    // TextStyle Card
    'demo18.textStyle.icon.icon': 'mTextFields',
    'demo18.textStyle.title.label': 'AnimatedDefaultTextStyle',
    'demo18.textStyle.description.label':
        'Animates text style changes including size, weight, and color.',
    'demo18.textStyle.demoLabel.label': 'Toggle to animate text style',
    'demo18.textStyle.hint.label':
        'Wraps Text widgets to animate their default style',

    // PhysicalModel Card
    'demo18.physicalModel.icon.icon': 'mLayers',
    'demo18.physicalModel.title.label': 'AnimatedPhysicalModel',
    'demo18.physicalModel.description.label':
        'Animates elevation, color, and shadow changes.',
    'demo18.physicalModel.demoLabel.label': 'Adjust elevation with slider',
    'demo18.physicalModel.hint.label':
        'Creates Material Design elevation effects',

    // FadeTransition Card
    'demo18.fadeTransition.icon.icon': 'mBlurOn',
    'demo18.fadeTransition.title.label': 'FadeTransition',
    'demo18.fadeTransition.description.label':
        'Controller-driven fade animation for precise control.',
    'demo18.fadeTransition.demoLabel.label': 'Use buttons to control fade animation',
    'demo18.fadeTransition.hint.label':
        'Requires AnimationController for the opacity',

    // ScaleTransition Card
    'demo18.scaleTransition.icon.icon': 'mZoomOutMap',
    'demo18.scaleTransition.title.label': 'ScaleTransition',
    'demo18.scaleTransition.description.label':
        'Controller-driven scale animation with curves.',
    'demo18.scaleTransition.demoLabel.label': 'Control scale with animation controller',
    'demo18.scaleTransition.hint.label':
        'Elastic curves create bouncy scale effects',

    // RotationTransition Card
    'demo18.rotationTransition.icon.icon': 'mSync',
    'demo18.rotationTransition.title.label': 'RotationTransition',
    'demo18.rotationTransition.description.label':
        'Controller-driven rotation with loop support.',
    'demo18.rotationTransition.demoLabel.label': 'Control rotation with precise timing',
    'demo18.rotationTransition.hint.label':
        'Use repeat() for continuous spinning',

    // Hero Card
    'demo18.hero.icon.icon': 'mFlightTakeoff',
    'demo18.hero.title.label': 'Hero Transitions',
    'demo18.hero.description.label':
        'Shared element transitions between different views.',
    'demo18.hero.demoLabel.label': 'Tap a card to see hero animation',
    'demo18.hero.hint.label':
        'Hero widgets with matching tags animate together',

    // ==========================================================================
    // Demo 19: Effects & Filters
    // ==========================================================================

    // Section Headers
    'demo19.section.backdrop.title.label': 'Backdrop Filters',
    'demo19.section.backdrop.subtitle.label':
        'Apply blur and filter effects behind content',
    'demo19.section.image.title.label': 'Image Filters',
    'demo19.section.image.subtitle.label':
        'Apply blur and matrix filters to images',
    'demo19.section.color.title.label': 'Color Filters',
    'demo19.section.color.subtitle.label':
        'Color matrix transformations and blend modes',
    'demo19.section.shader.title.label': 'Shader Masks',
    'demo19.section.shader.subtitle.label':
        'Apply gradient and custom shader effects',
    'demo19.section.selection.title.label': 'Text Selection',
    'demo19.section.selection.subtitle.label':
        'Enable text selection in widget subtrees',
    'demo19.section.sensitive.title.label': 'Sensitive Content',
    'demo19.section.sensitive.subtitle.label':
        'Flag content as sensitive for platform handling',

    // BackdropFilter Card
    'demo19.backdropFilter.icon.icon': 'mBlurOn',
    'demo19.backdropFilter.title.label': 'BackdropFilter',
    'demo19.backdropFilter.description.label':
        'Applies blur effect to everything painted beneath the widget.',
    'demo19.backdropFilter.hint.label':
        'Use ClipRRect to constrain the blur region',

    // ImageFilter Card
    'demo19.imageFilter.icon.icon': 'mFilterBAndW',
    'demo19.imageFilter.title.label': 'ImageFiltered',
    'demo19.imageFilter.description.label':
        'Applies ImageFilter effects like blur and matrix transforms to child.',
    'demo19.imageFilter.hint.label':
        'Toggle enabled to compare filtered vs original',

    // ColorFilter Card
    'demo19.colorFilter.icon.icon': 'mColorLens',
    'demo19.colorFilter.title.label': 'ColorFiltered',
    'demo19.colorFilter.description.label':
        'Applies color matrix transformations for effects like grayscale, sepia, and invert.',
    'demo19.colorFilter.hint.label':
        'Color matrices can create complex visual effects',

    // ShaderMask Card
    'demo19.shaderMask.icon.icon': 'mGradient',
    'demo19.shaderMask.title.label': 'ShaderMask',
    'demo19.shaderMask.description.label':
        'Applies a shader as a mask, enabling gradient fades and custom effects.',
    'demo19.shaderMask.hint.label':
        'Different blend modes create different visual results',

    // SelectionArea Card
    'demo19.selectionArea.icon.icon': 'mSelectAll',
    'demo19.selectionArea.title.label': 'SelectionArea',
    'demo19.selectionArea.description.label':
        'Enables text selection for all descendant Text widgets automatically.',
    'demo19.selectionArea.hint.label':
        'Ideal for making entire content areas selectable',

    // SelectableRegion Card
    'demo19.selectableRegion.icon.icon': 'mTextFieldsRounded',
    'demo19.selectableRegion.title.label': 'SelectableRegion',
    'demo19.selectableRegion.description.label':
        'Lower-level widget for custom text selection with explicit controls.',
    'demo19.selectableRegion.hint.label':
        'Requires explicit selectionControls parameter',

    // SensitiveContent Card
    'demo19.sensitiveContent.icon.icon': 'mSecurity',
    'demo19.sensitiveContent.title.label': 'SensitiveContent',
    'demo19.sensitiveContent.description.label':
        'Flags content for special OS handling of sensitive data like passwords.',
    'demo19.sensitiveContent.hint.label':
        'Platform may hide content in app switcher or screenshots',

    // ==========================================================================
    // Demo 20: Interactions & Gestures
    // ==========================================================================

    // Section Headers
    'demo20.section.gesture.title.label': 'Gesture Detection',
    'demo20.section.gesture.subtitle.label':
        'Tap, drag, pan, scale, and long press gestures',
    'demo20.section.ink.title.label': 'Ink Effects',
    'demo20.section.ink.subtitle.label':
        'Material ink splash and ripple responses',
    'demo20.section.dragdrop.title.label': 'Drag and Drop',
    'demo20.section.dragdrop.subtitle.label':
        'Draggable widgets and drop targets',
    'demo20.section.longpress.title.label': 'Long Press Drag',
    'demo20.section.longpress.subtitle.label':
        'Long press activated drag and drop',
    'demo20.section.pointer.title.label': 'Pointer Blocking',
    'demo20.section.pointer.subtitle.label':
        'Absorb or ignore pointer events',
    'demo20.section.mouse.title.label': 'Mouse Region',
    'demo20.section.mouse.subtitle.label':
        'Track mouse position, hover, and cursor',

    // GestureDetector Card
    'demo20.gestureDetector.icon.icon': 'mTouchApp',
    'demo20.gestureDetector.title.label': 'GestureDetector',
    'demo20.gestureDetector.description.label':
        'Detects taps, drags, pans, scales, and other touch/mouse gestures.',
    'demo20.gestureDetector.hint.label':
        'Supports single tap, double tap, long press, pan, scale, and force press',

    // InkWell Card
    'demo20.inkWell.icon.icon': 'mWaterDrop',
    'demo20.inkWell.title.label': 'InkWell',
    'demo20.inkWell.description.label':
        'Material ink splash effect for tap feedback with customizable colors.',
    'demo20.inkWell.hint.label':
        'Provides visual and haptic feedback for touch interactions',

    // InkResponse Card
    'demo20.inkResponse.icon.icon': 'mLensBlur',
    'demo20.inkResponse.title.label': 'InkResponse',
    'demo20.inkResponse.description.label':
        'Low-level ink splash with configurable shape, radius, and spread.',
    'demo20.inkResponse.hint.label':
        'Base widget for InkWell with more customization options',

    // DragDrop Card
    'demo20.dragDrop.icon.icon': 'mDragIndicator',
    'demo20.dragDrop.title.label': 'Draggable & DragTarget',
    'demo20.dragDrop.description.label':
        'Drag-and-drop system with typed data transfer and visual feedback.',
    'demo20.dragDrop.hint.label':
        'Draggable provides the source, DragTarget provides the destination',

    // LongPressDrag Card
    'demo20.longPressDrag.icon.icon': 'mPanTool',
    'demo20.longPressDrag.title.label': 'LongPressDraggable',
    'demo20.longPressDrag.description.label':
        'Drag-and-drop that activates after a long press with haptic feedback.',
    'demo20.longPressDrag.hint.label':
        'Useful for reorderable lists and tile-based interfaces',

    // AbsorbPointer Card
    'demo20.absorbPointer.icon.icon': 'mBlock',
    'demo20.absorbPointer.title.label': 'AbsorbPointer',
    'demo20.absorbPointer.description.label':
        'Absorbs and blocks all pointer events from reaching child widgets.',
    'demo20.absorbPointer.hint.label':
        'Events are consumed but children below still render normally',

    // IgnorePointer Card
    'demo20.ignorePointer.icon.icon': 'mVisibilityOff',
    'demo20.ignorePointer.title.label': 'IgnorePointer',
    'demo20.ignorePointer.description.label':
        'Makes child widgets invisible to pointer events, passing them through.',
    'demo20.ignorePointer.hint.label':
        'Unlike AbsorbPointer, events pass to widgets behind',

    // MouseRegion Card
    'demo20.mouseRegion.icon.icon': 'mMouse',
    'demo20.mouseRegion.title.label': 'MouseRegion',
    'demo20.mouseRegion.description.label':
        'Tracks mouse enter, exit, and hover events with cursor customization.',
    'demo20.mouseRegion.hint.label':
        'Essential for desktop and web hover effects',

    // ==========================================================================
    // Demo 21: Resource Resolution — Visual Styling Parameters
    // ==========================================================================
    // All text and icons resolved from resources to demonstrate
    // complete resource resolution pattern.

    // --- Section Headers ---
    'demo21.section.intro.title.label': 'Resource Resolution',
    'demo21.section.intro.subtitle.label': 'Visual styling parameters from resources',
    'demo21.section.container.title.label': 'Container Parameters',
    'demo21.section.container.subtitle.label': 'padding, margin, width, height from resources',
    'demo21.section.textStyle.title.label': 'Text Style Parameters',
    'demo21.section.textStyle.subtitle.label': 'fontSize, fontWeight, color from resources',
    'demo21.section.colors.title.label': 'Color Parameters',
    'demo21.section.colors.subtitle.label': 'icon color, progress colors from resources',
    'demo21.section.numeric.title.label': 'Numeric Parameters',
    'demo21.section.numeric.subtitle.label': 'elevation, size, opacity from resources',
    'demo21.section.toggle.title.label': 'Toggle Colors',
    'demo21.section.toggle.subtitle.label': 'activeColor, checkColor from resources',
    'demo21.section.lookup.title.label': 'Lookup Type Coverage',
    'demo21.section.lookup.subtitle.label': 'explicit checks for text/color/icon/double/int/bool/edgeInsets/list/map',

    // --- Introduction Card ---
    'demo21.intro.icon.icon': 'mAutoAwesome',
    'demo21.intro.title.label': 'Visual Parameter Resolution',
    'demo21.intro.subtitle.label': 'How styling parameters are resolved',
    'demo21.intro.explanation.label':
        'Visual parameters like padding, colors, textStyle, and elevation '
        'can be resolved from resources using tomId. This enables theme '
        'customization, white-labeling, and runtime configuration.',
    'demo21.intro.formats.label':
        'Formats: EdgeInsets as maps, colors as hex strings, '
        'TextStyle as maps with fontSize/fontWeight/color.',

    // --- Container Section ---
    'demo21.paddingDemo.icon.icon': 'mPadding',
    'demo21.paddingDemo.title.label': 'TomContainer with Padding',
    'demo21.paddingDemo.subtitle.label': 'padding resolved from resources',
    'demo21.paddingDemo.info.label':
        'Resource: demo21.paddedBox.padding → {left: 24, top: 16, right: 24, bottom: 16}',
    'demo21.paddedBox.content.label': 'Padded content',

    'demo21.sizeDemo.icon.icon': 'mAspectRatio',
    'demo21.sizeDemo.title.label': 'TomContainer with Dimensions',
    'demo21.sizeDemo.subtitle.label': 'width, height resolved from resources',
    'demo21.sizeDemo.info.label': 'Resources: demo21.sizedBox.width → 150, height → 100',
    'demo21.sizedBox.content.label': '150×100',

    'demo21.marginDemo.icon.icon': 'mMargin',
    'demo21.marginDemo.title.label': 'TomContainer with Margin',
    'demo21.marginDemo.subtitle.label': 'margin resolved from resources',
    'demo21.marginDemo.info.label': 'Resource: demo21.marginedBox.margin → {all: 16}',
    'demo21.marginedBox.content.label': 'Margined content',

    // --- TextStyle Section ---
    'demo21.textStyleDemo.icon.icon': 'mTextFormat',
    'demo21.textStyleDemo.title.label': 'TomAnimatedDefaultTextStyle',
    'demo21.textStyleDemo.subtitle.label': 'style resolved from resources',
    'demo21.textStyleDemo.info.label':
        'Resources resolve fontSize, fontWeight, fontStyle, color, letterSpacing',
    'demo21.styledText1.content.label': 'Large Bold Blue',
    'demo21.styledText2.content.label': 'Italic Purple with Spacing',
    'demo21.styledText3.content.label': 'Medium Green Underlined',

    // --- Icon Resources Section (icon + color from resources) ---
    'demo21.iconColorDemo.icon.icon': 'mPalette',
    'demo21.iconColorDemo.title.label': 'TomIcon — icon & color from resources',
    'demo21.iconColorDemo.subtitle.label':
        'both the glyph and its color are resolved',
    'demo21.iconColorDemo.info.label':
        'Every TomIcon below is constructed with just a tomId — the '
            '.icon resource selects which glyph is drawn AND the '
            '.color resource paints it. '
            'e.g. demo21.coloredIcon1.icon → mFavorite · '
            'demo21.coloredIcon1.color → #E91E63.',
    'demo21.coloredIcon1.icon': 'mFavorite',
    'demo21.coloredIcon1.caption.label': 'mFavorite\n#E91E63',
    'demo21.coloredIcon2.icon': 'mStar',
    'demo21.coloredIcon2.caption.label': 'mStar\n#FF9800',
    'demo21.coloredIcon3.icon': 'mThumbUp',
    'demo21.coloredIcon3.caption.label': 'mThumbUp\n#4CAF50',
    'demo21.coloredIcon4.icon': 'mLightbulb',
    'demo21.coloredIcon4.caption.label': 'mLightbulb\n#2196F3',

    // --- Container Color Section ---
    'demo21.containerColorDemo.icon.icon': 'mViewModule',
    'demo21.containerColorDemo.title.label': 'TomContainer Colors',
    'demo21.containerColorDemo.subtitle.label': 'color resolved from resources (hex, named, int)',
    'demo21.containerColorDemo.info.label':
        'Resources: colorBox1=#D32F2F, colorBox2=mTeal700, colorBox3=0xFF5E35B1',
    'demo21.colorBox1.content.label': 'HEX',
    'demo21.colorBox2.content.label': 'NAME',
    'demo21.colorBox3.content.label': 'INT',

    // --- Progress Color Section ---
    'demo21.progressColorDemo.icon.icon': 'mRefresh',
    'demo21.progressColorDemo.title.label': 'Progress Indicator Colors',
    'demo21.progressColorDemo.subtitle.label': 'color, backgroundColor from resources',
    'demo21.progressColorDemo.info.label':
        'Resources: demo21.progress1.color → #9C27B0, backgroundColor → #E1BEE7',

    // --- Card Elevation Section ---
    'demo21.elevationDemo.icon.icon': 'mLayers',
    'demo21.elevationDemo.title.label': 'TomCard Elevation',
    'demo21.elevationDemo.subtitle.label': 'elevation resolved from resources',
    'demo21.elevationDemo.info.label': 'Resources: demo21.card1.elevation → 2, 8, 16',
    'demo21.card1.content.label': 'Elev 2',
    'demo21.card2.content.label': 'Elev 8',
    'demo21.card3.content.label': 'Elev 16',

    // --- Icon Size Section ---
    'demo21.iconSizeDemo.icon.icon': 'mFormatSize',
    'demo21.iconSizeDemo.title.label': 'TomIcon Size',
    'demo21.iconSizeDemo.subtitle.label': 'size resolved from resources',
    'demo21.iconSizeDemo.info.label': 'Resources: demo21.sizedIcon1.size → 16, 32, 48',
    'demo21.sizedIcon1.icon': 'mHome',
    'demo21.sizedIcon2.icon': 'mHome',
    'demo21.sizedIcon3.icon': 'mHome',

    // --- Opacity Section ---
    'demo21.opacityDemo.icon.icon': 'mOpacity',
    'demo21.opacityDemo.title.label': 'TomAnimatedOpacity',
    'demo21.opacityDemo.subtitle.label': 'opacity resolved from resources',
    'demo21.opacityDemo.info.label': 'Resources: demo21.opacity1.opacity → 1.0, 0.6, 0.3',
    'demo21.opacity1.content.label': '100%',
    'demo21.opacity2.content.label': '60%',
    'demo21.opacity3.content.label': '30%',

    // --- Toggle Section ---
    'demo21.toggleDemo.icon.icon': 'mToggleOn',
    'demo21.toggleDemo.title.label': 'Switch & Checkbox Colors',
    'demo21.toggleDemo.subtitle.label': 'activeColor, trackColor from resources',
    'demo21.toggleDemo.info.label':
        'Resources include active + inactive switch colors and checkbox side styling.',
    'demo21.switch1.label.label': 'Green switch',
    'demo21.switch2.label.label': 'Blue switch',
    'demo21.checkbox1.label.label': 'Purple checkbox',
    'demo21.checkbox2.label.label': 'Orange checkbox',

    // --- Lookup Type Coverage Section ---
    'demo21.lookupDemo.icon.icon': 'mFactCheck',
    'demo21.lookupDemo.title.label': 'Core Lookup API Coverage',
    'demo21.lookupDemo.subtitle.label': 'all supported lookup types resolved at least once',
    'demo21.lookupDemo.info.label':
        'This card reads each typed API directly from TomCtr.',

    // Text sample for direct resolveText(basePath, suffix)
    'demo21.lookup.text': 'Hello from resolveText',
  };

  /// Structured data resources (lists, maps) for Phase 1 typed resolution.
  ///
  /// These demonstrate how complex resources can be stored for widgets
  /// to auto-assemble their content.
  static final Map<String, dynamic> _structuredResources = {
    // Example: Countries list for auto-assembling dropdowns
    'demo03.dropdown.countries.items': [
      {'value': 'us', 'label': '🇺🇸 United States', 'icon': 'mFlag'},
      {'value': 'uk', 'label': '🇬🇧 United Kingdom', 'icon': 'mFlag'},
      {'value': 'de', 'label': '🇩🇪 Germany', 'icon': 'mFlag'},
      {'value': 'fr', 'label': '🇫🇷 France', 'icon': 'mFlag'},
      {'value': 'jp', 'label': '🇯🇵 Japan', 'icon': 'mFlag'},
    ],
    // Example: Categories list
    'demo03.dropdown.categories.items': [
      {'value': 'electronics', 'label': 'Electronics', 'icon': 'mDevices'},
      {'value': 'clothing', 'label': 'Clothing', 'icon': 'mCheckroom'},
      {'value': 'homeGarden', 'label': 'Home & Garden', 'icon': 'mHome'},
      {'value': 'books', 'label': 'Books', 'icon': 'mMenuBook'},
      {'value': 'sports', 'label': 'Sports', 'icon': 'mSportsBaseball'},
    ],
    // Example: Numeric configuration
    'demo03.card.elevation': 4.0,
    'demo03.card.margin': {'all': 16},
    'demo03.card.padding': [16, 12, 16, 12],
    // Example: Color configuration
    'demo03.card.backgroundColor': 'mBlue50',

    // ==========================================================================
    // Demo 21: Visual Styling Resources (EdgeInsets, TextStyle, Colors, etc.)
    // ==========================================================================

    // --- Container Parameters (padding, margin, dimensions) ---
    'demo21.paddedBox.padding': {'left': 24.0, 'top': 16.0, 'right': 24.0, 'bottom': 16.0},
    'demo21.sizedBox.width': 150.0,
    'demo21.sizedBox.height': 100.0,
    'demo21.marginedBox.margin': {'all': 16.0},

    // --- TextStyle Parameters ---
    'demo21.styledText1.style': {
      'fontSize': 28.0,
      'fontWeight': 'bold',
      'color': '#1565C0',  // Blue 800
    },
    'demo21.styledText2.style': {
      'fontSize': 18.0,
      'fontStyle': 'italic',
      'color': '#6A1B9A',  // Purple 800
      'letterSpacing': 1.5,
    },
    'demo21.styledText3.style': {
      'fontSize': 14.0,
      'fontWeight': 'w500',
      'color': '#2E7D32',  // Green 800
      'decoration': 'underline',
    },

    // --- Icon Color Parameters ---
    'demo21.coloredIcon1.color': '#E91E63',  // Pink
    'demo21.coloredIcon2.color': '#FF9800',  // Orange
    'demo21.coloredIcon3.color': '#4CAF50',  // Green
    'demo21.coloredIcon4.color': '#2196F3',  // Blue

    // --- Container Color Parameters ---
    'demo21.colorBox1.color': '#D32F2F',  // Red 700
    'demo21.colorBox2.color': 'mTeal700',
    'demo21.colorBox3.color': 0xFF5E35B1,  // Deep Purple 600

    // --- Progress Indicator Colors ---
    'demo21.progress1.color': '#9C27B0',  // Purple
    'demo21.progress1.backgroundColor': '#E1BEE7',  // Purple 100
    'demo21.progress2.color': '#00BCD4',  // Cyan
    'demo21.progress2.backgroundColor': '#B2EBF2',  // Cyan 100
    'demo21.progress3.color': '#FF5722',  // Deep Orange
    'demo21.progress3.backgroundColor': '#FFCCBC',  // Deep Orange 100

    // --- Card Elevation ---
    'demo21.card1.elevation': 2.0,
    'demo21.card2.elevation': 8.0,
    'demo21.card3.elevation': 16.0,

    // --- Icon Size ---
    'demo21.sizedIcon1.size': 16.0,
    'demo21.sizedIcon2.size': 32.0,
    'demo21.sizedIcon3.size': 48.0,

    // --- Opacity ---
    'demo21.opacity1.opacity': 1.0,
    'demo21.opacity2.opacity': 0.6,
    'demo21.opacity3.opacity': 0.3,

    // --- Toggle Widget Colors ---
    'demo21.switch1.activeColor': '#4CAF50',  // Green
    'demo21.switch1.activeTrackColor': '#A5D6A7',  // Green 200
    'demo21.switch2.activeColor': '#2196F3',  // Blue
    'demo21.switch2.activeTrackColor': '#90CAF9',  // Blue 200
        'demo21.switch2.inactiveThumbColor': '#1E88E5',  // Blue 600 (visible when off)
        'demo21.switch2.inactiveTrackColor': '#BBDEFB',  // Blue 100 (visible when off)
    'demo21.checkbox1.activeColor': '#9C27B0',  // Purple
    'demo21.checkbox1.checkColor': '#FFFFFF',
    'demo21.checkbox2.activeColor': '#FF5722',  // Deep Orange
    'demo21.checkbox2.checkColor': '#FFFFFF',
        'demo21.checkbox2.side': {
            'color': '#FF5722',
            'width': 2.0,
            'style': 'solid',
        },

        // --- Explicit Lookup Type Coverage ---
        'demo21.lookup.color': '#3F51B5',
        'demo21.lookup.icon': 'mScience',
        'demo21.lookup.double': 42.5,
        'demo21.lookup.int': 7,
        'demo21.lookup.bool': true,
        'demo21.lookup.edgeInsets': {
            'left': 4.0,
            'top': 8.0,
            'right': 12.0,
            'bottom': 16.0,
        },
        'demo21.lookup.list': ['alpha', 'beta', 'gamma'],
        'demo21.lookup.map': {'status': 'ok', 'count': 3, 'source': 'demo21'},

  };
}

// ==========================================================================
// Demo 22: Extension Widgets
// ==========================================================================
// Section headers
const _demo22SectionResources = <String, String>{
  'demo22.section.appbar.title.label': 'App Bars',
  'demo22.section.appbar.subtitle.label':
      'TomAppBar with title, actions, and styling',
  'demo22.section.navDestination.title.label': 'Navigation Destinations',
  'demo22.section.navDestination.subtitle.label':
      'TomNavigationDestination in NavigationBar',
  'demo22.section.drawerDestination.title.label': 'Drawer Destinations',
  'demo22.section.drawerDestination.subtitle.label':
      'TomNavigationDrawerDestination in NavigationDrawer',
  'demo22.section.tableCell.title.label': 'Table Cells',
  'demo22.section.tableCell.subtitle.label':
      'TomTableCell with vertical alignment and data tables',
  'demo22.section.refreshProgress.title.label': 'Refresh Progress',
  'demo22.section.refreshProgress.subtitle.label':
      'TomRefreshProgressIndicator for pull-to-refresh',
  'demo22.section.cupertinoTabView.title.label': 'Cupertino Tab View',
  'demo22.section.cupertinoTabView.subtitle.label':
      'TomCupertinoTabView for iOS-style tab navigation',
};
// Demo cards
const _demo22CardResources = <String, String>{
  'demo22.demo.appbar.basic.icon': 'mDashboard',
  'demo22.demo.appbar.basic.title.label': 'Basic TomAppBar',
  'demo22.demo.appbar.basic.subtitle.label': 'Simple app bar with title and actions',
  'demo22.demo.appbar.styled.icon': 'mPalette',
  'demo22.demo.appbar.styled.title.label': 'Styled TomAppBar',
  'demo22.demo.appbar.styled.subtitle.label': 'Custom colors, elevation, and shape',
  'demo22.demo.appbar.titleWidget.icon': 'mWidgets',
  'demo22.demo.appbar.titleWidget.title.label': 'TomAppBar with Title Widget',
  'demo22.demo.appbar.titleWidget.subtitle.label': 'Custom widget as app bar title',
  'demo22.demo.navDest.basic.icon': 'mNavigation',
  'demo22.demo.navDest.basic.title.label': 'TomNavigationDestination',
  'demo22.demo.navDest.basic.subtitle.label': 'Destinations inside a NavigationBar',
  'demo22.demo.drawerDest.basic.icon': 'mMenu',
  'demo22.demo.drawerDest.basic.title.label': 'TomNavigationDrawerDestination',
  'demo22.demo.drawerDest.basic.subtitle.label': 'Destinations inside a NavigationDrawer',
  'demo22.demo.tableCell.basic.icon': 'mTableChart',
  'demo22.demo.tableCell.basic.title.label': 'TomTableCell',
  'demo22.demo.tableCell.basic.subtitle.label': 'Cells with vertical alignment in DataTable',
  'demo22.demo.refreshProgress.static.icon': 'mRefresh',
  'demo22.demo.refreshProgress.static.title.label': 'Static Progress Values',
  'demo22.demo.refreshProgress.static.subtitle.label': 'Various progress indicator states',
  'demo22.demo.refreshProgress.inRefresh.icon': 'mSync',
  'demo22.demo.refreshProgress.inRefresh.title.label': 'Pull-to-Refresh',
  'demo22.demo.refreshProgress.inRefresh.subtitle.label': 'RefreshIndicator with TomRefreshProgressIndicator',
  'demo22.demo.cupertinoTabView.info.icon': 'mInfoOutline',
  'demo22.demo.cupertinoTabView.info.title.label': 'TomCupertinoTabView',
  'demo22.demo.cupertinoTabView.info.subtitle.label': 'iOS tab view requiring CupertinoTabScaffold context',
};

// ==========================================================================
// Demo 23: Builders, Clips & Base
// ==========================================================================
const _demo23SectionResources = <String, String>{
  'demo23.section.asyncBuilders.title.label': 'Async Builders',
  'demo23.section.asyncBuilders.subtitle.label':
      'FutureBuilder, StreamBuilder for async data',
  'demo23.section.listenableBuilders.title.label': 'Listenable Builders',
  'demo23.section.listenableBuilders.subtitle.label':
      'ValueListenableBuilder and ListenableBuilder',
  'demo23.section.layoutBuilders.title.label': 'Layout Builders',
  'demo23.section.layoutBuilders.subtitle.label':
      'LayoutBuilder, OrientationBuilder, StatefulBuilder',
  'demo23.section.animationBuilders.title.label': 'Animation Builders',
  'demo23.section.animationBuilders.subtitle.label':
      'AnimatedBuilder, TweenAnimationBuilder, animated positioning',
  'demo23.section.clips.title.label': 'Clip Widgets',
  'demo23.section.clips.subtitle.label':
      'ClipOval, ClipPath, ClipRect, ClipRRect, ClipRSuperellipse',
  'demo23.section.baseWidgets.title.label': 'Base Widgets',
  'demo23.section.baseWidgets.subtitle.label':
      'Opacity, RawChip, EditableText primitives',
};
const _demo23CardResources = <String, String>{
  'demo23.demo.futureBuilder.icon': 'mSchedule',
  'demo23.demo.futureBuilder.title.label': 'TomFutureBuilder',
  'demo23.demo.futureBuilder.subtitle.label': 'Async data loading with snapshot handling',
  'demo23.demo.streamBuilder.icon': 'mStream',
  'demo23.demo.streamBuilder.title.label': 'TomStreamBuilder',
  'demo23.demo.streamBuilder.subtitle.label': 'Reactive stream data display',
  'demo23.demo.valueListenable.icon': 'mHearing',
  'demo23.demo.valueListenable.title.label': 'TomValueListenableBuilder',
  'demo23.demo.valueListenable.subtitle.label': 'Rebuilds on ValueNotifier changes',
  'demo23.demo.listenableBuilder.icon': 'mNotifications',
  'demo23.demo.listenableBuilder.title.label': 'TomListenableBuilder',
  'demo23.demo.listenableBuilder.subtitle.label': 'Rebuilds on any Listenable change',
  'demo23.demo.layoutBuilder.icon': 'mViewQuilt',
  'demo23.demo.layoutBuilder.title.label': 'TomLayoutBuilder',
  'demo23.demo.layoutBuilder.subtitle.label': 'Builds based on parent constraints',
  'demo23.demo.orientationBuilder.icon': 'mScreenRotation',
  'demo23.demo.orientationBuilder.title.label': 'TomOrientationBuilder',
  'demo23.demo.orientationBuilder.subtitle.label': 'Responds to orientation changes',
  'demo23.demo.statefulBuilder.icon': 'mBuildCircle',
  'demo23.demo.statefulBuilder.title.label': 'TomStatefulBuilder',
  'demo23.demo.statefulBuilder.subtitle.label': 'Local setState without full StatefulWidget',
  'demo23.demo.animatedBuilder.icon': 'mAnimation',
  'demo23.demo.animatedBuilder.title.label': 'TomAnimatedBuilder',
  'demo23.demo.animatedBuilder.subtitle.label': 'Custom animation with AnimationController',
  'demo23.demo.tweenAnimation.icon': 'mTimeline',
  'demo23.demo.tweenAnimation.title.label': 'TomTweenAnimationBuilder',
  'demo23.demo.tweenAnimation.subtitle.label': 'Implicit tween-based animation',
  'demo23.demo.animatedFractional.icon': 'mAspectRatio',
  'demo23.demo.animatedFractional.title.label': 'TomAnimatedFractionallySizedBox',
  'demo23.demo.animatedFractional.subtitle.label': 'Animated size changes with fractions',
  'demo23.demo.animatedPositioned.icon': 'mOpenWith',
  'demo23.demo.animatedPositioned.title.label': 'TomAnimatedPositionedDirectional',
  'demo23.demo.animatedPositioned.subtitle.label': 'Animated position in Stack with direction',
  'demo23.demo.clips.icon': 'mContentCut',
  'demo23.demo.clips.title.label': 'Clip Widgets',
  'demo23.demo.clips.subtitle.label': 'ClipOval, ClipPath, ClipRect, ClipRRect, ClipRSuperellipse',
  'demo23.demo.opacity.icon': 'mOpacity',
  'demo23.demo.opacity.title.label': 'TomOpacity',
  'demo23.demo.opacity.subtitle.label': 'Renders child with variable opacity',
  'demo23.demo.rawChip.icon': 'mLabel',
  'demo23.demo.rawChip.title.label': 'TomRawChip',
  'demo23.demo.rawChip.subtitle.label': 'Low-level chip with full customization',
  'demo23.demo.editableText.icon': 'mEdit',
  'demo23.demo.editableText.title.label': 'TomEditableText',
  'demo23.demo.editableText.subtitle.label': 'Base editable text without Material decoration',
};

// ==========================================================================
// Demo 24: Containers & Layout
// ==========================================================================
const _demo24SectionResources = <String, String>{
  'demo24.section.scaffolds.title.label': 'Scaffolds',
  'demo24.section.scaffolds.subtitle.label':
      'TomScaffold, BottomAppBar, CupertinoPageScaffold, CupertinoTabScaffold',
  'demo24.section.surfaces.title.label': 'Surfaces & Decorations',
  'demo24.section.surfaces.subtitle.label':
      'DecoratedBox, ColoredBox, PhysicalModel, PhysicalShape',
  'demo24.section.transforms.title.label': 'Transforms',
  'demo24.section.transforms.subtitle.label':
      'Transform, RotatedBox, FractionalTranslation, ConstraintsTransformBox',
  'demo24.section.multiChild.title.label': 'Multi-Child Layout',
  'demo24.section.multiChild.subtitle.label':
      'OverflowBar, Flow, ListBody',
  'demo24.section.customLayout.title.label': 'Custom Layout & Painting',
  'demo24.section.customLayout.subtitle.label':
      'CustomPaint, CustomSingleChildLayout',
  'demo24.section.gridExpansion.title.label': 'Grids & Expansion',
  'demo24.section.gridExpansion.subtitle.label':
      'GridTile, GridTileBar, ExpansionPanelList',
  'demo24.section.sliverExtras.title.label': 'Sliver Extras',
  'demo24.section.sliverExtras.subtitle.label':
      'SliverOffstage, SliverResizingHeader',
};
const _demo24CardResources = <String, String>{
  'demo24.demo.scaffold.icon': 'mWebAsset',
  'demo24.demo.scaffold.title.label': 'TomScaffold & TomBottomAppBar',
  'demo24.demo.scaffold.subtitle.label': 'Page scaffold with bottom app bar and FAB',
  'demo24.demo.cupertinoScaffold.icon': 'mPhoneIphone',
  'demo24.demo.cupertinoScaffold.title.label': 'TomCupertinoPageScaffold',
  'demo24.demo.cupertinoScaffold.subtitle.label': 'iOS-style page scaffold with navigation bar',
  'demo24.demo.cupertinoTabScaffold.icon': 'mTabUnselected',
  'demo24.demo.cupertinoTabScaffold.title.label': 'TomCupertinoTabScaffold',
  'demo24.demo.cupertinoTabScaffold.subtitle.label': 'iOS-style tab scaffold with tab bar',
  'demo24.demo.surfaces.icon': 'mLayers',
  'demo24.demo.surfaces.title.label': 'Surface Widgets',
  'demo24.demo.surfaces.subtitle.label': 'DecoratedBox, ColoredBox, PhysicalModel, PhysicalShape',
  'demo24.demo.transforms.icon': 'mTransform',
  'demo24.demo.transforms.title.label': 'Transform Widgets',
  'demo24.demo.transforms.subtitle.label': 'Rotate, translate, scale, transform clip',
  'demo24.demo.overflowBar.icon': 'mViewStream',
  'demo24.demo.overflowBar.title.label': 'TomOverflowBar',
  'demo24.demo.overflowBar.subtitle.label': 'Actions bar that overflows to column',
  'demo24.demo.flow.icon': 'mAccountTree',
  'demo24.demo.flow.title.label': 'TomFlow',
  'demo24.demo.flow.subtitle.label': 'Custom layout delegating to FlowDelegate',
  'demo24.demo.customPaint.icon': 'mBrush',
  'demo24.demo.customPaint.title.label': 'TomCustomPaint',
  'demo24.demo.customPaint.subtitle.label': 'Canvas-based custom painting',
  'demo24.demo.customLayout.icon': 'mDashboardCustomize',
  'demo24.demo.customLayout.title.label': 'TomCustomSingleChildLayout',
  'demo24.demo.customLayout.subtitle.label': 'Custom child positioning via delegate',
  'demo24.demo.gridTile.icon': 'mGridView',
  'demo24.demo.gridTile.title.label': 'TomGridTile & TomGridTileBar',
  'demo24.demo.gridTile.subtitle.label': 'Grid tiles with header and footer bars',
  'demo24.demo.expansionPanel.icon': 'mExpandMore',
  'demo24.demo.expansionPanel.title.label': 'TomExpansionPanel',
  'demo24.demo.expansionPanel.subtitle.label': 'Expandable panels in an ExpansionPanelList',
  'demo24.demo.sliverExtras.icon': 'mViewDay',
  'demo24.demo.sliverExtras.title.label': 'Sliver Extras',
  'demo24.demo.sliverExtras.subtitle.label': 'SliverOffstage and SliverResizingHeader',
};

// ==========================================================================
// Demo 25: Remaining Widgets
// ==========================================================================
const _demo25SectionResources = <String, String>{
  'demo25.section.buttonExtras.title.label': 'Button Extras',
  'demo25.section.buttonExtras.subtitle.label':
      'ButtonBar, MaterialButton, SnackBarAction, DropdownMenuEntry',
  'demo25.section.dialogExtras.title.label': 'Dialog Extras',
  'demo25.section.dialogExtras.subtitle.label':
      'Dialog, AboutDialog, SimpleDialogOption, DateRangePicker, TimePicker',
  'demo25.section.labelExtras.title.label': 'Label Extras',
  'demo25.section.labelExtras.subtitle.label':
      'AboutListTile, Banner, MenuAcceleratorLabel',
  'demo25.section.navExtras.title.label': 'Navigation Extras',
  'demo25.section.navExtras.subtitle.label':
      'Breadcrumb, DrawerHeader, FlexibleSpaceBar, TabPageSelector, Cupertino nav',
  'demo25.section.imageExtras.title.label': 'Image Extras',
  'demo25.section.imageExtras.subtitle.label':
      'AssetImage, FileImage, InkImage reference',
  'demo25.section.listExtras.title.label': 'List Extras',
  'demo25.section.listExtras.subtitle.label':
      'CupertinoListSection, CupertinoListTile, ReorderableListView',
};
const _demo25CardResources = <String, String>{
  'demo25.demo.dropdownMenuEntry.icon': 'mArrowDropDown',
  'demo25.demo.dropdownMenuEntry.title.label': 'TomDropdownMenuEntry',
  'demo25.demo.dropdownMenuEntry.subtitle.label': 'Entries inside TomDropdownMenu',
  'demo25.demo.snackBarAction.icon': 'mUndo',
  'demo25.demo.snackBarAction.title.label': 'TomSnackBarAction',
  'demo25.demo.snackBarAction.subtitle.label': 'Action button inside TomSnackBar',
  'demo25.demo.dialogs.icon': 'mOpenInNew',
  'demo25.demo.dialogs.title.label': 'Dialog Widgets',
  'demo25.demo.dialogs.subtitle.label': 'TomDialog, AboutDialog, SimpleDialogOption, pickers, context menu',
  'demo25.demo.cupertinoDialogActions.icon': 'mPhoneIphone',
  'demo25.demo.cupertinoDialogActions.title.label': 'Cupertino Dialog & Action Sheet',
  'demo25.demo.cupertinoDialogActions.subtitle.label': 'CupertinoDialogAction and CupertinoActionSheetAction',
  'demo25.demo.aboutListTile.icon': 'mInfoOutline',
  'demo25.demo.aboutListTile.title.label': 'TomAboutListTile',
  'demo25.demo.aboutListTile.subtitle.label': 'ListTile that shows an AboutDialog',
  'demo25.demo.banner.icon': 'mFlag',
  'demo25.demo.banner.title.label': 'TomBanner',
  'demo25.demo.banner.subtitle.label': 'Corner banner overlay on content',
  'demo25.demo.menuAccelerator.icon': 'mKeyboard',
  'demo25.demo.menuAccelerator.title.label': 'TomMenuAcceleratorLabel',
  'demo25.demo.menuAccelerator.subtitle.label': 'Keyboard accelerator hint in menus',
  'demo25.demo.breadcrumb.icon': 'mChevronRight',
  'demo25.demo.breadcrumb.title.label': 'TomBreadcrumb',
  'demo25.demo.breadcrumb.subtitle.label': 'Breadcrumb navigation trail',
  'demo25.demo.drawerHeaders.icon': 'mAccountCircle',
  'demo25.demo.drawerHeaders.title.label': 'Drawer Headers',
  'demo25.demo.drawerHeaders.subtitle.label': 'TomDrawerHeader and TomUserAccountsDrawerHeader',
  'demo25.demo.flexibleSpaceBar.icon': 'mLandscape',
  'demo25.demo.flexibleSpaceBar.title.label': 'TomFlexibleSpaceBar',
  'demo25.demo.flexibleSpaceBar.subtitle.label': 'Collapsing space in SliverAppBar',
  'demo25.demo.tabPageSelector.icon': 'mFiberManualRecord',
  'demo25.demo.tabPageSelector.title.label': 'TomTabPageSelector',
  'demo25.demo.tabPageSelector.subtitle.label': 'Dot indicators for TabController pages',
  'demo25.demo.cupertinoNavExtras.icon': 'mArrowBack',
  'demo25.demo.cupertinoNavExtras.title.label': 'Cupertino Navigation',
  'demo25.demo.cupertinoNavExtras.subtitle.label': 'CupertinoSliverNavigationBar and back button',
  'demo25.demo.imageExtras.icon': 'mImage',
  'demo25.demo.imageExtras.title.label': 'Image Widgets',
  'demo25.demo.imageExtras.subtitle.label': 'TomAssetImage, TomFileImage, TomInkImage reference',
  'demo25.demo.cupertinoList.icon': 'mList',
  'demo25.demo.cupertinoList.title.label': 'Cupertino Lists',
  'demo25.demo.cupertinoList.subtitle.label': 'TomCupertinoListSection and TomCupertinoListTile',
  'demo25.demo.reorderableList.icon': 'mDragHandle',
  'demo25.demo.reorderableList.title.label': 'TomReorderableListView',
  'demo25.demo.reorderableList.subtitle.label': 'Drag-to-reorder list items',
};

// Demo 25: Picker dialog text resources
// Primary texts are always resolved; secondary texts (errors, hints, labels)
// fall back to Flutter's built-in MaterialLocalizations when not in resources.
const _demo25PickerResources = <String, String>{
  // TomDateRangePickerDialog
  'demo25.dateRange.demo.help': 'Select date range',
  'demo25.dateRange.demo.cancel': 'Cancel',
  'demo25.dateRange.demo.confirm': 'OK',
  'demo25.dateRange.demo.save': 'Save',
  // TomTimePickerDialog
  'demo25.timePicker.demo.help': 'Select time',
  'demo25.timePicker.demo.cancel': 'Cancel',
  'demo25.timePicker.demo.confirm': 'OK',
};

// =============================================================================
// Demo 26: Scope & Action resources
// =============================================================================

const _demo26SectionResources = <String, String>{
  'demo26.section.basic.title.label': 'Basic Provider',
  'demo26.section.basic.subtitle.label': 'Widgets created once in a TomScreenElementsProviderBase, reused across rebuilds',
  'demo26.section.nested.title.label': 'Nested Scope Chains',
  'demo26.section.nested.subtitle.label': 'Providers nesting inside providers — scopes chain automatically',
  'demo26.section.actions.title.label': 'Actions Provider',
  'demo26.section.actions.subtitle.label': 'Standalone provider using zone scope (no explicit parent)',
  'demo26.section.composite.title.label': 'Composite Provider with ACL',
  'demo26.section.composite.subtitle.label': 'Provider with nested sub-providers used inside TomAclBuilder',
  'demo26.section.paths.title.label': 'Scope Path Visualization',
  'demo26.section.paths.subtitle.label': 'Shows the resolved scope path for each provider',
};

const _demo26CardResources = <String, String>{
  'demo26.card.basicProvider.icon': 'mWidgets',
  'demo26.card.basicProvider.title.label': 'Basic Provider Demo',
  'demo26.card.basicProvider.description.label': 'Widgets from BasicSectionProvider — scope path: demo26.basic',
  'demo26.card.nested1.icon': 'mLooksOne',
  'demo26.card.nested1.title.label': 'Level 1: basic',
  'demo26.card.nested1.description.label': 'Top-level provider widgets (demo26.basic.*)',
  'demo26.card.nested2.icon': 'mLooksTwo',
  'demo26.card.nested2.title.label': 'Level 2: basic.details',
  'demo26.card.nested2.description.label': 'Nested provider widgets (demo26.basic.details.*)',
  'demo26.card.nested3.icon': 'mLooks3',
  'demo26.card.nested3.title.label': 'Level 3: basic.details.metadata',
  'demo26.card.nested3.description.label': 'Deeply nested provider widgets (demo26.basic.details.metadata.*)',
  'demo26.card.actions.icon': 'mPlayArrow',
  'demo26.card.actions.title.label': 'Action Buttons',
  'demo26.card.actions.description.label': 'ActionsSectionProvider using zone scope — path: demo26.actions',
  'demo26.card.composite.icon': 'mAccountTree',
  'demo26.card.composite.title.label': 'Composite Provider',
  'demo26.card.composite.description.label': 'Provider composing address and contact sub-providers via TomAclBuilder',
  'demo26.card.paths.icon': 'mRoute',
  'demo26.card.paths.title.label': 'Resolved Scope Paths',
  'demo26.card.paths.description.label': 'Runtime scope path for each provider in the hierarchy',
};

const _demo26WidgetResources = <String, String>{
  // BasicSectionProvider: demo26.basic.*
  'demo26.basic.title.label': 'Basic Section',
  'demo26.basic.description.label': 'This section demonstrates widgets created inside a TomScreenElementsProviderBase. All widgets resolve resources under demo26.basic.',
  'demo26.basic.action.label': 'Action',
  'demo26.basic.info.label': 'Info',
  // DetailsSectionProvider: demo26.basic.details.*
  'demo26.basic.details.label.label': 'Detail Information',
  'demo26.basic.details.status.label': 'Active',
  'demo26.basic.details.edit.label': 'Edit',
  // MetadataSectionProvider: demo26.basic.details.metadata.*
  'demo26.basic.details.metadata.created.label': 'Created: 2025-01-15',
  'demo26.basic.details.metadata.modified.label': 'Modified: 2026-04-06',
  // ActionsSectionProvider: demo26.actions.*
  'demo26.actions.save.label': 'Save',
  'demo26.actions.cancel.label': 'Cancel',
  'demo26.actions.delete.label': 'Delete',
  // CompositeSectionProvider: demo26.composite.*
  'demo26.composite.header.label': 'Composite Form',
  // AddressSubProvider: demo26.composite.address.*
  'demo26.composite.address.street.label': 'Street',
  'demo26.composite.address.city.label': 'City',
  // ContactSubProvider: demo26.composite.contact.*
  'demo26.composite.contact.email.label': 'Email',
  'demo26.composite.contact.phone.label': 'Phone',
};

// =============================================================================
// Demo 27: Forms resources
// =============================================================================

const _demo27SectionResources = <String, String>{
  'demo27.section.login.title.label': 'Simple Login Form',
  'demo27.section.login.subtitle.label': 'Login form using scoped provider — all fields resolve under demo27.login',
  'demo27.section.contact.title.label': 'Multi-Section Contact Form',
  'demo27.section.contact.subtitle.label': 'Nested providers for personal info and address, laid out with TomAclBuilder',
  'demo27.section.settings.title.label': 'Settings Form',
  'demo27.section.settings.subtitle.label': 'Mixed input types: text fields and switches in a scoped provider',
  'demo27.section.aclForm.title.label': 'Form with ACL Layout',
  'demo27.section.aclForm.subtitle.label': 'Top-level TomAclBuilder accessing nested sub-provider fields via dot navigation',
};

const _demo27CardResources = <String, String>{
  'demo27.card.login.icon': 'mLogin',
  'demo27.card.login.title.label': 'Login Form',
  'demo27.card.login.description.label': 'Email and password fields from LoginFormProvider (demo27.login)',
  'demo27.card.contact.icon': 'mContacts',
  'demo27.card.contact.title.label': 'Contact Form',
  'demo27.card.contact.description.label': 'Personal and address sections with ACL layout (demo27.contact)',
  'demo27.card.settings.icon': 'mSettings',
  'demo27.card.settings.title.label': 'Settings Form',
  'demo27.card.settings.description.label': 'Text fields and toggle switches (demo27.settings)',
  'demo27.card.aclForm.icon': 'mDashboard',
  'demo27.card.aclForm.title.label': 'ACL-Laid-Out Form',
  'demo27.card.aclForm.description.label': 'ContactFormProvider fields accessed through nested sub-providers',
};

const _demo27WidgetResources = <String, String>{
  // LoginFormProvider: demo27.login.*
  'demo27.login.email.label': 'Email',
  'demo27.login.email.hint': 'Enter your email address',
  'demo27.login.password.label': 'Password',
  'demo27.login.password.hint': 'Enter your password',
  'demo27.login.submit.label': 'Sign In',
  'demo27.login.forgot.label': 'Forgot password?',
  // ContactFormProvider: demo27.contact.*
  'demo27.contact.header.label': 'Contact Information',
  'demo27.contact.save.label': 'Save Contact',
  'demo27.contact.reset.label': 'Reset',
  // PersonalSectionProvider: demo27.contact.personal.*
  'demo27.contact.personal.firstName.label': 'First Name',
  'demo27.contact.personal.firstName.hint': 'John',
  'demo27.contact.personal.lastName.label': 'Last Name',
  'demo27.contact.personal.lastName.hint': 'Doe',
  'demo27.contact.personal.email.label': 'Email',
  'demo27.contact.personal.email.hint': 'john.doe@example.com',
  'demo27.contact.personal.phone.label': 'Phone',
  'demo27.contact.personal.phone.hint': '+1 555 123 4567',
  // AddressSectionProvider: demo27.contact.address.*
  'demo27.contact.address.street.label': 'Street',
  'demo27.contact.address.street.hint': '123 Main St',
  'demo27.contact.address.city.label': 'City',
  'demo27.contact.address.city.hint': 'New York',
  'demo27.contact.address.zip.label': 'ZIP Code',
  'demo27.contact.address.zip.hint': '10001',
  'demo27.contact.address.country.label': 'Country',
  'demo27.contact.address.country.hint': 'United States',
  // SettingsFormProvider: demo27.settings.*
  'demo27.settings.displayName.label': 'Display Name',
  'demo27.settings.displayName.hint': 'Your display name',
  'demo27.settings.bio.label': 'Bio',
  'demo27.settings.bio.hint': 'Tell us about yourself',
  'demo27.settings.notificationsLabel.label': 'Enable notifications',
  'demo27.settings.darkModeLabel.label': 'Dark mode',
  'demo27.settings.notifications.label': 'Notifications',
  'demo27.settings.darkMode.label': 'Dark Mode',
  'demo27.settings.save.label': 'Save Settings',
};

// =============================================================================
// Demo 28: Authorization resources
// =============================================================================

const _demo28SectionResources = <String, String>{
  'demo28.section.controls.title.label': 'Authorization Controls',
  'demo28.section.controls.subtitle.label': 'Toggle switches to change authorization rules at runtime',
  'demo28.section.perWidget.title.label': 'Per-Widget Authorization',
  'demo28.section.perWidget.subtitle.label': 'Individual widgets hidden or made readonly based on their resource path',
  'demo28.section.groups.title.label': 'Group Authorization',
  'demo28.section.groups.subtitle.label': 'TomAuthorizationGroup controls collective visibility for premium vs. basic features',
  'demo28.section.sectionLevel.title.label': 'Section-Level Authorization',
  'demo28.section.sectionLevel.subtitle.label': 'TomAclBuilder applies authorization to the entire container and its children',
  'demo28.section.states.title.label': 'Auth State Visualization',
  'demo28.section.states.subtitle.label': 'Live view of resolved TomAuthState for each resource path',
};

const _demo28CardResources = <String, String>{
  'demo28.card.controls.icon': 'mTune',
  'demo28.card.controls.title.label': 'Control Panel',
  'demo28.card.controls.description.label': 'Toggle authorization rules and see widgets respond in real-time',
  'demo28.card.perWidget.icon': 'mVisibility',
  'demo28.card.perWidget.title.label': 'Admin Actions',
  'demo28.card.perWidget.description.label': 'View, Edit, Delete buttons with individual auth state control',
  'demo28.card.groups.icon': 'mGroup',
  'demo28.card.groups.title.label': 'Feature Groups',
  'demo28.card.groups.description.label': 'Premium and basic feature chips controlled by TomAuthorizationGroup visibility',
  'demo28.card.sectionLevel.icon': 'mSecurity',
  'demo28.card.sectionLevel.title.label': 'Profile Section',
  'demo28.card.sectionLevel.description.label': 'Entire form section controlled by parent path authorization',
  'demo28.card.states.icon': 'mPolicy',
  'demo28.card.states.title.label': 'Auth State Table',
  'demo28.card.states.description.label': 'Current TomAuthState for each resource path in the demo',
};

const _demo28WidgetResources = <String, String>{
  // Apply button (root scope)
  'demo28.apply.label': 'Apply (Rebuild All)',
  // AdminSectionProvider: demo28.admin.*
  'demo28.admin.view.label': 'View',
  'demo28.admin.edit.label': 'Edit',
  'demo28.admin.delete.label': 'Delete',
  // GroupedSectionProvider: demo28.grouped.*
  'demo28.grouped.premium1.label': 'Premium Analytics',
  'demo28.grouped.premium2.label': 'Priority Support',
  'demo28.grouped.basic1.label': 'Basic Dashboard',
  'demo28.grouped.basic2.label': 'Email Reports',
  // ProfileSectionProvider: demo28.profile.*
  'demo28.profile.name.label': 'Full Name',
  'demo28.profile.name.hint': 'Enter your full name',
  'demo28.profile.email.label': 'Email Address',
  'demo28.profile.email.hint': 'Enter your email',
  'demo28.profile.role.label': 'Role',
  'demo28.profile.role.hint': 'Your role',
  'demo28.profile.save.label': 'Save Profile',
};

/// The single registry of every per-demo resource map.
///
/// Why a list folded in a loop rather than a hand-edited spread block: the
/// merge in [initializeDemoResources] used to be ~20 inline `...map` entries,
/// so a forgotten spread silently dropped a demo's resources with no compile
/// error. Routing every map through this one list means the fold below can't
/// skip an entry — adding a demo appends its map here in exactly one place.
///
/// The per-demo maps keep their own co-located declarations (each demo's keys
/// stay reviewable next to that demo's code); this list is the authoring
/// registry, not a runtime lookup boundary — `TomTextResourceProvider`
/// resolves a single flat namespace by full `<basePath>.<suffix>` key.
final List<Map<String, dynamic>> _allDemoResourceMaps = [
  _DemoResources._resources,
  _DemoResources._structuredResources,
  _demo22SectionResources,
  _demo22CardResources,
  _demo23SectionResources,
  _demo23CardResources,
  _demo24SectionResources,
  _demo24CardResources,
  _demo25SectionResources,
  _demo25CardResources,
  _demo25PickerResources,
  _demo26SectionResources,
  _demo26CardResources,
  _demo26WidgetResources,
  _demo27SectionResources,
  _demo27CardResources,
  _demo27WidgetResources,
  _demo28SectionResources,
  _demo28CardResources,
  _demo28WidgetResources,
];

/// Initializes the Tom UI resource and icon adapters for the demo app.
///
/// Call this in `main()` before `runApp()`.
void initializeDemoResources() {
  final Map<String, dynamic> allResources = {
    for (final map in _allDemoResourceMaps) ...map,
  };
  // Why: these three static adapters are the global seams tom_flutter_ui
  // widgets read at build time — text by tomId (resource provider), icon
  // names → IconData (icon adapter), and color names → Color (color
  // adapter). Setting them here, before runApp, is what makes the demos'
  // string-keyed `mSave`/`primary` references resolve to real widgets.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(allResources),
  );
  TomUIIcons.adapter = AllIconsAdapter();
  TomUIColors.adapter = AllColorsAdapter();
}
