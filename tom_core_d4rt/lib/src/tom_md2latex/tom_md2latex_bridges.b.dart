// D4rt Bridge - Generated file, do not edit
// Sources: 4 files
// Generated: 2026-03-12T17:01:55.671012

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';
import 'dart:io';

import 'package:tom_md2latex/src/markdown_parser.dart' as $tom_md2latex_1;
import 'package:tom_md2latex/src/md_latex_converter.dart' as $tom_md2latex_2;

/// Bridge class for tom_md2latex module.
class TomMd2latexBridge {
  /// Returns all bridge class definitions.
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

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'Md2Latex': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md2latex.dart',
      'LatexMacros': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\latex_macros.dart',
      'MarkdownParserOptions': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'MarkdownParser': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'ParsedMarkdown': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'MarkdownElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'HeadingElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'ParagraphElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'CodeBlockElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'InlineCodeElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'TableElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'UnorderedListElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'OrderedListElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'BlockQuoteElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'HorizontalRuleElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'LinkElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'ImageElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'RawTextElement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'MdLatexConverter': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md_latex_converter.dart',
      'MdLatexConverterOptions': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md_latex_converter.dart',
      'MdLatexConverterResult': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md_latex_converter.dart',
      'ConvertedFile': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md_latex_converter.dart',
      'ConversionError': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md_latex_converter.dart',
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

  /// Registers all bridges with an interpreter.
  ///
  /// [importPath] is the package import path that D4rt scripts will use
  /// to access these classes (e.g., 'package:tom_build/tom.dart').
  static void registerBridges(D4rt interpreter, String importPath) {
    // Register bridged classes with source URIs for deduplication
    final classes = bridgeClasses();
    final classSources = classSourceUris();
    for (final bridge in classes) {
      interpreter.registerBridgedClass(bridge, importPath, sourceUri: classSources[bridge.name]);
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
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\latex_macros.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\markdown_parser.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md2latex.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\devops\tom_md2latex\lib\src\md_latex_converter.dart',
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
    nativeType: Md2Latex,
    name: 'Md2Latex',
    isAssignable: (v) => v is Md2Latex,
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
        return Md2Latex.convertString(markdown: markdown, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
      },
      'convertFile': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFile');
        final outputPath = D4.getOptionalNamedArg<String?>(named, 'outputPath');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', true);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return Md2Latex.convertFile(inputPath: inputPath, outputPath: outputPath, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
      },
      'convertFileToString': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFileToString');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', false);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return Md2Latex.convertFileToString(inputPath: inputPath, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
      },
      'convertFileToStringSync': (visitor, positional, named, typeArgs) {
        final inputPath = D4.getRequiredNamedArg<String>(named, 'inputPath', 'convertFileToStringSync');
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final generatePreamble = D4.getNamedArgWithDefault<bool>(named, 'generatePreamble', true);
        final generateToc = D4.getNamedArgWithDefault<bool>(named, 'generateToc', false);
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return Md2Latex.convertFileToStringSync(inputPath: inputPath, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth);
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
        return Md2Latex.convertDirectory(inputDir: inputDir, outputDir: outputDir, documentClass: documentClass, author: author, generatePreamble: generatePreamble, generateToc: generateToc, tocDepth: tocDepth, excludePatterns: excludePatterns);
      },
      'parse': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parse');
        final markdown = D4.getRequiredArg<String>(positional, 0, 'markdown', 'parse');
        final options = D4.getNamedArgWithDefault<$tom_md2latex_1.MarkdownParserOptions>(named, 'options', const $tom_md2latex_1.MarkdownParserOptions());
        return Md2Latex.parse(markdown, options: options);
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
    nativeType: LatexMacros,
    name: 'LatexMacros',
    isAssignable: (v) => v is LatexMacros,
    constructors: {
    },
    staticMethods: {
      'preamble': (visitor, positional, named, typeArgs) {
        final documentClass = D4.getNamedArgWithDefault<String>(named, 'documentClass', 'article');
        final title = D4.getOptionalNamedArg<String?>(named, 'title');
        final author = D4.getOptionalNamedArg<String?>(named, 'author');
        final date = D4.getOptionalNamedArg<String?>(named, 'date');
        final tocDepth = D4.getNamedArgWithDefault<int>(named, 'tocDepth', 3);
        return LatexMacros.preamble(documentClass: documentClass, title: title, author: author, date: date, tocDepth: tocDepth);
      },
      'beginDocument': (visitor, positional, named, typeArgs) {
        return LatexMacros.beginDocument();
      },
      'endDocument': (visitor, positional, named, typeArgs) {
        return LatexMacros.endDocument();
      },
      'makeTitle': (visitor, positional, named, typeArgs) {
        return LatexMacros.makeTitle();
      },
      'textToSlug': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'textToSlug');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'textToSlug');
        return LatexMacros.textToSlug(text);
      },
      'heading': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'heading');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'heading');
        final level = D4.getRequiredArg<int>(positional, 1, 'level', 'heading');
        final label = D4.getOptionalNamedArg<String?>(named, 'label');
        final numbered = D4.getNamedArgWithDefault<bool>(named, 'numbered', true);
        return LatexMacros.heading(text, level, label: label, numbered: numbered);
      },
      'paragraph': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'paragraph');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'paragraph');
        return LatexMacros.paragraph(text);
      },
      'bold': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'bold');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'bold');
        return LatexMacros.bold(text);
      },
      'italic': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'italic');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'italic');
        return LatexMacros.italic(text);
      },
      'inlineCode': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'inlineCode');
        final code = D4.getRequiredArg<String>(positional, 0, 'code', 'inlineCode');
        return LatexMacros.inlineCode(code);
      },
      'codeBlock': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'codeBlock');
        final code = D4.getRequiredArg<String>(positional, 0, 'code', 'codeBlock');
        final language = D4.getOptionalNamedArg<String?>(named, 'language');
        return LatexMacros.codeBlock(code, language: language);
      },
      'asciiDiagram': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'asciiDiagram');
        final diagram = D4.getRequiredArg<String>(positional, 0, 'diagram', 'asciiDiagram');
        return LatexMacros.asciiDiagram(diagram);
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
        return LatexMacros.table(headers, rows, alignments);
      },
      'unorderedList': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'unorderedList');
        if (positional.isEmpty) {
          throw ArgumentError('unorderedList: Missing required argument "items" at position 0');
        }
        final items = D4.coerceList<String>(positional[0], 'items');
        return LatexMacros.unorderedList(items);
      },
      'orderedList': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'orderedList');
        if (positional.isEmpty) {
          throw ArgumentError('orderedList: Missing required argument "items" at position 0');
        }
        final items = D4.coerceList<String>(positional[0], 'items');
        return LatexMacros.orderedList(items);
      },
      'blockQuote': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'blockQuote');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'blockQuote');
        return LatexMacros.blockQuote(text);
      },
      'horizontalRule': (visitor, positional, named, typeArgs) {
        return LatexMacros.horizontalRule();
      },
      'link': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'link');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'link');
        final url = D4.getRequiredArg<String>(positional, 1, 'url', 'link');
        return LatexMacros.link(text, url);
      },
      'image': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'image');
        final altText = D4.getRequiredArg<String>(positional, 0, 'altText', 'image');
        final url = D4.getRequiredArg<String>(positional, 1, 'url', 'image');
        return LatexMacros.image(altText, url);
      },
      'escapeText': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'escapeText');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'escapeText');
        return LatexMacros.escapeText(text);
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
    nativeType: $tom_md2latex_1.MarkdownParserOptions,
    name: 'MarkdownParserOptions',
    isAssignable: (v) => v is $tom_md2latex_1.MarkdownParserOptions,
    constructors: {
      '': (visitor, positional, named) {
        final detectAsciiDiagrams = D4.getNamedArgWithDefault<bool>(named, 'detectAsciiDiagrams', true);
        final asciiDiagramPatterns = named.containsKey('asciiDiagramPatterns') && named['asciiDiagramPatterns'] != null
            ? D4.coerceList<String>(named['asciiDiagramPatterns'], 'asciiDiagramPatterns')
            : const ['├', '└', '│', '─', '┬', '┴', '┼', '┤', '┌', '┐', '┘', '┐', '+--', '|--', '\\--', '+-', '|-', '/---', '\\---', '[', ']'];
        return $tom_md2latex_1.MarkdownParserOptions(detectAsciiDiagrams: detectAsciiDiagrams, asciiDiagramPatterns: asciiDiagramPatterns);
      },
    },
    getters: {
      'detectAsciiDiagrams': (visitor, target) => D4.validateTarget<$tom_md2latex_1.MarkdownParserOptions>(target, 'MarkdownParserOptions').detectAsciiDiagrams,
      'asciiDiagramPatterns': (visitor, target) => D4.validateTarget<$tom_md2latex_1.MarkdownParserOptions>(target, 'MarkdownParserOptions').asciiDiagramPatterns,
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
    nativeType: MarkdownParser,
    name: 'MarkdownParser',
    isAssignable: (v) => v is MarkdownParser,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'MarkdownParser');
        final content = D4.getRequiredArg<String>(positional, 0, 'content', 'MarkdownParser');
        final options = D4.getNamedArgWithDefault<$tom_md2latex_1.MarkdownParserOptions>(named, 'options', const $tom_md2latex_1.MarkdownParserOptions());
        return MarkdownParser(content, options: options);
      },
    },
    getters: {
      'content': (visitor, target) => D4.validateTarget<MarkdownParser>(target, 'MarkdownParser').content,
      'options': (visitor, target) => D4.validateTarget<MarkdownParser>(target, 'MarkdownParser').options,
    },
    methods: {
      'parse': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MarkdownParser>(target, 'MarkdownParser');
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
    nativeType: $tom_md2latex_1.ParsedMarkdown,
    name: 'ParsedMarkdown',
    isAssignable: (v) => v is $tom_md2latex_1.ParsedMarkdown,
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
        final elements = D4.coerceList<$tom_md2latex_1.MarkdownElement>(named['elements'], 'elements');
        return $tom_md2latex_1.ParsedMarkdown(title: title, author: author, date: date, generateToc: generateToc, tocDepth: tocDepth, elements: elements);
      },
    },
    getters: {
      'title': (visitor, target) => D4.validateTarget<$tom_md2latex_1.ParsedMarkdown>(target, 'ParsedMarkdown').title,
      'author': (visitor, target) => D4.validateTarget<$tom_md2latex_1.ParsedMarkdown>(target, 'ParsedMarkdown').author,
      'date': (visitor, target) => D4.validateTarget<$tom_md2latex_1.ParsedMarkdown>(target, 'ParsedMarkdown').date,
      'generateToc': (visitor, target) => D4.validateTarget<$tom_md2latex_1.ParsedMarkdown>(target, 'ParsedMarkdown').generateToc,
      'tocDepth': (visitor, target) => D4.validateTarget<$tom_md2latex_1.ParsedMarkdown>(target, 'ParsedMarkdown').tocDepth,
      'elements': (visitor, target) => D4.validateTarget<$tom_md2latex_1.ParsedMarkdown>(target, 'ParsedMarkdown').elements,
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
    nativeType: $tom_md2latex_1.MarkdownElement,
    name: 'MarkdownElement',
    isAssignable: (v) => v is $tom_md2latex_1.MarkdownElement,
    constructors: {
    },
    constructorSignatures: {
      '': 'MarkdownElement()',
    },
  );
}

// =============================================================================
// HeadingElement Bridge
// =============================================================================

BridgedClass _createHeadingElementBridge() {
  return BridgedClass(
    nativeType: HeadingElement,
    name: 'HeadingElement',
    isAssignable: (v) => v is HeadingElement,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'HeadingElement');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'HeadingElement');
        final level = D4.getRequiredArg<int>(positional, 1, 'level', 'HeadingElement');
        return HeadingElement(text, level);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<HeadingElement>(target, 'HeadingElement').text,
      'level': (visitor, target) => D4.validateTarget<HeadingElement>(target, 'HeadingElement').level,
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
    nativeType: ParagraphElement,
    name: 'ParagraphElement',
    isAssignable: (v) => v is ParagraphElement,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'ParagraphElement');
        return ParagraphElement(text: text);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<ParagraphElement>(target, 'ParagraphElement').text,
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
    nativeType: CodeBlockElement,
    name: 'CodeBlockElement',
    isAssignable: (v) => v is CodeBlockElement,
    constructors: {
      '': (visitor, positional, named) {
        final code = D4.getRequiredNamedArg<String>(named, 'code', 'CodeBlockElement');
        final language = D4.getOptionalNamedArg<String?>(named, 'language');
        final isAsciiDiagram = D4.getNamedArgWithDefault<bool>(named, 'isAsciiDiagram', false);
        return CodeBlockElement(code: code, language: language, isAsciiDiagram: isAsciiDiagram);
      },
    },
    getters: {
      'code': (visitor, target) => D4.validateTarget<CodeBlockElement>(target, 'CodeBlockElement').code,
      'language': (visitor, target) => D4.validateTarget<CodeBlockElement>(target, 'CodeBlockElement').language,
      'isAsciiDiagram': (visitor, target) => D4.validateTarget<CodeBlockElement>(target, 'CodeBlockElement').isAsciiDiagram,
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
    nativeType: InlineCodeElement,
    name: 'InlineCodeElement',
    isAssignable: (v) => v is InlineCodeElement,
    constructors: {
      '': (visitor, positional, named) {
        final code = D4.getRequiredNamedArg<String>(named, 'code', 'InlineCodeElement');
        return InlineCodeElement(code: code);
      },
    },
    getters: {
      'code': (visitor, target) => D4.validateTarget<InlineCodeElement>(target, 'InlineCodeElement').code,
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
    nativeType: TableElement,
    name: 'TableElement',
    isAssignable: (v) => v is TableElement,
    constructors: {
      '': (visitor, positional, named) {
        if (!named.containsKey('headers') || named['headers'] == null) {
          throw ArgumentError('TableElement: Missing required named argument "headers"');
        }
        final headers = D4.coerceList<String>(named['headers'], 'headers');
        if (!named.containsKey('rows') || named['rows'] == null) {
          throw ArgumentError('TableElement: Missing required named argument "rows"');
        }
        final rows = D4.coerceList<List<String>>(named['rows'], 'rows');
        if (!named.containsKey('alignments') || named['alignments'] == null) {
          throw ArgumentError('TableElement: Missing required named argument "alignments"');
        }
        final alignments = D4.coerceList<String>(named['alignments'], 'alignments');
        return TableElement(headers: headers, rows: rows, alignments: alignments);
      },
    },
    getters: {
      'headers': (visitor, target) => D4.validateTarget<TableElement>(target, 'TableElement').headers,
      'rows': (visitor, target) => D4.validateTarget<TableElement>(target, 'TableElement').rows,
      'alignments': (visitor, target) => D4.validateTarget<TableElement>(target, 'TableElement').alignments,
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
    nativeType: UnorderedListElement,
    name: 'UnorderedListElement',
    isAssignable: (v) => v is UnorderedListElement,
    constructors: {
      '': (visitor, positional, named) {
        if (!named.containsKey('items') || named['items'] == null) {
          throw ArgumentError('UnorderedListElement: Missing required named argument "items"');
        }
        final items = D4.coerceList<String>(named['items'], 'items');
        return UnorderedListElement(items: items);
      },
    },
    getters: {
      'items': (visitor, target) => D4.validateTarget<UnorderedListElement>(target, 'UnorderedListElement').items,
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
    nativeType: OrderedListElement,
    name: 'OrderedListElement',
    isAssignable: (v) => v is OrderedListElement,
    constructors: {
      '': (visitor, positional, named) {
        if (!named.containsKey('items') || named['items'] == null) {
          throw ArgumentError('OrderedListElement: Missing required named argument "items"');
        }
        final items = D4.coerceList<String>(named['items'], 'items');
        return OrderedListElement(items: items);
      },
    },
    getters: {
      'items': (visitor, target) => D4.validateTarget<OrderedListElement>(target, 'OrderedListElement').items,
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
    nativeType: BlockQuoteElement,
    name: 'BlockQuoteElement',
    isAssignable: (v) => v is BlockQuoteElement,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'BlockQuoteElement');
        return BlockQuoteElement(text: text);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<BlockQuoteElement>(target, 'BlockQuoteElement').text,
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
    nativeType: HorizontalRuleElement,
    name: 'HorizontalRuleElement',
    isAssignable: (v) => v is HorizontalRuleElement,
    constructors: {
      '': (visitor, positional, named) {
        return HorizontalRuleElement();
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
    nativeType: LinkElement,
    name: 'LinkElement',
    isAssignable: (v) => v is LinkElement,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'LinkElement');
        final url = D4.getRequiredNamedArg<String>(named, 'url', 'LinkElement');
        return LinkElement(text: text, url: url);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<LinkElement>(target, 'LinkElement').text,
      'url': (visitor, target) => D4.validateTarget<LinkElement>(target, 'LinkElement').url,
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
    nativeType: ImageElement,
    name: 'ImageElement',
    isAssignable: (v) => v is ImageElement,
    constructors: {
      '': (visitor, positional, named) {
        final altText = D4.getRequiredNamedArg<String>(named, 'altText', 'ImageElement');
        final url = D4.getRequiredNamedArg<String>(named, 'url', 'ImageElement');
        return ImageElement(altText: altText, url: url);
      },
    },
    getters: {
      'altText': (visitor, target) => D4.validateTarget<ImageElement>(target, 'ImageElement').altText,
      'url': (visitor, target) => D4.validateTarget<ImageElement>(target, 'ImageElement').url,
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
    nativeType: RawTextElement,
    name: 'RawTextElement',
    isAssignable: (v) => v is RawTextElement,
    constructors: {
      '': (visitor, positional, named) {
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'RawTextElement');
        return RawTextElement(text: text);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<RawTextElement>(target, 'RawTextElement').text,
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
    nativeType: MdLatexConverter,
    name: 'MdLatexConverter',
    isAssignable: (v) => v is MdLatexConverter,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'MdLatexConverter');
        final sourcePath = D4.getRequiredArg<String>(positional, 0, 'sourcePath', 'MdLatexConverter');
        final options = D4.getOptionalNamedArg<$tom_md2latex_2.MdLatexConverterOptions?>(named, 'options');
        return MdLatexConverter(sourcePath, options: options);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<MdLatexConverter>(target, 'MdLatexConverter').sourcePath,
      'options': (visitor, target) => D4.validateTarget<MdLatexConverter>(target, 'MdLatexConverter').options,
    },
    methods: {
      'findMarkdownFiles': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MdLatexConverter>(target, 'MdLatexConverter');
        return t.findMarkdownFiles();
      },
      'convertAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MdLatexConverter>(target, 'MdLatexConverter');
        final outputDir = D4.getRequiredNamedArg<String>(named, 'outputDir', 'convertAll');
        return t.convertAll(outputDir: outputDir);
      },
      'convertFile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MdLatexConverter>(target, 'MdLatexConverter');
        D4.requireMinArgs(positional, 1, 'convertFile');
        final file = D4.getRequiredArg<File>(positional, 0, 'file', 'convertFile');
        final outputDir = D4.getRequiredNamedArg<String>(named, 'outputDir', 'convertFile');
        return t.convertFile(file, outputDir: outputDir);
      },
      'convert': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MdLatexConverter>(target, 'MdLatexConverter');
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
    nativeType: $tom_md2latex_2.MdLatexConverterOptions,
    name: 'MdLatexConverterOptions',
    isAssignable: (v) => v is $tom_md2latex_2.MdLatexConverterOptions,
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
        final parserOptions = D4.getNamedArgWithDefault<$tom_md2latex_1.MarkdownParserOptions>(named, 'parserOptions', const $tom_md2latex_1.MarkdownParserOptions());
        return $tom_md2latex_2.MdLatexConverterOptions(excludePatterns: excludePatterns, generatePreamble: generatePreamble, documentClass: documentClass, author: author, generateToc: generateToc, tocDepth: tocDepth, parserOptions: parserOptions);
      },
    },
    getters: {
      'excludePatterns': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').excludePatterns,
      'generatePreamble': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').generatePreamble,
      'documentClass': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').documentClass,
      'author': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').author,
      'generateToc': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').generateToc,
      'tocDepth': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').tocDepth,
      'parserOptions': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterOptions>(target, 'MdLatexConverterOptions').parserOptions,
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
    nativeType: $tom_md2latex_2.MdLatexConverterResult,
    name: 'MdLatexConverterResult',
    isAssignable: (v) => v is $tom_md2latex_2.MdLatexConverterResult,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_md2latex_2.MdLatexConverterResult();
      },
    },
    getters: {
      'converted': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterResult>(target, 'MdLatexConverterResult').converted,
      'errors': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterResult>(target, 'MdLatexConverterResult').errors,
      'isSuccess': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterResult>(target, 'MdLatexConverterResult').isSuccess,
      'totalProcessed': (visitor, target) => D4.validateTarget<$tom_md2latex_2.MdLatexConverterResult>(target, 'MdLatexConverterResult').totalProcessed,
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
    nativeType: $tom_md2latex_2.ConvertedFile,
    name: 'ConvertedFile',
    isAssignable: (v) => v is $tom_md2latex_2.ConvertedFile,
    constructors: {
      '': (visitor, positional, named) {
        final sourcePath = D4.getRequiredNamedArg<String>(named, 'sourcePath', 'ConvertedFile');
        final outputPath = D4.getRequiredNamedArg<String>(named, 'outputPath', 'ConvertedFile');
        final parsed = D4.getRequiredNamedArg<$tom_md2latex_1.ParsedMarkdown>(named, 'parsed', 'ConvertedFile');
        return $tom_md2latex_2.ConvertedFile(sourcePath: sourcePath, outputPath: outputPath, parsed: parsed);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ConvertedFile>(target, 'ConvertedFile').sourcePath,
      'outputPath': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ConvertedFile>(target, 'ConvertedFile').outputPath,
      'parsed': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ConvertedFile>(target, 'ConvertedFile').parsed,
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
    nativeType: $tom_md2latex_2.ConversionError,
    name: 'ConversionError',
    isAssignable: (v) => v is $tom_md2latex_2.ConversionError,
    constructors: {
      '': (visitor, positional, named) {
        final sourcePath = D4.getRequiredNamedArg<String>(named, 'sourcePath', 'ConversionError');
        final message = D4.getRequiredNamedArg<String>(named, 'message', 'ConversionError');
        final stackTrace = D4.getOptionalNamedArg<StackTrace?>(named, 'stackTrace');
        return $tom_md2latex_2.ConversionError(sourcePath: sourcePath, message: message, stackTrace: stackTrace);
      },
    },
    getters: {
      'sourcePath': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ConversionError>(target, 'ConversionError').sourcePath,
      'message': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ConversionError>(target, 'ConversionError').message,
      'stackTrace': (visitor, target) => D4.validateTarget<$tom_md2latex_2.ConversionError>(target, 'ConversionError').stackTrace,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_md2latex_2.ConversionError>(target, 'ConversionError');
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

