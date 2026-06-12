// PlaceholderStack — the lexical scope chain placeholders resolve against.
//
// Part of the shared placeholder system (originally Extension F, step 1 of
// `tom_brain_procedure_specification.md` § 21.7; relocated to
// `tom_core_agentic` so every config layer — substrate / access / memory /
// run — and the engine share one resolver).
//
// § 21.7 frames the scope stack as "the d4rt lexical scope chain": each
// nested procedure / `sub.llm` frame pushes a child scope; a child may
// bind its own variables — **even same-named** ones, shadowing the parent;
// on pop the child is discarded and the parent's bindings are restored, so
// lower-level writes never leak upward.
//
// The chain is modelled here as a Dart-side stack of frames: the simple
// `${name}` form reads a binding directly from this stack, and the
// `${{ … }}` form receives the *flattened* stack as the locals it evaluates
// against. Keeping the namespace here (a) gives the requested
// push/pop shadow/restore semantics exactly, and (b) keeps the two forms
// reading one set of bindings, the "unifies the simple and expression forms
// under one variable namespace" property § 21.7 calls for.

/// Returns whether [name] is a bare Dart identifier — the shape the simple
/// `${name}` fast path accepts and the only binding names that can be
/// injected as d4rt expression locals.
bool isSimpleIdentifier(String name) => _identifier.hasMatch(name);

final RegExp _identifier = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');

/// A stack of binding frames implementing lexical, shadowing scope.
///
/// Starts with a single root frame. [push] opens a child frame; [bind]
/// always writes to the current (top) frame; [lookup] / [has] walk
/// top→root so a child binding shadows a same-named parent one; [pop]
/// discards the top frame and restores the parent's view.
final class PlaceholderStack {
  /// Creates a stack with a single, empty root frame.
  PlaceholderStack() : _frames = <Map<String, Object?>>[<String, Object?>{}];

  final List<Map<String, Object?>> _frames;

  /// Number of frames currently on the stack (the root counts as 1).
  int get depth => _frames.length;

  /// Pushes a new child frame, optionally seeded with [initial] bindings.
  ///
  /// The seed is copied, so later mutation of [initial] does not leak into
  /// the frame.
  void push([Map<String, Object?>? initial]) {
    _frames.add(<String, Object?>{...?initial});
  }

  /// Pops and discards the top frame, restoring the parent's bindings.
  ///
  /// Throws a [StateError] if only the root frame remains — the root is
  /// never popped.
  void pop() {
    if (_frames.length == 1) {
      throw StateError('PlaceholderStack: cannot pop the root frame');
    }
    _frames.removeLast();
  }

  /// Binds [name] to [value] in the current (top) frame, shadowing any
  /// same-named binding in a parent frame for as long as this frame lives.
  void bind(String name, Object? value) {
    _frames.last[name] = value;
  }

  /// Binds every entry of [values] in the current (top) frame.
  void bindAll(Map<String, Object?> values) {
    _frames.last.addAll(values);
  }

  /// Whether any frame currently binds [name].
  bool has(String name) => _frames.any((f) => f.containsKey(name));

  /// The value bound to [name] in the nearest enclosing frame, or `null`
  /// when no frame binds it.
  ///
  /// Because a binding may legitimately hold `null`, callers that must
  /// distinguish "absent" from "bound to null" should consult [has] first.
  Object? lookup(String name) {
    for (var i = _frames.length - 1; i >= 0; i--) {
      final frame = _frames[i];
      if (frame.containsKey(name)) {
        return frame[name];
      }
    }
    return null;
  }

  /// The whole chain flattened into one map, with child frames winning on
  /// name collisions — the binding view a `${{ … }}` expression sees.
  Map<String, Object?> flatten() {
    final merged = <String, Object?>{};
    for (final frame in _frames) {
      merged.addAll(frame);
    }
    return merged;
  }
}
