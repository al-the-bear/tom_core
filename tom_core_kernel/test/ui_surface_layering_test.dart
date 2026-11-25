import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// What a user interface takes from the kernel stays apart from the kernel's
/// HTTP client, its token handling and the local file system.
///
/// A form field or a settings screen uses a handful of kernel types:
/// observables, text resources, scopes, the authorization model and the
/// file-transfer contract. Their libraries must not import, however
/// indirectly, `package:tom_crypto`, `package:http` or `dart:io`. An import
/// graph grows one line at a time, and a single convenience import in a low
/// module (an exception base importing the server connection for one type)
/// puts the whole HTTP and token stack under every library above it. Nothing
/// fails when that happens: the code compiles and every suite passes, so this
/// test is where the edge is seen.
///
/// The roots are found by declaration, not by path, so moving a type keeps
/// the rule on it.
void main() {
  final lib = Directory('lib');
  final sources = <String, String>{
    for (final file in lib.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        p.normalize(file.path): file.readAsStringSync(),
  };

  /// The file declaring the class, mixin or enum [name].
  String declaring(String name) {
    final pattern = RegExp(
      r'^(?:abstract |final |base |sealed |interface |mixin )*'
      '(?:class|mixin|enum) $name\\b',
      multiLine: true,
    );
    final found = [
      for (final entry in sources.entries)
        if (pattern.hasMatch(entry.value)) entry.key,
    ];
    expect(found, hasLength(1), reason: '$name is declared in one file');
    return found.single;
  }

  final directive = RegExp(
    r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Every URI reachable from [root] through imports, exports and parts,
  /// each with the chain of files that leads to it.
  Map<String, List<String>> reachable(String root) {
    final chains = <String, List<String>>{
      root: [root],
    };
    final queue = [root];
    while (queue.isNotEmpty) {
      final file = queue.removeLast();
      final source = sources[file];
      if (source == null) continue;
      for (final match in directive.allMatches(source)) {
        final uri = match.group(1)!;
        final String target;
        if (uri.startsWith('package:tom_core_kernel/')) {
          target = p.normalize(
            p.join('lib', uri.substring('package:tom_core_kernel/'.length)),
          );
        } else if (uri.startsWith('package:') || uri.startsWith('dart:')) {
          target = uri;
        } else {
          target = p.normalize(p.join(p.dirname(file), uri));
        }
        if (chains.containsKey(target)) continue;
        chains[target] = [...chains[file]!, target];
        if (sources.containsKey(target)) queue.add(target);
      }
    }
    return chains;
  }

  const roots = [
    'TomObservable',
    'TomTextResourceProvider',
    'TomScope',
    'TomAuthorization',
    'TomFileTransferClient',
  ];
  const forbidden = ['package:tom_crypto/', 'package:http/', 'dart:io'];

  for (final root in roots) {
    test('UI-LAYER: the library of $root reaches no token handling, HTTP '
        'client or dart:io', () {
      final chains = reachable(declaring(root));
      final offences = [
        for (final entry in chains.entries)
          if (forbidden.any(entry.key.startsWith))
            '${entry.key} through ${entry.value.join(' -> ')}',
      ];
      expect(offences, isEmpty);
    });
  }

  test('UI-LAYER: the walk sees the graph: the server connection, which is '
      'not part of this surface, does reach package:http', () {
    // What stops the tests above passing because the walk follows nothing.
    final chains = reachable(declaring('TomServerCall'));
    expect(chains.keys, contains(startsWith('package:http/')));
  });
}
