/// The guard that keeps `TomClientJwtToken` nameable through *this* barrel.
///
/// `tom_core_kernel` has its own copy of this check, and the two are not
/// redundant: they guard different re-exports. The kernel's guards the blanket
/// `export 'package:tom_crypto/tom_crypto.dart';` that puts the type into the
/// kernel's surface; this one guards the blanket
/// `export 'package:tom_core_kernel/tom_core_kernel.dart';` that carries it on
/// into the Flutter binding. Narrowing either one drops the type, and a Flutter
/// application only ever imports this barrel.
///
/// That application is real. `tom_uam_client` declares
/// `static TomClientJwtToken? clientToken;` with `tom_core_flutter` as its only
/// Tom import, so the type crossing both barrels is precisely what lets that
/// file compile.
///
/// Using the API is not the same as naming its types, which is why the
/// existing coverage did not close this. `preferences_test.dart` already calls
/// `TomBearerAuthentication.setTokens` through this barrel and would keep
/// passing with `TomClientJwtToken` unreachable — a call site never has to
/// write the type of what it ignores. This file writes it, so losing the
/// re-export stops the file compiling rather than failing an assertion.
///
/// The first test keeps that property true: the guard's whole strength is its
/// import list, and adding one `tom_core_kernel` or `tom_crypto` import would
/// leave it passing while proving nothing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// This file's own path, read back to check how it imports.
const _ownPath = 'test/bearer_auth_barrel_export_test.dart';

/// The only import this file may have into the Tom packages.
const _barrelImport =
    "import 'package:tom_core_flutter/tom_core_flutter.dart';";

void main() {
  group('bearer-auth token types cross into the Flutter binding', () {
    test('this file reaches Tom only through the tom_core_flutter barrel', () {
      final source = File(_ownPath);
      expect(
        source.existsSync(),
        isTrue,
        reason:
            'the guard reads its own source; if this file moved, $_ownPath '
            'must move with it',
      );

      final reachingImports = [
        for (final line in source.readAsLinesSync())
          if (RegExp(r"^\s*(import|export)\s+'").hasMatch(line) &&
              (line.contains('tom_core_flutter') ||
                  line.contains('tom_core_kernel') ||
                  line.contains('tom_crypto')))
            line.trim(),
      ];

      // Non-vacuity: an empty list would satisfy the check below while
      // testing nothing.
      expect(reachingImports, isNotEmpty);
      expect(
        reachingImports,
        equals([_barrelImport]),
        reason:
            'the compile-time guard below only proves this barrel carries '
            'TomClientJwtToken while it is the only way this file can see it',
      );
    });

    test('a consumer can declare the type the getters return', () {
      // Writing the type is the assertion; both are null because nothing has
      // logged in, and the declaration has to compile whatever the value is.
      // This is the line `tom_uam_client` needs.
      final TomClientJwtToken? authentication =
          TomBearerAuthentication.clientJwtToken;
      final TomClientJwtToken? authorization =
          TomBearerAuthentication.clientAuthorizationJwtToken;

      expect(authentication, isNull);
      expect(authorization, isNull);
    });
  });
}
