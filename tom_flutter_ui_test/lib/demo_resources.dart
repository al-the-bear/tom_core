/// Demo resources adapter for tom_flutter_ui_test.
///
/// Provides text and icon resources for the demo widgets via tomId lookup.
/// This demonstrates how a real application would configure resources.
library;

import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Demo resource adapter providing texts for all demo widgets.
///
/// Resource keys follow the pattern: `<tomId>.<suffix>`
/// - `demo01.elevated.basic.label` → "Basic"
/// - `demo01.elevated.save.icon` → "mSave"
class DemoResourceAdapter implements TomUIResourceAdapter {
  /// All text resources for the demo app.
  ///
  /// Keys are `<tomId>.<suffix>` where suffix is typically:
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
    'demo03.aclDropdown.sizeLabel.label': 'Size:',
    'demo03.aclDropdown.size.hint': 'Select size',

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
    return _resources.containsKey(key) ||
        _structuredResources.containsKey(key);
  }

  @override
  dynamic resolveValue(String basePath, String suffix) {
    final cleanPath = basePath.replaceFirst(RegExp(r'^w-'), '');
    final key = '$cleanPath.$suffix';

    // First check structured resources
    if (_structuredResources.containsKey(key)) {
      return _structuredResources[key];
    }

    // Fall back to string resources
    if (_resources.containsKey(key)) {
      return _resources[key];
    }

    return null;
  }

  @override
  List<dynamic>? resolveList(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value is List) return value;
    return null;
  }

  @override
  Map<String, dynamic>? resolveMap(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value is Map<String, dynamic>) return value;
    return null;
  }
}

/// Initializes the Tom UI resource and icon adapters for the demo app.
///
/// Call this in `main()` before `runApp()`.
void initializeDemoResources() {
  TomUIResources.adapter = DemoResourceAdapter();
  TomUIIcons.adapter = AllIconsAdapter();
  TomUIColors.adapter = AllColorsAdapter();
}
