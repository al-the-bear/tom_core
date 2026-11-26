/// Test support for the internationalisation guideline of the Tom workspace
/// (`_agent_guidelines/i18n.md`): a package's texts loaded from
/// `lib/resources/<package-name>_<language>.json`, installed as Tom Core's
/// text resources under the package's scope or any scope an application
/// mounts it under ([PackageTexts], [withPackageTexts]), and the coverage
/// check that holds the resource files and the code to each other
/// ([checkTextCoverage], [expectTextCoverage]).
///
/// Pure Dart on `tom_core_kernel`: Flutter and pure-Dart packages take it as
/// a dev dependency alike.
library;

export 'src/dart_source.dart' show DartSource, DartStringLiteral;
export 'src/element_kinds.dart' show TextElementKind, TextElementKinds;
export 'src/package_texts.dart'
    show
        PackageTexts,
        TextMergeConflict,
        TextResourceFileException,
        clearTexts,
        installTexts,
        mergeTexts,
        mountTexts,
        runInScopePath,
        textResourcePath,
        withPackageTexts;
export 'src/text_coverage.dart'
    show
        AllowedLiteral,
        TextCoverageFailure,
        TextCoverageFinding,
        TextCoverageKind,
        TextCoverageReport,
        TextIdCarrier,
        checkTextCoverage,
        defaultNonUserCalls,
        expectTextCoverage;
