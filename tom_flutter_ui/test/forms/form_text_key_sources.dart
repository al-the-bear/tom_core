import 'dart:io';

/// The text keys the forms read under a path of their own, read from the
/// sources of `lib/src/forms`, by class.
///
/// A key is read as `TomCtr.text*(basePath, '<key>')`, or under a child path
/// built with `_childKey(basePath, '<child>')`, which gives `<child>.<key>`. A
/// class gets the reads in its own body, in the mixins it names and in every
/// class it extends, so a concrete field carries what its abstract base and
/// `TomField` read. Reads under a computed key (a validation message's
/// `errorKey`) and under another root (a theme block) are not literal keys of
/// a path and are left out.
class FormTextKeySources {
  FormTextKeySources._(this._declarations);

  factory FormTextKeySources.scan([String root = 'lib/src/forms']) {
    final declarations = <String, _Declaration>{};
    for (final file in Directory(root).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final starts = [
        for (final m in _header.allMatches(source))
          (start: m.start, end: m.end, match: m),
      ]..sort((a, b) => a.start.compareTo(b.start));
      for (var i = 0; i < starts.length; i++) {
        final m = starts[i].match;
        final bodyEnd = i + 1 < starts.length
            ? starts[i + 1].start
            : source.length;
        final header = _withoutTypeArguments(source.substring(m.start, m.end));
        final body = source.substring(m.start, bodyEnd);
        final name = m.group(3)!;
        final withClause = RegExp(
          r'\bwith\s+([\w\s,]+?)\s*(?:\bimplements\b|\{)',
        ).firstMatch(header);
        declarations[name] = _Declaration(
          name: name,
          isAbstract: m.group(1) != null || m.group(2) == 'mixin',
          superName: RegExp(r'\bextends\s+(\w+)').firstMatch(header)?.group(1),
          mixins: [
            for (final part in (withClause?.group(1) ?? '').split(','))
              if (part.trim().isNotEmpty) part.trim(),
          ],
          reads: _readsIn(body),
        );
      }
    }
    return FormTextKeySources._(declarations);
  }

  final Map<String, _Declaration> _declarations;

  /// `abstract? ... class|mixin Name ... {` up to the opening brace.
  static final _header = RegExp(
    r'^(abstract\s+)?(?:base\s+|final\s+|sealed\s+|interface\s+)*'
    r'(class|mixin)\s+(\w+)[^{;]*\{',
    multiLine: true,
  );

  static final _read = RegExp(
    r"TomCtr\.(?:textOrFail|textOrNull|text)\(\s*(basePath|\w+Base),\s*"
    r"'([A-Za-z.]+)'",
  );

  static final _child = RegExp(
    r"final\s+(\w+Base)\s*=\s*_childKey\(\s*basePath,\s*'(\w+)'\s*\)",
  );

  static Set<String> _readsIn(String body) {
    final children = {
      for (final m in _child.allMatches(body)) m.group(1)!: m.group(2)!,
    };
    return {
      for (final m in _read.allMatches(body))
        if (m.group(1) == 'basePath')
          m.group(2)!
        else if (children[m.group(1)] != null)
          '${children[m.group(1)]}.${m.group(2)}',
    };
  }

  /// [text] without its type arguments and parameters (`<T extends X>`), so
  /// a bound's `extends` is not read as the superclass.
  static String _withoutTypeArguments(String text) {
    final out = StringBuffer();
    var depth = 0;
    for (final c in text.split('')) {
      if (c == '<') {
        depth++;
      } else if (c == '>') {
        depth--;
      } else if (depth == 0) {
        out.write(c);
      }
    }
    return out.toString();
  }

  /// Whether [name] is a field: it extends `TomField`, however indirectly.
  bool isField(String name) {
    String? current = name;
    for (var depth = 0; current != null && depth < 12; depth++) {
      final d = _declarations[current];
      if (d == null) return current == 'TomField';
      if (d.superName == 'TomField') return true;
      current = d.superName;
    }
    return false;
  }

  /// Every public concrete class declared under the scanned root.
  Iterable<String> get concreteClasses => [
    for (final d in _declarations.values)
      if (!d.isAbstract && !d.name.startsWith('_')) d.name,
  ];

  /// The keys [name] reads, inherited and mixed-in reads included.
  Set<String> keysOf(String name) {
    final keys = <String>{};
    final seen = <String>{};
    void visit(String? n) {
      if (n == null || !seen.add(n)) return;
      final d = _declarations[n];
      if (d == null) return;
      keys.addAll(d.reads);
      d.mixins.forEach(visit);
      visit(d.superName);
    }

    visit(name);
    return keys;
  }
}

class _Declaration {
  _Declaration({
    required this.name,
    required this.isAbstract,
    required this.superName,
    required this.mixins,
    required this.reads,
  });

  final String name;
  final bool isAbstract;
  final String? superName;
  final List<String> mixins;
  final Set<String> reads;
}
