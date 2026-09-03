/// The showcase application shell.
///
/// [ShowcaseApp] is a plain [MaterialApp] whose home indexes every
/// [ShowcaseGroup]. Tapping a group opens its [GroupScreen], which renders one
/// `code | rendered` [ShowcaseCell] per forms feature. The app is intentionally
/// thin — all teaching content lives in the group files under `lib/groups/`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'common/showcase_section.dart';
import 'groups/authorization_group.dart';
import 'groups/field_types_group.dart';
import 'groups/layout_group.dart';
import 'groups/lists_group.dart';
import 'groups/master_detail_group.dart';
import 'groups/responsive_group.dart';
import 'groups/theming_group.dart';
import 'groups/validation_group.dart';

/// Every group displayed by the showcase, in presentation order — building
/// blocks first, then composition, then the advanced patterns.
final List<ShowcaseGroup> showcaseGroups = [
  fieldTypesGroup,
  validationGroup,
  layoutGroup,
  themingGroup,
  responsiveGroup,
  authorizationGroup,
  listsGroup,
  masterDetailGroup,
];

/// Root widget of the forms showcase.
// Why: extends [TomStatelessWidget] (not raw StatelessWidget) so the app shell
// conforms to G-UI-2. It owns no tomId/resources, so a family base would attach
// a spurious identity; construction reads [TomScope.current] (safe at runApp —
// falls back to the default scope) so the constructor cannot be const.
class ShowcaseApp extends TomStatelessWidget {
  /// Creates the showcase application.
  ShowcaseApp({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return MaterialApp(
      // OS-level app identity (task switcher / window title), not on-screen copy
      // — intentionally hardcoded, outside the G-RES-1 resource bundle.
      title: 'Tom Flutter UI — Forms Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: _ShowcaseHome(),
    );
  }
}

// Why: scope-participating chrome container with no tomId/resources →
// [TomStatelessWidget], non-const for the same reason.
class _ShowcaseHome extends TomStatelessWidget {
  _ShowcaseHome();

  @override
  Widget buildContent(BuildContext context) {
    return TomScaffold(
      appBar: TomAppBar(
        // On-screen app-bar copy → resource per G-RES-1 (see chrome_texts.dart).
        title: TomText(text: TomCtr.text('showcase.app.title')),
      ),
      body: TomListView.separated(
        itemCount: showcaseGroups.length,
        separatorBuilder: (_, _) => TomDivider(height: 1),
        itemBuilder: (context, index) {
          final group = showcaseGroups[index];
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
