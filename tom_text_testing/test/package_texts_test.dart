import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

const _root = 'test/fixtures/rename_demo';

String _text(String id) => TomTextResourceProvider.getAppResources().getText(
  runInScopePath(TomScope.current.getScopePath(), () => id),
);

/// The text of [id] resolved under the current scope, as a widget would.
String _scoped(String id) {
  final path = TomScope.current.getScopePath();
  return _text(path.isEmpty ? id : '$path.$id');
}

void main() {
  tearDown(clearTexts);

  group('PackageTexts', () {
    test('loads the block under the package name', () {
      final texts = PackageTexts.load('rename_demo', packageRoot: _root);
      expect(texts.block.keys, ['rename']);
      expect(texts.language, 'en');
    });

    test('refuses a missing file and a wrong top level', () {
      expect(
        () => PackageTexts.load('nope', packageRoot: _root),
        throwsA(isA<TextResourceFileException>()),
      );
      final dir = Directory.systemTemp.createTempSync('tom_text_testing_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/lib/resources/other_en.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"something": {}}');
      expect(
        () => PackageTexts.load('other', packageRoot: dir.path),
        throwsA(
          isA<TextResourceFileException>().having(
            (e) => e.message,
            'message',
            contains('"other"'),
          ),
        ),
      );
    });

    test('mounts the block under a scope, a nested one deeper', () {
      final texts = PackageTexts.load('rename_demo', packageRoot: _root);
      expect(texts.mountedAt().keys, ['rename_demo']);
      expect(texts.mountedAt('files')['files'], same(texts.block));
      expect((texts.mountedAt('a.b')['a'] as Map)['b'], same(texts.block));
      expect(mountTexts(texts.block, ''), same(texts.block));
    });

    test('installs under the package scope and runs a body in it', () {
      final texts = PackageTexts.load('rename_demo', packageRoot: _root)
        ..install();
      texts.run(() {
        expect(TomScope.current.getScopePath(), 'rename_demo');
        expect(_scoped('rename.renameDialog.title'), 'Rename file');
      });
    });

    test('installs under several scopes at once', () {
      PackageTexts.load(
        'rename_demo',
        packageRoot: _root,
      ).installAt(['files', 'workbench.explorer']);
      for (final scope in ['files', 'workbench.explorer']) {
        runInScopePath(scope, () {
          expect(TomScope.current.getScopePath(), scope);
          expect(_scoped('rename.cancelButton.label'), 'Cancel');
        });
      }
      expect(_text('rename_demo.rename.cancelButton.label'), isNot('Cancel'));
    });
  });

  group('mergeTexts', () {
    test('merges deeply', () {
      expect(
        mergeTexts([
          {
            'a': {'x': '1'},
          },
          {
            'a': {'y': '2'},
            'b': '3',
          },
        ]),
        {
          'a': {'x': '1', 'y': '2'},
          'b': '3',
        },
      );
    });

    test('refuses an entry both maps hold', () {
      expect(
        () => mergeTexts([
          {
            'a': {'x': '1'},
          },
          {
            'a': {'x': '2'},
          },
        ]),
        throwsA(isA<TextMergeConflict>().having((e) => e.path, 'path', 'a.x')),
      );
      expect(
        () => mergeTexts([
          {'a': '1'},
          {
            'a': {'x': '2'},
          },
        ]),
        throwsA(isA<TextMergeConflict>()),
      );
    });
  });

  group('withPackageTexts', () {
    bool installed() {
      try {
        TomTextResourceProvider.getAppResources();
        return true;
      } on TomResourceException {
        return false;
      }
    }

    test('runs the body in the scope and clears afterwards', () {
      final title = withPackageTexts(
        'rename_demo',
        () => _scoped('rename.renameDialog.title'),
        packageRoot: _root,
        scopePath: 'a.b',
      );
      expect(title, 'Rename file');
      expect(installed(), isFalse);
    });

    test('clears when an asynchronous body completes', () async {
      final title = await withPackageTexts('rename_demo', () async {
        await Future<void>.delayed(Duration.zero);
        expect(installed(), isTrue);
        return _scoped('rename.nameField.hint');
      }, packageRoot: _root);
      expect(title, 'e.g. notes.txt');
      expect(installed(), isFalse);
    });

    test('clears when the body throws', () {
      expect(
        () => withPackageTexts(
          'rename_demo',
          () => throw StateError('x'),
          packageRoot: _root,
        ),
        throwsStateError,
      );
      expect(installed(), isFalse);
    });
  });
}
