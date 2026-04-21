/// Unit tests for Phase 4 field-type behaviour.
///
/// Mirrors the `phase3_unit_test.dart` pattern — constructs fields
/// directly (no widget tree, no reflection) and asserts the observable
/// surface contracted by Phase 4:
///
///   * Enum / Object single-select: setValue fires observers, dirty
///     tracking flips off the initial value.
///   * Enum / Object / Int multi-select: `toggleItem` allocates a fresh
///     list (so change detection fires) and is idempotent.
///   * Nullable inputs: distinguish pristine vs explicit-null vs set.
///   * File field: `checkFile` enforces `allowedExtensions` and
///     `maxSizeBytes`; `FileRef` is equatable / hashable.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

enum _Priority { low, medium, high }

@immutable
class _Country {
  final String code;
  const _Country(this.code);
  @override
  bool operator ==(Object other) => other is _Country && other.code == code;
  @override
  int get hashCode => code.hashCode;
  @override
  String toString() => 'Country($code)';
}

class _PrioritySource extends TomSelectableSource<_Priority> {
  @override
  Future<List<SelectableItem<_Priority>>> getItems() async => [
        for (final p in _Priority.values)
          SelectableItem<_Priority>(value: p, label: p.name),
      ];
}

class _CountrySource extends TomSelectableSource<_Country> {
  @override
  Future<List<SelectableItem<_Country>>> getItems() async => const [
        SelectableItem(value: _Country('US'), label: 'US'),
        SelectableItem(value: _Country('DE'), label: 'DE'),
        SelectableItem(value: _Country('FR'), label: 'FR'),
      ];
}

class _IntSource extends TomSelectableSource<int> {
  @override
  Future<List<SelectableItem<int>>> getItems() async => const [
        SelectableItem(value: 8, label: '8'),
        SelectableItem(value: 10, label: '10'),
        SelectableItem(value: 12, label: '12'),
      ];
}

void main() {
  group('Phase 4 — Enum single-select wiring', () {
    test('TomFormEnumDropdown setValue fires observer + flips isDirty',
        () {
      final src = _PrioritySource();
      final f = TomFormEnumDropdown<_Priority>(
        'p',
        _Priority.medium,
        source: src,
      );
      var fires = 0;
      // Hold strong ref — TomObservable stores observers via WeakReference.
      // ignore: unused_local_variable
      final obs = f >> (_) => fires++;
      expect(f.isDirty, isFalse);
      f.setValue(_Priority.high);
      expect(f.get(), _Priority.high);
      expect(f.isDirty, isTrue);
      expect(fires, 1);
    });

    test('TomFormEnumDropdown setValue with same value is a no-op', () {
      final src = _PrioritySource();
      final f = TomFormEnumDropdown<_Priority>(
        'p',
        _Priority.medium,
        source: src,
      );
      var fires = 0;
      // ignore: unused_local_variable
      final obs = f >> (_) => fires++;
      f.setValue(_Priority.medium);
      expect(fires, 0);
      expect(f.isDirty, isFalse);
    });
  });

  group('Phase 4 — Enum multi-select toggleItem', () {
    test('toggleItem(true) appends; toggleItem(false) removes', () {
      final src = _PrioritySource();
      final f = TomFormEnumFilterChips<_Priority>(
        'pset',
        const [_Priority.low],
        source: src,
      );
      var fires = 0;
      // ignore: unused_local_variable
      final obs = f >> (_) => fires++;

      f.toggleItem(_Priority.high, true);
      expect(f.get(), [_Priority.low, _Priority.high]);
      expect(fires, 1);

      f.toggleItem(_Priority.low, false);
      expect(f.get(), [_Priority.high]);
      expect(fires, 2);
    });

    test('toggleItem(true) is idempotent — no duplicates', () {
      final src = _PrioritySource();
      final f = TomFormEnumFilterChips<_Priority>(
        'pset',
        const [_Priority.low],
        source: src,
      );
      f.toggleItem(_Priority.low, true);
      expect(f.get(), [_Priority.low]);
    });

    test('toggleItem allocates a fresh list (non-identical to previous)',
        () {
      final src = _PrioritySource();
      final f = TomFormEnumFilterChips<_Priority>(
        'pset',
        const [_Priority.low],
        source: src,
      );
      final before = f.get();
      f.toggleItem(_Priority.high, true);
      final after = f.get();
      expect(identical(before, after), isFalse,
          reason: 'toggleItem must allocate fresh so change detection fires');
    });
  });

  group('Phase 4 — Object multi-select toggleItem', () {
    test('toggleItem on object list mirrors enum semantics', () {
      final src = _CountrySource();
      final f = TomFormObjectFilterChips<_Country>(
        'countries',
        const [_Country('US')],
        source: src,
      );
      f.toggleItem(const _Country('DE'), true);
      expect(f.get(), [const _Country('US'), const _Country('DE')]);
      f.toggleItem(const _Country('US'), false);
      expect(f.get(), [const _Country('DE')]);
    });
  });

  group('Phase 4 — TomFormIntFilterChips', () {
    test('toggleItem semantics on int list', () {
      final src = _IntSource();
      final f = TomFormIntFilterChips(
        'sizes',
        const [10],
        source: src,
      );
      var fires = 0;
      // ignore: unused_local_variable
      final obs = f >> (_) => fires++;

      f.toggleItem(12, true);
      expect(f.get(), [10, 12]);
      expect(fires, greaterThanOrEqualTo(1),
          reason: 'fresh-list allocation must trigger change detection');

      // No duplicates in the list (firing count is implementation detail —
      // the list-equality of `setValue` falls back to identity for List<int>
      // so a redundant toggle may still fire; the contract under test is
      // "no duplicates in the list").
      f.toggleItem(12, true);
      expect(f.get(), [10, 12]);

      // Remove.
      f.toggleItem(10, false);
      expect(f.get(), [12]);
    });
  });

  group('Phase 4 — Nullable inputs distinguish pristine / set / explicit-null',
      () {
    test('TomFormNStringInput pristine vs set vs explicit-null', () {
      final f = TomFormNStringInput('notes', null);
      expect(f.get(), isNull);
      expect(f.isDirty, isFalse, reason: 'pristine null');

      f.setValue('hello');
      expect(f.get(), 'hello');
      expect(f.isDirty, isTrue);

      f.setValue(null);
      expect(f.get(), isNull);
      expect(f.isDirty, isFalse,
          reason:
              'value back to initialValue (null) — isDirty resets per current contract');
    });

    test('TomFormNIntInput initial-null + setValue + clear', () {
      final f = TomFormNIntInput('age', null);
      expect(f.get(), isNull);
      expect(f.isDirty, isFalse);

      f.setValue(42);
      expect(f.get(), 42);
      expect(f.isDirty, isTrue);

      f.setValue(null);
      expect(f.get(), isNull);
      expect(f.isDirty, isFalse);
    });

    test(
        'Nullable initial-set field treats setValue(null) as explicit-null '
        '(isDirty=true)', () {
      // When the initial value is non-null, setting null is a real change.
      final f = TomFormNStringInput('greeting', 'hi');
      expect(f.isDirty, isFalse);
      f.setValue(null);
      expect(f.get(), isNull);
      expect(f.isDirty, isTrue,
          reason: 'explicit-null distinguishable from pristine "hi"');
    });

    test('TomFormNDoubleInput accepts decimals and clears', () {
      final f = TomFormNDoubleInput('score', null);
      f.setValue(3.14);
      expect(f.get(), 3.14);
      f.setValue(null);
      expect(f.get(), isNull);
    });

    test('TomFormNDateInput accepts explicit DateTime and clears', () {
      final f = TomFormNDateInput(
        'birthday',
        null,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      final d = DateTime(2025, 1, 15);
      f.setValue(d);
      expect(f.get(), d);
      f.setValue(null);
      expect(f.get(), isNull);
    });
  });

  group('Phase 4 — File field validation (checkFile)', () {
    TomFormFileUpload makeFile({
      List<String>? allowedExtensions,
      int? maxSizeBytes,
    }) =>
        TomFormFileUpload(
          'doc',
          null,
          picker: (_) async => null,
          allowedExtensions: allowedExtensions,
          maxSizeBytes: maxSizeBytes,
        );

    test('null constraints accept any file', () {
      final f = makeFile();
      expect(
          f.checkFile(const FileRef(name: 'foo.bin', sizeBytes: 999)),
          isNull);
    });

    test('rejects extension mismatch with error.fileExtension', () {
      final f = makeFile(allowedExtensions: const ['pdf', 'png']);
      expect(
        f.checkFile(const FileRef(name: 'notes.txt', sizeBytes: 10)),
        'error.fileExtension',
      );
    });

    test('extension match is case-insensitive', () {
      final f = makeFile(allowedExtensions: const ['pdf']);
      expect(
        f.checkFile(const FileRef(name: 'REPORT.PDF', sizeBytes: 10)),
        isNull,
      );
    });

    test('files without an extension fail when allowedExtensions is set',
        () {
      final f = makeFile(allowedExtensions: const ['pdf']);
      expect(
        f.checkFile(const FileRef(name: 'README', sizeBytes: 10)),
        'error.fileExtension',
      );
    });

    test('rejects oversize with error.fileTooLarge', () {
      final f = makeFile(maxSizeBytes: 1024);
      expect(
        f.checkFile(const FileRef(name: 'big.bin', sizeBytes: 2048)),
        'error.fileTooLarge',
      );
    });

    test('size at the boundary is accepted', () {
      final f = makeFile(maxSizeBytes: 1024);
      expect(
        f.checkFile(const FileRef(name: 'edge.bin', sizeBytes: 1024)),
        isNull,
      );
    });

    test('extension check runs before size check', () {
      // Both fail; the extension error should surface first.
      final f =
          makeFile(allowedExtensions: const ['pdf'], maxSizeBytes: 1024);
      expect(
        f.checkFile(const FileRef(name: 'big.txt', sizeBytes: 2048)),
        'error.fileExtension',
      );
    });
  });

  group('Phase 4 — File field validation pipeline (auto-prepended validators)',
      () {
    TomFormFileUpload makeFile({
      List<String>? allowedExtensions,
      int? maxSizeBytes,
    }) =>
        TomFormFileUpload(
          'doc',
          null,
          picker: (_) async => null,
          allowedExtensions: allowedExtensions,
          maxSizeBytes: maxSizeBytes,
        );

    test('no constraints → no auto-prepended validators', () {
      final f = makeFile();
      expect(f.validators, isEmpty);
    });

    test('allowedExtensions auto-prepends one validator', () {
      final f = makeFile(allowedExtensions: const ['pdf']);
      expect(f.validators.length, 1);
    });

    test('maxSizeBytes auto-prepends one validator', () {
      final f = makeFile(maxSizeBytes: 1024);
      expect(f.validators.length, 1);
    });

    test('both constraints auto-prepend two validators', () {
      final f = makeFile(allowedExtensions: const ['pdf'], maxSizeBytes: 1024);
      expect(f.validators.length, 2);
    });

    test('user-supplied validators are appended after built-ins', () {
      ValidationResult always(FileRef? _) => const ValidationSuccess();
      final f = TomFormFileUpload(
        'doc',
        null,
        picker: (_) async => null,
        allowedExtensions: const ['pdf'],
        maxSizeBytes: 1024,
        validators: [always],
      );
      expect(f.validators.length, 3);
      expect(f.validators.last, same(always));
    });

    test('null value is pristine-pass (no error from auto-prepended validators)',
        () async {
      final f = makeFile(allowedExtensions: const ['pdf'], maxSizeBytes: 1024);
      final r = await f.validate();
      expect(r, isA<ValidationSuccess>());
    });

    test('setValue(invalid extension) → validate() yields fileExtension error',
        () async {
      final f = makeFile(allowedExtensions: const ['pdf']);
      f.setValue(const FileRef(name: 'bad.txt', sizeBytes: 1));
      final r = await f.validate();
      expect(r, isA<ValidationError>());
      expect((r as ValidationError).errorKey, 'error.fileExtension');
    });

    test('setValue(oversize) → validate() yields fileTooLarge error',
        () async {
      final f = makeFile(maxSizeBytes: 1024);
      f.setValue(const FileRef(name: 'huge.bin', sizeBytes: 2048));
      final r = await f.validate();
      expect(r, isA<ValidationError>());
      expect((r as ValidationError).errorKey, 'error.fileTooLarge');
    });

    test('setValue(valid file) → validate() yields ValidationSuccess',
        () async {
      final f = makeFile(allowedExtensions: const ['pdf'], maxSizeBytes: 1024);
      f.setValue(const FileRef(name: 'ok.pdf', sizeBytes: 512));
      final r = await f.validate();
      expect(r, isA<ValidationSuccess>());
    });

    test('extension validator runs before size validator (order preserved)',
        () async {
      // Both invalid → extension error wins because it's prepended first.
      final f = makeFile(allowedExtensions: const ['pdf'], maxSizeBytes: 1024);
      f.setValue(const FileRef(name: 'big.txt', sizeBytes: 9999));
      final r = await f.validate();
      expect(r, isA<ValidationError>());
      expect((r as ValidationError).errorKey, 'error.fileExtension');
    });

    test('TomFormFileDropzone propagates auto-prepend through super-call',
        () async {
      final f = TomFormFileDropzone(
        'doc',
        null,
        picker: (_) async => null,
        allowedExtensions: const ['pdf'],
        maxSizeBytes: 1024,
      );
      expect(f.validators.length, 2);
      f.setValue(const FileRef(name: 'big.pdf', sizeBytes: 99999));
      final r = await f.validate();
      expect(r, isA<ValidationError>());
      expect((r as ValidationError).errorKey, 'error.fileTooLarge');
    });
  });

  group('Phase 4 — FileRef value type', () {
    test('equatable + hashable on (name, size, mime)', () {
      const a = FileRef(
          name: 'a.pdf', sizeBytes: 100, mimeType: 'application/pdf');
      const b = FileRef(
          name: 'a.pdf', sizeBytes: 100, mimeType: 'application/pdf');
      const c = FileRef(
          name: 'a.pdf', sizeBytes: 200, mimeType: 'application/pdf');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('equality ignores byte payload', () {
      final a = FileRef(
          name: 'x', sizeBytes: 3, bytes: Uint8List.fromList([1, 2, 3]));
      final b = FileRef(
          name: 'x', sizeBytes: 3, bytes: Uint8List.fromList([4, 5, 6]));
      expect(a, equals(b),
          reason: 'name+size+mime define identity; bytes are payload');
    });

    test('toString includes name and size', () {
      const a = FileRef(name: 'doc.pdf', sizeBytes: 42);
      expect(a.toString(), contains('doc.pdf'));
      expect(a.toString(), contains('42'));
    });
  });
}
