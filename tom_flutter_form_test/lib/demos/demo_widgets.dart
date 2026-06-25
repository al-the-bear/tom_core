import 'package:flutter/material.dart';

/// A single bullet line for the demos' intro cards.
///
/// This was previously copy-pasted as a byte-identical private `_Bullet`
/// class in twelve demo files; it is hoisted here as the single shared
/// definition (code_quality §69).
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
