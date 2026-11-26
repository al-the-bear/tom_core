// The worked example of the workspace guideline `_agent_guidelines/i18n.md`
// section 10, held to the guideline: the fixture `test/fixtures/rename_demo` is a
// verbatim copy of its resource file, its component and the assembled file
// of an application mounting it under `files` and `workbench.explorer`.
// (The example's widget test needs Flutter; this pure-Dart package checks
// what the helpers make of it: the mounts, the assembled file, the paths a
// widget constructed in each scope reads, and the coverage check.)
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

const _root = 'test/fixtures/rename_demo';

String _read(String id) {
  final scope = TomScope.current.getScopePath();
  return TomTextResourceProvider.getAppResources().getText(
    scope.isEmpty ? id : '$scope.$id',
  );
}

void main() {
  tearDown(clearTexts);

  test('the fixture is the guideline\'s example, verbatim', () {
    final guideline = File('../../../_agent_guidelines/i18n.md');
    if (!guideline.existsSync()) {
      markTestSkipped('the workspace guideline is not beside this checkout');
      return;
    }
    final text = guideline.readAsStringSync();
    final example = text.substring(
      text.indexOf('## 10 Worked example'),
      text.indexOf('## 11 '),
    );
    final blocks = RegExp(
      r'```\w+\n(.*?)```',
      dotAll: true,
    ).allMatches(example).map((m) => m.group(1)).toList();
    expect(
      File('$_root/lib/resources/rename_demo_en.json').readAsStringSync(),
      blocks[0],
    );
    expect(
      File('$_root/lib/src/rename_dialog.dart').readAsStringSync(),
      blocks[1],
    );
    expect(File('$_root/assembled_en.json').readAsStringSync(), blocks[3]);
  });

  test('the two mounts are the assembled file of section 10', () {
    final texts = PackageTexts.load('rename_demo', packageRoot: _root);
    expect(
      mergeTexts([
        texts.mountedAt('files'),
        texts.mountedAt('workbench.explorer'),
      ]),
      jsonDecode(File('$_root/assembled_en.json').readAsStringSync()),
    );
  });

  test('a widget constructed in each scope reads its texts', () {
    final texts = PackageTexts.load('rename_demo', packageRoot: _root);
    texts.install();
    expect(texts.run(() => _read('rename.renameDialog.title')), 'Rename file');
    texts.installAt(['files', 'workbench.explorer']);
    expect(
      runInScopePath('files', () => _read('rename.nameField.hint')),
      'e.g. notes.txt',
    );
    expect(
      runInScopePath(
        'workbench.explorer',
        () => _read('rename.nameField.error.taken'),
      ),
      '"{name}" exists already.',
    );
  });

  test('a missing text shows its path', () {
    installTexts(const {});
    expect(
      runInScopePath('rename_demo', () => _read('rename.nameText.label')),
      'rename_demo.rename.nameText.label',
    );
  });

  test('its code and file pass the coverage check', () {
    expectTextCoverage('rename_demo', packageRoot: _root);
  });
}
