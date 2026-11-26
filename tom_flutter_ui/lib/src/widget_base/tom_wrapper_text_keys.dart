/// The text keys each widget wrapper reads under its resource path, as data.
///
/// A wrapper given a `tomId` reads its texts from the application's text
/// resources at `<path>.<suffix>`: a button its `label`, a text field its
/// `label`, `hint`, `helper`, `prefix` and `suffix`. Which suffixes a wrapper
/// reads was written only in its constructor; [tomWrapperTextKeys] states it
/// for every wrapper, so a tool that checks a resource file ("this element is
/// a button, so `label` and nothing else") reads it here.
///
/// `test/widgets/wrapper_text_keys_test.dart` holds the map to the wrappers:
/// it builds every wrapper with a resource provider that records each key
/// asked for, and compares, so the map cannot drift from the code.
library;

/// What a text key holds.
enum TomTextKeyKind {
  /// A text shown to the user: a label, a hint, a tooltip. Translated.
  text,

  /// A text read by assistive technology only: a semantics label, an image's
  /// alternative text, or a `label` a wrapper uses as its semantics label (a
  /// progress indicator, a drawer). Translated.
  semantics,

  /// A value read through the text resources but never shown: a restoration
  /// id, a keyboard type, a curve name. Not translated.
  setting,
}

/// Whether a resource file has to hold a key.
enum TomTextKeyPresence {
  /// Read whenever the wrapper has a `tomId` and nothing explicit was given;
  /// a missing resource shows the dotted key on screen (`save.label`), so a
  /// missing translation is visible. A widget passed for the same slot (a
  /// `title:` widget for a `label`) takes its place and needs no resource.
  required,

  /// Used only when the resource exists; without it the wrapper has no such
  /// text.
  optional,
}

/// One text key of a wrapper or a form element: the suffix after its resource
/// path, what it holds and whether a resource file has to hold it. The
/// wrappers' keys are [tomWrapperTextKeys], the forms' `tomFormFieldTextKeys`.
class TomTextKey {
  /// A key `<path>.[suffix]`.
  const TomTextKey(this.suffix, this.kind, this.presence);

  /// The suffix after the wrapper's resource path, e.g. `label`, or
  /// `child.label` for the text a wrapper puts into a slot of its own.
  final String suffix;

  /// What the key holds.
  final TomTextKeyKind kind;

  /// Whether a resource file has to hold it.
  final TomTextKeyPresence presence;

  @override
  bool operator ==(Object other) =>
      other is TomTextKey &&
      other.suffix == suffix &&
      other.kind == kind &&
      other.presence == presence;

  @override
  int get hashCode => Object.hash(suffix, kind, presence);

  @override
  String toString() => 'TomTextKey($suffix, ${kind.name}, ${presence.name})';
}

/// The text keys of every widget wrapper of the package, by class name.
///
/// Every wrapper is listed; an empty list means the wrapper reads no text.
/// `TomDataColumn`, which is not a widget but carries a `tomId`, is listed
/// too.
const Map<String, List<TomTextKey>> tomWrapperTextKeys = {
  'TomAboutDialog': [
    TomTextKey(
      'applicationLegalese',
      TomTextKeyKind.text,
      TomTextKeyPresence.required,
    ),
    TomTextKey(
      'applicationName',
      TomTextKeyKind.text,
      TomTextKeyPresence.required,
    ),
    TomTextKey(
      'applicationVersion',
      TomTextKeyKind.text,
      TomTextKeyPresence.required,
    ),
  ],
  'TomAboutListTile': [
    TomTextKey(
      'applicationLegalese',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'applicationName',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'applicationVersion',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomAbsorbPointer': [],
  'TomActionChip': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomAlertDialog': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('title', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomAlign': [],
  'TomAnimatedAlign': [],
  'TomAnimatedBuilder': [],
  'TomAnimatedContainer': [],
  'TomAnimatedCrossFade': [],
  'TomAnimatedDefaultTextStyle': [],
  'TomAnimatedFractionallySizedBox': [],
  'TomAnimatedIcon': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomAnimatedList': [],
  'TomAnimatedOpacity': [],
  'TomAnimatedPadding': [],
  'TomAnimatedPhysicalModel': [],
  'TomAnimatedPositioned': [
    TomTextKey('child.label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'child.semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomAnimatedPositionedDirectional': [
    TomTextKey('child.label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'child.semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomAnimatedRotation': [],
  'TomAnimatedScale': [],
  'TomAnimatedSize': [],
  'TomAnimatedSlide': [],
  'TomAnimatedSwitcher': [],
  'TomAppBar': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomAspectRatio': [],
  'TomAssetImage': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.required,
    ),
  ],
  'TomAutocomplete': [],
  'TomBackButton': [],
  'TomBackdropFilter': [
    TomTextKey(
      'blendMode',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomBadge': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomBanner': [
    TomTextKey('message', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomBaseline': [],
  'TomBottomAppBar': [],
  'TomBottomNavigationBar': [],
  'TomBottomSheet': [],
  'TomBreadcrumb': [],
  'TomCalendarDatePicker': [],
  'TomCard': [],
  'TomCarouselView': [],
  'TomCenter': [],
  'TomCheckbox': [],
  'TomCheckboxListTile': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('subtitle', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomCheckboxMenuButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCheckedPopupMenuItem': [],
  'TomChip': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomChoiceChip': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCircleAvatar': [],
  'TomCircularProgressIndicator': [
    TomTextKey('label', TomTextKeyKind.semantics, TomTextKeyPresence.required),
    TomTextKey(
      'semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'semanticsValue',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomClipOval': [],
  'TomClipPath': [],
  'TomClipRRect': [],
  'TomClipRSuperellipse': [],
  'TomClipRect': [],
  'TomCloseButton': [],
  'TomColorFiltered': [],
  'TomColoredBox': [],
  'TomColumn': [],
  'TomConstrainedBox': [],
  'TomConstraintsTransformBox': [],
  'TomContainer': [],
  'TomCupertinoActionSheet': [
    TomTextKey('title', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCupertinoActionSheetAction': [],
  'TomCupertinoActivityIndicator': [],
  'TomCupertinoAlertDialog': [
    TomTextKey('title', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCupertinoButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCupertinoCheckbox': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomCupertinoContextMenu': [],
  'TomCupertinoContextMenuAction': [],
  'TomCupertinoDatePicker': [],
  'TomCupertinoDialogAction': [],
  'TomCupertinoExpansionTile': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCupertinoFormRow': [],
  'TomCupertinoFormSection': [],
  'TomCupertinoLinearActivityIndicator': [],
  'TomCupertinoListSection': [],
  'TomCupertinoListTile': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('subtitle', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomCupertinoNavigationBar': [
    TomTextKey(
      'previousPageTitle',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomCupertinoNavigationBarBackButton': [
    TomTextKey(
      'previousPageTitle',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomCupertinoPageScaffold': [],
  'TomCupertinoPicker': [],
  'TomCupertinoRadio': [],
  'TomCupertinoScrollbar': [],
  'TomCupertinoSearchTextField': [
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCupertinoSegmentedControl': [],
  'TomCupertinoSlider': [],
  'TomCupertinoSlidingSegmentedControl': [],
  'TomCupertinoSliverNavigationBar': [
    TomTextKey(
      'previousPageTitle',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomCupertinoSliverRefreshControl': [],
  'TomCupertinoSwitch': [],
  'TomCupertinoTabBar': [],
  'TomCupertinoTabScaffold': [],
  'TomCupertinoTabView': [],
  'TomCupertinoTextField': [
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCupertinoTextFormFieldRow': [
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomCupertinoTimerPicker': [],
  'TomCustomMultiChildLayout': [],
  'TomCustomPaint': [],
  'TomCustomScrollView': [],
  'TomCustomSingleChildLayout': [],
  'TomDataColumn': [
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomDataTable': [],
  'TomDatePickerDialog': [
    TomTextKey('cancel', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('confirm', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('errorFormat', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey(
      'errorInvalid',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('fieldHint', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('fieldLabel', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('help', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey(
      'keyboardType',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomDateRangePickerDialog': [
    TomTextKey('cancel', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('confirm', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('errorFormat', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey(
      'errorInvalid',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'errorInvalidRange',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'fieldEndHint',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'fieldEndLabel',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'fieldStartHint',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'fieldStartLabel',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('help', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey(
      'keyboardType',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('save', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomDecoratedBox': [],
  'TomDecoratedSliver': [],
  'TomDefaultTextStyle': [],
  'TomDialog': [],
  'TomDismissible': [],
  'TomDivider': [],
  'TomDragTarget': [
    TomTextKey(
      'hitTestBehavior',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomDraggable': [],
  'TomDraggableScrollableSheet': [],
  'TomDrawer': [
    TomTextKey('label', TomTextKeyKind.semantics, TomTextKeyPresence.required),
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomDrawerHeader': [],
  'TomDropdownButton': [
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomDropdownButtonFormField': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomDropdownMenu': [
    TomTextKey('error', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('helper', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomDropdownMenuEntry': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomDropdownMenuFormField': [
    TomTextKey('helper', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomDropdownMenuItem': [],
  'TomEditableText': [],
  'TomElevatedButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomExpandIcon': [],
  'TomExpanded': [
    TomTextKey('child.label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'child.semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomExpansionPanelList': [],
  'TomExpansionTile': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomFadeInImage': [
    TomTextKey('alt', TomTextKeyKind.semantics, TomTextKeyPresence.required),
  ],
  'TomFadeTransition': [],
  'TomFileImage': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.required,
    ),
  ],
  'TomFilledButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomFilterChip': [
    TomTextKey(
      'deleteButtonTooltipMessage',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomFittedBox': [],
  'TomFlexible': [
    TomTextKey('child.label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'child.semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomFlexibleSpaceBar': [],
  'TomFloatingActionButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomFlow': [],
  'TomFormClassic': [],
  'TomFractionalTranslation': [],
  'TomFractionallySizedBox': [],
  'TomFutureBuilder': [],
  'TomGestureDetector': [],
  'TomGridTile': [],
  'TomGridTileBar': [],
  'TomGridView': [
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomHero': [],
  'TomIcon': [
    TomTextKey('alt', TomTextKeyKind.semantics, TomTextKeyPresence.required),
  ],
  'TomIconButton': [
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomIgnorePointer': [],
  'TomImage': [
    TomTextKey('alt', TomTextKeyKind.semantics, TomTextKeyPresence.required),
  ],
  'TomImageFiltered': [],
  'TomImageIcon': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.required,
    ),
  ],
  'TomIndexedStack': [],
  'TomInk': [],
  'TomInkImage': [],
  'TomInkResponse': [],
  'TomInkWell': [],
  'TomInputChip': [
    TomTextKey(
      'deleteButtonTooltipMessage',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomInputDatePickerFormField': [
    TomTextKey('errorFormat', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'errorInvalid',
      TomTextKeyKind.text,
      TomTextKeyPresence.required,
    ),
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomInteractiveViewer': [],
  'TomIntrinsicHeight': [],
  'TomIntrinsicWidth': [],
  'TomLayoutBuilder': [],
  'TomLicensePage': [
    TomTextKey(
      'applicationLegalese',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'applicationName',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'applicationVersion',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomLimitedBox': [],
  'TomLinearProgressIndicator': [
    TomTextKey('label', TomTextKeyKind.semantics, TomTextKeyPresence.required),
    TomTextKey(
      'semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'semanticsValue',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomListBody': [],
  'TomListTile': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('subtitle', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomListView': [
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomListWheelScrollView': [
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomListenableBuilder': [],
  'TomLongPressDraggable': [],
  'TomMaterial': [],
  'TomMaterialBanner': [],
  'TomMenuAcceleratorLabel': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomMenuAnchor': [],
  'TomMenuBar': [],
  'TomMenuItemButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomModalBottomSheet': [],
  'TomMouseRegion': [
    TomTextKey(
      'hitTestBehavior',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomNavigationBar': [],
  'TomNavigationDestination': [],
  'TomNavigationDrawer': [],
  'TomNavigationDrawerDestination': [],
  'TomNavigationRail': [],
  'TomNestedScrollView': [
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomNetworkImage': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.required,
    ),
    TomTextKey('src', TomTextKeyKind.setting, TomTextKeyPresence.optional),
  ],
  'TomOffstage': [],
  'TomOpacity': [],
  'TomOrientationBuilder': [],
  'TomOutlinedButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomOverflowBar': [],
  'TomOverflowBox': [],
  'TomPadding': [],
  'TomPageView': [],
  'TomPaginatedDataTable': [],
  'TomPhysicalModel': [],
  'TomPhysicalShape': [],
  'TomPinnedHeaderSliver': [],
  'TomPopupMenuButton': [
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomPopupMenuDivider': [],
  'TomPopupMenuItem': [],
  'TomPositioned': [],
  'TomPositionedDirectional': [],
  'TomRadio': [],
  'TomRadioListTile': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('subtitle', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomRadioMenuButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomRangeSlider': [],
  'TomRawChip': [
    TomTextKey(
      'deleteButtonTooltipMessage',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomRefreshIndicator': [
    TomTextKey('label', TomTextKeyKind.semantics, TomTextKeyPresence.required),
    TomTextKey(
      'semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'semanticsValue',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomRefreshProgressIndicator': [
    TomTextKey(
      'semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
    TomTextKey(
      'semanticsValue',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomReorderableList': [],
  'TomReorderableListView': [
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomRichText': [],
  'TomRotatedBox': [],
  'TomRotationTransition': [],
  'TomRow': [],
  'TomSafeArea': [],
  'TomScaffold': [
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomScaleTransition': [],
  'TomScrollbar': [],
  'TomSearchAnchor': [
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomSearchBar': [
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomSegmentedButton': [],
  'TomSelectableRegion': [],
  'TomSelectableText': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomSelectionArea': [],
  'TomSensitiveContent': [
    TomTextKey(
      'sensitivity',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomShaderMask': [
    TomTextKey(
      'blendMode',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomSimpleDialog': [
    TomTextKey(
      'semanticLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('title', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomSimpleDialogOption': [],
  'TomSingleChildScrollView': [
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomSizedBox': [],
  'TomSizedOverflowBox': [],
  'TomSlider': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomSliverAppBar': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomSliverConstrainedCrossAxis': [],
  'TomSliverCrossAxisExpanded': [],
  'TomSliverCrossAxisGroup': [],
  'TomSliverFillRemaining': [],
  'TomSliverFillViewport': [],
  'TomSliverFixedExtentList': [],
  'TomSliverFloatingHeader': [],
  'TomSliverGrid': [],
  'TomSliverList': [],
  'TomSliverMainAxisGroup': [],
  'TomSliverOffstage': [],
  'TomSliverOpacity': [],
  'TomSliverPadding': [],
  'TomSliverPersistentHeader': [],
  'TomSliverPrototypeExtentList': [],
  'TomSliverReorderableList': [],
  'TomSliverResizingHeader': [],
  'TomSliverSafeArea': [],
  'TomSliverToBoxAdapter': [],
  'TomSliverVariedExtentList': [],
  'TomSliverVisibility': [],
  'TomSnackBar': [
    TomTextKey(
      'content.label',
      TomTextKeyKind.text,
      TomTextKeyPresence.required,
    ),
    TomTextKey(
      'content.semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomSnackBarAction': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomSpacer': [],
  'TomStack': [],
  'TomStatefulBuilder': [],
  'TomStepper': [],
  'TomStreamBuilder': [],
  'TomSubmenuButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomSwitch': [],
  'TomSwitchListTile': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('subtitle', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomTab': [],
  'TomTabBar': [],
  'TomTabBarView': [],
  'TomTabPageSelector': [],
  'TomTable': [],
  'TomTableCell': [
    TomTextKey('child.label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'child.semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomText': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'semanticsLabel',
      TomTextKeyKind.semantics,
      TomTextKeyPresence.optional,
    ),
  ],
  'TomTextButton': [
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomTextField': [
    TomTextKey('helper', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'obscuringCharacter',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('prefix', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey(
      'restorationId',
      TomTextKeyKind.setting,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('suffix', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomTextFormField': [
    TomTextKey('helper', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('hint', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey(
      'initialValue',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('label', TomTextKeyKind.text, TomTextKeyPresence.required),
    TomTextKey('prefix', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('suffix', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomTimePickerDialog': [
    TomTextKey('cancel', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('confirm', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey(
      'errorInvalid',
      TomTextKeyKind.text,
      TomTextKeyPresence.optional,
    ),
    TomTextKey('help', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('hourLabel', TomTextKeyKind.text, TomTextKeyPresence.optional),
    TomTextKey('minuteLabel', TomTextKeyKind.text, TomTextKeyPresence.optional),
  ],
  'TomToggleButtons': [],
  'TomTooltip': [
    TomTextKey('tooltip', TomTextKeyKind.text, TomTextKeyPresence.required),
  ],
  'TomTransform': [],
  'TomTreeSliver': [],
  'TomTreeView': [],
  'TomTweenAnimationBuilder': [
    TomTextKey('curve', TomTextKeyKind.setting, TomTextKeyPresence.optional),
  ],
  'TomUnconstrainedBox': [],
  'TomUserAccountsDrawerHeader': [],
  'TomValueListenableBuilder': [],
  'TomVerticalDivider': [],
  'TomVisibility': [],
  'TomWrap': [],
  'TomYearPicker': [],
};
