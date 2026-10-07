/// Reflection data a test controls, for raise sites that only a reflected
/// class with a particular shape can reach.
///
/// Several of the framework's decisions are taken *about a reflected class*:
/// whether a scanned driver can be built, whether two adaptors claim one type,
/// whether a result row can be instantiated, what a column's annotation says.
/// The shared reflection fixture is generated and committed, and every class in
/// it is visible to every test — so a class whose constructor throws, or a
/// second adaptor for an existing type, would break the scan for every other
/// suite. A test that needs one of those shapes therefore states it here, in
/// its own isolate, rather than in the shared fixture.
///
/// Two forms are offered:
///
/// * [installReflectedClasses] replaces the reflector's data outright with a
///   handful of [ScriptedClassMirror]s, for the registry scans that walk
///   `tomReflector.annotatedClasses`.
/// * [PatchedReflection] copies the generated data and swaps individual
///   entries — one class's mirror, one field's annotations, one setter — so the
///   rest of the reflected surface keeps working exactly as generated.
///
/// What a swapped entry stands for is always a class a person could write: a
/// constructor that throws, a field annotated `isJson`, a setter that refuses
/// its value. The mirror describes that declaration; the framework code that
/// reads it is the real code.
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:tom_reflection/generated.dart' as r;

/// A class mirror whose identity, annotations and declarations are given, and
/// whose construction answers from a script.
///
/// [construct] is called once per `newInstance`, so a test can let the first
/// construction succeed and the next one fail — the shape of a class whose
/// constructor depends on state that changes between calls.
class ScriptedClassMirror implements r.ClassMirror<Object> {
  /// A mirror for a class named [simpleName] carrying [metadata].
  ScriptedClassMirror(
    this.simpleName, {
    required this.construct,
    this.metadata = const [],
    this.reflectedType = Object,
  }) : _real = null;

  /// A mirror that answers everything but construction from [real].
  ScriptedClassMirror.over(r.ClassMirror real, {required this.construct})
    : _real = real,
      simpleName = real.simpleName,
      metadata = real.metadata,
      reflectedType = real.reflectedType;

  final r.ClassMirror? _real;

  /// Produces the next instance, or throws.
  final Object Function() construct;

  @override
  final String simpleName;

  @override
  final List<Object> metadata;

  @override
  final Type reflectedType;

  @override
  String get qualifiedName => _real?.qualifiedName ?? '.$simpleName';

  @override
  Map<String, r.DeclarationMirror> get declarations =>
      _real?.declarations ?? const {};

  @override
  Object newInstance(
    String constructorName,
    List positionalArguments, [
    Map<Symbol, dynamic> namedArguments = const {},
  ]) => construct();

  @override
  String toString() => 'ScriptedClassMirror($simpleName)';

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'ScriptedClassMirror($simpleName) was asked for '
    '${invocation.memberName}. Answer it here if a test needs it.',
  );
}

/// A field mirror that reports [metadata] and [reflectedType] in place of the
/// generated ones, and delegates the rest of its identity to [real].
///
/// It stands for the same field declared differently — another annotation, or
/// another type — which is all the column analyser and the row mapper read.
class AnnotatedFieldMirror implements r.VariableMirror {
  /// Overrides [real]'s annotations with [metadata], and its declared type with
  /// [reflectedType] when one is given.
  AnnotatedFieldMirror(this.real, this.metadata, {Type? reflectedType})
    : reflectedType = reflectedType ?? real.reflectedType;

  /// The generated mirror for the field.
  final r.VariableMirror real;

  @override
  final List<Object> metadata;

  @override
  final Type reflectedType;

  @override
  String get simpleName => real.simpleName;

  @override
  String get qualifiedName => real.qualifiedName;

  @override
  r.DeclarationMirror get owner => real.owner;

  @override
  bool get isStatic => real.isStatic;

  @override
  bool get isFinal => real.isFinal;

  @override
  bool get isConst => real.isConst;

  @override
  bool get isPrivate => real.isPrivate;

  @override
  bool get isTopLevel => real.isTopLevel;

  @override
  bool get hasReflectedType => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'AnnotatedFieldMirror(${real.simpleName}) was asked for '
    '${invocation.memberName}. Delegate it here if a test needs it.',
  );
}

/// Replaces the reflector's data with exactly [classes].
///
/// The scans read `tomReflector.annotatedClasses`, which is every class mirror
/// in the data in order, so this decides both what a scan finds and the order
/// it finds it in.
void installReflectedClasses(List<r.ClassMirror> classes) {
  r.data = {
    tomReflector: r.ReflectorData(
      [...classes],
      const [],
      const [],
      [for (final mirror in classes) mirror.reflectedType],
      classes.length,
      const {},
      const {},
      null,
      null,
    ),
  };
}

/// A copy of the generated reflection data, installed in its place, whose
/// entries can be swapped one at a time.
///
/// The copy is installed before anything is swapped, and every swap happens
/// before the first lookup a test makes: generated mirrors cache the data they
/// first read and the declarations they first compute, so a swap made after a
/// mirror has been used would not be seen by it.
class PatchedReflection {
  PatchedReflection._(this._data);

  /// Copies the currently installed data for `tomReflector` and installs the
  /// copy. The generated `initializeReflection()` must have run first.
  factory PatchedReflection.install() {
    final real = r.data[tomReflector]!;
    final copy = r.ReflectorData(
      List.of(real.typeMirrors),
      real.memberMirrors == null ? null : List.of(real.memberMirrors!),
      real.parameterMirrors,
      real.types,
      real.supportedClassCount,
      Map.of(real.getters),
      Map.of(real.setters),
      real.libraryMirrors,
      real.parameterListShapes,
    );
    r.data = {...r.data, tomReflector: copy};
    return PatchedReflection._(copy);
  }

  final r.ReflectorData _data;

  /// The installed mirror for [type].
  r.ClassMirror classMirror(Type type) {
    final index = _data.types.indexOf(type);
    if (index < 0) throw StateError('$type is not reflected');
    return _data.typeMirrors[index] as r.ClassMirror;
  }

  /// Replaces the mirror for [type] with [mirror].
  void replaceClass(Type type, r.ClassMirror mirror) {
    final index = _data.types.indexOf(type);
    if (index < 0) throw StateError('$type is not reflected');
    _data.typeMirrors[index] = mirror;
  }

  /// Replaces the mirror of [owner]'s field [field] with what [patch] makes of
  /// the generated one.
  ///
  /// The field is found by its own name and its owner's name rather than
  /// through the owner's `declarations`, which would cache the unpatched list
  /// on the owner's mirror.
  void replaceField(
    Type owner,
    String field,
    r.VariableMirror Function(r.VariableMirror real) patch,
  ) {
    final members = _data.memberMirrors!;
    final ownerName = '$owner';
    for (var i = 0; i < members.length; i++) {
      final member = members[i];
      if (member is r.VariableMirror &&
          member.simpleName == field &&
          member.owner.simpleName == ownerName) {
        members[i] = patch(member);
        return;
      }
    }
    throw StateError('$owner.$field is not a reflected field');
  }

  /// Replaces the reflective setter for every field named [field].
  void replaceSetter(
    String field,
    Object? Function(Object? instance, Object? value) setter,
  ) {
    _data.setters['$field='] = setter;
  }
}
