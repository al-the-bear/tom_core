import 'package:test/test.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

const _msg = TextIdCarrier.call(
  r'\bMsg',
  includesKey: true,
  paramsArgument: 'params',
);

TextCoverageReport _broken() => checkTextCoverage(
  'broken_demo',
  packageRoot: 'test/fixtures/broken_demo',
  carriers: const [_msg],
  allowedLiterals: const [
    AllowedLiteral(
      file: 'lib/broken.dart',
      text: 'Allowed words',
      reason: 'a fixture of an allowed literal',
    ),
    AllowedLiteral(
      file: 'lib/broken.dart',
      text: 'Gone text',
      reason: 'a fixture of an allowance nothing matches',
    ),
  ],
);

void main() {
  test('the worked example of the guideline is clean', () {
    final report = checkTextCoverage(
      'rename_demo',
      packageRoot: 'test/fixtures/rename_demo',
    );
    expect(report.findings, isEmpty, reason: '$report');
    expect(
      () => expectTextCoverage(
        'rename_demo',
        packageRoot: 'test/fixtures/rename_demo',
      ),
      returnsNormally,
    );
  });

  group('a package breaking every rule', () {
    late TextCoverageReport report;
    setUpAll(() => report = _broken());

    List<String> idsOf(TextCoverageKind kind) => [
      for (final f in report.ofKind(kind))
        '${f.id}${f.key == null ? '' : '/${f.key}'}',
    ];

    test('(1) an id the code uses that the file lacks', () {
      expect(idsOf(TextCoverageKind.missingId), [
        'files.missingText',
        'broken_demo.files.openButton',
      ]);
      final finding = report.ofKind(TextCoverageKind.missingId).first;
      expect(finding.file, 'lib/broken.dart');
      expect(finding.line, 13);
      expect(idsOf(TextCoverageKind.missingKey), ['save.failedMessage/title']);
    });

    test('(2) an element no code uses', () {
      expect(idsOf(TextCoverageKind.unusedEntry), ['files.orphanButton']);
      expect(
        report.ofKind(TextCoverageKind.unusedEntry).single.file,
        'lib/resources/broken_demo_en.json',
      );
    });

    test('(3) suffixes, allowed and required keys', () {
      expect(idsOf(TextCoverageKind.noSuffix), ['files.caption']);
      expect(idsOf(TextCoverageKind.disallowedKey), [
        'files.nameField/color',
        'files.dottedButton/x.y',
      ]);
      expect(idsOf(TextCoverageKind.missingRequiredKey), [
        'files.titleText/label',
        'files.nullButton/label',
        'files.listButton/label',
      ]);
    });

    test('(4) parameters against placeholders', () {
      final finding = report.ofKind(TextCoverageKind.placeholders).single;
      expect(finding.id, 'save.failedMessage');
      expect(finding.key, 'text');
      expect(finding.message, contains('{reason}'));
    });

    test('(5) user-visible literals, with the allow-list', () {
      expect(
        [
          for (final f in report.ofKind(TextCoverageKind.literal))
            f.message.split('"')[1],
        ],
        ['Hello world', 'Yes'],
        reason:
            'debugPrint and StateError texts, ids, keys, comments and the '
            'allowed literal are not reported',
      );
      expect(
        report.ofKind(TextCoverageKind.unusedAllowance).single.message,
        contains('Gone text'),
      );
    });

    test('(6) another language differs', () {
      final findings = report.ofKind(TextCoverageKind.language);
      expect(
        [
          for (final f in findings)
            if (f.file == 'lib/resources/broken_demo_de.json') f.id,
        ],
        ['save.failedMessage.text', 'files.extraButton.label'],
        reason: 'the extra plural form "few" is allowed',
      );
    });

    test('the shape of the file', () {
      expect(
        [
          for (final f in report.ofKind(TextCoverageKind.shape))
            if (f.file.endsWith('_en.json')) f.id,
        ],
        [
          'files.dottedButton.x.y',
          'files.nullButton.label',
          'files.listButton.label',
        ],
      );
    });

    test('ids that cannot be checked or name the package', () {
      expect(
        report.ofKind(TextCoverageKind.nonLiteralId).single.id,
        r'files.${}',
      );
      expect(idsOf(TextCoverageKind.packageName), [
        'broken_demo.files.openButton',
      ]);
    });

    test('expectTextCoverage fails naming id, key and file', () {
      expect(
        () => expectTextCoverage(
          'broken_demo',
          packageRoot: 'test/fixtures/broken_demo',
          carriers: const [_msg],
        ),
        throwsA(
          isA<TextCoverageFailure>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('lib/broken.dart:13 files.missingText'),
              contains('files.nameField / color'),
              contains('lib/resources/broken_demo_en.json'),
            ),
          ),
        ),
      );
    });

    test('literals can be left unchecked for a package not migrated yet', () {
      final unchecked = checkTextCoverage(
        'broken_demo',
        packageRoot: 'test/fixtures/broken_demo',
        carriers: const [_msg],
        checkLiterals: false,
      );
      expect(unchecked.ofKind(TextCoverageKind.literal), isEmpty);
      expect(unchecked.ofKind(TextCoverageKind.unusedAllowance), isEmpty);
    });
  });
}
