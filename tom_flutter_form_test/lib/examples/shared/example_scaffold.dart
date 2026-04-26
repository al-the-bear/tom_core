import 'package:flutter/material.dart';

/// Minimal AppBar + body wrapper used by the Examples section.
///
/// Examples deliberately avoid event logs, state debug panels, control rows,
/// or inspector toggles. The intent is that each example file reads like a
/// stripped-down sample that a developer could lift verbatim into their own
/// app — what you see here is the same scaffolding any host app would
/// already provide.
class ExampleScaffold extends StatelessWidget {
  const ExampleScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: child,
    );
  }
}
