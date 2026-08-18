// D4rt Bridge - Generated file, do not edit
// Sources: 3 files
// Generated: 2026-08-18T08:49:43.449552

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls, invalid_use_of_protected_member, unnecessary_non_null_assertion, invalid_use_of_visible_for_testing_member, unnecessary_cast, unused_local_variable, no_leading_underscores_for_local_identifiers, prefer_is_empty, unnecessary_question_mark, unreachable_switch_case, unintended_html_in_doc_comment, empty_constructor_bodies, prefer_const_constructors_in_immutables, prefer_final_fields, unused_field, must_call_super, no_logic_in_create_state, use_key_in_widget_constructors, annotate_overrides, non_const_argument_for_const_parameter, unnecessary_import

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';
import 'dart:io';

import 'package:htmltopdfwidgets/src/htmltagstyles.dart' as $htmltopdfwidgets_1;
import 'package:pdf/src/pdf/page_format.dart' as $pdf_1;
import 'package:pdf/src/widgets/geometry.dart' as $pdf_2;
import 'package:pdf/src/widgets/widget.dart' as $pdf_3;
import 'package:tom_md2pdf/src/md2pdf.dart' as $tom_md2pdf_1;
import 'package:tom_md2pdf/src/md_pdf_converter.dart' as $tom_md2pdf_2;
import 'package:tom_md2pdf/src/pdf_options_wrapper.dart' as $tom_md2pdf_3;

/// Bridge class for tom_md2pdf module.
class TomMd2pdfBridge {
  /// Returns all bridge class definitions.
  ///
  /// Eager — building every class. Prefer [bridgeClassThunks] +
  /// [bridgeClassTypes] for lazy registration (Step #17); this remains
  /// for diagnostics and callers that need the full list.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createMd2PdfBridge(),
      _createMdPdfConverterBridge(),
      _createMdPdfConverterOptionsBridge(),
      _createMdPdfConverterResultBridge(),
      _createPdfConvertedFileBridge(),
      _createPdfConversionErrorBridge(),
      _createPageMarginsBridge(),
      _createPdfConverterOptionsWrapperBridge(),
    ];
  }

  /// Returns deferred factory thunks keyed by class name.
  ///
  /// Each thunk builds one class's [BridgedClass] on demand. Plugs into
  /// the interpreter's lazy registry via [registerBridges] (Step #17).
  static Map<String, BridgedClass Function()> bridgeClassThunks() {
    return {
      'Md2Pdf': _createMd2PdfBridge,
      'MdPdfConverter': _createMdPdfConverterBridge,
      'MdPdfConverterOptions': _createMdPdfConverterOptionsBridge,
      'MdPdfConverterResult': _createMdPdfConverterResultBridge,
      'PdfConvertedFile': _createPdfConvertedFileBridge,
      'PdfConversionError': _createPdfConversionErrorBridge,
      'PageMargins': _createPageMarginsBridge,
      'PdfConverterOptionsWrapper': _createPdfConverterOptionsWrapperBridge,
    };
  }

  /// Returns native [Type]s keyed by class name, parallel to
  /// [bridgeClassThunks] (Step #17). Used to register the native-type
  /// lookup thunk without building the BridgedClass.
  static Map<String, Type> bridgeClassTypes() {
    return {
      'Md2Pdf': $tom_md2pdf_1.Md2Pdf,
      'MdPdfConverter': $tom_md2pdf_2.MdPdfConverter,
      'MdPdfConverterOptions': $tom_md2pdf_2.MdPdfConverterOptions,
      'MdPdfConverterResult': $tom_md2pdf_2.MdPdfConverterResult,
      'PdfConvertedFile': $tom_md2pdf_2.PdfConvertedFile,
      'PdfConversionError': $tom_md2pdf_2.PdfConversionError,
      'PageMargins': $tom_md2pdf_3.PageMargins,
      'PdfConverterOptionsWrapper': $tom_md2pdf_3.PdfConverterOptionsWrapper,
    };
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'Md2Pdf': 'package:tom_md2pdf/src/md2pdf.dart',
      'MdPdfConverter': 'package:tom_md2pdf/src/md_pdf_converter.dart',
      'MdPdfConverterOptions': 'package:tom_md2pdf/src/md_pdf_converter.dart',
      'MdPdfConverterResult': 'package:tom_md2pdf/src/md_pdf_converter.dart',
      'PdfConvertedFile': 'package:tom_md2pdf/src/md_pdf_converter.dart',
      'PdfConversionError': 'package:tom_md2pdf/src/md_pdf_converter.dart',
      'PageMargins': 'package:tom_md2pdf/src/pdf_options_wrapper.dart',
      'PdfConverterOptionsWrapper': 'package:tom_md2pdf/src/pdf_options_wrapper.dart',
    };
  }

  /// Returns a map of class names to their flattened (transitive)
  /// native supertype names (superclasses, interfaces and mixins).
  ///
  /// Fed to `BridgedClass.registerSupertypes` so interpreted subclasses
  /// of bridged classes pass `is`/subtype checks against bridged
  /// ancestors and the interface-proxy supertype walk resolves up the
  /// chain.
  static Map<String, List<String>> classSupertypes() {
    return {
    };
  }

  /// Returns a map of type alias names to their target class names.
  ///
  /// Type aliases like `typedef MaterialStateProperty<T> = WidgetStateProperty<T>`
  /// are registered so that code using the alias name can resolve to the
  /// bridged class under its canonical name.
  static Map<String, String> classAliases() {
    return {
    };
  }

  /// Returns the list of function typedef names declared in this library.
  ///
  /// Function typedefs like `typedef VoidCallback = void Function()` are
  /// registered so that they can be used as type arguments in D4rt scripts.
  static List<String> functionTypedefs() {
    return [
    ];
  }

  /// Returns all bridged enum definitions.
  static List<BridgedEnumDefinition> bridgedEnums() {
    return [
      BridgedEnumDefinition<$tom_md2pdf_3.PageFormat>(
        name: 'PageFormat',
        values: $tom_md2pdf_3.PageFormat.values,
        methods: {
          'toPdfPageFormat': (visitor, target, positional, named, typeArgs) {
            final t = target as $tom_md2pdf_3.PageFormat;
            return Function.apply(t.toPdfPageFormat, positional, named.map((k, v) => MapEntry(Symbol(k), v)));
          },
        },
        staticMethods: {
          'fromString': (visitor, positional, named, typeArgs) {
            return Function.apply($tom_md2pdf_3.PageFormat.fromString, positional, named.map((k, v) => MapEntry(Symbol(k), v)));
          },
        },
      ),
    ];
  }

  /// Returns a map of enum names to their canonical source URIs.
  ///
  /// Used for deduplication when the same enum is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> enumSourceUris() {
    return {
      'PageFormat': 'package:tom_md2pdf/src/pdf_options_wrapper.dart',
    };
  }

  /// Returns all bridged extension definitions.
  static List<BridgedExtensionDefinition> bridgedExtensions() {
    return [
    ];
  }

  /// Returns a map of extension identifiers to their canonical source URIs.
  static Map<String, String> extensionSourceUris() {
    return {
    };
  }

  /// GEN-107: Library re-exports declared by the bridged source
  /// libraries. Each tuple mirrors a Dart `export '…'` directive.
  /// Consumed by `registerBridges` via `D4rt.registerLibraryReExport`
  /// (mirrored on `D4rtRunner` in tom_d4rt_ast).
  static List<({String source, String target, Set<String>? show, Set<String>? hide})>
  bridgeReExports() {
    return [
      (source: 'package:tom_md2pdf/tom_md2pdf.dart', target: 'package:tom_md2pdf/src/md2pdf.dart', show: null, hide: null),
      (source: 'package:tom_md2pdf/tom_md2pdf.dart', target: 'package:tom_md2pdf/src/md_pdf_converter.dart', show: null, hide: null),
      (source: 'package:tom_md2pdf/tom_md2pdf.dart', target: 'package:tom_md2pdf/src/pdf_options_wrapper.dart', show: null, hide: null),
    ];
  }

  /// Registers all bridges with an interpreter.
  ///
  /// [importPath] is the package import path that D4rt scripts will use
  /// to access these classes (e.g., 'package:tom_build/tom.dart').
  static void registerBridges(D4rt interpreter, String importPath) {
    // Step #17 — register deferred factory thunks (not pre-built
    // BridgedClass objects): a script touching N of the M classes
    // materializes ≈N (each thunk builds its class on first resolve).
    final classThunks = bridgeClassThunks();
    final classTypes = bridgeClassTypes();
    final classSources = classSourceUris();
    for (final entry in classThunks.entries) {
      interpreter.registerBridgedClassLazy(
        entry.key,
        classTypes[entry.key]!,
        entry.value,
        importPath,
        sourceUri: classSources[entry.key],
      );
    }

    // Register the flattened native supertype table so
    // interpreted subclasses pass subtype checks against bridged
    // ancestors. Idempotent — safe to call per barrel.
    BridgedClass.registerSupertypes(classSupertypes());

    // Register bridged enums with source URIs for deduplication
    final enums = bridgedEnums();
    final enumSources = enumSourceUris();
    for (final enumDef in enums) {
      interpreter.registerBridgedEnum(enumDef, importPath, sourceUri: enumSources[enumDef.name]);
    }

    // GEN-107: Register library re-exports
    for (final r in bridgeReExports()) {
      interpreter.registerLibraryReExport(r.source, r.target, show: r.show, hide: r.hide);
    }
  }

  /// Returns a map of global function names to their native implementations.
  static Map<String, NativeFunctionImpl> globalFunctions() {
    return {};
  }

  /// Returns a map of global function names to their canonical source URIs.
  static Map<String, String> globalFunctionSourceUris() {
    return {};
  }

  /// Returns a map of global function names to their display signatures.
  static Map<String, String> globalFunctionSignatures() {
    return {};
  }

  /// Returns the list of canonical source library URIs.
  ///
  /// These are the actual source locations of all elements in this bridge,
  /// used for deduplication when the same libraries are exported through
  /// multiple barrels.
  static List<String> sourceLibraries() {
    return [
      'package:tom_md2pdf/src/md2pdf.dart',
      'package:tom_md2pdf/src/md_pdf_converter.dart',
      'package:tom_md2pdf/src/pdf_options_wrapper.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    return "import 'package:tom_md2pdf/tom_md2pdf.dart';";
  }

  /// Returns barrel import URIs for sub-packages discovered through re-exports.
  ///
  /// When a module follows re-exports into sub-packages (e.g., dcli re-exports
  /// dcli_core), D4rt scripts may import those sub-packages directly.
  /// These barrels need to be registered with the interpreter separately
  /// so that module resolution finds content for those URIs.
  static List<String> subPackageBarrels() {
    return [];
  }

  /// Returns a list of bridged enum names.
  static List<String> get enumNames => [
    'PageFormat',
  ];

}

// =============================================================================
// Md2Pdf Bridge
// =============================================================================

BridgedClass _createMd2PdfBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_1.Md2Pdf,
    name: 'Md2Pdf',
    isAssignable: (v) => v is $tom_md2pdf_1.Md2Pdf,
    constructors: {
    },
    staticMethods: {
      'convertString': (visitor, positional, named, typeArgs) {
        final markdown = D4.getRequiredNamedArg<String>(named, 'markdown', 'convertString');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final pageFormat = D4.getNamedArgWithDefault<String>(named, 'pageFormat', 'a4');
        final fontSize = D4.getNamedArgWithDefault<double>(named, 'fontSize', 12.0);
        final fontFamily = D4.getNamedArgWithDefault<String>(named, 'fontFamily', 'Roboto');
        final margins = D4.getNamedArgWithDefault<$tom_md2pdf_3.PageMargins>(named, 'margins', const $tom_md2pdf_3.PageMargins.all(72));
        return $tom_md2pdf_1.Md2Pdf.convertString(markdown: markdown, title: title, author: author, pageFormat: pageFormat, fontSize: fontSize, fontFamily: fontFamily, margins: margins);
      },
      'convertFile': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFile');
        final outputPath = D4.getOptionalNamedArg<String?>(named, 'outputPath');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final pageFormat = D4.getNamedArgWithDefault<String>(named, 'pageFormat', 'a4');
        final fontSize = D4.getNamedArgWithDefault<double>(named, 'fontSize', 12.0);
        final fontFamily = D4.getNamedArgWithDefault<String>(named, 'fontFamily', 'Roboto');
        final margins = D4.getNamedArgWithDefault<$tom_md2pdf_3.PageMargins>(named, 'margins', const $tom_md2pdf_3.PageMargins.all(72));
        return $tom_md2pdf_1.Md2Pdf.convertFile(inputPath: inputPath, outputPath: outputPath, title: title, author: author, pageFormat: pageFormat, fontSize: fontSize, fontFamily: fontFamily, margins: margins);
      },
      'convertFileToBytes': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFileToBytes');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final pageFormat = D4.getNamedArgWithDefault<String>(named, 'pageFormat', 'a4');
        final fontSize = D4.getNamedArgWithDefault<double>(named, 'fontSize', 12.0);
        final fontFamily = D4.getNamedArgWithDefault<String>(named, 'fontFamily', 'Roboto');
        final margins = D4.getNamedArgWithDefault<$tom_md2pdf_3.PageMargins>(named, 'margins', const $tom_md2pdf_3.PageMargins.all(72));
        return $tom_md2pdf_1.Md2Pdf.convertFileToBytes(inputPath: inputPath, title: title, author: author, pageFormat: pageFormat, fontSize: fontSize, fontFamily: fontFamily, margins: margins);
      },
      'convertDirectory': (visitor, positional, named, typeArgs) {
        final inputDir = D4.getRequiredNamedArg<String>(named, 'inputDir', 'convertDirectory');
        final outputDir = D4.getOptionalNamedArg<String?>(named, 'outputDir');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final pageFormat = D4.getNamedArgWithDefault<String>(named, 'pageFormat', 'a4');
        final fontSize = D4.getNamedArgWithDefault<double>(named, 'fontSize', 12.0);
        final fontFamily = D4.getNamedArgWithDefault<String>(named, 'fontFamily', 'Roboto');
        final margins = D4.getNamedArgWithDefault<$tom_md2pdf_3.PageMargins>(named, 'margins', const $tom_md2pdf_3.PageMargins.all(72));
        final excludePatterns = named.containsKey('excludePatterns') && named['excludePatterns'] != null
            ? D4.coerceList<String>(named['excludePatterns'], 'excludePatterns')
            : const ['node_modules', '.git', 'build'];
        return $tom_md2pdf_1.Md2Pdf.convertDirectory(inputDir: inputDir, outputDir: outputDir, title: title, author: author, pageFormat: pageFormat, fontSize: fontSize, fontFamily: fontFamily, margins: margins, excludePatterns: excludePatterns);
      },
      'convertFileAndSave': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFileAndSave');
        final outputPath = D4.getRequiredNamedArg<String>(named, 'outputPath', 'convertFileAndSave');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final pageFormat = D4.getNamedArgWithDefault<String>(named, 'pageFormat', 'a4');
        final fontSize = D4.getNamedArgWithDefault<double>(named, 'fontSize', 12.0);
        final fontFamily = D4.getNamedArgWithDefault<String>(named, 'fontFamily', 'Roboto');
        final margins = D4.getNamedArgWithDefault<$tom_md2pdf_3.PageMargins>(named, 'margins', const $tom_md2pdf_3.PageMargins.all(72));
        return $tom_md2pdf_1.Md2Pdf.convertFileAndSave(inputPath: inputPath, outputPath: outputPath, title: title, author: author, pageFormat: pageFormat, fontSize: fontSize, fontFamily: fontFamily, margins: margins);
      },
    },
    staticMethodSignatures: {
      'convertString': 'Future<List<int>> convertString({required String markdown, String? title, String? author, String pageFormat = \'a4\', double fontSize = 12.0, String fontFamily = \'Roboto\', PageMargins margins = const PageMargins.all(72)})',
      'convertFile': 'Future<PdfConvertedFile> convertFile({required String inputPath, String? outputPath, String? title, String? author, String pageFormat = \'a4\', double fontSize = 12.0, String fontFamily = \'Roboto\', PageMargins margins = const PageMargins.all(72)})',
      'convertFileToBytes': 'Future<List<int>> convertFileToBytes({required String inputPath, String? title, String? author, String pageFormat = \'a4\', double fontSize = 12.0, String fontFamily = \'Roboto\', PageMargins margins = const PageMargins.all(72)})',
      'convertDirectory': 'Future<MdPdfConverterResult> convertDirectory({required String inputDir, String? outputDir, String? title, String? author, String pageFormat = \'a4\', double fontSize = 12.0, String fontFamily = \'Roboto\', PageMargins margins = const PageMargins.all(72), List<String> excludePatterns = const [\'node_modules\', \'.git\', \'build\']})',
      'convertFileAndSave': 'Future<bool> convertFileAndSave({required String inputPath, required String outputPath, String? title, String? author, String pageFormat = \'a4\', double fontSize = 12.0, String fontFamily = \'Roboto\', PageMargins margins = const PageMargins.all(72)})',
    },
  );
}

// =============================================================================
// MdPdfConverter Bridge
// =============================================================================

BridgedClass _createMdPdfConverterBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_2.MdPdfConverter,
    name: 'MdPdfConverter',
    isAssignable: (v) => v is $tom_md2pdf_2.MdPdfConverter,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'MdPdfConverter');
        final sourcePath = D4.getRequiredArg<String>(positional, 0, 'sourcePath', 'MdPdfConverter');
        final options = D4.getOptionalNamedArg<$tom_md2pdf_2.MdPdfConverterOptions?>(named, 'options');
        return $tom_md2pdf_2.MdPdfConverter(sourcePath, options: options);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverter>(target, 'MdPdfConverter').sourcePath,
      'options': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverter>(target, 'MdPdfConverter').options,
    },
    methods: {
      'findMarkdownFiles': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2pdf_2.MdPdfConverter>(target, 'MdPdfConverter');
        return t.findMarkdownFiles();
      },
      'convertAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2pdf_2.MdPdfConverter>(target, 'MdPdfConverter');
        final outputDir = D4.getOptionalNamedArg<String?>(named, 'outputDir');
        return t.convertAll(outputDir: outputDir);
      },
      'convertFile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2pdf_2.MdPdfConverter>(target, 'MdPdfConverter');
        D4.requireMinArgs(positional, 1, 'convertFile');
        final file = D4.getRequiredArg<File>(positional, 0, 'file', 'convertFile');
        final outputDir = D4.getOptionalNamedArg<String?>(named, 'outputDir');
        return t.convertFile(file, outputDir: outputDir);
      },
      'convertString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2pdf_2.MdPdfConverter>(target, 'MdPdfConverter');
        D4.requireMinArgs(positional, 1, 'convertString');
        final markdown = D4.getRequiredArg<String>(positional, 0, 'markdown', 'convertString');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        return t.convertString(markdown, title: title);
      },
    },
    constructorSignatures: {
      '': 'MdPdfConverter(String sourcePath, {MdPdfConverterOptions? options})',
    },
    methodSignatures: {
      'findMarkdownFiles': 'Future<List<File>> findMarkdownFiles()',
      'convertAll': 'Future<MdPdfConverterResult> convertAll({String? outputDir})',
      'convertFile': 'Future<PdfConvertedFile> convertFile(File file, {String? outputDir})',
      'convertString': 'Future<List<int>> convertString(String markdown, {String? title})',
    },
    getterSignatures: {
      'sourcePath': 'String get sourcePath',
      'options': 'MdPdfConverterOptions get options',
    },
  );
}

// =============================================================================
// MdPdfConverterOptions Bridge
// =============================================================================

BridgedClass _createMdPdfConverterOptionsBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_2.MdPdfConverterOptions,
    name: 'MdPdfConverterOptions',
    isAssignable: (v) => v is $tom_md2pdf_2.MdPdfConverterOptions,
    constructors: {
      '': (visitor, positional, named) {
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final pageFormat = D4.getNamedArgWithDefault<$pdf_1.PdfPageFormat>(named, 'pageFormat', $pdf_1.PdfPageFormat.a4);
        final fontSize = D4.getNamedArgWithDefault<double>(named, 'fontSize', 12.0);
        final fontFamily = D4.getNamedArgWithDefault<String>(named, 'fontFamily', 'Roboto');
        final tagStyle = D4.getNamedArgWithDefault<$htmltopdfwidgets_1.HtmlTagStyle>(named, 'tagStyle', const $htmltopdfwidgets_1.HtmlTagStyle());
        final excludePatterns = named.containsKey('excludePatterns') && named['excludePatterns'] != null
            ? D4.coerceList<String>(named['excludePatterns'], 'excludePatterns')
            : const ['node_modules', '.git', 'build'];
        final headerBuilderRaw = named['headerBuilder'];
        final footerBuilderRaw = named['footerBuilder'];
        if (!named.containsKey('margin')) {
          return $tom_md2pdf_2.MdPdfConverterOptions(title: title, author: author, pageFormat: pageFormat, fontSize: fontSize, fontFamily: fontFamily, tagStyle: tagStyle, excludePatterns: excludePatterns, headerBuilder: headerBuilderRaw == null ? null : (($pdf_3.Context p0) { return D4.extractBridgedArg<$pdf_3.Widget>(D4.callInterpreterCallback(visitor!, headerBuilderRaw, [p0]), 'callback', visitor) as $pdf_3.Widget; }) as $pdf_3.Widget Function($pdf_3.Context), footerBuilder: footerBuilderRaw == null ? null : (($pdf_3.Context p0) { return D4.extractBridgedArg<$pdf_3.Widget>(D4.callInterpreterCallback(visitor!, footerBuilderRaw, [p0]), 'callback', visitor) as $pdf_3.Widget; }) as $pdf_3.Widget Function($pdf_3.Context));
        }
        if (named.containsKey('margin')) {
          final margin = D4.getRequiredNamedArg<$pdf_2.EdgeInsets>(named, 'margin', 'MdPdfConverterOptions');
          return $tom_md2pdf_2.MdPdfConverterOptions(title: title, author: author, pageFormat: pageFormat, fontSize: fontSize, fontFamily: fontFamily, tagStyle: tagStyle, excludePatterns: excludePatterns, headerBuilder: headerBuilderRaw == null ? null : (($pdf_3.Context p0) { return D4.extractBridgedArg<$pdf_3.Widget>(D4.callInterpreterCallback(visitor!, headerBuilderRaw, [p0]), 'callback', visitor) as $pdf_3.Widget; }) as $pdf_3.Widget Function($pdf_3.Context), footerBuilder: footerBuilderRaw == null ? null : (($pdf_3.Context p0) { return D4.extractBridgedArg<$pdf_3.Widget>(D4.callInterpreterCallback(visitor!, footerBuilderRaw, [p0]), 'callback', visitor) as $pdf_3.Widget; }) as $pdf_3.Widget Function($pdf_3.Context), margin: margin);
        }
        throw StateError('Unreachable: all named parameter combinations should be covered');
      },
    },
    getters: {
      'title': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').title,
      'author': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').author,
      'pageFormat': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').pageFormat,
      'margin': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').margin,
      'fontSize': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').fontSize,
      'fontFamily': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').fontFamily,
      'tagStyle': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').tagStyle,
      'excludePatterns': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').excludePatterns,
      'headerBuilder': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').headerBuilder,
      'footerBuilder': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterOptions>(target, 'MdPdfConverterOptions').footerBuilder,
    },
    constructorSignatures: {
      '': 'MdPdfConverterOptions({String? title, String? author, PdfPageFormat pageFormat = PdfPageFormat.a4, EdgeInsets margin = const pw.EdgeInsets.all(72), double fontSize = 12.0, String fontFamily = \'Roboto\', HtmlTagStyle tagStyle = const HtmlTagStyle(), List<String> excludePatterns = const [\'node_modules\', \'.git\', \'build\'], Widget Function(Context)? headerBuilder, Widget Function(Context)? footerBuilder})',
    },
    getterSignatures: {
      'title': 'String? get title',
      'author': 'String? get author',
      'pageFormat': 'PdfPageFormat get pageFormat',
      'margin': 'EdgeInsets get margin',
      'fontSize': 'double get fontSize',
      'fontFamily': 'String get fontFamily',
      'tagStyle': 'HtmlTagStyle get tagStyle',
      'excludePatterns': 'List<String> get excludePatterns',
      'headerBuilder': 'Widget Function(Context)? get headerBuilder',
      'footerBuilder': 'Widget Function(Context)? get footerBuilder',
    },
  );
}

// =============================================================================
// MdPdfConverterResult Bridge
// =============================================================================

BridgedClass _createMdPdfConverterResultBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_2.MdPdfConverterResult,
    name: 'MdPdfConverterResult',
    isAssignable: (v) => v is $tom_md2pdf_2.MdPdfConverterResult,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_md2pdf_2.MdPdfConverterResult();
      },
    },
    getters: {
      'converted': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterResult>(target, 'MdPdfConverterResult').converted,
      'errors': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterResult>(target, 'MdPdfConverterResult').errors,
      'isSuccess': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.MdPdfConverterResult>(target, 'MdPdfConverterResult').isSuccess,
    },
    constructorSignatures: {
      '': 'MdPdfConverterResult()',
    },
    getterSignatures: {
      'converted': 'List<PdfConvertedFile> get converted',
      'errors': 'List<PdfConversionError> get errors',
      'isSuccess': 'bool get isSuccess',
    },
  );
}

// =============================================================================
// PdfConvertedFile Bridge
// =============================================================================

BridgedClass _createPdfConvertedFileBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_2.PdfConvertedFile,
    name: 'PdfConvertedFile',
    isAssignable: (v) => v is $tom_md2pdf_2.PdfConvertedFile,
    constructors: {
      '': (visitor, positional, named) {
        final sourcePath = D4.getRequiredNamedArg<String>(named, 'sourcePath', 'PdfConvertedFile');
        final outputPath = D4.getRequiredNamedArg<String>(named, 'outputPath', 'PdfConvertedFile');
        return $tom_md2pdf_2.PdfConvertedFile(sourcePath: sourcePath, outputPath: outputPath);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.PdfConvertedFile>(target, 'PdfConvertedFile').sourcePath,
      'outputPath': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.PdfConvertedFile>(target, 'PdfConvertedFile').outputPath,
    },
    constructorSignatures: {
      '': 'PdfConvertedFile({required String sourcePath, required String outputPath})',
    },
    getterSignatures: {
      'sourcePath': 'String get sourcePath',
      'outputPath': 'String get outputPath',
    },
  );
}

// =============================================================================
// PdfConversionError Bridge
// =============================================================================

BridgedClass _createPdfConversionErrorBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_2.PdfConversionError,
    name: 'PdfConversionError',
    isAssignable: (v) => v is $tom_md2pdf_2.PdfConversionError,
    constructors: {
      '': (visitor, positional, named) {
        final sourcePath = D4.getRequiredNamedArg<String>(named, 'sourcePath', 'PdfConversionError');
        final message = D4.getRequiredNamedArg<String>(named, 'message', 'PdfConversionError');
        final stackTrace = D4.getOptionalNamedArg<StackTrace?>(named, 'stackTrace');
        return $tom_md2pdf_2.PdfConversionError(sourcePath: sourcePath, message: message, stackTrace: stackTrace);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.PdfConversionError>(target, 'PdfConversionError').sourcePath,
      'message': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.PdfConversionError>(target, 'PdfConversionError').message,
      'stackTrace': (visitor, target) => D4.validateTarget<$tom_md2pdf_2.PdfConversionError>(target, 'PdfConversionError').stackTrace,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2pdf_2.PdfConversionError>(target, 'PdfConversionError');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'PdfConversionError({required String sourcePath, required String message, StackTrace? stackTrace})',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'sourcePath': 'String get sourcePath',
      'message': 'String get message',
      'stackTrace': 'StackTrace? get stackTrace',
    },
  );
}

// =============================================================================
// PageMargins Bridge
// =============================================================================

BridgedClass _createPageMarginsBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_3.PageMargins,
    name: 'PageMargins',
    isAssignable: (v) => v is $tom_md2pdf_3.PageMargins,
    constructors: {
      '': (visitor, positional, named) {
        final top = D4.getNamedArgWithDefault<double>(named, 'top', 72.0);
        final right = D4.getNamedArgWithDefault<double>(named, 'right', 72.0);
        final bottom = D4.getNamedArgWithDefault<double>(named, 'bottom', 72.0);
        final left = D4.getNamedArgWithDefault<double>(named, 'left', 72.0);
        return $tom_md2pdf_3.PageMargins(top: top, right: right, bottom: bottom, left: left);
      },
      'all': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'PageMargins');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'PageMargins');
        return $tom_md2pdf_3.PageMargins.all(value);
      },
      'symmetric': (visitor, positional, named) {
        final horizontal = D4.getNamedArgWithDefault<double>(named, 'horizontal', 72.0);
        final vertical = D4.getNamedArgWithDefault<double>(named, 'vertical', 72.0);
        return $tom_md2pdf_3.PageMargins.symmetric(horizontal: horizontal, vertical: vertical);
      },
    },
    getters: {
      'top': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PageMargins>(target, 'PageMargins').top,
      'right': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PageMargins>(target, 'PageMargins').right,
      'bottom': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PageMargins>(target, 'PageMargins').bottom,
      'left': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PageMargins>(target, 'PageMargins').left,
    },
    methods: {
      'toEdgeInsets': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2pdf_3.PageMargins>(target, 'PageMargins');
        return t.toEdgeInsets();
      },
    },
    constructorSignatures: {
      '': 'const PageMargins({double top = 72.0, double right = 72.0, double bottom = 72.0, double left = 72.0})',
      'all': 'const PageMargins.all(double value)',
      'symmetric': 'const PageMargins.symmetric({double horizontal = 72.0, double vertical = 72.0})',
    },
    methodSignatures: {
      'toEdgeInsets': 'EdgeInsets toEdgeInsets()',
    },
    getterSignatures: {
      'top': 'double get top',
      'right': 'double get right',
      'bottom': 'double get bottom',
      'left': 'double get left',
    },
  );
}

// =============================================================================
// PdfConverterOptionsWrapper Bridge
// =============================================================================

BridgedClass _createPdfConverterOptionsWrapperBridge() {
  return BridgedClass(
    nativeType: $tom_md2pdf_3.PdfConverterOptionsWrapper,
    name: 'PdfConverterOptionsWrapper',
    isAssignable: (v) => v is $tom_md2pdf_3.PdfConverterOptionsWrapper,
    constructors: {
      '': (visitor, positional, named) {
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final pageFormat = D4.getNamedArgWithDefault<String>(named, 'pageFormat', 'a4');
        final margins = D4.getNamedArgWithDefault<$tom_md2pdf_3.PageMargins>(named, 'margins', const $tom_md2pdf_3.PageMargins.all(72));
        final fontSize = D4.getNamedArgWithDefault<double>(named, 'fontSize', 12.0);
        final fontFamily = D4.getNamedArgWithDefault<String>(named, 'fontFamily', 'Roboto');
        final excludePatterns = named.containsKey('excludePatterns') && named['excludePatterns'] != null
            ? D4.coerceList<String>(named['excludePatterns'], 'excludePatterns')
            : const ['node_modules', '.git', 'build'];
        return $tom_md2pdf_3.PdfConverterOptionsWrapper(title: title, author: author, pageFormat: pageFormat, margins: margins, fontSize: fontSize, fontFamily: fontFamily, excludePatterns: excludePatterns);
      },
    },
    getters: {
      'title': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper').title,
      'author': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper').author,
      'pageFormat': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper').pageFormat,
      'margins': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper').margins,
      'fontSize': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper').fontSize,
      'fontFamily': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper').fontFamily,
      'excludePatterns': (visitor, target) => D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper').excludePatterns,
    },
    methods: {
      'toOptions': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2pdf_3.PdfConverterOptionsWrapper>(target, 'PdfConverterOptionsWrapper');
        return t.toOptions();
      },
    },
    constructorSignatures: {
      '': 'PdfConverterOptionsWrapper({String? title, String? author, String pageFormat = \'a4\', PageMargins margins = const PageMargins.all(72), double fontSize = 12.0, String fontFamily = \'Roboto\', List<String> excludePatterns = const [\'node_modules\', \'.git\', \'build\']})',
    },
    methodSignatures: {
      'toOptions': 'MdPdfConverterOptions toOptions()',
    },
    getterSignatures: {
      'title': 'String? get title',
      'author': 'String? get author',
      'pageFormat': 'String get pageFormat',
      'margins': 'PageMargins get margins',
      'fontSize': 'double get fontSize',
      'fontFamily': 'String get fontFamily',
      'excludePatterns': 'List<String> get excludePatterns',
    },
  );
}

