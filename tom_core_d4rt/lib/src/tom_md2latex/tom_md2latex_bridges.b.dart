// D4rt Bridge - Generated file, do not edit
// Sources: 4 files
// Generated: 2026-08-19T16:19:01.161224

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls, invalid_use_of_protected_member, unnecessary_non_null_assertion, invalid_use_of_visible_for_testing_member, unnecessary_cast, unused_local_variable, no_leading_underscores_for_local_identifiers, prefer_is_empty, unnecessary_question_mark, unreachable_switch_case, unintended_html_in_doc_comment, empty_constructor_bodies, prefer_const_constructors_in_immutables, prefer_final_fields, unused_field, must_call_super, no_logic_in_create_state, use_key_in_widget_constructors, annotate_overrides, non_const_argument_for_const_parameter, unnecessary_import

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';
import 'dart:io';

import 'package:tom_md2latex/src/latex_macros.dart' as $tom_md2latex_1;
import 'package:tom_md2latex/src/markdown_parser.dart' as $tom_md2latex_2;
import 'package:tom_md2latex/src/md2latex.dart' as $tom_md2latex_3;
import 'package:tom_md2latex/src/md_latex_converter.dart' as $tom_md2latex_4;

/// Bridge class for tom_md2latex module.
class TomMd2latexBridge {
  /// Returns all bridge class definitions.
  ///
  /// Eager — building every class. Prefer [bridgeClassThunks] +
  /// [bridgeClassTypes] for lazy registration (Step #17); this remains
  /// for diagnostics and callers that need the full list.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createMd2LatexBridge(),
      _createLatexMacrosBridge(),
      _createMarkdownParserOptionsBridge(),
      _createMarkdownParserBridge(),
      _createParsedMarkdownBridge(),
      _createMarkdownElementBridge(),
      _createHeadingElementBridge(),
      _createParagraphElementBridge(),
      _createCodeBlockElementBridge(),
      _createInlineCodeElementBridge(),
      _createTableElementBridge(),
      _createUnorderedListElementBridge(),
      _createOrderedListElementBridge(),
      _createBlockQuoteElementBridge(),
      _createHorizontalRuleElementBridge(),
      _createLinkElementBridge(),
      _createImageElementBridge(),
      _createRawTextElementBridge(),
      _createMdLatexConverterBridge(),
      _createMdLatexConverterOptionsBridge(),
      _createMdLatexConverterResultBridge(),
      _createConvertedFileBridge(),
      _createConversionErrorBridge(),
    ];
  }

  /// Returns deferred factory thunks keyed by class name.
  ///
  /// Each thunk builds one class's [BridgedClass] on demand. Plugs into
  /// the interpreter's lazy registry via [registerBridges] (Step #17).
  static Map<String, BridgedClass Function()> bridgeClassThunks() {
    return {
      'Md2Latex': _createMd2LatexBridge,
      'LatexMacros': _createLatexMacrosBridge,
      'MarkdownParserOptions': _createMarkdownParserOptionsBridge,
      'MarkdownParser': _createMarkdownParserBridge,
      'ParsedMarkdown': _createParsedMarkdownBridge,
      'MarkdownElement': _createMarkdownElementBridge,
      'HeadingElement': _createHeadingElementBridge,
      'ParagraphElement': _createParagraphElementBridge,
      'CodeBlockElement': _createCodeBlockElementBridge,
      'InlineCodeElement': _createInlineCodeElementBridge,
      'TableElement': _createTableElementBridge,
      'UnorderedListElement': _createUnorderedListElementBridge,
      'OrderedListElement': _createOrderedListElementBridge,
      'BlockQuoteElement': _createBlockQuoteElementBridge,
      'HorizontalRuleElement': _createHorizontalRuleElementBridge,
      'LinkElement': _createLinkElementBridge,
      'ImageElement': _createImageElementBridge,
      'RawTextElement': _createRawTextElementBridge,
      'MdLatexConverter': _createMdLatexConverterBridge,
      'MdLatexConverterOptions': _createMdLatexConverterOptionsBridge,
      'MdLatexConverterResult': _createMdLatexConverterResultBridge,
      'ConvertedFile': _createConvertedFileBridge,
      'ConversionError': _createConversionErrorBridge,
    };
  }

  /// Returns native [Type]s keyed by class name, parallel to
  /// [bridgeClassThunks] (Step #17). Used to register the native-type
  /// lookup thunk without building the BridgedClass.
  static Map<String, Type> bridgeClassTypes() {
    return {
      'Md2Latex': $tom_md2latex_3.Md2Latex,
      'LatexMacros': $tom_md2latex_1.LatexMacros,
      'MarkdownParserOptions': $tom_md2latex_2.MarkdownParserOptions,
      'MarkdownParser': $tom_md2latex_2.MarkdownParser,
      'ParsedMarkdown': $tom_md2latex_2.ParsedMarkdown,
      'MarkdownElement': $tom_md2latex_2.MarkdownElement,
      'HeadingElement': $tom_md2latex_2.HeadingElement,
      'ParagraphElement': $tom_md2latex_2.ParagraphElement,
      'CodeBlockElement': $tom_md2latex_2.CodeBlockElement,
      'InlineCodeElement': $tom_md2latex_2.InlineCodeElement,
      'TableElement': $tom_md2latex_2.TableElement,
      'UnorderedListElement': $tom_md2latex_2.UnorderedListElement,
      'OrderedListElement': $tom_md2latex_2.OrderedListElement,
      'BlockQuoteElement': $tom_md2latex_2.BlockQuoteElement,
      'HorizontalRuleElement': $tom_md2latex_2.HorizontalRuleElement,
      'LinkElement': $tom_md2latex_2.LinkElement,
      'ImageElement': $tom_md2latex_2.ImageElement,
      'RawTextElement': $tom_md2latex_2.RawTextElement,
      'MdLatexConverter': $tom_md2latex_4.MdLatexConverter,
      'MdLatexConverterOptions': $tom_md2latex_4.MdLatexConverterOptions,
      'MdLatexConverterResult': $tom_md2latex_4.MdLatexConverterResult,
      'ConvertedFile': $tom_md2latex_4.ConvertedFile,
      'ConversionError': $tom_md2latex_4.ConversionError,
    };
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'Md2Latex': 'package:tom_md2latex/src/md2latex.dart',
      'LatexMacros': 'package:tom_md2latex/src/latex_macros.dart',
      'MarkdownParserOptions': 'package:tom_md2latex/src/markdown_parser.dart',
      'MarkdownParser': 'package:tom_md2latex/src/markdown_parser.dart',
      'ParsedMarkdown': 'package:tom_md2latex/src/markdown_parser.dart',
      'MarkdownElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'HeadingElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'ParagraphElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'CodeBlockElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'InlineCodeElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'TableElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'UnorderedListElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'OrderedListElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'BlockQuoteElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'HorizontalRuleElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'LinkElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'ImageElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'RawTextElement': 'package:tom_md2latex/src/markdown_parser.dart',
      'MdLatexConverter': 'package:tom_md2latex/src/md_latex_converter.dart',
      'MdLatexConverterOptions': 'package:tom_md2latex/src/md_latex_converter.dart',
      'MdLatexConverterResult': 'package:tom_md2latex/src/md_latex_converter.dart',
      'ConvertedFile': 'package:tom_md2latex/src/md_latex_converter.dart',
      'ConversionError': 'package:tom_md2latex/src/md_latex_converter.dart',
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
      'HeadingElement': ['MarkdownElement'],
      'ParagraphElement': ['MarkdownElement'],
      'CodeBlockElement': ['MarkdownElement'],
      'InlineCodeElement': ['MarkdownElement'],
      'TableElement': ['MarkdownElement'],
      'UnorderedListElement': ['MarkdownElement'],
      'OrderedListElement': ['MarkdownElement'],
      'BlockQuoteElement': ['MarkdownElement'],
      'HorizontalRuleElement': ['MarkdownElement'],
      'LinkElement': ['MarkdownElement'],
      'ImageElement': ['MarkdownElement'],
      'RawTextElement': ['MarkdownElement'],
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
    ];
  }

  /// Returns a map of enum names to their canonical source URIs.
  ///
  /// Used for deduplication when the same enum is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> enumSourceUris() {
    return {
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
      (source: 'package:tom_md2latex/tom_md2latex.dart', target: 'package:tom_md2latex/src/md2latex.dart', show: null, hide: null),
      (source: 'package:tom_md2latex/tom_md2latex.dart', target: 'package:tom_md2latex/src/md_latex_converter.dart', show: null, hide: null),
      (source: 'package:tom_md2latex/tom_md2latex.dart', target: 'package:tom_md2latex/src/latex_macros.dart', show: null, hide: null),
      (source: 'package:tom_md2latex/tom_md2latex.dart', target: 'package:tom_md2latex/src/markdown_parser.dart', show: null, hide: null),
      (source: 'package:tom_md2latex/src/md_latex_converter.dart', target: 'package:tom_md2latex/src/latex_macros.dart', show: null, hide: null),
      (source: 'package:tom_md2latex/src/md_latex_converter.dart', target: 'package:tom_md2latex/src/markdown_parser.dart', show: null, hide: null),
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
      'package:tom_md2latex/src/latex_macros.dart',
      'package:tom_md2latex/src/markdown_parser.dart',
      'package:tom_md2latex/src/md2latex.dart',
      'package:tom_md2latex/src/md_latex_converter.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    return "import 'package:tom_md2latex/tom_md2latex.dart';";
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

}

// =============================================================================
// Md2Latex Bridge
// =============================================================================

BridgedClass _createMd2LatexBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_3.Md2Latex,
    name: 'Md2Latex',
    isAssignable: (v) => v is $tom_md2latex_3.Md2Latex,
    constructors: {
    },
    staticMethods: {
      'convertString': (visitor, positional, named, typeArgs) {
        final markdown = D4.getRequiredNamedArg<String>(named, 'markdown', 'convertString');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', false);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return $tom_md2latex_3.Md2Latex.convertString(markdown: markdown, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
      },
      'convertFile': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFile');
        final outputPath = D4.getOptionalNamedArg<String?>(named, 'outputPath');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', true);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return $tom_md2latex_3.Md2Latex.convertFile(inputPath: inputPath, outputPath: outputPath, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
      },
      'convertFileToString': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFileToString');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', false);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return $tom_md2latex_3.Md2Latex.convertFileToString(inputPath: inputPath, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
      },
      'convertFileToStringSync': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFileToStringSync');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', false);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return $tom_md2latex_3.Md2Latex.convertFileToStringSync(inputPath: inputPath, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
      },
      'convertDirectory': (visitor, positional, named, typeArgs) {
        final inputDir = D4.getRequiredNamedArg<String>(named, 'inputDir', 'convertDirectory');
        final outputDir = D4.getRequiredNamedArg<String>(named, 'outputDir', 'convertDirectory');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', true);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        final excludePatterns = named.containsKey('excludePatterns') && named['excludePatterns'] != null
            ? D4.coerceList<String>(named['excludePatterns'], 'excludePatterns')
            : const ['.git', 'node_modules', '.dart_tool'];
        return $tom_md2latex_3.Md2Latex.convertDirectory(inputDir: inputDir, outputDir: outputDir, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth, excludePatterns: excludePatterns);
      },
      'parse': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parse');
        final markdown = D4.getRequiredArg<String>(positional, 0, 'markdown', 'parse');
        final options = D4.getNamedArgWithDefault<$tom_md2latex_2.MarkdownParserOptions>(named, 'options', const $tom_md2latex_2.MarkdownParserOptions());
        return $tom_md2latex_3.Md2Latex.parse(markdown, options: options);
      },
    },
    staticMethodSignatures: {
      'convertString': 'String convertString({required String markdown, String documentClass = \'article\', String? author, bool generatePreamble = true, bool generateToc = false, int tocDepth = 3})',
      'convertFile': 'Future<ConvertedFile> convertFile({required String inputPath, String? outputPath, String documentClass = \'article\', String? author, bool generatePreamble = true, bool generateToc = true, int tocDepth = 3})',
      'convertFileToString': 'Future<String> convertFileToString({required String inputPath, String documentClass = \'article\', String? author, bool generatePreamble = true, bool generateToc = false, int tocDepth = 3})',
      'convertFileToStringSync': 'String convertFileToStringSync({required String inputPath, String documentClass = \'article\', String? author, bool generatePreamble = true, bool generateToc = false, int tocDepth = 3})',
      'convertDirectory': 'Future<MdLatexConverterResult> convertDirectory({required String inputDir, required String outputDir, String documentClass = \'article\', String? author, bool generatePreamble = true, bool generateToc = true, int tocDepth = 3, List<String> excludePatterns = const [\'.git\', \'node_modules\', \'.dart_tool\']})',
      'parse': 'ParsedMarkdown parse(String markdown, {MarkdownParserOptions options = const MarkdownParserOptions()})',
    },
  );
}

// =============================================================================
// LatexMacros Bridge
// =============================================================================

BridgedClass _createLatexMacrosBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_1.LatexMacros,
    name: 'LatexMacros',
    isAssignable: (v) => v is $tom_md2latex_1.LatexMacros,
    constructors: {
    },
    staticMethods: {
      'preamble': (visitor, positional, named, typeArgs) {
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final date = D4.getOptionalNamedArg<String?>(named, 'date');
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return $tom_md2latex_1.LatexMacros.preamble(documentClass: documentClass, title: title, author: author, date: date, tocDepth: tocDepth);
      },
      'beginDocument': (visitor, positional, named, typeArgs) {
        return $tom_md2latex_1.LatexMacros.beginDocument();
      },
      'endDocument': (visitor, positional, named, typeArgs) {
        return $tom_md2latex_1.LatexMacros.endDocument();
      },
      'makeTitle': (visitor, positional, named, typeArgs) {
        return $tom_md2latex_1.LatexMacros.makeTitle();
      },
      'textToSlug': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'textToSlug');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'textToSlug');
        return $tom_md2latex_1.LatexMacros.textToSlug(text);
      },
      'heading': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'heading');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'heading');
        final level = D4.getRequiredArg<int>(positional, 1, 'level', 'heading');
        final label = D4.getOptionalNamedArg<String?>(named, 'label');
        final numbered = D4.getNamedArgWithDefault<bool>(named, 'numbered', true);
        return $tom_md2latex_1.LatexMacros.heading(text, level, label: label, numbered: numbered);
      },
      'paragraph': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'paragraph');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'paragraph');
        return $tom_md2latex_1.LatexMacros.paragraph(text);
      },
      'bold': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'bold');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'bold');
        return $tom_md2latex_1.LatexMacros.bold(text);
      },
      'italic': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'italic');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'italic');
        return $tom_md2latex_1.LatexMacros.italic(text);
      },
      'inlineCode': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'inlineCode');
        final code = D4.getRequiredArg<String>(positional, 0, 'code', 'inlineCode');
        return $tom_md2latex_1.LatexMacros.inlineCode(code);
      },
      'codeBlock': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'codeBlock');
        final code = D4.getRequiredArg<String>(positional, 0, 'code', 'codeBlock');
        final language = D4.getOptionalNamedArg<String?>(named, 'language');
        return $tom_md2latex_1.LatexMacros.codeBlock(code, language: language);
      },
      'asciiDiagram': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'asciiDiagram');
        final diagram = D4.getRequiredArg<String>(positional, 0, 'diagram', 'asciiDiagram');
        return $tom_md2latex_1.LatexMacros.asciiDiagram(diagram);
      },
      'table': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'table');
        if (positional.isEmpty) {
          throw ArgumentError('table: Missing required argument "headers" at position 0');
        }
        final headers = D4.coerceList<String>(positional[0], 'headers');
        if (positional.length <= 1) {
          throw ArgumentError('table: Missing required argument "rows" at position 1');
        }
        final rows = D4.coerceList<List<String>>(positional[1], 'rows');
        if (positional.length <= 2) {
          throw ArgumentError('table: Missing required argument "alignments" at position 2');
        }
        final alignments = D4.coerceList<String>(positional[2], 'alignments');
        return $tom_md2latex_1.LatexMacros.table(headers, rows, alignments);
      },
      'unorderedList': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'unorderedList');
        if (positional.isEmpty) {
          throw ArgumentError('unorderedList: Missing required argument "items" at position 0');
        }
        final items = D4.coerceList<String>(positional[0], 'items');
        return $tom_md2latex_1.LatexMacros.unorderedList(items);
      },
      'orderedList': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'orderedList');
        if (positional.isEmpty) {
          throw ArgumentError('orderedList: Missing required argument "items" at position 0');
        }
        final items = D4.coerceList<String>(positional[0], 'items');
        return $tom_md2latex_1.LatexMacros.orderedList(items);
      },
      'blockQuote': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'blockQuote');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'blockQuote');
        return $tom_md2latex_1.LatexMacros.blockQuote(text);
      },
      'horizontalRule': (visitor, positional, named, typeArgs) {
        return $tom_md2latex_1.LatexMacros.horizontalRule();
      },
      'link': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'link');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'link');
        final url = D4.getRequiredArg<String>(positional, 1, 'url', 'link');
        return $tom_md2latex_1.LatexMacros.link(text, url);
      },
      'image': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'image');
        final altText = D4.getRequiredArg<String>(positional, 0, 'altText', 'image');
        final url = D4.getRequiredArg<String>(positional, 1, 'url', 'image');
        return $tom_md2latex_1.LatexMacros.image(altText, url);
      },
      'escapeText': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'escapeText');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'escapeText');
        return $tom_md2latex_1.LatexMacros.escapeText(text);
      },
    },
    staticMethodSignatures: {
      'preamble': 'String preamble({String documentClass = \'article\', String? title, String? author, String? date, int tocDepth = 3})',
      'beginDocument': 'String beginDocument()',
      'endDocument': 'String endDocument()',
      'makeTitle': 'String makeTitle()',
      'textToSlug': 'String textToSlug(String text)',
      'heading': 'String heading(String text, int level, {String? label, bool numbered = true})',
      'paragraph': 'String paragraph(String text)',
      'bold': 'String bold(String text)',
      'italic': 'String italic(String text)',
      'inlineCode': 'String inlineCode(String code)',
      'codeBlock': 'String codeBlock(String code, {String? language})',
      'asciiDiagram': 'String asciiDiagram(String diagram)',
      'table': 'String table(List<String> headers, List<List<String>> rows, List<String> alignments)',
      'unorderedList': 'String unorderedList(List<String> items)',
      'orderedList': 'String orderedList(List<String> items)',
      'blockQuote': 'String blockQuote(String text)',
      'horizontalRule': 'String horizontalRule()',
      'link': 'String link(String text, String url)',
      'image': 'String image(String altText, String url)',
      'escapeText': 'String escapeText(String text)',
    },
  );
}

// =============================================================================
// MarkdownParserOptions Bridge
// =============================================================================

BridgedClass _createMarkdownParserOptionsBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.MarkdownParserOptions,
    name: 'MarkdownParserOptions',
    isAssignable: (v) => v is $tom_md2latex_2.MarkdownParserOptions,
    constructors: {
      '': (visitor, positional, named) {
        final detectAsciiDiagrams = D4.getNamedArgWithDefault<bool>(named, 'detectAsciiDiagrams', true);
        final asciiDiagramPatterns = named.containsKey('asciiDiagramPatterns') && named['asciiDiagramPatterns'] != null
            ? D4.coerceList<String>(named['asciiDiagramPatterns'], 'asciiDiagramPatterns')
            : const ['├', '└', '│', '─', '┬', '┴', '┼', '┤', '┌', '┐', '┘', '┐', '+--', '|--', '\\--', '+-', '|-', '/---', '\\---', '[', ']'];
        return $tom_md2latex_2.MarkdownParserOptions(detectAsciiDiagrams: detectAsciiDiagrams, asciiDiagramPatterns: asciiDiagramPatterns);
      },
    },
    getters: {
      'detectAsciiDiagrams': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MarkdownParserOptions>(target, 'MarkdownParserOptions').detectAsciiDiagrams,
      'asciiDiagramPatterns': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MarkdownParserOptions>(target, 'MarkdownParserOptions').asciiDiagramPatterns,
    },
    constructorSignatures: {
      '': 'const MarkdownParserOptions({bool detectAsciiDiagrams = true, List<String> asciiDiagramPatterns = const [\'├\', \'└\', \'│\', \'─\', \'┬\', \'┴\', \'┼\', \'┤\', \'┌\', \'┐\', \'┘\', \'┐\', \'+--\', \'|--\', \'\\\\--\', \'+-\', \'|-\', \'/---\', \'\\\\---\', \'[\', \']\']})',
    },
    getterSignatures: {
      'detectAsciiDiagrams': 'bool get detectAsciiDiagrams',
      'asciiDiagramPatterns': 'List<String> get asciiDiagramPatterns',
    },
  );
}

// =============================================================================
// MarkdownParser Bridge
// =============================================================================

BridgedClass _createMarkdownParserBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.MarkdownParser,
    name: 'MarkdownParser',
    isAssignable: (v) => v is $tom_md2latex_2.MarkdownParser,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'MarkdownParser');
        final content = D4.getRequiredArg<String>(positional, 0, 'content', 'MarkdownParser');
        final options = D4.getNamedArgWithDefault<$tom_md2latex_2.MarkdownParserOptions>(named, 'options', const $tom_md2latex_2.MarkdownParserOptions());
        return $tom_md2latex_2.MarkdownParser(content, options: options);
      },
    },
    getters: {
      'content': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MarkdownParser>(target, 'MarkdownParser').content,
      'options': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MarkdownParser>(target, 'MarkdownParser').options,
    },
    methods: {
      'parse': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2latex_2.MarkdownParser>(target, 'MarkdownParser');
        return t.parse();
      },
    },
    constructorSignatures: {
      '': 'MarkdownParser(String content, {MarkdownParserOptions options = const MarkdownParserOptions()})',
    },
    methodSignatures: {
      'parse': 'ParsedMarkdown parse()',
    },
    getterSignatures: {
      'content': 'String get content',
      'options': 'MarkdownParserOptions get options',
    },
  );
}

// =============================================================================
// ParsedMarkdown Bridge
// =============================================================================

BridgedClass _createParsedMarkdownBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.ParsedMarkdown,
    name: 'ParsedMarkdown',
    isAssignable: (v) => v is $tom_md2latex_2.ParsedMarkdown,
    constructors: {
      '': (visitor, positional, named) {
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final date = D4.getOptionalNamedArg<String?>(named, 'date');
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', false);
        final tocDepth = D4.getOptionalNamedArg<int?>(named, 'tocDepth');
        if (!named.containsKey('elements') || named['elements'] == null) {
          throw ArgumentError('ParsedMarkdown: Missing required named argument "elements"');
        }
        final elements = D4.coerceList<$tom_md2latex_2.MarkdownElement>(named['elements'], 'elements');
        return $tom_md2latex_2.ParsedMarkdown(title: title, author: author, date: date, generateToc: generateToc, tocDepth: tocDepth, elements: elements);
      },
    },
    getters: {
      'title': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ParsedMarkdown>(target, 'ParsedMarkdown').title,
      'author': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ParsedMarkdown>(target, 'ParsedMarkdown').author,
      'date': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ParsedMarkdown>(target, 'ParsedMarkdown').date,
      'generateToc': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ParsedMarkdown>(target, 'ParsedMarkdown').generateToc,
      'tocDepth': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ParsedMarkdown>(target, 'ParsedMarkdown').tocDepth,
      'elements': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ParsedMarkdown>(target, 'ParsedMarkdown').elements,
    },
    constructorSignatures: {
      '': 'const ParsedMarkdown({String? title, String? author, String? date, bool generateToc = false, int? tocDepth, required List<MarkdownElement> elements})',
    },
    getterSignatures: {
      'title': 'String? get title',
      'author': 'String? get author',
      'date': 'String? get date',
      'generateToc': 'bool get generateToc',
      'tocDepth': 'int? get tocDepth',
      'elements': 'List<MarkdownElement> get elements',
    },
  );
}

// =============================================================================
// MarkdownElement Bridge
// =============================================================================

BridgedClass _createMarkdownElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.MarkdownElement,
    name: 'MarkdownElement',
    isAssignable: (v) => v is $tom_md2latex_2.MarkdownElement,
    constructors: {
    },
  );
}

// =============================================================================
// HeadingElement Bridge
// =============================================================================

BridgedClass _createHeadingElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.HeadingElement,
    name: 'HeadingElement',
    isAssignable: (v) => v is $tom_md2latex_2.HeadingElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'HeadingElement');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'HeadingElement');
        final level = D4.getRequiredArg<int>(positional, 1, 'level', 'HeadingElement');
        return $tom_md2latex_2.HeadingElement(text, level);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<$tom_md2latex_2.HeadingElement>(target, 'HeadingElement').text,
      'level': (visitor, target) => D4.validateTarget<$tom_md2latex_2.HeadingElement>(target, 'HeadingElement').level,
    },
    constructorSignatures: {
      '': 'HeadingElement(String text, int level)',
    },
    getterSignatures: {
      'text': 'String get text',
      'level': 'int get level',
    },
  );
}

// =============================================================================
// ParagraphElement Bridge
// =============================================================================

BridgedClass _createParagraphElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.ParagraphElement,
    name: 'ParagraphElement',
    isAssignable: (v) => v is $tom_md2latex_2.ParagraphElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'ParagraphElement');
        return $tom_md2latex_2.ParagraphElement(text: text);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ParagraphElement>(target, 'ParagraphElement').text,
    },
    constructorSignatures: {
      '': 'ParagraphElement({required String text})',
    },
    getterSignatures: {
      'text': 'String get text',
    },
  );
}

// =============================================================================
// CodeBlockElement Bridge
// =============================================================================

BridgedClass _createCodeBlockElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.CodeBlockElement,
    name: 'CodeBlockElement',
    isAssignable: (v) => v is $tom_md2latex_2.CodeBlockElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final code = D4.getRequiredNamedArg<String>(named, 'code', 'CodeBlockElement');
        final language = D4.getOptionalNamedArg<String?>(named, 'language');
        final isAsciiDiagram = D4.getNamedArgWithDefault<bool>(named, 'isAsciiDiagram', false);
        return $tom_md2latex_2.CodeBlockElement(code: code, language: language, isAsciiDiagram: isAsciiDiagram);
      },
    },
    getters: {
      'code': (visitor, target) => D4.validateTarget<$tom_md2latex_2.CodeBlockElement>(target, 'CodeBlockElement').code,
      'language': (visitor, target) => D4.validateTarget<$tom_md2latex_2.CodeBlockElement>(target, 'CodeBlockElement').language,
      'isAsciiDiagram': (visitor, target) => D4.validateTarget<$tom_md2latex_2.CodeBlockElement>(target, 'CodeBlockElement').isAsciiDiagram,
    },
    constructorSignatures: {
      '': 'CodeBlockElement({required String code, String? language, bool isAsciiDiagram = false})',
    },
    getterSignatures: {
      'code': 'String get code',
      'language': 'String? get language',
      'isAsciiDiagram': 'bool get isAsciiDiagram',
    },
  );
}

// =============================================================================
// InlineCodeElement Bridge
// =============================================================================

BridgedClass _createInlineCodeElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.InlineCodeElement,
    name: 'InlineCodeElement',
    isAssignable: (v) => v is $tom_md2latex_2.InlineCodeElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final code = D4.getRequiredNamedArg<String>(named, 'code', 'InlineCodeElement');
        return $tom_md2latex_2.InlineCodeElement(code: code);
      },
    },
    getters: {
      'code': (visitor, target) => D4.validateTarget<$tom_md2latex_2.InlineCodeElement>(target, 'InlineCodeElement').code,
    },
    constructorSignatures: {
      '': 'InlineCodeElement({required String code})',
    },
    getterSignatures: {
      'code': 'String get code',
    },
  );
}

// =============================================================================
// TableElement Bridge
// =============================================================================

BridgedClass _createTableElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.TableElement,
    name: 'TableElement',
    isAssignable: (v) => v is $tom_md2latex_2.TableElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        if (!named.containsKey('headers') || named['headers'] == null) {
          throw ArgumentError('TableElement: Missing required named argument "headers"');
        }
        final headers = D4.coerceList<String>(named['headers'], 'headers');
        if (!named.containsKey('rows') || named['rows'] == null) {
          throw ArgumentError('TableElement: Missing required named argument "rows"');
        }
        final rows = D4.coerceNestedList<String>(named['rows'], 'rows');
        if (!named.containsKey('alignments') || named['alignments'] == null) {
          throw ArgumentError('TableElement: Missing required named argument "alignments"');
        }
        final alignments = D4.coerceList<String>(named['alignments'], 'alignments');
        return $tom_md2latex_2.TableElement(headers: headers, rows: rows, alignments: alignments);
      },
    },
    getters: {
      'headers': (visitor, target) => D4.validateTarget<$tom_md2latex_2.TableElement>(target, 'TableElement').headers,
      'rows': (visitor, target) => D4.validateTarget<$tom_md2latex_2.TableElement>(target, 'TableElement').rows,
      'alignments': (visitor, target) => D4.validateTarget<$tom_md2latex_2.TableElement>(target, 'TableElement').alignments,
    },
    constructorSignatures: {
      '': 'TableElement({required List<String> headers, required List<List<String>> rows, required List<String> alignments})',
    },
    getterSignatures: {
      'headers': 'List<String> get headers',
      'rows': 'List<List<String>> get rows',
      'alignments': 'List<String> get alignments',
    },
  );
}

// =============================================================================
// UnorderedListElement Bridge
// =============================================================================

BridgedClass _createUnorderedListElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.UnorderedListElement,
    name: 'UnorderedListElement',
    isAssignable: (v) => v is $tom_md2latex_2.UnorderedListElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        if (!named.containsKey('items') || named['items'] == null) {
          throw ArgumentError('UnorderedListElement: Missing required named argument "items"');
        }
        final items = D4.coerceList<String>(named['items'], 'items');
        return $tom_md2latex_2.UnorderedListElement(items: items);
      },
    },
    getters: {
      'items': (visitor, target) => D4.validateTarget<$tom_md2latex_2.UnorderedListElement>(target, 'UnorderedListElement').items,
    },
    constructorSignatures: {
      '': 'UnorderedListElement({required List<String> items})',
    },
    getterSignatures: {
      'items': 'List<String> get items',
    },
  );
}

// =============================================================================
// OrderedListElement Bridge
// =============================================================================

BridgedClass _createOrderedListElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.OrderedListElement,
    name: 'OrderedListElement',
    isAssignable: (v) => v is $tom_md2latex_2.OrderedListElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        if (!named.containsKey('items') || named['items'] == null) {
          throw ArgumentError('OrderedListElement: Missing required named argument "items"');
        }
        final items = D4.coerceList<String>(named['items'], 'items');
        return $tom_md2latex_2.OrderedListElement(items: items);
      },
    },
    getters: {
      'items': (visitor, target) => D4.validateTarget<$tom_md2latex_2.OrderedListElement>(target, 'OrderedListElement').items,
    },
    constructorSignatures: {
      '': 'OrderedListElement({required List<String> items})',
    },
    getterSignatures: {
      'items': 'List<String> get items',
    },
  );
}

// =============================================================================
// BlockQuoteElement Bridge
// =============================================================================

BridgedClass _createBlockQuoteElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.BlockQuoteElement,
    name: 'BlockQuoteElement',
    isAssignable: (v) => v is $tom_md2latex_2.BlockQuoteElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'BlockQuoteElement');
        return $tom_md2latex_2.BlockQuoteElement(text: text);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<$tom_md2latex_2.BlockQuoteElement>(target, 'BlockQuoteElement').text,
    },
    constructorSignatures: {
      '': 'BlockQuoteElement({required String text})',
    },
    getterSignatures: {
      'text': 'String get text',
    },
  );
}

// =============================================================================
// HorizontalRuleElement Bridge
// =============================================================================

BridgedClass _createHorizontalRuleElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.HorizontalRuleElement,
    name: 'HorizontalRuleElement',
    isAssignable: (v) => v is $tom_md2latex_2.HorizontalRuleElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_md2latex_2.HorizontalRuleElement();
      },
    },
    constructorSignatures: {
      '': 'HorizontalRuleElement()',
    },
  );
}

// =============================================================================
// LinkElement Bridge
// =============================================================================

BridgedClass _createLinkElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.LinkElement,
    name: 'LinkElement',
    isAssignable: (v) => v is $tom_md2latex_2.LinkElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'LinkElement');
        final url = D4.getRequiredNamedArg<String>(named, 'url', 'LinkElement');
        return $tom_md2latex_2.LinkElement(text: text, url: url);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<$tom_md2latex_2.LinkElement>(target, 'LinkElement').text,
      'url': (visitor, target) => D4.validateTarget<$tom_md2latex_2.LinkElement>(target, 'LinkElement').url,
    },
    constructorSignatures: {
      '': 'LinkElement({required String text, required String url})',
    },
    getterSignatures: {
      'text': 'String get text',
      'url': 'String get url',
    },
  );
}

// =============================================================================
// ImageElement Bridge
// =============================================================================

BridgedClass _createImageElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.ImageElement,
    name: 'ImageElement',
    isAssignable: (v) => v is $tom_md2latex_2.ImageElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final altText = D4.getRequiredNamedArg<String>(named, 'altText', 'ImageElement');
        final url = D4.getRequiredNamedArg<String>(named, 'url', 'ImageElement');
        return $tom_md2latex_2.ImageElement(altText: altText, url: url);
      },
    },
    getters: {
      'altText': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ImageElement>(target, 'ImageElement').altText,
      'url': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ImageElement>(target, 'ImageElement').url,
    },
    constructorSignatures: {
      '': 'ImageElement({required String altText, required String url})',
    },
    getterSignatures: {
      'altText': 'String get altText',
      'url': 'String get url',
    },
  );
}

// =============================================================================
// RawTextElement Bridge
// =============================================================================

BridgedClass _createRawTextElementBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_2.RawTextElement,
    name: 'RawTextElement',
    isAssignable: (v) => v is $tom_md2latex_2.RawTextElement,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'RawTextElement');
        return $tom_md2latex_2.RawTextElement(text: text);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<$tom_md2latex_2.RawTextElement>(target, 'RawTextElement').text,
    },
    constructorSignatures: {
      '': 'RawTextElement({required String text})',
    },
    getterSignatures: {
      'text': 'String get text',
    },
  );
}

// =============================================================================
// MdLatexConverter Bridge
// =============================================================================

BridgedClass _createMdLatexConverterBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_4.MdLatexConverter,
    name: 'MdLatexConverter',
    isAssignable: (v) => v is $tom_md2latex_4.MdLatexConverter,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'MdLatexConverter');
        final sourcePath = D4.getRequiredArg<String>(positional, 0, 'sourcePath', 'MdLatexConverter');
        final options = D4.getOptionalNamedArg<$tom_md2latex_4.MdLatexConverterOptions?>(named, 'options');
        return $tom_md2latex_4.MdLatexConverter(sourcePath, options: options);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverter>(target, 'MdLatexConverter').sourcePath,
      'options': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverter>(target, 'MdLatexConverter').options,
    },
    methods: {
      'findMarkdownFiles': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2latex_4.MdLatexConverter>(target, 'MdLatexConverter');
        return t.findMarkdownFiles();
      },
      'convertAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2latex_4.MdLatexConverter>(target, 'MdLatexConverter');
        final outputDir = D4.getRequiredNamedArg<String>(named, 'outputDir', 'convertAll');
        return t.convertAll(outputDir: outputDir);
      },
      'convertFile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2latex_4.MdLatexConverter>(target, 'MdLatexConverter');
        D4.requireMinArgs(positional, 1, 'convertFile');
        final file = D4.getRequiredArg<File>(positional, 0, 'file', 'convertFile');
        final outputDir = D4.getRequiredNamedArg<String>(named, 'outputDir', 'convertFile');
        return t.convertFile(file, outputDir: outputDir);
      },
      'convert': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2latex_4.MdLatexConverter>(target, 'MdLatexConverter');
        D4.requireMinArgs(positional, 1, 'convert');
        final markdownContent = D4.getRequiredArg<String>(positional, 0, 'markdownContent', 'convert');
        return t.convert(markdownContent);
      },
    },
    constructorSignatures: {
      '': 'MdLatexConverter(String sourcePath, {MdLatexConverterOptions? options})',
    },
    methodSignatures: {
      'findMarkdownFiles': 'Future<List<File>> findMarkdownFiles()',
      'convertAll': 'Future<MdLatexConverterResult> convertAll({required String outputDir})',
      'convertFile': 'Future<ConvertedFile> convertFile(File file, {required String outputDir})',
      'convert': 'String convert(String markdownContent)',
    },
    getterSignatures: {
      'sourcePath': 'String get sourcePath',
      'options': 'MdLatexConverterOptions get options',
    },
  );
}

// =============================================================================
// MdLatexConverterOptions Bridge
// =============================================================================

BridgedClass _createMdLatexConverterOptionsBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_4.MdLatexConverterOptions,
    name: 'MdLatexConverterOptions',
    isAssignable: (v) => v is $tom_md2latex_4.MdLatexConverterOptions,
    constructors: {
      '': (visitor, positional, named) {
        final excludePatterns = named.containsKey('excludePatterns') && named['excludePatterns'] != null
            ? D4.coerceList<String>(named['excludePatterns'], 'excludePatterns')
            : const ['.git', 'node_modules', '.dart_tool'];
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', true);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        final parserOptions = D4.getNamedArgWithDefault<$tom_md2latex_2.MarkdownParserOptions>(named, 'parserOptions', const $tom_md2latex_2.MarkdownParserOptions());
        return $tom_md2latex_4.MdLatexConverterOptions(excludePatterns: excludePatterns, generatePreamble: generatePreamble, documentClass: documentClass, author: author, generateToc: generateToc, tocDepth: tocDepth, parserOptions: parserOptions);
      },
    },
    getters: {
      'excludePatterns': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').excludePatterns,
      'generatePreamble': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').generatePreamble,
      'documentClass': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').documentClass,
      'author': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').author,
      'generateToc': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').generateToc,
      'tocDepth': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').tocDepth,
      'parserOptions': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').parserOptions,
    },
    constructorSignatures: {
      '': 'const MdLatexConverterOptions({List<String> excludePatterns = const [\'.git\', \'node_modules\', \'.dart_tool\'], bool generatePreamble = true, String documentClass = \'article\', String? author, bool generateToc = true, int tocDepth = 3, MarkdownParserOptions parserOptions = const MarkdownParserOptions()})',
    },
    getterSignatures: {
      'excludePatterns': 'List<String> get excludePatterns',
      'generatePreamble': 'bool get generatePreamble',
      'documentClass': 'String get documentClass',
      'author': 'String? get author',
      'generateToc': 'bool get generateToc',
      'tocDepth': 'int get tocDepth',
      'parserOptions': 'MarkdownParserOptions get parserOptions',
    },
  );
}

// =============================================================================
// MdLatexConverterResult Bridge
// =============================================================================

BridgedClass _createMdLatexConverterResultBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_4.MdLatexConverterResult,
    name: 'MdLatexConverterResult',
    isAssignable: (v) => v is $tom_md2latex_4.MdLatexConverterResult,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_md2latex_4.MdLatexConverterResult();
      },
    },
    getters: {
      'converted': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterResult>(target, 'MdLatexConverterResult').converted,
      'errors': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterResult>(target, 'MdLatexConverterResult').errors,
      'isSuccess': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterResult>(target, 'MdLatexConverterResult').isSuccess,
      'totalProcessed': (visitor, target) => D4.validateTarget<$tom_md2latex_4.MdLatexConverterResult>(target, 'MdLatexConverterResult').totalProcessed,
    },
    constructorSignatures: {
      '': 'MdLatexConverterResult()',
    },
    getterSignatures: {
      'converted': 'List<ConvertedFile> get converted',
      'errors': 'List<ConversionError> get errors',
      'isSuccess': 'bool get isSuccess',
      'totalProcessed': 'int get totalProcessed',
    },
  );
}

// =============================================================================
// ConvertedFile Bridge
// =============================================================================

BridgedClass _createConvertedFileBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_4.ConvertedFile,
    name: 'ConvertedFile',
    isAssignable: (v) => v is $tom_md2latex_4.ConvertedFile,
    constructors: {
      '': (visitor, positional, named) {
        final sourcePath = D4.getRequiredNamedArg<String>(named, 'sourcePath', 'ConvertedFile');
        final outputPath = D4.getRequiredNamedArg<String>(named, 'outputPath', 'ConvertedFile');
        final parsed = D4.getRequiredNamedArg<$tom_md2latex_2.ParsedMarkdown>(named, 'parsed', 'ConvertedFile');
        return $tom_md2latex_4.ConvertedFile(sourcePath: sourcePath, outputPath: outputPath, parsed: parsed);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2latex_4.ConvertedFile>(target, 'ConvertedFile').sourcePath,
      'outputPath': (visitor, target) => D4.validateTarget<$tom_md2latex_4.ConvertedFile>(target, 'ConvertedFile').outputPath,
      'parsed': (visitor, target) => D4.validateTarget<$tom_md2latex_4.ConvertedFile>(target, 'ConvertedFile').parsed,
    },
    constructorSignatures: {
      '': 'const ConvertedFile({required String sourcePath, required String outputPath, required ParsedMarkdown parsed})',
    },
    getterSignatures: {
      'sourcePath': 'String get sourcePath',
      'outputPath': 'String get outputPath',
      'parsed': 'ParsedMarkdown get parsed',
    },
  );
}

// =============================================================================
// ConversionError Bridge
// =============================================================================

BridgedClass _createConversionErrorBridge() {
  return BridgedClass(
    nativeType: $tom_md2latex_4.ConversionError,
    name: 'ConversionError',
    isAssignable: (v) => v is $tom_md2latex_4.ConversionError,
    constructors: {
      '': (visitor, positional, named) {
        final sourcePath = D4.getRequiredNamedArg<String>(named, 'sourcePath', 'ConversionError');
        final message = D4.getRequiredNamedArg<String>(named, 'message', 'ConversionError');
        final stackTrace = D4.getOptionalNamedArg<StackTrace?>(named, 'stackTrace');
        return $tom_md2latex_4.ConversionError(sourcePath: sourcePath, message: message, stackTrace: stackTrace);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2latex_4.ConversionError>(target, 'ConversionError').sourcePath,
      'message': (visitor, target) => D4.validateTarget<$tom_md2latex_4.ConversionError>(target, 'ConversionError').message,
      'stackTrace': (visitor, target) => D4.validateTarget<$tom_md2latex_4.ConversionError>(target, 'ConversionError').stackTrace,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2latex_4.ConversionError>(target, 'ConversionError');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const ConversionError({required String sourcePath, required String message, StackTrace? stackTrace})',
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

