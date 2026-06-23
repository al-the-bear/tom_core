/// The responsive showcase application shell.
///
/// [ResponsiveApp] is a plain [MaterialApp] whose home indexes every responsive
/// [ShowcaseGroup]. Tapping a group opens its [GroupScreen], which renders one
/// width-reactive [ShowcaseCell] per mechanism. The app is intentionally thin —
/// all teaching content lives in the group files under `lib/groups/`. Shaped
/// after the verified `core_flutter_form_showcase` shell.
library;

import 'package:flutter/material.dart';

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
class ResponsiveApp extends StatelessWidget {
  /// Creates the responsive showcase application.
  const ResponsiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Flutter UI — Responsive Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const _ResponsiveHome(),
    );
  }
}

class _ResponsiveHome extends StatelessWidget {
  const _ResponsiveHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tom Flutter UI — Responsive Showcase'),
      ),
      body: ListView.separated(
        itemCount: responsiveGroups.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final group = responsiveGroups[index];
          return ListTile(
            leading: Icon(group.icon),
            title: Text(group.title),
            subtitle: Text(group.summary),
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
