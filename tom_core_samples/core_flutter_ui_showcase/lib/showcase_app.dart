/// The showcase application shell.
///
/// [ShowcaseApp] is a plain [MaterialApp] whose home is an index of every
/// [ShowcaseGroup]. Tapping a group opens its [GroupScreen], which renders one
/// `code | rendered` [ShowcaseCell] per component. The app is intentionally
/// thin — all teaching content lives in the group files under `lib/groups/`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'common/showcase_section.dart';
import 'groups/acl_group.dart';
import 'groups/authorization_group.dart';
import 'groups/buttons_group.dart';
import 'groups/cards_group.dart';
import 'groups/labels_group.dart';
import 'groups/layout_group.dart';
import 'groups/progress_group.dart';
import 'groups/toggles_sliders_group.dart';

/// Every group displayed by the showcase, in presentation order.
final List<ShowcaseGroup> showcaseGroups = [
  buttonsGroup,
  labelsGroup,
  cardsGroup,
  togglesSlidersGroup,
  progressGroup,
  layoutGroup,
  aclGroup,
  authorizationGroup,
];

/// Root widget of the component showcase.
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
      title: 'Tom Flutter UI — Component Showcase',
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
