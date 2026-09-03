/// The responsive showcase application shell.
///
/// [ResponsiveApp] is a plain [MaterialApp] whose home indexes every responsive
/// [ShowcaseGroup]. Tapping a group opens its [GroupScreen], which renders one
/// width-reactive [ShowcaseCell] per mechanism. The app is intentionally thin —
/// all teaching content lives in the group files under `lib/groups/`. Shaped
/// after the verified `core_flutter_form_showcase` shell.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'common/showcase_section.dart';
import 'groups/adaptive_sizing_group.dart';
import 'groups/breakpoint_field_style_group.dart';
import 'groups/family_swap_group.dart';
import 'groups/form_factor_group.dart';
import 'groups/responsive_acl_form_group.dart';
import 'groups/row_breakpoint_group.dart';

/// Every responsive group displayed by the showcase, in teaching order —
/// single-axis mechanisms first (style, then layout), then the combined
/// capstone that exercises both at once.
final List<ShowcaseGroup> responsiveGroups = [
  breakpointFieldStyleGroup,
  familySwapGroup,
  rowBreakpointGroup,
  formFactorGroup,
  adaptiveSizingGroup,
  responsiveAclFormGroup,
];

/// Root widget of the responsive showcase.
// Why: extends [TomStatelessWidget] (not raw StatelessWidget) so the app shell
// conforms to G-UI-2. It owns no tomId/resources, so a family base would attach
// a spurious identity; construction reads [TomScope.current] (safe at runApp —
// falls back to the default scope) so the constructor cannot be const.
class ResponsiveApp extends TomStatelessWidget {
  /// Creates the responsive showcase application.
  ResponsiveApp({super.key});

  @override
  Widget buildContent(BuildContext context) {
    // Why: raw MaterialApp — the app root has no Tom counterpart. One of the two
    // raw-Flutter exceptions named in `README.md` §5.
    return MaterialApp(
      // OS-level app identity (task switcher / window title), not on-screen copy
      // — intentionally hardcoded, outside the G-RES-1 resource bundle.
      title: 'Tom Flutter UI — Responsive Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: _ResponsiveHome(),
    );
  }
}

// Why: scope-participating chrome container with no tomId/resources →
// [TomStatelessWidget], non-const for the same reason.
class _ResponsiveHome extends TomStatelessWidget {
  _ResponsiveHome();

  @override
  Widget buildContent(BuildContext context) {
    return TomScaffold(
      appBar: TomAppBar(
        // On-screen app-bar copy → resource per G-RES-1 (see chrome_texts.dart).
        title: TomText(text: TomCtr.text('showcase.app.title')),
      ),
      body: TomListView.separated(
        itemCount: responsiveGroups.length,
        separatorBuilder: (_, _) => TomDivider(height: 1),
        itemBuilder: (context, index) {
          final group = responsiveGroups[index];
          return TomListTile(
            leading: TomIcon(icon: group.icon),
            titleText: group.title,
            subtitle: TomText(text: group.summary),
            isThreeLine: true,
            trailing: TomIcon(icon: Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              TomPageRoute<void>(builder: (_) => GroupScreen(group: group)),
            ),
          );
        },
      ),
    );
  }
}
