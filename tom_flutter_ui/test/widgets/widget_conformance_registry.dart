import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoTabBar;
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Builds one exported widget with a known [id] and [s]cope.
///
/// The return type is the contract, not a convenience. [TomWidgetSurface] is
/// what a Tom wrapper adds over the Flutter widget it delegates to, so a
/// wrapper that does not implement it **cannot be added to this map** — the
/// compiler refuses the entry. That is half the guard; the other half is
/// `widget_conformance_test.dart`, which refuses the *absence* of an entry.
typedef TomWidgetFactory = TomWidgetSurface Function(String id, TomScope? s);

/// Every widget `lib/src/widgets/` exports, and how to build one.
///
/// ## Why a written-out map and not reflection
///
/// Dart cannot construct a class by name without a mirror, and these wrappers
/// share no constructor signature: 130 take no required argument at all, and
/// the rest take between one and four — a child, a delegate, a callback, a
/// list of destinations. So the map is written out.
///
/// Written-out maps go stale, which is exactly why the test sits beside it.
/// `tccm1-01` re-scans `lib/src/widgets/**.dart` for class declarations and
/// asserts this key set is *precisely* that set. Add a wrapper and forget this
/// file and the suite names it; delete a wrapper and leave the entry behind
/// and the suite names that too. The map is hand-maintained but not
/// hand-trusted.
///
/// ## Why the arguments are the bare minimum
///
/// Each factory passes `tomId` and `scope`, plus whatever the constructor
/// marks `required` — nothing else. The conformance suite asserts the Tom
/// surface: identity, resource path, family, and the four-state authorization
/// resolution. All of that is decided at *construction*, from those two
/// arguments. Rendering is not in scope here and is covered by the
/// hand-written `testWidgets` files, which can afford to set a widget up
/// properly because there are a dozen of them rather than 290.
///
/// The required arguments are therefore inert stubs: a builder returning
/// `const SizedBox()`, an empty destination list, a zero `Duration`. These are
/// not placeholders awaiting something better. For a test that never pumps,
/// they are the correct arguments, and making them realistic would add
/// maintenance to this file without adding a single assertion to the suite.
final Map<String, TomWidgetFactory> widgetConformanceRegistry = {
  'TomAboutDialog': (id, s) => TomAboutDialog(tomId: id, scope: s),
  'TomAboutListTile': (id, s) => TomAboutListTile(tomId: id, scope: s),
  'TomAbsorbPointer': (id, s) => TomAbsorbPointer(tomId: id, scope: s),
  'TomActionChip': (id, s) => TomActionChip(tomId: id, scope: s),
  'TomAlertDialog': (id, s) => TomAlertDialog(tomId: id, scope: s),
  'TomAlign': (id, s) => TomAlign(tomId: id, scope: s),
  'TomAnimatedAlign': (id, s) => TomAnimatedAlign(tomId: id, scope: s),
  'TomAnimatedBuilder': (id, s) => TomAnimatedBuilder(
        tomId: id,
        scope: s,
        builder: (_, _) => const SizedBox(),
      ),
  'TomAnimatedContainer': (id, s) => TomAnimatedContainer(tomId: id, scope: s),
  'TomAnimatedCrossFade': (id, s) => TomAnimatedCrossFade(
        tomId: id,
        scope: s,
        firstChild: const SizedBox(),
        secondChild: const SizedBox(),
        crossFadeState: CrossFadeState.showFirst,
      ),
  'TomAnimatedDefaultTextStyle': (id, s) => TomAnimatedDefaultTextStyle(
        tomId: id,
        scope: s,
        style: const TextStyle(),
        child: const SizedBox(),
      ),
  'TomAnimatedFractionallySizedBox': (id, s) =>
      TomAnimatedFractionallySizedBox(tomId: id, scope: s),
  'TomAnimatedIcon': (id, s) => TomAnimatedIcon(
        tomId: id,
        scope: s,
        icon: AnimatedIcons.add_event,
        progress: const AlwaysStoppedAnimation<double>(0),
      ),
  'TomAnimatedList': (id, s) => TomAnimatedList(
        tomId: id,
        scope: s,
        itemBuilder: (_, _, _) => const SizedBox(),
      ),
  'TomAnimatedOpacity': (id, s) => TomAnimatedOpacity(tomId: id, scope: s),
  'TomAnimatedPadding': (id, s) => TomAnimatedPadding(tomId: id, scope: s),
  'TomAnimatedPhysicalModel': (id, s) => TomAnimatedPhysicalModel(
        tomId: id,
        scope: s,
        shape: BoxShape.rectangle,
        child: const SizedBox(),
      ),
  'TomAnimatedPositioned': (id, s) =>
      TomAnimatedPositioned(tomId: id, scope: s, duration: Duration.zero),
  'TomAnimatedPositionedDirectional': (id, s) =>
      TomAnimatedPositionedDirectional(
        tomId: id,
        scope: s,
        duration: Duration.zero,
      ),
  'TomAnimatedRotation': (id, s) => TomAnimatedRotation(tomId: id, scope: s),
  'TomAnimatedScale': (id, s) => TomAnimatedScale(tomId: id, scope: s),
  'TomAnimatedSize': (id, s) => TomAnimatedSize(tomId: id, scope: s),
  'TomAnimatedSlide': (id, s) => TomAnimatedSlide(tomId: id, scope: s),
  'TomAnimatedSwitcher': (id, s) => TomAnimatedSwitcher(tomId: id, scope: s),
  'TomAppBar': (id, s) => TomAppBar(tomId: id, scope: s),
  'TomAspectRatio': (id, s) =>
      TomAspectRatio(tomId: id, scope: s, aspectRatio: 0),
  'TomAssetImage': (id, s) => TomAssetImage(tomId: id, scope: s, name: 'x'),
  'TomAutocomplete': (id, s) =>
      TomAutocomplete<int>(tomId: id, scope: s, optionsBuilder: _options),
  'TomBackButton': (id, s) => TomBackButton(tomId: id, scope: s),
  'TomBackdropFilter': (id, s) =>
      TomBackdropFilter(tomId: id, scope: s, filter: ImageFilter.blur()),
  'TomBadge': (id, s) => TomBadge(tomId: id, scope: s),
  'TomBanner': (id, s) =>
      TomBanner(tomId: id, scope: s, location: BannerLocation.topStart),
  'TomBaseline': (id, s) =>
      TomBaseline(tomId: id, scope: s, baselineType: TextBaseline.alphabetic),
  'TomBottomAppBar': (id, s) => TomBottomAppBar(tomId: id, scope: s),
  'TomBottomNavigationBar': (id, s) =>
      TomBottomNavigationBar(tomId: id, scope: s, items: _navItems),
  'TomBottomSheet': (id, s) => TomBottomSheet(
        tomId: id,
        scope: s,
        onClosing: () {},
        builder: (_) => const SizedBox(),
      ),
  'TomBreadcrumb': (id, s) =>
      TomBreadcrumb(tomId: id, scope: s, items: const <Widget>[]),
  'TomCalendarDatePicker': (id, s) => TomCalendarDatePicker(
        tomId: id,
        scope: s,
        initialDate: DateTime(2026),
        firstDate: DateTime(2026),
        lastDate: DateTime(2026),
        onDateChanged: (_) {},
      ),
  'TomCard': (id, s) => TomCard(tomId: id, scope: s),
  'TomCarouselView': (id, s) =>
      TomCarouselView(tomId: id, scope: s, children: const <Widget>[]),
  'TomCenter': (id, s) => TomCenter(tomId: id, scope: s),
  'TomCheckbox': (id, s) => TomCheckbox(tomId: id, scope: s, value: false),
  'TomCheckboxListTile': (id, s) =>
      TomCheckboxListTile(tomId: id, scope: s, value: false),
  'TomCheckboxMenuButton': (id, s) =>
      TomCheckboxMenuButton(tomId: id, scope: s),
  'TomCheckedPopupMenuItem': (id, s) =>
      TomCheckedPopupMenuItem<int>(tomId: id, scope: s),
  'TomChip': (id, s) => TomChip(tomId: id, scope: s),
  'TomChoiceChip': (id, s) =>
      TomChoiceChip(tomId: id, scope: s, selected: false),
  'TomCircleAvatar': (id, s) => TomCircleAvatar(tomId: id, scope: s),
  'TomCircularProgressIndicator': (id, s) =>
      TomCircularProgressIndicator(tomId: id, scope: s),
  'TomClipOval': (id, s) => TomClipOval(tomId: id, scope: s),
  'TomClipPath': (id, s) => TomClipPath(tomId: id, scope: s),
  'TomClipRRect': (id, s) => TomClipRRect(tomId: id, scope: s),
  'TomClipRSuperellipse': (id, s) => TomClipRSuperellipse(tomId: id, scope: s),
  'TomClipRect': (id, s) => TomClipRect(tomId: id, scope: s),
  'TomCloseButton': (id, s) => TomCloseButton(tomId: id, scope: s),
  'TomColorFiltered': (id, s) =>
      TomColorFiltered(tomId: id, scope: s, colorFilter: _colorFilter),
  'TomColoredBox': (id, s) => TomColoredBox(tomId: id, scope: s),
  'TomColumn': (id, s) => TomColumn(tomId: id, scope: s),
  'TomConstrainedBox': (id, s) => TomConstrainedBox(
        tomId: id,
        scope: s,
        constraints: const BoxConstraints(),
      ),
  'TomConstraintsTransformBox': (id, s) => TomConstraintsTransformBox(
        tomId: id,
        scope: s,
        constraintsTransform: (c) => c,
      ),
  'TomContainer': (id, s) => TomContainer(tomId: id, scope: s),
  'TomCupertinoActionSheet': (id, s) =>
      TomCupertinoActionSheet(tomId: id, scope: s),
  'TomCupertinoActionSheetAction': (id, s) => TomCupertinoActionSheetAction(
        tomId: id,
        scope: s,
        onPressed: () {},
        child: const SizedBox(),
      ),
  'TomCupertinoActivityIndicator': (id, s) =>
      TomCupertinoActivityIndicator(tomId: id, scope: s),
  'TomCupertinoAlertDialog': (id, s) =>
      TomCupertinoAlertDialog(tomId: id, scope: s),
  'TomCupertinoButton': (id, s) => TomCupertinoButton(tomId: id, scope: s),
  'TomCupertinoCheckbox': (id, s) =>
      TomCupertinoCheckbox(tomId: id, scope: s, value: false),
  'TomCupertinoContextMenu': (id, s) => TomCupertinoContextMenu(
        tomId: id,
        scope: s,
        actions: const <Widget>[],
        child: const SizedBox(),
      ),
  'TomCupertinoContextMenuAction': (id, s) => TomCupertinoContextMenuAction(
        tomId: id,
        scope: s,
        child: const SizedBox(),
      ),
  'TomCupertinoDatePicker': (id, s) =>
      TomCupertinoDatePicker(tomId: id, scope: s, onDateTimeChanged: (_) {}),
  'TomCupertinoDialogAction': (id, s) =>
      TomCupertinoDialogAction(tomId: id, scope: s, child: const SizedBox()),
  'TomCupertinoExpansionTile': (id, s) =>
      TomCupertinoExpansionTile(tomId: id, scope: s, child: const SizedBox()),
  'TomCupertinoFormRow': (id, s) =>
      TomCupertinoFormRow(tomId: id, scope: s, child: const SizedBox()),
  'TomCupertinoFormSection': (id, s) =>
      TomCupertinoFormSection(tomId: id, scope: s, children: const <Widget>[]),
  'TomCupertinoLinearActivityIndicator': (id, s) =>
      TomCupertinoLinearActivityIndicator(tomId: id, scope: s),
  'TomCupertinoListSection': (id, s) =>
      TomCupertinoListSection(tomId: id, scope: s),
  'TomCupertinoListTile': (id, s) => TomCupertinoListTile(tomId: id, scope: s),
  'TomCupertinoNavigationBar': (id, s) =>
      TomCupertinoNavigationBar(tomId: id, scope: s),
  'TomCupertinoNavigationBarBackButton': (id, s) =>
      TomCupertinoNavigationBarBackButton(tomId: id, scope: s),
  'TomCupertinoPageScaffold': (id, s) =>
      TomCupertinoPageScaffold(tomId: id, scope: s, child: const SizedBox()),
  'TomCupertinoPicker': (id, s) => TomCupertinoPicker(
        tomId: id,
        scope: s,
        onSelectedItemChanged: (_) {},
        children: const <Widget>[],
      ),
  'TomCupertinoRadio': (id, s) =>
      TomCupertinoRadio<int>(tomId: id, scope: s, value: 0, groupValue: 0),
  'TomCupertinoScrollbar': (id, s) =>
      TomCupertinoScrollbar(tomId: id, scope: s, child: const SizedBox()),
  'TomCupertinoSearchTextField': (id, s) =>
      TomCupertinoSearchTextField(tomId: id, scope: s),
  'TomCupertinoSegmentedControl': (id, s) => TomCupertinoSegmentedControl<int>(
        tomId: id,
        scope: s,
        onValueChanged: (_) {},
        children: const <int, Widget>{},
      ),
  'TomCupertinoSlider': (id, s) =>
      TomCupertinoSlider(tomId: id, scope: s, value: 0),
  'TomCupertinoSlidingSegmentedControl': (id, s) =>
      TomCupertinoSlidingSegmentedControl<int>(
        tomId: id,
        scope: s,
        groupValue: 0,
        onValueChanged: (_) {},
        children: const <int, Widget>{},
      ),
  'TomCupertinoSliverNavigationBar': (id, s) =>
      TomCupertinoSliverNavigationBar(tomId: id, scope: s),
  'TomCupertinoSliverRefreshControl': (id, s) =>
      TomCupertinoSliverRefreshControl(tomId: id, scope: s),
  'TomCupertinoSwitch': (id, s) =>
      TomCupertinoSwitch(tomId: id, scope: s, value: false),
  'TomCupertinoTabBar': (id, s) =>
      TomCupertinoTabBar(tomId: id, scope: s, items: _navItems),
  'TomCupertinoTabScaffold': (id, s) => TomCupertinoTabScaffold(
        tomId: id,
        scope: s,
        tabBar: _tabBar(),
        tabBuilder: (_, _) => const SizedBox(),
      ),
  'TomCupertinoTabView': (id, s) => TomCupertinoTabView(tomId: id, scope: s),
  'TomCupertinoTextField': (id, s) =>
      TomCupertinoTextField(tomId: id, scope: s),
  'TomCupertinoTextFormFieldRow': (id, s) =>
      TomCupertinoTextFormFieldRow(tomId: id, scope: s),
  'TomCupertinoTimerPicker': (id, s) => TomCupertinoTimerPicker(
        tomId: id,
        scope: s,
        onTimerDurationChanged: (_) {},
      ),
  'TomCustomMultiChildLayout': (id, s) => TomCustomMultiChildLayout(
        tomId: id,
        scope: s,
        delegate: _EmptyMultiChildDelegate(),
      ),
  'TomCustomPaint': (id, s) => TomCustomPaint(tomId: id, scope: s),
  'TomCustomScrollView': (id, s) => TomCustomScrollView(tomId: id, scope: s),
  'TomCustomSingleChildLayout': (id, s) => TomCustomSingleChildLayout(
        tomId: id,
        scope: s,
        delegate: _EmptySingleChildDelegate(),
      ),
  'TomDataTable': (id, s) => TomDataTable(
        tomId: id,
        scope: s,
        columns: _dataColumns,
        rows: const <DataRow>[],
      ),
  'TomDatePickerDialog': (id, s) => TomDatePickerDialog(
        tomId: id,
        scope: s,
        initialDate: DateTime(2026),
        firstDate: DateTime(2026),
        lastDate: DateTime(2026),
      ),
  'TomDateRangePickerDialog': (id, s) => TomDateRangePickerDialog(
        tomId: id,
        scope: s,
        firstDate: DateTime(2026),
        lastDate: DateTime(2026),
      ),
  'TomDecoratedBox': (id, s) =>
      TomDecoratedBox(tomId: id, scope: s, decoration: const BoxDecoration()),
  'TomDecoratedSliver': (id, s) =>
      TomDecoratedSliver(tomId: id, scope: s, sliver: const SizedBox()),
  'TomDefaultTextStyle': (id, s) => TomDefaultTextStyle(
        tomId: id,
        scope: s,
        style: const TextStyle(),
        child: const SizedBox(),
      ),
  'TomDialog': (id, s) => TomDialog(tomId: id, scope: s),
  'TomDismissible': (id, s) =>
      TomDismissible(tomId: id, scope: s, child: const SizedBox()),
  'TomDivider': (id, s) => TomDivider(tomId: id, scope: s),
  'TomDragTarget': (id, s) => TomDragTarget<int>(
        tomId: id,
        scope: s,
        builder: (_, _, _) => const SizedBox(),
      ),
  'TomDraggable': (id, s) => TomDraggable<int>(
        tomId: id,
        scope: s,
        feedback: const SizedBox(),
        child: const SizedBox(),
      ),
  'TomDraggableScrollableSheet': (id, s) => TomDraggableScrollableSheet(
        tomId: id,
        scope: s,
        builder: (_, _) => const SizedBox(),
      ),
  'TomDrawer': (id, s) => TomDrawer(tomId: id, scope: s),
  'TomDrawerHeader': (id, s) => TomDrawerHeader(tomId: id, scope: s),
  'TomDropdownButton': (id, s) => TomDropdownButton<int>(tomId: id, scope: s),
  'TomDropdownButtonFormField': (id, s) => TomDropdownButtonFormField<int>(
        tomId: id,
        scope: s,
        items: const <DropdownMenuItem<int>>[],
      ),
  'TomDropdownMenu': (id, s) => TomDropdownMenu<int>(
        tomId: id,
        scope: s,
        dropdownMenuEntries: _menuEntries,
      ),
  'TomDropdownMenuEntry': (id, s) =>
      TomDropdownMenuEntry<int>(tomId: id, scope: s, value: 0),
  'TomDropdownMenuFormField': (id, s) => TomDropdownMenuFormField<int>(
        tomId: id,
        scope: s,
        dropdownMenuEntries: _menuEntries,
      ),
  'TomDropdownMenuItem': (id, s) =>
      TomDropdownMenuItem<int>(tomId: id, scope: s, child: const SizedBox()),
  'TomEditableText': (id, s) => TomEditableText(
        tomId: id,
        scope: s,
        controller: TextEditingController(),
        focusNode: FocusNode(),
        style: const TextStyle(),
        cursorColor: const Color(0xFF000000),
      ),
  'TomElevatedButton': (id, s) => TomElevatedButton(tomId: id, scope: s),
  'TomExpandIcon': (id, s) => TomExpandIcon(tomId: id, scope: s),
  'TomExpanded': (id, s) => TomExpanded(tomId: id, scope: s),
  'TomExpansionPanelList': (id, s) =>
      TomExpansionPanelList(tomId: id, scope: s),
  'TomExpansionTile': (id, s) => TomExpansionTile(tomId: id, scope: s),
  'TomFadeInImage': (id, s) => TomFadeInImage(
        tomId: id,
        scope: s,
        placeholder: const AssetImage('x'),
        image: const AssetImage('x'),
      ),
  'TomFadeTransition': (id, s) => TomFadeTransition(
        tomId: id,
        scope: s,
        opacity: const AlwaysStoppedAnimation<double>(0),
      ),
  'TomFileImage': (id, s) => TomFileImage(tomId: id, scope: s, filePath: 'x'),
  'TomFilledButton': (id, s) => TomFilledButton(tomId: id, scope: s),
  'TomFilterChip': (id, s) =>
      TomFilterChip(tomId: id, scope: s, selected: false),
  'TomFittedBox': (id, s) => TomFittedBox(tomId: id, scope: s),
  'TomFlexible': (id, s) => TomFlexible(tomId: id, scope: s),
  'TomFlexibleSpaceBar': (id, s) => TomFlexibleSpaceBar(tomId: id, scope: s),
  'TomFloatingActionButton': (id, s) =>
      TomFloatingActionButton(tomId: id, scope: s),
  'TomFlow': (id, s) =>
      TomFlow(tomId: id, scope: s, delegate: _EmptyFlowDelegate()),
  'TomFormClassic': (id, s) =>
      TomFormClassic(tomId: id, scope: s, child: const SizedBox()),
  'TomFractionalTranslation': (id, s) =>
      TomFractionalTranslation(tomId: id, scope: s, translation: Offset.zero),
  'TomFractionallySizedBox': (id, s) =>
      TomFractionallySizedBox(tomId: id, scope: s),
  'TomFutureBuilder': (id, s) => TomFutureBuilder<int>(
        tomId: id,
        scope: s,
        builder: (_, _) => const SizedBox(),
      ),
  'TomGestureDetector': (id, s) => TomGestureDetector(tomId: id, scope: s),
  'TomGridTile': (id, s) =>
      TomGridTile(tomId: id, scope: s, child: const SizedBox()),
  'TomGridTileBar': (id, s) => TomGridTileBar(tomId: id, scope: s),
  'TomGridView': (id, s) => TomGridView(
        tomId: id,
        scope: s,
        gridDelegate: _gridDelegate,
        childrenDelegate: SliverChildListDelegate(const []),
      ),
  'TomHero': (id, s) =>
      TomHero(tomId: id, scope: s, tag: 0, child: const SizedBox()),
  'TomIcon': (id, s) => TomIcon(tomId: id, scope: s),
  'TomIconButton': (id, s) => TomIconButton(tomId: id, scope: s),
  'TomIgnorePointer': (id, s) => TomIgnorePointer(tomId: id, scope: s),
  'TomImage': (id, s) =>
      TomImage(tomId: id, scope: s, imageProvider: const AssetImage('x')),
  'TomImageFiltered': (id, s) =>
      TomImageFiltered(tomId: id, scope: s, imageFilter: ImageFilter.blur()),
  'TomImageIcon': (id, s) => TomImageIcon(tomId: id, scope: s),
  'TomIndexedStack': (id, s) => TomIndexedStack(tomId: id, scope: s),
  'TomInk': (id, s) => TomInk(tomId: id, scope: s),
  'TomInkImage': (id, s) =>
      TomInkImage(tomId: id, scope: s, image: const AssetImage('x')),
  'TomInkResponse': (id, s) => TomInkResponse(tomId: id, scope: s),
  'TomInkWell': (id, s) => TomInkWell(tomId: id, scope: s),
  'TomInputChip': (id, s) => TomInputChip(tomId: id, scope: s),
  'TomInputDatePickerFormField': (id, s) => TomInputDatePickerFormField(
        tomId: id,
        scope: s,
        initialDate: DateTime(2026),
        firstDate: DateTime(2026),
        lastDate: DateTime(2026),
      ),
  'TomInteractiveViewer': (id, s) =>
      TomInteractiveViewer(tomId: id, scope: s, child: const SizedBox()),
  'TomIntrinsicHeight': (id, s) => TomIntrinsicHeight(tomId: id, scope: s),
  'TomIntrinsicWidth': (id, s) => TomIntrinsicWidth(tomId: id, scope: s),
  'TomLayoutBuilder': (id, s) => TomLayoutBuilder(
        tomId: id,
        scope: s,
        builder: (_, _) => const SizedBox(),
      ),
  'TomLicensePage': (id, s) => TomLicensePage(tomId: id, scope: s),
  'TomLimitedBox': (id, s) => TomLimitedBox(tomId: id, scope: s),
  'TomLinearProgressIndicator': (id, s) =>
      TomLinearProgressIndicator(tomId: id, scope: s),
  'TomListBody': (id, s) => TomListBody(tomId: id, scope: s),
  'TomListTile': (id, s) => TomListTile(tomId: id, scope: s),
  'TomListView': (id, s) => TomListView(tomId: id, scope: s),
  'TomListWheelScrollView': (id, s) => TomListWheelScrollView(
        tomId: id,
        scope: s,
        childDelegate: ListWheelChildListDelegate(children: const []),
      ),
  'TomListenableBuilder': (id, s) => TomListenableBuilder(
        tomId: id,
        scope: s,
        listenable: ValueNotifier<int>(0),
        builder: (_, _) => const SizedBox(),
      ),
  'TomLongPressDraggable': (id, s) => TomLongPressDraggable<int>(
        tomId: id,
        scope: s,
        feedback: const SizedBox(),
        child: const SizedBox(),
      ),
  'TomMaterial': (id, s) => TomMaterial(tomId: id, scope: s),
  'TomMaterialBanner': (id, s) => TomMaterialBanner(
        tomId: id,
        scope: s,
        content: const SizedBox(),
        actions: const <Widget>[],
      ),
  'TomMenuAcceleratorLabel': (id, s) =>
      TomMenuAcceleratorLabel(tomId: id, scope: s),
  'TomMenuAnchor': (id, s) =>
      TomMenuAnchor(tomId: id, scope: s, menuChildren: const <Widget>[]),
  'TomMenuBar': (id, s) =>
      TomMenuBar(tomId: id, scope: s, children: const <Widget>[]),
  'TomMenuItemButton': (id, s) => TomMenuItemButton(tomId: id, scope: s),
  'TomModalBottomSheet': (id, s) => TomModalBottomSheet(
        tomId: id,
        scope: s,
        builder: (_) => const SizedBox(),
      ),
  'TomMouseRegion': (id, s) => TomMouseRegion(tomId: id, scope: s),
  'TomNavigationBar': (id, s) =>
      TomNavigationBar(tomId: id, scope: s, destinations: const <Widget>[]),
  'TomNavigationDestination': (id, s) => TomNavigationDestination(
        tomId: id,
        scope: s,
        icon: const SizedBox(),
        label: 'x',
      ),
  'TomNavigationDrawer': (id, s) =>
      TomNavigationDrawer(tomId: id, scope: s, children: const <Widget>[]),
  'TomNavigationDrawerDestination': (id, s) => TomNavigationDrawerDestination(
        tomId: id,
        scope: s,
        icon: const SizedBox(),
        label: const SizedBox(),
      ),
  'TomNavigationRail': (id, s) =>
      TomNavigationRail(tomId: id, scope: s, destinations: _railDestinations),
  'TomNestedScrollView': (id, s) => TomNestedScrollView(
        tomId: id,
        scope: s,
        headerSliverBuilder: (_, _) => const <Widget>[],
        body: const SizedBox(),
      ),
  'TomNetworkImage': (id, s) => TomNetworkImage(tomId: id, scope: s, src: 'x'),
  'TomOffstage': (id, s) => TomOffstage(tomId: id, scope: s),
  'TomOpacity': (id, s) => TomOpacity(tomId: id, scope: s),
  'TomOrientationBuilder': (id, s) => TomOrientationBuilder(
        tomId: id,
        scope: s,
        builder: (_, _) => const SizedBox(),
      ),
  'TomOutlinedButton': (id, s) => TomOutlinedButton(tomId: id, scope: s),
  'TomOverflowBar': (id, s) => TomOverflowBar(tomId: id, scope: s),
  'TomOverflowBox': (id, s) => TomOverflowBox(tomId: id, scope: s),
  'TomPadding': (id, s) =>
      TomPadding(tomId: id, scope: s, padding: EdgeInsets.zero),
  'TomPageView': (id, s) =>
      TomPageView(tomId: id, scope: s, children: const <Widget>[]),
  'TomPaginatedDataTable': (id, s) => TomPaginatedDataTable(
        tomId: id,
        scope: s,
        columns: _dataColumns,
        source: _EmptyDataSource(),
      ),
  'TomPhysicalModel': (id, s) => TomPhysicalModel(tomId: id, scope: s),
  'TomPhysicalShape': (id, s) =>
      TomPhysicalShape(tomId: id, scope: s, clipper: _EmptyClipper()),
  'TomPinnedHeaderSliver': (id, s) =>
      TomPinnedHeaderSliver(tomId: id, scope: s, child: const SizedBox()),
  'TomPopupMenuButton': (id, s) => TomPopupMenuButton<int>(
        tomId: id,
        scope: s,
        itemBuilder: (_) => const <PopupMenuEntry<int>>[],
      ),
  'TomPopupMenuDivider': (id, s) => TomPopupMenuDivider(tomId: id, scope: s),
  'TomPopupMenuItem': (id, s) =>
      TomPopupMenuItem<int>(tomId: id, scope: s, child: const SizedBox()),
  'TomPositioned': (id, s) =>
      TomPositioned(tomId: id, scope: s, child: const SizedBox()),
  'TomPositionedDirectional': (id, s) =>
      TomPositionedDirectional(tomId: id, scope: s, child: const SizedBox()),
  'TomRadio': (id, s) => TomRadio<int>(tomId: id, scope: s, value: 0),
  'TomRadioListTile': (id, s) =>
      TomRadioListTile<int>(tomId: id, scope: s, value: 0),
  'TomRadioMenuButton': (id, s) =>
      TomRadioMenuButton<int>(tomId: id, scope: s, value: 0),
  'TomRangeSlider': (id, s) =>
      TomRangeSlider(tomId: id, scope: s, values: const RangeValues(0, 1)),
  'TomRawChip': (id, s) => TomRawChip(tomId: id, scope: s),
  'TomRefreshIndicator': (id, s) => TomRefreshIndicator(
        tomId: id,
        scope: s,
        onRefresh: () async {},
        child: const SizedBox(),
      ),
  'TomRefreshProgressIndicator': (id, s) =>
      TomRefreshProgressIndicator(tomId: id, scope: s),
  'TomReorderableList': (id, s) => TomReorderableList(
        tomId: id,
        scope: s,
        childrenDelegate: SliverChildListDelegate(const []),
        onReorderItem: (_, _) {},
      ),
  'TomReorderableListView': (id, s) => TomReorderableListView(
        tomId: id,
        scope: s,
        onReorderItem: (_, _) {},
        children: const <Widget>[],
      ),
  'TomRichText': (id, s) =>
      TomRichText(tomId: id, scope: s, text: const TextSpan(text: 'x')),
  'TomRotatedBox': (id, s) => TomRotatedBox(tomId: id, scope: s),
  'TomRotationTransition': (id, s) => TomRotationTransition(
        tomId: id,
        scope: s,
        turns: const AlwaysStoppedAnimation<double>(0),
      ),
  'TomRow': (id, s) => TomRow(tomId: id, scope: s),
  'TomSafeArea': (id, s) =>
      TomSafeArea(tomId: id, scope: s, child: const SizedBox()),
  'TomScaffold': (id, s) => TomScaffold(tomId: id, scope: s),
  'TomScaleTransition': (id, s) => TomScaleTransition(
        tomId: id,
        scope: s,
        scale: const AlwaysStoppedAnimation<double>(0),
      ),
  'TomScrollbar': (id, s) =>
      TomScrollbar(tomId: id, scope: s, child: const SizedBox()),
  'TomSearchAnchor': (id, s) => TomSearchAnchor(
        tomId: id,
        scope: s,
        suggestionsBuilder: (_, _) => const <Widget>[],
      ),
  'TomSearchBar': (id, s) => TomSearchBar(tomId: id, scope: s),
  'TomSegmentedButton': (id, s) => TomSegmentedButton<int>(
        tomId: id,
        scope: s,
        segments: _segments,
        selected: const <int>{0},
      ),
  'TomSelectableRegion': (id, s) => TomSelectableRegion(
        tomId: id,
        scope: s,
        selectionControls: materialTextSelectionControls,
        child: const SizedBox(),
      ),
  'TomSelectableText': (id, s) => TomSelectableText(tomId: id, scope: s),
  'TomSelectionArea': (id, s) =>
      TomSelectionArea(tomId: id, scope: s, child: const SizedBox()),
  'TomSensitiveContent': (id, s) =>
      TomSensitiveContent(tomId: id, scope: s, child: const SizedBox()),
  'TomShaderMask': (id, s) =>
      TomShaderMask(tomId: id, scope: s, shaderCallback: _shader),
  'TomSimpleDialog': (id, s) => TomSimpleDialog(tomId: id, scope: s),
  'TomSimpleDialogOption': (id, s) =>
      TomSimpleDialogOption(tomId: id, scope: s),
  'TomSingleChildScrollView': (id, s) =>
      TomSingleChildScrollView(tomId: id, scope: s),
  'TomSizedBox': (id, s) => TomSizedBox(tomId: id, scope: s),
  'TomSizedOverflowBox': (id, s) =>
      TomSizedOverflowBox(tomId: id, scope: s, size: Size.zero),
  'TomSlider': (id, s) => TomSlider(tomId: id, scope: s, value: 0),
  'TomSliverAppBar': (id, s) => TomSliverAppBar(tomId: id, scope: s),
  'TomSliverConstrainedCrossAxis': (id, s) => TomSliverConstrainedCrossAxis(
        tomId: id,
        scope: s,
        sliver: const SizedBox(),
      ),
  'TomSliverCrossAxisExpanded': (id, s) =>
      TomSliverCrossAxisExpanded(tomId: id, scope: s, sliver: const SizedBox()),
  'TomSliverCrossAxisGroup': (id, s) =>
      TomSliverCrossAxisGroup(tomId: id, scope: s, slivers: const <Widget>[]),
  'TomSliverFillRemaining': (id, s) =>
      TomSliverFillRemaining(tomId: id, scope: s),
  'TomSliverFillViewport': (id, s) => TomSliverFillViewport(
        tomId: id,
        scope: s,
        delegate: SliverChildListDelegate(const []),
      ),
  'TomSliverFixedExtentList': (id, s) => TomSliverFixedExtentList(
        tomId: id,
        scope: s,
        delegate: SliverChildListDelegate(const []),
      ),
  'TomSliverFloatingHeader': (id, s) =>
      TomSliverFloatingHeader(tomId: id, scope: s, child: const SizedBox()),
  'TomSliverGrid': (id, s) => TomSliverGrid(
        tomId: id,
        scope: s,
        delegate: SliverChildListDelegate(const []),
        gridDelegate: _gridDelegate,
      ),
  'TomSliverList': (id, s) => TomSliverList(
        tomId: id,
        scope: s,
        delegate: SliverChildListDelegate(const []),
      ),
  'TomSliverMainAxisGroup': (id, s) =>
      TomSliverMainAxisGroup(tomId: id, scope: s, slivers: const <Widget>[]),
  'TomSliverOffstage': (id, s) =>
      TomSliverOffstage(tomId: id, scope: s, sliver: const SizedBox()),
  'TomSliverOpacity': (id, s) =>
      TomSliverOpacity(tomId: id, scope: s, sliver: const SizedBox()),
  'TomSliverPadding': (id, s) =>
      TomSliverPadding(tomId: id, scope: s, sliver: const SizedBox()),
  'TomSliverPersistentHeader': (id, s) => TomSliverPersistentHeader(
        tomId: id,
        scope: s,
        delegate: _EmptyHeaderDelegate(),
      ),
  'TomSliverPrototypeExtentList': (id, s) => TomSliverPrototypeExtentList(
        tomId: id,
        scope: s,
        delegate: SliverChildListDelegate(const []),
        prototypeItem: const SizedBox(),
      ),
  'TomSliverReorderableList': (id, s) => TomSliverReorderableList(
        tomId: id,
        scope: s,
        itemBuilder: (_, _) => const SizedBox(),
        itemCount: 0,
        onReorderItem: (_, _) {},
      ),
  'TomSliverResizingHeader': (id, s) =>
      TomSliverResizingHeader(tomId: id, scope: s),
  'TomSliverSafeArea': (id, s) =>
      TomSliverSafeArea(tomId: id, scope: s, sliver: const SizedBox()),
  'TomSliverToBoxAdapter': (id, s) =>
      TomSliverToBoxAdapter(tomId: id, scope: s),
  'TomSliverVariedExtentList': (id, s) => TomSliverVariedExtentList(
        tomId: id,
        scope: s,
        delegate: SliverChildListDelegate(const []),
        itemExtentBuilder: (_, _) => 1.0,
      ),
  'TomSliverVisibility': (id, s) =>
      TomSliverVisibility(tomId: id, scope: s, sliver: const SizedBox()),
  'TomSnackBar': (id, s) => TomSnackBar(tomId: id, scope: s),
  'TomSnackBarAction': (id, s) =>
      TomSnackBarAction(tomId: id, scope: s, onPressed: () {}),
  'TomSpacer': (id, s) => TomSpacer(tomId: id, scope: s),
  'TomStack': (id, s) => TomStack(tomId: id, scope: s),
  'TomStatefulBuilder': (id, s) => TomStatefulBuilder(
        tomId: id,
        scope: s,
        builder: (_, _) => const SizedBox(),
      ),
  'TomStepper': (id, s) => TomStepper(tomId: id, scope: s, steps: _steps),
  'TomStreamBuilder': (id, s) => TomStreamBuilder<int>(
        tomId: id,
        scope: s,
        builder: (_, _) => const SizedBox(),
      ),
  'TomSubmenuButton': (id, s) =>
      TomSubmenuButton(tomId: id, scope: s, menuChildren: const <Widget>[]),
  'TomSwitch': (id, s) => TomSwitch(tomId: id, scope: s, value: false),
  'TomSwitchListTile': (id, s) =>
      TomSwitchListTile(tomId: id, scope: s, value: false),
  'TomTab': (id, s) => TomTab(tomId: id, scope: s, text: 'x'),
  'TomTabBar': (id, s) =>
      TomTabBar(tomId: id, scope: s, tabs: const <Widget>[]),
  'TomTabBarView': (id, s) =>
      TomTabBarView(tomId: id, scope: s, children: const <Widget>[]),
  'TomTabPageSelector': (id, s) => TomTabPageSelector(tomId: id, scope: s),
  'TomTable': (id, s) => TomTable(tomId: id, scope: s),
  'TomTableCell': (id, s) => TomTableCell(tomId: id, scope: s),
  'TomText': (id, s) => TomText(tomId: id, scope: s),
  'TomTextButton': (id, s) => TomTextButton(tomId: id, scope: s),
  'TomTextField': (id, s) => TomTextField(tomId: id, scope: s),
  'TomTextFormField': (id, s) => TomTextFormField(tomId: id, scope: s),
  'TomTimePickerDialog': (id, s) => TomTimePickerDialog(
        tomId: id,
        scope: s,
        initialTime: const TimeOfDay(hour: 0, minute: 0),
      ),
  'TomToggleButtons': (id, s) => TomToggleButtons(
        tomId: id,
        scope: s,
        isSelected: const [false],
        children: const <Widget>[],
      ),
  'TomTooltip': (id, s) => TomTooltip(tomId: id, scope: s),
  'TomTransform': (id, s) =>
      TomTransform(tomId: id, scope: s, transform: Matrix4.identity()),
  'TomTreeSliver': (id, s) => TomTreeSliver<int>(
        tomId: id,
        scope: s,
        tree: const <TreeSliverNode<int>>[],
      ),
  'TomTreeView': (id, s) =>
      TomTreeView(tomId: id, scope: s, nodes: const <TomTreeNode>[]),
  'TomTweenAnimationBuilder': (id, s) => TomTweenAnimationBuilder<int>(
        tomId: id,
        scope: s,
        tween: IntTween(begin: 0, end: 1),
        duration: Duration.zero,
        builder: (_, _, _) => const SizedBox(),
      ),
  'TomUnconstrainedBox': (id, s) => TomUnconstrainedBox(tomId: id, scope: s),
  'TomUserAccountsDrawerHeader': (id, s) =>
      TomUserAccountsDrawerHeader(tomId: id, scope: s),
  'TomValueListenableBuilder': (id, s) => TomValueListenableBuilder<int>(
        tomId: id,
        scope: s,
        valueListenable: ValueNotifier<int>(0),
        builder: (_, _, _) => const SizedBox(),
      ),
  'TomVerticalDivider': (id, s) => TomVerticalDivider(tomId: id, scope: s),
  'TomVisibility': (id, s) =>
      TomVisibility(tomId: id, scope: s, child: const SizedBox()),
  'TomWrap': (id, s) => TomWrap(tomId: id, scope: s),
  'TomYearPicker': (id, s) => TomYearPicker(
        tomId: id,
        scope: s,
        currentDate: DateTime(2026),
        firstDate: DateTime(2026),
        lastDate: DateTime(2026),
        selectedDate: DateTime(2026),
        onChanged: (_) {},
      ),};

// ---------------------------------------------------------------------------
// Fixtures
//
// Arguments that do not fit on a registry line, and the few delegate types
// that have no zero-argument concrete. Each is the emptiest thing that
// satisfies its type — the suite reads no rendered output, so "empty" and
// "realistic" are indistinguishable to it, and empty is cheaper to keep true.
// ---------------------------------------------------------------------------

const _navItems = <BottomNavigationBarItem>[
  BottomNavigationBarItem(icon: SizedBox(), label: 'a'),
  BottomNavigationBarItem(icon: SizedBox(), label: 'b'),
];

const _railDestinations = <NavigationRailDestination>[
  NavigationRailDestination(icon: SizedBox(), label: SizedBox()),
  NavigationRailDestination(icon: SizedBox(), label: SizedBox()),
];

const _steps = <Step>[Step(title: SizedBox(), content: SizedBox())];

const _dataColumns = <DataColumn>[DataColumn(label: SizedBox())];

const _menuEntries = <DropdownMenuEntry<int>>[
  DropdownMenuEntry<int>(value: 0, label: 'a'),
];

const _segments = <ButtonSegment<int>>[
  ButtonSegment<int>(value: 0, label: SizedBox()),
];

const _colorFilter =
    ColorFilter.mode(Color(0xFF000000), BlendMode.srcOver);

const _gridDelegate =
    SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1);

Shader _shader(Rect bounds) => const LinearGradient(
      colors: [Color(0xFF000000), Color(0xFF000000)],
    ).createShader(bounds);

Iterable<int> _options(TextEditingValue value) => const <int>[];

CupertinoTabBar _tabBar() => CupertinoTabBar(items: _navItems);

class _EmptyDataSource extends DataTableSource {
  @override
  DataRow? getRow(int index) => null;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => 0;
  @override
  int get selectedRowCount => 0;
}

class _EmptyHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      const SizedBox();
  @override
  double get maxExtent => 1;
  @override
  double get minExtent => 1;
  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _EmptyFlowDelegate extends FlowDelegate {
  @override
  void paintChildren(FlowPaintingContext context) {}
  @override
  bool shouldRepaint(FlowDelegate oldDelegate) => false;
}

class _EmptyMultiChildDelegate extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {}
  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => false;
}

class _EmptySingleChildDelegate extends SingleChildLayoutDelegate {
  @override
  bool shouldRelayout(SingleChildLayoutDelegate oldDelegate) => false;
}

class _EmptyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path();
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
