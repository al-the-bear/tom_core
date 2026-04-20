/// Diagnostic: measure the actual rendered heights of the
/// reference_constraints vertical-alignment ACL blocks so we can see
/// whether the "empty space at bottom / pushed-out at top" is inside
/// the ACL or between it and the surrounding container.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_flutter_ui_test/acl_demos/acl_demos.dart';

void main() {
  testWidgets('alignTopToBottom — measure ACL, anchor, follower rects',
      (tester) async {
    const anchorKey = ValueKey('d-anchor');
    const followerKey = ValueKey('d-follower');
    const aclKey = ValueKey('d-acl');

    final anchor = const KeyedSubtree(
      key: anchorKey,
      child: SizedBox(
        width: 220,
        child: DemoBox('Anchor (top->bottom)', Colors.deepOrange),
      ),
    );
    final follower = const KeyedSubtree(
      key: followerKey,
      child: SizedBox(
        width: 220,
        child: DemoBox('Follower top->anchor bottom', Colors.green),
      ),
    );

    final acl = KeyedSubtree(
      key: aclKey,
      child: AclBuilder()
          .append(anchor)
          .setPSize(220, 64)
          .append(const SizedBox(width: 24))
          .append(follower)
          .setPSize(220, 36)
          .alignTopToBottom(anchor)
          .build(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 800, child: acl),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final aclRect = tester.getRect(find.byKey(aclKey));
    final anchorRect = tester.getRect(find.byKey(anchorKey));
    final followerRect = tester.getRect(find.byKey(followerKey));

    // ignore: avoid_print
    print('ACL      rect: $aclRect');
    // ignore: avoid_print
    print('anchor   rect: $anchorRect');
    // ignore: avoid_print
    print('follower rect: $followerRect');
    // ignore: avoid_print
    print('anchor.bottom=${anchorRect.bottom}, '
        'follower.top=${followerRect.top}, '
        'gap=${followerRect.top - anchorRect.bottom}');
    // ignore: avoid_print
    print('aclRect.bottom - follower.bottom = '
        '${aclRect.bottom - followerRect.bottom}');
  });

  testWidgets('alignBottomToTop — measure ACL, anchor, follower rects',
      (tester) async {
    const anchorKey = ValueKey('d-anchor-b');
    const followerKey = ValueKey('d-follower-b');
    const aclKey = ValueKey('d-acl-b');

    final anchor = const KeyedSubtree(
      key: anchorKey,
      child: SizedBox(
        width: 220,
        child: DemoBox('Anchor (bottom->top)', Colors.blueGrey),
      ),
    );
    final follower = const KeyedSubtree(
      key: followerKey,
      child: SizedBox(
        width: 220,
        child: DemoBox('Follower bottom->anchor top', Colors.purple),
      ),
    );

    final acl = KeyedSubtree(
      key: aclKey,
      child: AclBuilder()
          .append(anchor)
          .setPSize(220, 64)
          .append(const SizedBox(width: 24))
          .append(follower)
          .setPSize(220, 36)
          .alignBottomToTop(anchor)
          .build(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 800, child: acl),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final aclRect = tester.getRect(find.byKey(aclKey));
    final anchorRect = tester.getRect(find.byKey(anchorKey));
    final followerRect = tester.getRect(find.byKey(followerKey));

    // ignore: avoid_print
    print('ACL      rect: $aclRect');
    // ignore: avoid_print
    print('anchor   rect: $anchorRect');
    // ignore: avoid_print
    print('follower rect: $followerRect');
    // ignore: avoid_print
    print('follower.bottom=${followerRect.bottom}, '
        'anchor.top=${anchorRect.top}, '
        'gap=${anchorRect.top - followerRect.bottom}');
    // ignore: avoid_print
    print('follower.top - aclRect.top = '
        '${followerRect.top - aclRect.top}');
  });
}
