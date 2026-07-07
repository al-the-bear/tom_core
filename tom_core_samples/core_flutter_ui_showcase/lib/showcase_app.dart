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
class ShowcaseApp extends StatelessWidget {
  /// Creates the showcase application.
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Flutter UI — Component Showcase',
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
        title: TomText(text: 'Tom Flutter UI — Component Showcase'),
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
