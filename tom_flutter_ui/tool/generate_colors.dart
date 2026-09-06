// ignore_for_file: avoid_print
// Generates tom_colors_generated.dart from Flutter SDK color source files.
// Run with: dart run tool/generate_colors.dart
//
// Mirrors tool/generate_icons.dart, and for the same reason: this script runs
// under plain `dart`, which has no `dart:ui`, so it cannot import Flutter and
// reflect over `Colors` / `CupertinoColors`. It reads the SDK's own
// declarations instead.
//
// Like the icons generator it emits no timestamp. The output has to
// reproduce byte-for-byte on a second run, and a wall clock in the header
// makes every regeneration a diff even when no color moved.
import 'dart:io';

void main() {
  final flutterSdk = _findFlutterSdk();
  if (flutterSdk == null) {
    print('Error: Could not find Flutter SDK');
    exit(1);
  }

  print('Flutter SDK: $flutterSdk');

  final materialColorsFile = File(
    '$flutterSdk/packages/flutter/lib/src/material/colors.dart',
  );
  final cupertinoColorsFile = File(
    '$flutterSdk/packages/flutter/lib/src/cupertino/colors.dart',
  );

  if (!materialColorsFile.existsSync()) {
    print('Error: Material colors file not found');
    exit(1);
  }
  if (!cupertinoColorsFile.existsSync()) {
    print('Error: Cupertino colors file not found');
    exit(1);
  }

  final materialColors = _extractMaterialColors(
    materialColorsFile.readAsStringSync(),
  );
  final cupertinoColors = _extractCupertinoColors(
    cupertinoColorsFile.readAsStringSync(),
  );

  print('Found ${materialColors.length} Material colors');
  print('Found ${cupertinoColors.length} Cupertino colors');

  final output = _generateOutput(materialColors, cupertinoColors);

  final outputFile = File('lib/src/resource_auth/tom_colors_generated.dart');
  outputFile.writeAsStringSync(output);
  _format(flutterSdk, outputFile);

  print('Generated ${outputFile.path}');
  print('Total colors: ${materialColors.length + cupertinoColors.length}');
}

/// Formats the emitted file, because the checked-in table is formatted and the
/// point of the generator is that re-running it produces no diff.
///
/// The emitter writes one entry per line and lets the formatter decide where to
/// wrap; a few swatch lines exceed 80 columns, so without this the raw output
/// differs from the committed file. Doing it here rather than asking the caller
/// to remember `dart format` keeps the reproducibility a property of the
/// generator rather than of the procedure.
void _format(String flutterSdk, File file) {
  final result = Process.runSync('$flutterSdk/bin/dart', ['format', file.path]);
  if (result.exitCode != 0) {
    print('Error: dart format failed on ${file.path}');
    print(result.stderr);
    exit(1);
  }
}

String? _findFlutterSdk() {
  // Try 'which flutter' approach
  final result = Process.runSync('which', ['flutter']);
  if (result.exitCode == 0) {
    final flutterBin = (result.stdout as String).trim();
    // flutter binary is at <sdk>/bin/flutter
    final sdkDir = File(flutterBin).parent.parent;
    if (sdkDir.existsSync()) {
      return sdkDir.path;
    }
  }

  // Try FLUTTER_ROOT environment variable
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && Directory(flutterRoot).existsSync()) {
    return flutterRoot;
  }

  return null;
}

/// One `'key': expression,` line of a generated map.
///
/// [blankBefore] and [comment] carry the layout, so the emitter stays a plain
/// loop and the grouping is decided once, where the declarations are read.
class _ColorEntry {
  _ColorEntry(
    this.key,
    this.expression, {
    this.blankBefore = false,
    this.comment,
  });

  final String key;
  final String expression;
  final bool blankBefore;
  final String? comment;
}

/// Extracts the body of a class, so a declaration pattern cannot match a
/// same-shaped member of some other class in the same file.
String _classBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) {
    print('Error: Could not find "$declaration"');
    exit(1);
  }
  final lines = source.substring(start).split('\n');
  final body = <String>[];
  // Skip the declaration line itself, then take everything up to the closing
  // brace in column 0.
  for (final line in lines.skip(1)) {
    if (line == '}') break;
    body.add(line);
  }
  return body.join('\n');
}

/// The `static const int _xPrimaryValue = 0xFFF44336;` constants that the
/// swatch maps refer to instead of repeating a literal.
Map<String, String> _intConstants(String body) {
  final regex = RegExp(
    r'^  static const int (_\w+) = (0x[0-9A-Fa-f]+);',
    multiLine: true,
  );
  return {for (final m in regex.allMatches(body)) m.group(1)!: m.group(2)!};
}

/// Material colors, in the order the SDK declares them: the neutrals first,
/// then each swatch immediately followed by its accent swatch.
///
/// The base of a swatch is emitted as a `Colors.<name>` reference, but its
/// shades cannot be — `Colors.red[500]` is not a constant expression — so the
/// shades come out as the literal values the SDK swatch map holds.
List<_ColorEntry> _extractMaterialColors(String source) {
  final body = _classBody(source, 'abstract final class Colors {');
  final constants = _intConstants(body);
  final lines = body.split('\n');

  final neutral = RegExp(
    r'^  static const Color (\w+) = Color\((0x[0-9A-Fa-f]+)\);',
  );
  final swatch = RegExp(
    r'^  static const (MaterialColor|MaterialAccentColor) (\w+) =',
  );
  final shade = RegExp(r'^\s*(\d+): Color\(([^)]+)\),');
  final swatchEnd = RegExp(r'^\s*\}\);');

  final entries = <_ColorEntry>[];
  var seenNeutral = false;
  var seenSwatch = false;

  for (var i = 0; i < lines.length; i++) {
    final neutralMatch = neutral.firstMatch(lines[i]);
    if (neutralMatch != null) {
      final name = neutralMatch.group(1)!;
      entries.add(
        _ColorEntry(
          'm${_capitalize(name)}',
          'Colors.$name',
          comment: seenNeutral ? null : 'Neutral colors',
        ),
      );
      seenNeutral = true;
      continue;
    }

    final swatchMatch = swatch.firstMatch(lines[i]);
    if (swatchMatch == null) continue;

    final isAccent = swatchMatch.group(1) == 'MaterialAccentColor';
    final name = swatchMatch.group(2)!;
    entries.add(
      _ColorEntry(
        'm${_capitalize(name)}',
        'Colors.$name',
        // A swatch and its accent belong together; the blank line separates
        // one color family from the next.
        blankBefore: !isAccent && entries.isNotEmpty,
        comment: seenSwatch ? null : 'Color swatches, with their shades',
      ),
    );
    seenSwatch = true;

    // The declaration may wrap, so find the swatch map rather than assuming
    // it opened on the line just matched.
    while (i < lines.length && !lines[i].contains('<int, Color>{')) {
      i++;
    }
    for (i++; i < lines.length; i++) {
      if (swatchEnd.hasMatch(lines[i])) break;
      final shadeMatch = shade.firstMatch(lines[i]);
      if (shadeMatch == null) continue;
      final value = _resolveValue(shadeMatch.group(2)!, constants);
      entries.add(
        _ColorEntry(
          'm${_capitalize(name)}${shadeMatch.group(1)}',
          'Color($value)',
        ),
      );
    }
  }

  return entries;
}

/// Cupertino colors, in SDK declaration order.
///
/// Every one of them is a compile-time constant on `CupertinoColors`, so they
/// are all emitted as references — including the dynamic ones, which have to
/// be, since their light/dark resolution happens at lookup time.
List<_ColorEntry> _extractCupertinoColors(String source) {
  final body = _classBody(source, 'abstract final class CupertinoColors {');
  final regex = RegExp(
    r'^  static const (?:CupertinoDynamicColor|Color) (\w+) =',
    multiLine: true,
  );
  return [
    for (final m in regex.allMatches(body))
      _ColorEntry(
        'c${_capitalize(m.group(1)!)}',
        'CupertinoColors.${m.group(1)!}',
      ),
  ];
}

/// Resolves a swatch entry's value, which is either a literal or one of the
/// private `_xPrimaryValue` constants declared beside the swatch.
String _resolveValue(String value, Map<String, String> constants) {
  final trimmed = value.trim();
  if (trimmed.startsWith('0x')) return trimmed;
  final resolved = constants[trimmed];
  if (resolved == null) {
    print('Error: Unresolved color value "$trimmed"');
    exit(1);
  }
  return resolved;
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  // Color names are camelCase (deepPurple, secondarySystemFill), not the
  // snake_case the icon names use, so only the first letter changes.
  return s[0].toUpperCase() + s.substring(1);
}

void _writeMap(StringBuffer buffer, List<_ColorEntry> entries) {
  for (final entry in entries) {
    if (entry.blankBefore) buffer.writeln();
    if (entry.comment != null) buffer.writeln('    // ${entry.comment}');
    buffer.writeln("    '${entry.key}': ${entry.expression},");
  }
}

String _generateOutput(
  List<_ColorEntry> materialColors,
  List<_ColorEntry> cupertinoColors,
) {
  final buffer = StringBuffer();

  buffer.writeln('// GENERATED FILE - DO NOT EDIT');
  buffer.writeln('// Generated by: dart run tool/generate_colors.dart');
  buffer.writeln('//');
  buffer.writeln('// Extracted from the Flutter SDK declarations in');
  buffer.writeln(
    '// packages/flutter/lib/src/{material,cupertino}/colors.dart, in the order',
  );
  buffer.writeln('// the SDK declares them.');
  buffer.writeln('//');
  buffer.writeln(
    '// No timestamp is emitted on purpose: this file has to reproduce',
  );
  buffer.writeln(
    '// byte-for-byte from a clean checkout, so the header records only what the',
  );
  buffer.writeln(
    '// contents actually depend on. A regeneration that changes nothing produces',
  );
  buffer.writeln(
    '// no diff, and a count that moved means the SDK palette moved.',
  );
  buffer.writeln('//');
  buffer.writeln('// Material colors: ${materialColors.length}');
  buffer.writeln('// Cupertino colors: ${cupertinoColors.length}');
  buffer.writeln('// Total: ${materialColors.length + cupertinoColors.length}');
  buffer.writeln();
  buffer.writeln("import 'package:flutter/cupertino.dart';");
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln();
  buffer.writeln('/// Generated color mappings for all Flutter colors.');
  buffer.writeln('///');
  buffer.writeln(
    '/// Material colors are prefixed with `m` (e.g., `mRed`, `mBlue500`).',
  );
  buffer.writeln(
    '/// Cupertino colors are prefixed with `c` (e.g., `cSystemRed`, `cActiveBlue`).',
  );
  buffer.writeln('///');
  buffer.writeln(
    '/// The SDK name is capitalized after the prefix, so a swatch, its shades and',
  );
  buffer.writeln(
    '/// its accent all read the same way: `red` -> `mRed`, shade 500 -> `mRed500`,',
  );
  buffer.writeln(
    '/// `redAccent` -> `mRedAccent`, its shade 100 -> `mRedAccent100`.',
  );
  buffer.writeln('class GeneratedColors {');
  buffer.writeln('  GeneratedColors._();');
  buffer.writeln();
  buffer.writeln(
    '  /// All Material colors, keyed by `m<ColorName>` or `m<ColorName><Shade>`.',
  );
  buffer.writeln('  static const Map<String, Color> materialColors = {');
  _writeMap(buffer, materialColors);
  buffer.writeln('  };');
  buffer.writeln();
  buffer.writeln('  /// All Cupertino colors, keyed by `c<ColorName>`.');
  buffer.writeln('  static const Map<String, Color> cupertinoColors = {');
  _writeMap(buffer, cupertinoColors);
  buffer.writeln('  };');
  buffer.writeln();
  buffer.writeln('  /// Resolves a color by [name].');
  buffer.writeln('  ///');
  buffer.writeln('  /// Checks Material colors first, then Cupertino colors.');
  buffer.writeln(
    '  /// Returns `null` if no color is registered for that name.',
  );
  buffer.writeln('  static Color? resolve(String name) {');
  buffer.writeln('    return materialColors[name] ?? cupertinoColors[name];');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Whether a color with [name] exists.');
  buffer.writeln('  static bool exists(String name) {');
  buffer.writeln(
    '    return materialColors.containsKey(name) || cupertinoColors.containsKey(name);',
  );
  buffer.writeln('  }');
  buffer.writeln('}');

  return buffer.toString();
}
