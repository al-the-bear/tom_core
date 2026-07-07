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
class AclApp extends StatelessWidget {
  /// Creates the ACL feature-tour application.
  const AclApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Core — ACL Feature Tour',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const _AclHome(),
    );
  }
}

class _AclHome extends StatelessWidget {
  const _AclHome();

  @override
  Widget build(BuildContext context) {
    return TomScaffold(
      appBar: TomAppBar(
        title: TomText(text: 'Tom Core — ACL Feature Tour'),
      ),
      body: ListView.separated(
        itemCount: aclGroups.length,
        separatorBuilder: (_, _) => TomDivider(height: 1),
        itemBuilder: (context, index) {
          final group = aclGroups[index];
          return TomListTile(
            leading: Icon(group.icon),
            titleText: group.title,
            subtitle: TomText(text: group.summary),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupScreen(group: group),
              ),
            ),
          );
        },
      ),
    );
  }
}
