/// The builder's source, for the tests that read it rather than run it.
///
/// `AclBuilder` is one library split into parts by method family, so a test
/// that inspects "the builder" has to read the library and every part. The
/// parts are taken from the library's own `part` directives rather than from a
/// glob: a part the library stops naming stops being read with it, which is
/// the same thing the compiler does.
library;

import 'dart:io';

/// The library file, package-relative.
const aclBuilderLibraryPath =
    'lib/src/advanced_container_layout/acl_builder.dart';

/// The library and its parts, in the order the library names them.
List<String> aclBuilderSourcePaths() {
  final library = File(aclBuilderLibraryPath).readAsStringSync();
  final directory = File(aclBuilderLibraryPath).parent.path;
  return [
    aclBuilderLibraryPath,
    for (final match in RegExp(
      r"^part '([^']+)';",
      multiLine: true,
    ).allMatches(library))
      '$directory/${match.group(1)}',
  ];
}

/// The library and its parts, concatenated.
String aclBuilderSource() =>
    aclBuilderSourcePaths().map((p) => File(p).readAsStringSync()).join('\n');

/// The library and its parts, as lines.
List<String> aclBuilderSourceLines() => [
  for (final path in aclBuilderSourcePaths()) ...File(path).readAsLinesSync(),
];
