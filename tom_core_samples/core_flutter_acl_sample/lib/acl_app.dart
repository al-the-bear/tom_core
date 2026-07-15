/// The ACL feature-tour application shell.
///
/// [AclApp] is a plain [MaterialApp] whose home is an index of every ACL
/// capability group. Tapping a group opens its [GroupScreen], which renders one
/// `code | rendered` [ShowcaseCell] per ACL feature. The app is intentionally
/// thin — all teaching content lives in the group files under `lib/groups/`,
/// each mapped 1:1 to a verified `tom_flutter_ui_test/lib/acl_demos/` source.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'common/showcase_section.dart';
import 'groups/alignment_group.dart';
import 'groups/authorization_group.dart';
import 'groups/borders_titles_group.dart';
import 'groups/growth_group.dart';
import 'groups/nesting_group.dart';
import 'groups/reference_group.dart';
import 'groups/rows_spacing_group.dart';
import 'groups/sizing_group.dart';
import 'groups/variants_breakpoints_group.dart';
import 'groups/visibility_group.dart';

/// Every ACL capability group displayed by the tour, in presentation order.
///
/// The order follows the README's narrative: the static layout primitives
/// first (sizing → growth → alignment → rows → nesting → borders), then the
/// relational/adaptive features (reference constraints → variants → group
/// visibility), and the four-state authorization model last.
final List<ShowcaseGroup> aclGroups = [
  sizingGroup,
  growthGroup,
  alignmentGroup,
  rowsSpacingGroup,
  nestingGroup,
  bordersTitlesGroup,
  referenceGroup,
  variantsBreakpointsGroup,
  visibilityGroup,
  authorizationGroup,
];

/// Root widget of the ACL feature tour.
// Why: extends [TomStatelessWidget] (not raw StatelessWidget) so the app shell
// conforms to G-UI-2 — the sample's own root is a Tom base too. It owns no
// tomId/resources, so a family base would attach a spurious identity;
// [TomStatelessWidget] is the sanctioned base for a scope-participating shell.
// Construction reads [TomScope.current] (safe at runApp — it falls back to the
// default scope), so the constructor cannot be const.
class AclApp extends TomStatelessWidget {
  /// Creates the ACL feature-tour application.
  AclApp({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return MaterialApp(
      // OS-level app identity (task switcher / window title), not on-screen copy
      // — intentionally hardcoded, outside the G-RES-1 resource bundle.
      title: 'Tom Core — ACL Feature Tour',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: _AclHome(),
    );
  }
}

// Why: the home screen is a scope-participating chrome container with no
// tomId/resources → [TomStatelessWidget], non-const for the same reason.
class _AclHome extends TomStatelessWidget {
  _AclHome();

  @override
  Widget buildContent(BuildContext context) {
    return TomScaffold(
      appBar: TomAppBar(
        // On-screen app-bar copy → resource per G-RES-1 (see chrome_texts.dart).
        title: TomText(text: TomCtr.text('showcase.app.title')),
      ),
      body: TomListView.separated(
        itemCount: aclGroups.length,
        separatorBuilder: (_, _) => TomDivider(height: 1),
        itemBuilder: (context, index) {
          final group = aclGroups[index];
          return TomListTile(
            leading: TomIcon(icon: group.icon),
            titleText: group.title,
            subtitle: TomText(text: group.summary),
            isThreeLine: true,
            trailing: TomIcon(icon: Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              TomPageRoute<void>(
                builder: (_) => GroupScreen(group: group),
              ),
            ),
          );
        },
      ),
    );
  }
}
