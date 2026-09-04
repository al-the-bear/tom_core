import 'dart:io';

/// The census of `lib/src/widgets/`, read from the sources rather than listed.
///
/// Two suites need the same three answers — which Tom types the widget kit
/// declares, which of them are widgets, and which family base each one extends
/// — and they need them to agree. `widget_family_claims_test.dart` checks what
/// the *documents* may claim about those numbers;
/// `widget_conformance_test.dart` checks that every widget honours the base
/// contract. A second hand-kept copy of the scan would let the two drift, and
/// the drift would show up as one suite passing while the other failed on the
/// same wrapper.
///
/// Everything here is derived except the two exception sets below, which
/// cannot be: "is not a widget" and "reaches the surface through a mixin" are
/// facts about Flutter's type hierarchy, not about text this package owns. So
/// they are written out — and then asserted against the scan by
/// `widget_family_claims_test.dart`, which fails if a name is added to the kit
/// and not to them.

/// A public top-level `class` declaration and its `extends`/`with` clause.
///
/// The leading alternation is Dart's modifier soup (`abstract final class`);
/// the second group is everything up to the opening brace, which is where the
/// superclass and the mixins are.
final declarationPattern = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'class\s+(Tom\w+)(?:<[^>]*>)?\s*([^{]*)\{',
  multiLine: true,
);

final _extendsClause = RegExp(r'extends\s+(\w+)');

/// The text of every Dart file under `lib/src/widgets/`.
Iterable<String> widgetKitSources() => Directory('lib/src/widgets')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .map((f) => f.readAsStringSync());

/// Every Tom class declared under `lib/src/widgets/`, name → clause.
Map<String, String> widgetKitClasses() {
  final out = <String, String>{};
  for (final source in widgetKitSources()) {
    for (final m in declarationPattern.allMatches(source)) {
      out[m.group(1)!] = m.group(2)!.split(RegExp(r'\s+')).join(' ');
    }
  }
  return out;
}

/// The superclass named in [clause], or `null` when there is no `extends`.
String? parentIn(String? clause) =>
    _extendsClause.firstMatch(clause ?? '')?.group(1);

/// The twenty branch bases, read from `widget_base/` rather than listed here.
///
/// Deriving the set is what keeps this file from becoming a second hand-kept
/// copy of the catalogue it is guarding — adding a family base makes it a
/// family base here too, with no edit.
Set<String> familyBases() {
  final source = File(
    'lib/src/widget_base/tom_family_base.dart',
  ).readAsStringSync();
  return RegExp(
    r'class\s+(Tom\w+Base)\s+extends\s+TomFamilyBase',
  ).allMatches(source).map((m) => m.group(1)!).toSet();
}

/// The types under `widgets/` that are not widgets: a route, a static facade,
/// and seven plain classes that hold widgets without being one.
///
/// They are the only members of the kit that cannot carry the widget surface,
/// which is why the conformance registry has no entry for them: `TomDataCell`
/// holds a `Widget` but is not one, so there is nothing for `TomWidgetMixin`
/// (declared `on Widget`) to mix into. Four of the nine still need gating, and
/// get it from `TomAuthGate` around the slot they own — see
/// `wrapper_auth_gate_test.dart`.
const nonWidgetTypes = {
  'TomAclBuilder',
  'TomDataCell',
  'TomDataColumn',
  'TomDataRow',
  'TomDialogs',
  'TomExpansionPanel',
  'TomMessenger',
  'TomPageRoute',
  'TomTreeNode',
};

/// The widgets that extend a Flutter widget directly and mix in
/// `TomWidgetMixin`, because their Flutter original must be a specific subtype
/// to satisfy the parent that accepts it.
///
/// This is the kit's second route to the widget surface, and the reason
/// `TomWidgetSurface` exists as an interface rather than as a base class: a
/// `TomExpanded` has to *be* an `Expanded` for `Flex` to accept it, so it
/// cannot also extend `TomNodeBase`. These seventeen therefore report no
/// family — `family` lives on `TomFamilyBase` — which is a documented gap and
/// not a defect.
const mixinSurfaceWidgets = {
  'TomAnimatedPositioned',
  'TomAnimatedPositionedDirectional',
  'TomCheckedPopupMenuItem',
  'TomCupertinoTabView',
  'TomDropdownMenuItem',
  'TomExpanded',
  'TomFlexible',
  'TomNavigationDestination',
  'TomNavigationDrawerDestination',
  'TomPopupMenuDivider',
  'TomPopupMenuItem',
  'TomRefreshProgressIndicator',
  'TomSnackBar',
  'TomSnackBarAction',
  'TomSpacer',
  'TomTab',
  'TomTableCell',
};
