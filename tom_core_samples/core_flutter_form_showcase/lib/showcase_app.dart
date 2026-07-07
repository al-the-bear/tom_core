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
class ShowcaseApp extends StatelessWidget {
  /// Creates the showcase application.
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Flutter UI — Forms Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const _ShowcaseHome(),
    );
  }
}

class _ShowcaseHome extends StatelessWidget {
  const _ShowcaseHome();

  @override
  Widget build(BuildContext context) {
    return TomScaffold(
      appBar: TomAppBar(
        title: TomText(text: 'Tom Flutter UI — Forms Showcase'),
      ),
      body: ListView.separated(
        itemCount: showcaseGroups.length,
        separatorBuilder: (_, _) => TomDivider(height: 1),
        itemBuilder: (context, index) {
          final group = showcaseGroups[index];
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
