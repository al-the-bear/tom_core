/// Holds the signatures an API summary quotes to the package's element model.
///
/// Usage: `dart run bin/check_api_signatures.dart <package> <doc-dir>`
///
/// Prints one line per fault and a closing tally as JSON on the last line, so
/// the Python gate wrapper (`tool/check_api_signatures.py`) can report it in the
/// suite's terms. See that wrapper for why the check exists.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: check_api_signatures <package> <doc-dir>');
    exit(2);
  }
  final package = Directory(
    args[0],
  ).absolute.uri.normalizePath().toFilePath().replaceAll(RegExp(r'/$'), '');
  final docDir = Directory(
    Directory(args[1]).absolute.uri.normalizePath().toFilePath(),
  );
  final name = package.split(Platform.pathSeparator).last;
  final barrel = '$package/lib/$name.dart';

  final collection = AnalysisContextCollection(includedPaths: [package]);
  final context = collection.contextFor(barrel);
  final result = await context.currentSession.getResolvedLibrary(barrel);
  if (result is! ResolvedLibraryResult) {
    stderr.writeln('could not resolve $barrel');
    exit(2);
  }
  final exported = result.element.exportNamespace;

  final tally = Tally();
  final documents =
      docDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final document in documents) {
    final shown = document.path.startsWith('$package/')
        ? document.path.substring(package.length + 1)
        : document.path;
    for (final fence in fences(document.readAsStringSync())) {
      checkFence(shown, fence, exported.get2, tally);
    }
  }
  for (final fault in tally.faults) {
    stdout.writeln(fault);
  }
  stdout.writeln(
    jsonEncode({
      'fences': tally.fences,
      'programs': tally.programs,
      'members': tally.members,
      'faults': tally.faults.length,
    }),
  );
}

/// What one run saw.
class Tally {
  int fences = 0;
  int programs = 0;
  int members = 0;
  final faults = <String>[];
}

/// A ```dart fence, the line it opens on, and the names its headings carry,
/// nearest first -- a `#### Operators` under `### TomInt` names a section, not
/// a type, so the owner is the first of them the package actually exports.
typedef Fence = ({int line, String body, List<String> headings});

/// The heading that names a type: `### TomBean\<T\>`, `#### TomApi`.
final _typeHeading = RegExp(r'^#{3,4}\s+`?([A-Za-z_]\w*)');

Iterable<Fence> fences(String text) sync* {
  final lines = text.split('\n');
  String? h3;
  String? h4;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('## ')) h3 = h4 = null;
    final named = _typeHeading.firstMatch(line);
    if (named != null) {
      if (line.startsWith('### ')) {
        h3 = named.group(1);
        h4 = null;
      } else {
        h4 = named.group(1);
      }
    }
    if (line.trimLeft().startsWith('```dart')) {
      final start = i + 1;
      final body = <String>[];
      for (
        i++;
        i < lines.length && !lines[i].trimLeft().startsWith('```');
        i++
      ) {
        body.add(lines[i]);
      }
      yield (line: start, body: body.join('\n'), headings: [?h4, ?h3]);
    }
  }
}

/// A fence is a program, not a list of signatures, when it carries a body,
/// a statement or a type *with* its body: `=>`, a `{` that opens a block, a
/// line ending in `;`. A summary quotes declarations without either. Those
/// are usage samples, which `check_doc_dart_blocks.py` is the instrument for.
final _program = RegExp(r'=>|\)\s*(async\s*)?\{|;\s*(//.*)?$', multiLine: true);

/// A quoted type header with no body: `abstract interface class TomX`, whose
/// claim is the modifiers.
final _typeHeader = RegExp(
  r'^\s*((?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+|mixin\s+)*)'
  r'class\s+([A-Z]\w*)[^\n]*$',
);

/// The type a signature fence quotes the members of: the class its first
/// constructor names, else the heading above it.
final _constructorHead = RegExp(
  r'^\s*(?:const\s+|factory\s+)*([A-Z]\w*)(?:\.\w+)?\s*\(',
);

void checkFence(
  String document,
  Fence fence,
  Element? Function(String) lookUp,
  Tally tally,
) {
  tally.fences++;
  final where = '$document:${fence.line}';
  // An annotation shown in use -- `@TomX(...)` with nothing under it -- is a
  // usage sample like any other.
  final annotationOnly =
      fence.body.trimLeft().startsWith('@') &&
      afterAnnotations(fence.body).isEmpty;
  if (annotationOnly || _program.hasMatch(fence.body)) {
    tally.programs++;
    return;
  }
  final header = _typeHeader.firstMatch(fence.body.trim());
  if (header != null && !fence.body.trim().contains('\n')) {
    tally.members++;
    final element = lookUp(header.group(2)!);
    if (element is! ClassElement) {
      tally.faults.add(
        '$where  `${header.group(2)}` is not a class the '
        'package exports',
      );
      return;
    }
    final quoted = header.group(1)!.split(RegExp(r'\s+'))
      ..removeWhere((m) => m.isEmpty);
    final real = modifiers(element);
    if (quoted.join(' ') != real.join(' ')) {
      tally.faults.add(
        '$where  ${header.group(2)}: is `${[...real, 'class'].join(' ')}`, '
        'quoted as `${[...quoted, 'class'].join(' ')}`',
      );
    }
    return;
  }
  final named = _constructorHead.firstMatch(fence.body)?.group(1);
  final owner =
      named ??
      fence.headings.where((h) => lookUp(h) is InterfaceElement).firstOrNull;
  if (owner == null) {
    checkTopLevel(where, fence.body, lookUp, tally);
    return;
  }
  final element = lookUp(owner);
  if (element is! InterfaceElement) {
    tally.faults.add('$where  `$owner` is not a type the package exports');
    return;
  }

  // A summary writes declarations without bodies. Terminate each so it parses
  // as a member of its owner: a declaration ends where a line closes its last
  // open bracket and the next non-blank line starts another.
  final source = 'abstract class $owner {\n${terminate(fence.body)}\n}\n';
  final parsed = parseString(content: source, throwIfDiagnostics: false);
  if (!parsesAsSignatures(
    parsed.errors.map((e) => e.diagnosticCode.lowerCaseName),
  )) {
    unparsed(where, fence.body, tally);
    return;
  }
  final unit = parsed.unit;
  final declaration = unit.declarations.whereType<ClassDeclaration>().first;
  final members = declaration.body is BlockClassBody
      ? (declaration.body as BlockClassBody).members
      : const <ClassMember>[];
  if (members.isEmpty) {
    tally.faults.add(
      '$where  quotes nothing that reads as a member of `$owner`',
    );
    return;
  }
  for (final member in members) {
    tally.members++;
    final problems = compare(member, element);
    for (final problem in problems) {
      tally.faults.add('$where  $owner${memberLabel(member)}: $problem');
    }
  }
}

/// Whether a fence's parse errors are only the one a quoted signature always
/// has: a declaration without its body. Anything else means the fence is not a
/// list of declarations as written -- a truncated parameter list, a type
/// parameter on a constructor -- or is not a declaration at all.
bool parsesAsSignatures(Iterable<String> codes) =>
    codes.every((code) => code == 'missing_function_body');

/// A fence that does not parse as declarations: a usage sample if it parses
/// as statements, otherwise a fault -- a quote nobody can compare is a quote
/// nobody can trust.
void unparsed(String where, String body, Tally tally) {
  final asStatements = parseString(
    content: 'void _sample() {\n$body;\n}\n',
    throwIfDiagnostics: false,
  );
  if (asStatements.errors.isEmpty) {
    tally.programs++;
    return;
  }
  tally.faults.add('$where  does not parse as a signature');
}

/// What follows the leading annotations of `body`: each `@name` and, when it
/// has one, its balanced argument list.
String afterAnnotations(String body) {
  var rest = body.trimLeft();
  while (rest.startsWith('@')) {
    final head = RegExp(r'^@[\w.]+').firstMatch(rest);
    if (head == null) return rest;
    rest = rest.substring(head.end);
    if (rest.startsWith('(')) {
      var depth = 0;
      var i = 0;
      for (; i < rest.length; i++) {
        if (rest[i] == '(') depth++;
        if (rest[i] == ')' && --depth == 0) break;
      }
      rest = rest.substring(i + 1);
    }
    rest = rest.trimLeft();
  }
  return rest;
}

/// A fence that quotes top-level declarations -- a function, a getter -- each
/// looked up by its own name in the package's exports.
void checkTopLevel(
  String where,
  String body,
  Element? Function(String) lookUp,
  Tally tally,
) {
  final parsed = parseString(
    content: terminate(body),
    throwIfDiagnostics: false,
  );
  if (!parsesAsSignatures(
    parsed.errors.map((e) => e.diagnosticCode.lowerCaseName),
  )) {
    unparsed(where, body, tally);
    return;
  }
  final unit = parsed.unit;
  final functions = unit.declarations.whereType<FunctionDeclaration>().toList();
  final aliases = unit.declarations.whereType<GenericTypeAlias>().toList();
  for (final alias in aliases) {
    tally.members++;
    final name = alias.name.lexeme;
    final real = lookUp(name);
    if (real is! TypeAliasElement) {
      tally.faults.add('$where  $name: is not a typedef the package exports');
    } else if (!matches(alias.type, real.aliasedType)) {
      tally.faults.add(
        '$where  $name: aliases `${display(real.aliasedType)}`, '
        'quoted as `${alias.type.toSource()}`',
      );
    }
  }
  if (functions.isEmpty && aliases.isNotEmpty) return;
  if (functions.isEmpty) {
    tally.faults.add(
      '$where  names no type and declares no top-level '
      'function: no constructor leads the fence and no heading above it '
      'names an exported type',
    );
    return;
  }
  for (final function in functions) {
    tally.members++;
    final name = function.name.lexeme;
    final real = lookUp(name);
    final problems = <String>[];
    if (function.isGetter) {
      if (real is! GetterElement) {
        problems.add('is not a top-level getter the package exports');
      } else if (!matches(function.returnType, real.returnType)) {
        problems.add(
          'returns `${display(real.returnType)}`, quoted as '
          '`${function.returnType?.toSource()}`',
        );
      }
    } else if (real is! TopLevelFunctionElement) {
      problems.add('is not a top-level function the package exports');
    } else {
      if (!matches(function.returnType, real.returnType)) {
        problems.add(
          'returns `${display(real.returnType)}`, quoted as '
          '`${function.returnType?.toSource()}`',
        );
      }
      problems.addAll(
        compareParameters(
          function.functionExpression.parameters,
          real.formalParameters,
        ),
      );
    }
    for (final problem in problems) {
      tally.faults.add('$where  $name: $problem');
    }
  }
}

/// Adds the `;` a body-less declaration needs to parse.
String terminate(String body) {
  final lines = body.split('\n');
  final out = <String>[];
  var depth = 0;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    final code = line.replaceAll(RegExp(r'//.*$'), '');
    for (final char in code.split('')) {
      if ('([{<'.contains(char)) depth++;
      if (')]}>'.contains(char)) depth--;
    }
    final trimmed = code.trimRight();
    // An annotation line belongs to the declaration below it.
    if (trimmed.trimLeft().startsWith('@') && depth <= 0) {
      out.add(line);
      continue;
    }
    if (depth <= 0 &&
        trimmed.isNotEmpty &&
        !trimmed.endsWith(';') &&
        !trimmed.endsWith(',')) {
      final comment = line.length > code.length
          ? line.substring(code.length)
          : '';
      line = '${trimmed.trimRight()};$comment';
      depth = 0;
    }
    out.add(line);
  }
  return out.join('\n');
}

/// A class's modifiers in source order.
List<String> modifiers(ClassElement element) => [
  if (element.isAbstract && !element.isInterface && !element.isSealed ||
      element.isAbstract && element.isInterface)
    'abstract',
  if (element.isBase) 'base',
  if (element.isFinal) 'final',
  if (element.isInterface) 'interface',
  if (element.isSealed) 'sealed',
  if (element.isMixinClass) 'mixin',
];

String memberLabel(ClassMember member) => switch (member) {
  ConstructorDeclaration(:final name) =>
    name == null ? '()' : '.${name.lexeme}',
  MethodDeclaration(:final name) => '.${name.lexeme}',
  FieldDeclaration(:final fields) => '.${fields.variables.first.name.lexeme}',
  _ => '',
};

List<String> compare(ClassMember member, InterfaceElement owner) {
  switch (member) {
    case ConstructorDeclaration():
      final name = member.name?.lexeme ?? 'new';
      final real =
          owner.getNamedConstructor(name) ??
          (name == 'new' ? owner.unnamedConstructor : null);
      if (real == null) return ['no such constructor'];
      return [
        if ((member.factoryKeyword != null) != real.isFactory)
          real.isFactory
              ? 'is a factory, quoted as generative'
              : 'is generative, quoted as a factory',
        if ((member.constKeyword != null) != real.isConst)
          real.isConst ? 'is const, quoted without it' : 'is not const',
        ...compareParameters(member.parameters, real.formalParameters),
      ];
    case MethodDeclaration():
      final name = member.name.lexeme;
      final ExecutableElement? real = member.isGetter
          ? owner.getGetter(name)
          : member.isSetter
          ? owner.getSetter(name)
          : owner.getMethod(name);
      if (real == null)
        return [
          'no such ${member.isGetter
              ? 'getter'
              : member.isSetter
              ? 'setter'
              : 'method'} on the type',
        ];
      final quoted = member.returnType;
      return [
        if (member.isStatic != real.isStatic)
          real.isStatic
              ? 'is static, quoted as an instance member'
              : 'is an instance member, quoted as static',
        if (!matches(quoted, real.returnType))
          'returns `${display(real.returnType)}`, quoted as '
              '`${quoted?.toSource()}`',
        if (!member.isGetter)
          ...compareParameters(member.parameters, real.formalParameters),
      ];
    case FieldDeclaration():
      final name = member.fields.variables.first.name.lexeme;
      final real = owner.getGetter(name);
      if (real == null) return ['no such field or getter'];
      final quoted = member.fields.type;
      return [
        if (!matches(quoted, real.returnType))
          'is `${display(real.returnType)}`, quoted as `${quoted?.toSource()}`',
      ];
    default:
      return ['is not a declaration this check reads'];
  }
}

List<String> compareParameters(
  FormalParameterList? quoted,
  List<FormalParameterElement> real,
) {
  if (quoted == null) return const [];
  final problems = <String>[];
  final doc = quoted.parameters;
  // A positional parameter's name is not part of the API -- no caller writes
  // it -- so positional parameters are matched by position. A named one is
  // matched by name, which is the whole of its identity.
  final docPositional = [
    for (final p in doc)
      if (!p.isNamed) p,
  ];
  final realPositional = [
    for (final p in real)
      if (!p.isNamed) p,
  ];
  final docNamed = {
    for (final p in doc)
      if (p.isNamed) p.name?.lexeme ?? '': p,
  };
  final realNamed = {
    for (final p in real)
      if (p.isNamed) p.name ?? '': p,
  };

  if (docPositional.length != realPositional.length) {
    problems.add(
      'takes ${realPositional.length} positional parameter(s), '
      'quoted with ${docPositional.length}',
    );
  }
  for (var i = 0; i < docPositional.length && i < realPositional.length; i++) {
    problems.addAll(
      compareOne(
        docPositional[i],
        realPositional[i],
        'positional parameter ${i + 1}',
      ),
    );
  }
  for (final name in realNamed.keys) {
    if (!docNamed.containsKey(name)) problems.add('omits `$name`');
  }
  for (final entry in docNamed.entries) {
    final r = realNamed[entry.key];
    if (r == null) {
      problems.add('has no named parameter `${entry.key}`');
      continue;
    }
    problems.addAll(compareOne(entry.value, r, '`${entry.key}`'));
  }
  return problems;
}

List<String> compareOne(
  FormalParameter d,
  FormalParameterElement r,
  String label,
) {
  final type = declaredType(d);
  final quotedDefault = defaultOf(d);
  final realDefault = r.defaultValueCode;
  return [
    if (kind(d) != kindOf(r)) '$label is ${kindOf(r)}, quoted as ${kind(d)}',
    if (!matches(type, r.type))
      '$label is `${display(r.type)}`, quoted as `${type?.toSource()}`',
    if (quotedDefault != null &&
        realDefault != null &&
        !sameDefault(quotedDefault, realDefault))
      '$label defaults to `$realDefault`, quoted as `$quotedDefault`',
  ];
}

String kind(FormalParameter p) => p.isRequiredNamed
    ? 'required named'
    : p.isNamed
    ? 'optional named'
    : p.isOptionalPositional
    ? 'optional positional'
    : 'required positional';

String kindOf(FormalParameterElement p) => p.isRequiredNamed
    ? 'required named'
    : p.isNamed
    ? 'optional named'
    : p.isOptionalPositional
    ? 'optional positional'
    : 'required positional';

TypeAnnotation? declaredType(FormalParameter p) {
  final inner = p is DefaultFormalParameter ? p.parameter : p;
  return switch (inner) {
    SimpleFormalParameter(:final type) => type,
    FieldFormalParameter(:final type) => type,
    SuperFormalParameter(:final type) => type,
    _ => null,
  };
}

String? defaultOf(FormalParameter p) =>
    p is DefaultFormalParameter ? p.defaultValue?.toSource() : null;

String display(DartType type) => type.getDisplayString();

String squash(String text) => text.replaceAll(RegExp(r'\s+'), '');

/// Whether a quoted type annotation names the real type.
///
/// Compared structurally rather than as text, because the summaries write a
/// type the way its declaration does and the analyzer prints it expanded.
/// Three spellings are therefore the same type: a typedef's name with its
/// arguments for the function type it aliases (`ValueChanged<String>`), a raw
/// generic for its instantiation to bounds (`List<TomCompositeStep>`), and a
/// function type with parameter names for the same type without them. An
/// absent annotation claims nothing.
bool matches(TypeAnnotation? quoted, DartType real) {
  if (quoted == null) return true;
  final nullable = real.nullabilitySuffix == NullabilitySuffix.question;
  switch (quoted) {
    case NamedType(:final name, :final typeArguments, :final question):
      final args = typeArguments?.arguments;
      final text = name.lexeme;
      if (text == 'dynamic') return real is DynamicType;
      if ((question != null) != nullable && real is! DynamicType) return false;
      final alias = real.alias;
      if (alias != null && alias.element.name == text) {
        return args == null || sameAll(args, alias.typeArguments);
      }
      if (text == 'Function') return real is FunctionType;
      return switch (real) {
        InterfaceType(:final element, :final typeArguments) =>
          element.name == text &&
              (args == null || sameAll(args, typeArguments)),
        TypeParameterType(:final element) => element.name == text,
        VoidType() => text == 'void',
        NeverType() => text == 'Never',
        _ => squash(quoted.toSource()) == squash(display(real)),
      };
    case GenericFunctionType(
      :final returnType,
      :final parameters,
      :final question,
    ):
      if (real is! FunctionType) return false;
      if ((question != null) != nullable) return false;
      if (!matches(returnType, real.returnType)) return false;
      return compareParameters(parameters, real.formalParameters).isEmpty;
    case RecordTypeAnnotation(:final positionalFields, :final namedFields):
      if (real is! RecordType) return false;
      if ((quoted.question != null) != nullable) return false;
      if (positionalFields.length != real.positionalFields.length) return false;
      for (var i = 0; i < positionalFields.length; i++) {
        if (!matches(positionalFields[i].type, real.positionalFields[i].type)) {
          return false;
        }
      }
      // Named fields are a set: the analyzer prints them sorted.
      final quotedNamed = {
        for (final f
            in namedFields?.fields ?? const <RecordTypeAnnotationNamedField>[])
          f.name.lexeme: f.type,
      };
      if (quotedNamed.length != real.namedFields.length) return false;
      for (final field in real.namedFields) {
        final type = quotedNamed[field.name];
        if (type == null || !matches(type, field.type)) return false;
      }
      return true;
  }
}

bool sameAll(List<TypeAnnotation> quoted, List<DartType> real) {
  if (quoted.length != real.length) return false;
  for (var i = 0; i < quoted.length; i++) {
    if (!matches(quoted[i], real[i])) return false;
  }
  return true;
}

/// Whether a quoted default is the declared one. A constant the declaration
/// names bare (`defaultLimit`) is `Owner.defaultLimit` to everyone outside the
/// class, which is how a summary has to write it; and a private default cannot
/// be quoted at all, so there is nothing to hold it to.
bool sameDefault(String quoted, String real) {
  final q = squash(quoted);
  final r = squash(real);
  if (q == r) return true;
  if (r.startsWith('_')) return true;
  return RegExp(r'^\w+$').hasMatch(r) && q.endsWith('.$r');
}
