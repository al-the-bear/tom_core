import 'package:flutter/material.dart';

/// A single bullet line for the demos' intro cards.
///
/// One shared definition for all twelve demo files. A bullet line is
/// identical in every one of them, so a file-private copy apiece would be
/// twelve places for the styling to drift.
class DemoBullet extends StatelessWidget {
  const DemoBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text('• $text'),
    );
  }
}
