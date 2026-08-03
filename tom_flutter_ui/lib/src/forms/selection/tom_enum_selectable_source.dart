import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'tom_selectable_source.dart';

/// Shared implementation of the two bundle-labelled enum sources.
///
/// Both offer the same option set and resolve labels identically; they differ
/// only in what a selected option *is worth* — the enum itself
/// ([TomEnumSelectableSource]) or its [Enum.name]
/// ([TomEnumNameSelectableSource]). That single degree of freedom is the
/// abstract [valueOf]; everything else — scope capture, label resolution,
/// the enablement predicate and the re-emission on bundle change — lives here
/// once.
abstract class _BundleLabelledEnumSource<E extends Enum, V>
    extends TomSelectableSource<V> {
  _BundleLabelledEnumSource(
    List<E> values, {
    TomScope? scope,
    bool Function(E value)? isEnabled,
  })  : values = List<E>.unmodifiable(values),
        scope = scope ?? TomScope.current,
        _isEnabled = isEnabled;

  /// The offered enum values, in declaration order. Unmodifiable.
  final List<E> values;

  /// The scope used to resolve option labels.
  final TomScope scope;

  final bool Function(E value)? _isEnabled;

  StreamController<List<SelectableItem<V>>>? _controller;

  /// Retains the bundle-revision subscription while anyone is listening.
  ///
  /// [TomObservable] holds observers weakly, so without this strong reference
  /// re-emission would stop at a nondeterministic later time.
  TomFunctionObserver<TomObservable>? _observer;

  /// What a selected [value] is worth to the bound field.
  V valueOf(E value);

  @override
  Future<List<SelectableItem<V>>> getItems() async => buildItems();

  @override
  Stream<List<SelectableItem<V>>>? get itemsStream =>
      (_controller ??= StreamController<List<SelectableItem<V>>>.broadcast(
        onListen: _observeBundle,
        onCancel: _stopObservingBundle,
      ))
          .stream;

  /// Builds the current option list, resolving every label from the bundle.
  List<SelectableItem<V>> buildItems() => List.unmodifiable([
        for (final value in values)
          SelectableItem<V>(
            value: valueOf(value),
            label: TomObservableEnum.resolveText(value, scope: scope),
            enabled: _isEnabled?.call(value) ?? true,
          ),
      ]);

  void _observeBundle() {
    _observer ??= TomTextResourceProvider.appResourcesRevision >>
        (_) {
          final controller = _controller;
          if (controller != null && !controller.isClosed) {
            controller.add(buildItems());
          }
        };
  }

  void _stopObservingBundle() {
    final observer = _observer;
    if (observer != null) {
      TomTextResourceProvider.appResourcesRevision.removeObserver(observer);
      _observer = null;
    }
  }
}

/// A [TomSelectableSource] over an enum whose option labels come from the
/// application text bundle instead of a Dart-side label table.
///
/// Each option's label is resolved by [TomObservableEnum.resolveText] under
/// `<scope>.<enumName>.<value>`, so the strings a picker shows are the ones
/// the server sent. A value with no key in the bundle renders its raw enum
/// name and logs a warning — the option is still selectable, never blank.
///
/// The source re-emits its items whenever the installed bundle changes
/// (`TomTextResourceProvider.appResourcesRevision`), which is what makes a
/// locale switch re-render a bound field: the selection widgets already
/// listen to [itemsStream], so nothing on the widget side has to change and
/// the caller does not rebuild the field.
///
/// ```dart
/// final status = form.fields.enumPickerFor(
///   'status',
///   TodoStatus.open,
///   values: TodoStatus.values,
/// );
/// ```
///
/// Options are valued by the enum itself, so the bound field is
/// enum-typed. When the entity stores [Enum.name] in a `TomString` instead —
/// as domain classes that must stay JSON-serializable usually do — reach for
/// [TomEnumNameSelectableSource].
///
/// The scope used for resolution is the ambient [TomScope] at construction
/// time — display resolution happens inside Flutter builder callbacks, which
/// run outside the zone that installed the scope.
class TomEnumSelectableSource<E extends Enum>
    extends _BundleLabelledEnumSource<E, E> {
  /// Creates a source offering [values], labelled from the text bundle.
  ///
  /// [scope] overrides the ambient [TomScope] used for key resolution.
  /// [isEnabled] optionally disables individual options; by default every
  /// value is selectable.
  TomEnumSelectableSource(super.values, {super.scope, super.isEnabled});

  /// Creates a source offering the values of [cell], in [cell]'s scope.
  ///
  /// Use this when the bound value is already a [TomObservableEnum] so that
  /// the picker and the cell resolve their labels identically.
  TomEnumSelectableSource.of(
    TomObservableEnum<E> cell, {
    super.isEnabled,
  }) : super(cell.values, scope: cell.scope);

  @override
  E valueOf(E value) => value;
}

/// The [Enum.name]-valued twin of [TomEnumSelectableSource]: same
/// bundle-resolved labels, but each option is worth the enum's name.
///
/// This is the source for a field bound to a member that *stores* the name
/// rather than the enum — the common shape for a reflected domain class,
/// whose `getValues()` must stay JSON-safe and so keeps the value in a
/// `TomString`:
///
/// ```dart
/// // Entity: late final status = TomString(TodoStatus.backlog.name);
/// status = TomFormStringDropdown(
///   'status',
///   TodoStatus.backlog.name,
///   form: this,
///   source: TomEnumNameSelectableSource(TodoStatus.values),
/// );
/// ```
///
/// Because only the *label* is bundle-derived, a locale switch relabels the
/// options without ever disturbing the stored value.
class TomEnumNameSelectableSource<E extends Enum>
    extends _BundleLabelledEnumSource<E, String> {
  /// Creates a source offering [values], valued by name and labelled from the
  /// text bundle.
  ///
  /// [scope] overrides the ambient [TomScope] used for key resolution.
  /// [isEnabled] optionally disables individual options; by default every
  /// value is selectable.
  TomEnumNameSelectableSource(super.values, {super.scope, super.isEnabled});

  @override
  String valueOf(E value) => value.name;
}
