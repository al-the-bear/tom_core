/// Demo-local pure-logic coverage for the widget_demos showcase — review
/// tests finding §69.
///
/// Two genuinely-pure demo-local helpers had no behavioural assertions. The
/// widget demos are otherwise mount-only — `demo_overflow_test.dart`,
/// `demo_coverage_test.dart` and `screenshots.dart` build them and assert
/// nothing about their behaviour; the one exception is `widget_04_toggles`,
/// which `demo_04_radio_group_test.dart` drives. That is expected for a
/// showcase and is *not* the finding:
///
///  - [DemoAuthorizationAdapter.resolveAuth] — an exact-match-then-parent-walk
///    auth resolver (`demo_28_authorization.dart`): split the path on `.`,
///    return the first rule found walking from the full path up through each
///    parent, else [TomAuthState.full]. Its inheritance semantics (nearest
///    ancestor wins, exact match beats ancestor) are pure input→output.
///  - [createPlaceholderBytes] — a pure generator returning a fixed 1×1
///    transparent PNG byte array (`demo_12_images.dart`). Exposed
///    `@visibleForTesting` purely so this pure value can be pinned; it is not
///    part of the demo's real API.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_12_images.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_28_authorization.dart';

void main() {
  group('DemoAuthorizationAdapter.resolveAuth (§69)', () {
    late DemoAuthorizationAdapter adapter;

    setUp(() => adapter = DemoAuthorizationAdapter());

    test('defaults to full when no rule matches', () {
      expect(adapter.resolveAuth('demo28.admin.delete'), TomAuthState.full);
    });

    test('exact match returns its rule', () {
      adapter.setRule('demo28.admin.delete', TomAuthState.read);
      expect(adapter.resolveAuth('demo28.admin.delete'), TomAuthState.read);
    });

    test('a child inherits the nearest ancestor rule', () {
      // Rule on the parent path; the child has no exact rule of its own.
      adapter.setRule('demo28.admin', TomAuthState.disabled);
      expect(adapter.resolveAuth('demo28.admin.delete'), TomAuthState.disabled,
          reason: 'demo28.admin.delete inherits the demo28.admin rule');
    });

    test('exact match wins over an ancestor rule', () {
      adapter.setRule('demo28.admin', TomAuthState.disabled);
      adapter.setRule('demo28.admin.delete', TomAuthState.read);
      expect(adapter.resolveAuth('demo28.admin.delete'), TomAuthState.read,
          reason: 'the exact rule must beat the inherited ancestor rule');
    });

    test('the nearest ancestor wins when several ancestors have rules', () {
      adapter.setRule('demo28', TomAuthState.none);
      adapter.setRule('demo28.admin', TomAuthState.read);
      // Walking up from demo28.admin.delete hits demo28.admin before demo28.
      expect(adapter.resolveAuth('demo28.admin.delete'), TomAuthState.read,
          reason: 'the closest ancestor (demo28.admin) wins over demo28');
    });

    test('a single top-level segment falls through to full', () {
      // The parent-walk loop runs only while i > 0, so a one-segment path has
      // no ancestors to inherit from.
      adapter.setRule('demo28', TomAuthState.read);
      expect(adapter.resolveAuth('other'), TomAuthState.full);
      // The exact rule on the single segment still applies, though.
      expect(adapter.resolveAuth('demo28'), TomAuthState.read);
    });

    test('removeRule and clearRules drop matches back to full', () {
      adapter.setRule('demo28.admin', TomAuthState.read);
      adapter.removeRule('demo28.admin');
      expect(adapter.resolveAuth('demo28.admin.delete'), TomAuthState.full);

      adapter.setRule('demo28.admin', TomAuthState.read);
      adapter.setRule('demo28.view', TomAuthState.disabled);
      adapter.clearRules();
      expect(adapter.resolveAuth('demo28.admin.delete'), TomAuthState.full);
      expect(adapter.resolveAuth('demo28.view'), TomAuthState.full);
    });
  });

  group('createPlaceholderBytes (§69)', () {
    test('returns a well-formed 1x1 transparent PNG', () {
      final bytes = createPlaceholderBytes();
      expect(bytes, isA<Uint8List>());

      // PNG 8-byte signature.
      expect(bytes.sublist(0, 8),
          orderedEquals(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
          reason: 'must start with the canonical PNG signature');

      // IHDR declares a 1x1 image: width/height are the four bytes each
      // following the "IHDR" chunk-type tag.
      final ihdr = _chunkTypeIndex(bytes, 'IHDR');
      expect(ihdr, isNonNegative, reason: 'an IHDR chunk must be present');
      final width = _readUint32(bytes, ihdr + 4);
      final height = _readUint32(bytes, ihdr + 8);
      expect(width, 1);
      expect(height, 1);

      // Ends with the mandatory IEND terminator chunk: the "IEND" type tag
      // sits in the 4 bytes before the trailing 4-byte chunk CRC.
      expect(bytes.sublist(bytes.length - 8, bytes.length - 4),
          orderedEquals(const [0x49, 0x45, 0x4E, 0x44]),
          reason: 'a PNG must terminate with the IEND chunk');
    });

    test('is a pure generator — repeated calls are byte-identical', () {
      expect(createPlaceholderBytes(), orderedEquals(createPlaceholderBytes()));
    });
  });
}

/// Index of the four-byte ASCII chunk-type tag [type] within [bytes], or -1.
int _chunkTypeIndex(Uint8List bytes, String type) {
  final tag = type.codeUnits;
  for (var i = 0; i + tag.length <= bytes.length; i++) {
    var match = true;
    for (var j = 0; j < tag.length; j++) {
      if (bytes[i + j] != tag[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}

/// Reads a big-endian 32-bit unsigned int at [offset].
int _readUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
