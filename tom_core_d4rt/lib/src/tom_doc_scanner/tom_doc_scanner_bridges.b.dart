// D4rt Bridge - Generated file, do not edit
// Sources: 6 files
// Generated: 2026-08-18T23:05:11.633237

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls, invalid_use_of_protected_member, unnecessary_non_null_assertion, invalid_use_of_visible_for_testing_member, unnecessary_cast, unused_local_variable, no_leading_underscores_for_local_identifiers, prefer_is_empty, unnecessary_question_mark, unreachable_switch_case, unintended_html_in_doc_comment, empty_constructor_bodies, prefer_const_constructors_in_immutables, prefer_final_fields, unused_field, must_call_super, no_logic_in_create_state, use_key_in_widget_constructors, annotate_overrides, non_const_argument_for_const_parameter, unnecessary_import

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';

import 'package:tom_doc_scanner/src/doc_scanner.dart' as $tom_doc_scanner_1;
import 'package:tom_doc_scanner/src/doc_scanner_factory.dart' as $tom_doc_scanner_2;
import 'package:tom_doc_scanner/src/markdown_parser.dart' as $tom_doc_scanner_3;
import 'package:tom_doc_scanner/src/models/document.dart' as $tom_doc_scanner_4;
import 'package:tom_doc_scanner/src/models/document_folder.dart' as $tom_doc_scanner_5;
import 'package:tom_doc_scanner/src/models/section.dart' as $tom_doc_scanner_6;

/// Bridge class for tom_doc_scanner module.
class TomDocScannerBridge {
  /// Returns all bridge class definitions.
  ///
  /// Eager — building every class. Prefer [bridgeClassThunks] +
  /// [bridgeClassTypes] for lazy registration (Step #17); this remains
  /// for diagnostics and callers that need the full list.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createDocScannerBridge(),
      _createDocScannerFactoryBridge(),
      _createParsedHeadlineBridge(),
      _createMarkdownParserBridge(),
      _createDocumentBridge(),
      _createDocumentFolderBridge(),
      _createSectionBridge(),
    ];
  }

  /// Returns deferred factory thunks keyed by class name.
  ///
  /// Each thunk builds one class's [BridgedClass] on demand. Plugs into
  /// the interpreter's lazy registry via [registerBridges] (Step #17).
  static Map<String, BridgedClass Function()> bridgeClassThunks() {
    return {
      'DocScanner': _createDocScannerBridge,
      'DocScannerFactory': _createDocScannerFactoryBridge,
      'ParsedHeadline': _createParsedHeadlineBridge,
      'MarkdownParser': _createMarkdownParserBridge,
      'Document': _createDocumentBridge,
      'DocumentFolder': _createDocumentFolderBridge,
      'Section': _createSectionBridge,
    };
  }

  /// Returns native [Type]s keyed by class name, parallel to
  /// [bridgeClassThunks] (Step #17). Used to register the native-type
  /// lookup thunk without building the BridgedClass.
  static Map<String, Type> bridgeClassTypes() {
    return {
      'DocScanner': $tom_doc_scanner_1.DocScanner,
      'DocScannerFactory': $tom_doc_scanner_2.DocScannerFactory,
      'ParsedHeadline': $tom_doc_scanner_3.ParsedHeadline,
      'MarkdownParser': $tom_doc_scanner_3.MarkdownParser,
      'Document': $tom_doc_scanner_4.Document,
      'DocumentFolder': $tom_doc_scanner_5.DocumentFolder,
      'Section': $tom_doc_scanner_6.Section,
    };
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'DocScanner': 'package:tom_doc_scanner/src/doc_scanner.dart',
      'DocScannerFactory': 'package:tom_doc_scanner/src/doc_scanner_factory.dart',
      'ParsedHeadline': 'package:tom_doc_scanner/src/markdown_parser.dart',
      'MarkdownParser': 'package:tom_doc_scanner/src/markdown_parser.dart',
      'Document': 'package:tom_doc_scanner/src/models/document.dart',
      'DocumentFolder': 'package:tom_doc_scanner/src/models/document_folder.dart',
      'Section': 'package:tom_doc_scanner/src/models/section.dart',
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
      'Document': ['Section'],
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
      (source: 'package:tom_doc_scanner/tom_doc_scanner.dart', target: 'package:tom_doc_scanner/src/doc_scanner.dart', show: {'DocScanner'}, hide: null),
      (source: 'package:tom_doc_scanner/tom_doc_scanner.dart', target: 'package:tom_doc_scanner/src/doc_scanner_factory.dart', show: {'DocScannerFactory'}, hide: null),
      (source: 'package:tom_doc_scanner/tom_doc_scanner.dart', target: 'package:tom_doc_scanner/src/markdown_parser.dart', show: {'ParsedHeadline', 'MarkdownParser'}, hide: null),
      (source: 'package:tom_doc_scanner/tom_doc_scanner.dart', target: 'package:tom_doc_scanner/src/models/document.dart', show: {'Document'}, hide: null),
      (source: 'package:tom_doc_scanner/tom_doc_scanner.dart', target: 'package:tom_doc_scanner/src/models/document_folder.dart', show: {'DocumentFolder'}, hide: null),
      (source: 'package:tom_doc_scanner/tom_doc_scanner.dart', target: 'package:tom_doc_scanner/src/models/section.dart', show: {'Section'}, hide: null),
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
      'package:tom_doc_scanner/src/doc_scanner.dart',
      'package:tom_doc_scanner/src/doc_scanner_factory.dart',
      'package:tom_doc_scanner/src/markdown_parser.dart',
      'package:tom_doc_scanner/src/models/document.dart',
      'package:tom_doc_scanner/src/models/document_folder.dart',
      'package:tom_doc_scanner/src/models/section.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    return "import 'package:tom_doc_scanner/tom_doc_scanner.dart';";
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
// DocScanner Bridge
// =============================================================================

BridgedClass _createDocScannerBridge() {
  return BridgedClass(
    nativeType: $tom_doc_scanner_1.DocScanner,
    name: 'DocScanner',
    isAssignable: (v) => v is $tom_doc_scanner_1.DocScanner,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_doc_scanner_1.DocScanner();
      },
    },
    staticMethods: {
      'scanTree': (visitor, positional, named, typeArgs) {
        final path = D4.getRequiredNamedArg<String>(named, 'path', 'scanTree');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        final factory = D4.getOptionalNamedArg<$tom_doc_scanner_2.DocScannerFactory?>(named, 'factory');
        return $tom_doc_scanner_1.DocScanner.scanTree(path: path, workspaceRoot: workspaceRoot, factory: factory);
      },
      'scanTreeSync': (visitor, positional, named, typeArgs) {
        final path = D4.getRequiredNamedArg<String>(named, 'path', 'scanTreeSync');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        final factory = D4.getOptionalNamedArg<$tom_doc_scanner_2.DocScannerFactory?>(named, 'factory');
        return $tom_doc_scanner_1.DocScanner.scanTreeSync(path: path, workspaceRoot: workspaceRoot, factory: factory);
      },
      'scanDocuments': (visitor, positional, named, typeArgs) {
        if (!named.containsKey('filepaths') || named['filepaths'] == null) {
          throw ArgumentError('scanDocuments: Missing required named argument "filepaths"');
        }
        final filepaths = D4.coerceList<String>(named['filepaths'], 'filepaths');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        final factory = D4.getOptionalNamedArg<$tom_doc_scanner_2.DocScannerFactory?>(named, 'factory');
        return $tom_doc_scanner_1.DocScanner.scanDocuments(filepaths: filepaths, workspaceRoot: workspaceRoot, factory: factory);
      },
      'scanDocumentsSync': (visitor, positional, named, typeArgs) {
        if (!named.containsKey('filepaths') || named['filepaths'] == null) {
          throw ArgumentError('scanDocumentsSync: Missing required named argument "filepaths"');
        }
        final filepaths = D4.coerceList<String>(named['filepaths'], 'filepaths');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        final factory = D4.getOptionalNamedArg<$tom_doc_scanner_2.DocScannerFactory?>(named, 'factory');
        return $tom_doc_scanner_1.DocScanner.scanDocumentsSync(filepaths: filepaths, workspaceRoot: workspaceRoot, factory: factory);
      },
      'scanDocument': (visitor, positional, named, typeArgs) {
        final filepath = D4.getRequiredNamedArg<String>(named, 'filepath', 'scanDocument');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        final factory = D4.getOptionalNamedArg<$tom_doc_scanner_2.DocScannerFactory?>(named, 'factory');
        return $tom_doc_scanner_1.DocScanner.scanDocument(filepath: filepath, workspaceRoot: workspaceRoot, factory: factory);
      },
      'scanDocumentSync': (visitor, positional, named, typeArgs) {
        final filepath = D4.getRequiredNamedArg<String>(named, 'filepath', 'scanDocumentSync');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        final factory = D4.getOptionalNamedArg<$tom_doc_scanner_2.DocScannerFactory?>(named, 'factory');
        return $tom_doc_scanner_1.DocScanner.scanDocumentSync(filepath: filepath, workspaceRoot: workspaceRoot, factory: factory);
      },
    },
    constructorSignatures: {
      '': 'DocScanner()',
    },
    staticMethodSignatures: {
      'scanTree': 'Future<DocumentFolder> scanTree({required String path, String? workspaceRoot, DocScannerFactory? factory})',
      'scanTreeSync': 'DocumentFolder scanTreeSync({required String path, String? workspaceRoot, DocScannerFactory? factory})',
      'scanDocuments': 'Future<List<Document>> scanDocuments({required List<String> filepaths, String? workspaceRoot, DocScannerFactory? factory})',
      'scanDocumentsSync': 'List<Document> scanDocumentsSync({required List<String> filepaths, String? workspaceRoot, DocScannerFactory? factory})',
      'scanDocument': 'Future<Document> scanDocument({required String filepath, String? workspaceRoot, DocScannerFactory? factory})',
      'scanDocumentSync': 'Document scanDocumentSync({required String filepath, String? workspaceRoot, DocScannerFactory? factory})',
    },
  );
}

// =============================================================================
// DocScannerFactory Bridge
// =============================================================================

BridgedClass _createDocScannerFactoryBridge() {
  return BridgedClass(
    nativeType: $tom_doc_scanner_2.DocScannerFactory,
    name: 'DocScannerFactory',
    isAssignable: (v) => v is $tom_doc_scanner_2.DocScannerFactory,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_doc_scanner_2.DocScannerFactory();
      },
    },
    methods: {
      'createSection': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_2.DocScannerFactory>(target, 'DocScannerFactory');
        final index = D4.getRequiredNamedArg<int>(named, 'index', 'createSection');
        final lineNumber = D4.getRequiredNamedArg<int>(named, 'lineNumber', 'createSection');
        final rawHeadline = D4.getRequiredNamedArg<String>(named, 'rawHeadline', 'createSection');
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'createSection');
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'createSection');
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'createSection');
        if (!named.containsKey('fields') || named['fields'] == null) {
          throw ArgumentError('createSection: Missing required named argument "fields"');
        }
        final fields = D4.coerceMap<String, String>(named['fields'], 'fields');
        final sections = D4.coerceListOrNull<$tom_doc_scanner_6.Section>(named['sections'], 'sections');
        return t.createSection(index: index, lineNumber: lineNumber, rawHeadline: rawHeadline, name: name, id: id, text: text, fields: fields, sections: sections);
      },
      'createDocument': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_2.DocScannerFactory>(target, 'DocScannerFactory');
        final index = D4.getRequiredNamedArg<int>(named, 'index', 'createDocument');
        final lineNumber = D4.getRequiredNamedArg<int>(named, 'lineNumber', 'createDocument');
        final rawHeadline = D4.getRequiredNamedArg<String>(named, 'rawHeadline', 'createDocument');
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'createDocument');
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'createDocument');
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'createDocument');
        if (!named.containsKey('fields') || named['fields'] == null) {
          throw ArgumentError('createDocument: Missing required named argument "fields"');
        }
        final fields = D4.coerceMap<String, String>(named['fields'], 'fields');
        final sections = D4.coerceListOrNull<$tom_doc_scanner_6.Section>(named['sections'], 'sections');
        final filenameWithPath = D4.getRequiredNamedArg<String>(named, 'filenameWithPath', 'createDocument');
        final loadTimestamp = D4.getRequiredNamedArg<String>(named, 'loadTimestamp', 'createDocument');
        final filename = D4.getRequiredNamedArg<String>(named, 'filename', 'createDocument');
        final fullPath = D4.getRequiredNamedArg<String>(named, 'fullPath', 'createDocument');
        final workspacePath = D4.getRequiredNamedArg<String>(named, 'workspacePath', 'createDocument');
        final project = D4.getRequiredNamedArg<String>(named, 'project', 'createDocument');
        final projectPath = D4.getRequiredNamedArg<String>(named, 'projectPath', 'createDocument');
        final workspaceRoot = D4.getRequiredNamedArg<String>(named, 'workspaceRoot', 'createDocument');
        final projectRoot = D4.getRequiredNamedArg<String>(named, 'projectRoot', 'createDocument');
        final hierarchyDepth = D4.getRequiredNamedArg<int>(named, 'hierarchyDepth', 'createDocument');
        return t.createDocument(index: index, lineNumber: lineNumber, rawHeadline: rawHeadline, name: name, id: id, text: text, fields: fields, sections: sections, filenameWithPath: filenameWithPath, loadTimestamp: loadTimestamp, filename: filename, fullPath: fullPath, workspacePath: workspacePath, project: project, projectPath: projectPath, workspaceRoot: workspaceRoot, projectRoot: projectRoot, hierarchyDepth: hierarchyDepth);
      },
    },
    constructorSignatures: {
      '': 'const DocScannerFactory()',
    },
    methodSignatures: {
      'createSection': 'Section createSection({required int index, required int lineNumber, required String rawHeadline, required String name, required String id, required String text, required Map<String, String> fields, List<Section>? sections})',
      'createDocument': 'Document createDocument({required int index, required int lineNumber, required String rawHeadline, required String name, required String id, required String text, required Map<String, String> fields, List<Section>? sections, required String filenameWithPath, required String loadTimestamp, required String filename, required String fullPath, required String workspacePath, required String project, required String projectPath, required String workspaceRoot, required String projectRoot, required int hierarchyDepth})',
    },
  );
}

// =============================================================================
// ParsedHeadline Bridge
// =============================================================================

BridgedClass _createParsedHeadlineBridge() {
  return BridgedClass(
    nativeType: $tom_doc_scanner_3.ParsedHeadline,
    name: 'ParsedHeadline',
    isAssignable: (v) => v is $tom_doc_scanner_3.ParsedHeadline,
    constructors: {
      '': (visitor, positional, named) {
        final level = D4.getRequiredNamedArg<int>(named, 'level', 'ParsedHeadline');
        final lineNumber = D4.getRequiredNamedArg<int>(named, 'lineNumber', 'ParsedHeadline');
        final rawHeadline = D4.getRequiredNamedArg<String>(named, 'rawHeadline', 'ParsedHeadline');
        final explicitId = D4.getOptionalNamedArg<String?>(named, 'explicitId');
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'ParsedHeadline');
        final fields = named.containsKey('fields') && named['fields'] != null
            ? D4.coerceMap<String, String>(named['fields'], 'fields')
            : const <String, String>{};
        return $tom_doc_scanner_3.ParsedHeadline(level: level, lineNumber: lineNumber, rawHeadline: rawHeadline, explicitId: explicitId, text: text, fields: fields);
      },
    },
    getters: {
      'level': (visitor, target) => D4.validateTarget<$tom_doc_scanner_3.ParsedHeadline>(target, 'ParsedHeadline').level,
      'lineNumber': (visitor, target) => D4.validateTarget<$tom_doc_scanner_3.ParsedHeadline>(target, 'ParsedHeadline').lineNumber,
      'rawHeadline': (visitor, target) => D4.validateTarget<$tom_doc_scanner_3.ParsedHeadline>(target, 'ParsedHeadline').rawHeadline,
      'explicitId': (visitor, target) => D4.validateTarget<$tom_doc_scanner_3.ParsedHeadline>(target, 'ParsedHeadline').explicitId,
      'text': (visitor, target) => D4.validateTarget<$tom_doc_scanner_3.ParsedHeadline>(target, 'ParsedHeadline').text,
      'fields': (visitor, target) => D4.validateTarget<$tom_doc_scanner_3.ParsedHeadline>(target, 'ParsedHeadline').fields,
    },
    constructorSignatures: {
      '': 'const ParsedHeadline({required int level, required int lineNumber, required String rawHeadline, String? explicitId, required String text, Map<String, String> fields = const {}})',
    },
    getterSignatures: {
      'level': 'int get level',
      'lineNumber': 'int get lineNumber',
      'rawHeadline': 'String get rawHeadline',
      'explicitId': 'String? get explicitId',
      'text': 'String get text',
      'fields': 'Map<String, String> get fields',
    },
  );
}

// =============================================================================
// MarkdownParser Bridge
// =============================================================================

BridgedClass _createMarkdownParserBridge() {
  return BridgedClass(
    nativeType: $tom_doc_scanner_3.MarkdownParser,
    name: 'MarkdownParser',
    isAssignable: (v) => v is $tom_doc_scanner_3.MarkdownParser,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_doc_scanner_3.MarkdownParser();
      },
    },
    staticMethods: {
      'parseHeadlines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parseHeadlines');
        final content = D4.getRequiredArg<String>(positional, 0, 'content', 'parseHeadlines');
        return $tom_doc_scanner_3.MarkdownParser.parseHeadlines(content);
      },
      'extractText': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'extractText');
        final content = D4.getRequiredArg<String>(positional, 0, 'content', 'extractText');
        final startLine = D4.getRequiredArg<int>(positional, 1, 'startLine', 'extractText');
        final endLine = D4.getRequiredArg<int>(positional, 2, 'endLine', 'extractText');
        return $tom_doc_scanner_3.MarkdownParser.extractText(content, startLine, endLine);
      },
      'generateId': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'generateId');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'generateId');
        final parentId = D4.getRequiredArg<String?>(positional, 1, 'parentId', 'generateId');
        final index = D4.getRequiredArg<int>(positional, 2, 'index', 'generateId');
        return $tom_doc_scanner_3.MarkdownParser.generateId(text, parentId, index);
      },
      'calculateMaxDepth': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'calculateMaxDepth');
        if (positional.isEmpty) {
          throw ArgumentError('calculateMaxDepth: Missing required argument "headlines" at position 0');
        }
        final headlines = D4.coerceList<($tom_doc_scanner_3.ParsedHeadline, int, int)>(positional[0], 'headlines');
        return $tom_doc_scanner_3.MarkdownParser.calculateMaxDepth(headlines);
      },
    },
    constructorSignatures: {
      '': 'MarkdownParser()',
    },
    staticMethodSignatures: {
      'parseHeadlines': 'List<(ParsedHeadline, int, int)> parseHeadlines(String content)',
      'extractText': 'String extractText(String content, int startLine, int endLine)',
      'generateId': 'String generateId(String text, String? parentId, int index)',
      'calculateMaxDepth': 'int calculateMaxDepth(List<(ParsedHeadline, int, int)> headlines)',
    },
  );
}

// =============================================================================
// Document Bridge
// =============================================================================

BridgedClass _createDocumentBridge() {
  return BridgedClass(
    nativeType: $tom_doc_scanner_4.Document,
    name: 'Document',
    isAssignable: (v) => v is $tom_doc_scanner_4.Document,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final index = D4.getRequiredNamedArg<int>(named, 'index', 'Document');
        final lineNumber = D4.getRequiredNamedArg<int>(named, 'lineNumber', 'Document');
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'Document');
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'Document');
        final rawHeadline = D4.getRequiredNamedArg<String>(named, 'rawHeadline', 'Document');
        if (!named.containsKey('fields') || named['fields'] == null) {
          throw ArgumentError('Document: Missing required named argument "fields"');
        }
        final fields = D4.coerceMap<String, String>(named['fields'], 'fields');
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'Document');
        final sections = D4.coerceListOrNull<$tom_doc_scanner_6.Section>(named['sections'], 'sections');
        final filenameWithPath = D4.getRequiredNamedArg<String>(named, 'filenameWithPath', 'Document');
        final loadTimestamp = D4.getRequiredNamedArg<String>(named, 'loadTimestamp', 'Document');
        final filename = D4.getRequiredNamedArg<String>(named, 'filename', 'Document');
        final fullPath = D4.getRequiredNamedArg<String>(named, 'fullPath', 'Document');
        final workspacePath = D4.getRequiredNamedArg<String>(named, 'workspacePath', 'Document');
        final project = D4.getRequiredNamedArg<String>(named, 'project', 'Document');
        final projectPath = D4.getRequiredNamedArg<String>(named, 'projectPath', 'Document');
        final workspaceRoot = D4.getRequiredNamedArg<String>(named, 'workspaceRoot', 'Document');
        final projectRoot = D4.getRequiredNamedArg<String>(named, 'projectRoot', 'Document');
        final hierarchyDepth = D4.getRequiredNamedArg<int>(named, 'hierarchyDepth', 'Document');
        return $tom_doc_scanner_4.Document(index: index, lineNumber: lineNumber, name: name, id: id, rawHeadline: rawHeadline, fields: fields, text: text, sections: sections, filenameWithPath: filenameWithPath, loadTimestamp: loadTimestamp, filename: filename, fullPath: fullPath, workspacePath: workspacePath, project: project, projectPath: projectPath, workspaceRoot: workspaceRoot, projectRoot: projectRoot, hierarchyDepth: hierarchyDepth);
      },
      'fromJson': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Document');
        if (positional.isEmpty) {
          throw ArgumentError('Document: Missing required argument "json" at position 0');
        }
        final json = D4.coerceMap<String, dynamic>(positional[0], 'json');
        return $tom_doc_scanner_4.Document.fromJson(json);
      },
    },
    getters: {
      'index': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').index,
      'lineNumber': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').lineNumber,
      'rawHeadline': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').rawHeadline,
      'name': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').name,
      'id': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').id,
      'text': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').text,
      'fields': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').fields,
      'sections': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').sections,
      'filenameWithPath': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').filenameWithPath,
      'loadTimestamp': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').loadTimestamp,
      'filename': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').filename,
      'fullPath': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').fullPath,
      'workspacePath': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').workspacePath,
      'project': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').project,
      'projectPath': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').projectPath,
      'workspaceRoot': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').workspaceRoot,
      'projectRoot': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').projectRoot,
      'hierarchyDepth': (visitor, target) => D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document').hierarchyDepth,
    },
    methods: {
      'toJson': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document');
        return t.toJson();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_4.Document>(target, 'Document');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const Document({required int index, required int lineNumber, required String name, required String id, required String rawHeadline, required Map<String, String> fields, required String text, List<Section>? sections, required String filenameWithPath, required String loadTimestamp, required String filename, required String fullPath, required String workspacePath, required String project, required String projectPath, required String workspaceRoot, required String projectRoot, required int hierarchyDepth})',
      'fromJson': 'factory Document.fromJson(Map<String, dynamic> json)',
    },
    methodSignatures: {
      'toJson': 'Map<String, dynamic> toJson()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'index': 'int get index',
      'lineNumber': 'int get lineNumber',
      'rawHeadline': 'String get rawHeadline',
      'name': 'String get name',
      'id': 'String get id',
      'text': 'String get text',
      'fields': 'Map<String, String> get fields',
      'sections': 'List<Section>? get sections',
      'filenameWithPath': 'String get filenameWithPath',
      'loadTimestamp': 'String get loadTimestamp',
      'filename': 'String get filename',
      'fullPath': 'String get fullPath',
      'workspacePath': 'String get workspacePath',
      'project': 'String get project',
      'projectPath': 'String get projectPath',
      'workspaceRoot': 'String get workspaceRoot',
      'projectRoot': 'String get projectRoot',
      'hierarchyDepth': 'int get hierarchyDepth',
    },
  );
}

// =============================================================================
// DocumentFolder Bridge
// =============================================================================

BridgedClass _createDocumentFolderBridge() {
  return BridgedClass(
    nativeType: $tom_doc_scanner_5.DocumentFolder,
    name: 'DocumentFolder',
    isAssignable: (v) => v is $tom_doc_scanner_5.DocumentFolder,
    constructors: {
      '': (visitor, positional, named) {
        final foldername = D4.getRequiredNamedArg<String>(named, 'foldername', 'DocumentFolder');
        final workspaceFolderPath = D4.getRequiredNamedArg<String>(named, 'workspaceFolderPath', 'DocumentFolder');
        final absoluteFolderPath = D4.getRequiredNamedArg<String>(named, 'absoluteFolderPath', 'DocumentFolder');
        if (!named.containsKey('documents') || named['documents'] == null) {
          throw ArgumentError('DocumentFolder: Missing required named argument "documents"');
        }
        final documents = D4.coerceList<$tom_doc_scanner_4.Document>(named['documents'], 'documents');
        if (!named.containsKey('folders') || named['folders'] == null) {
          throw ArgumentError('DocumentFolder: Missing required named argument "folders"');
        }
        final folders = D4.coerceList<$tom_doc_scanner_5.DocumentFolder>(named['folders'], 'folders');
        return $tom_doc_scanner_5.DocumentFolder(foldername: foldername, workspaceFolderPath: workspaceFolderPath, absoluteFolderPath: absoluteFolderPath, documents: documents, folders: folders);
      },
      'fromJson': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'DocumentFolder');
        if (positional.isEmpty) {
          throw ArgumentError('DocumentFolder: Missing required argument "json" at position 0');
        }
        final json = D4.coerceMap<String, dynamic>(positional[0], 'json');
        return $tom_doc_scanner_5.DocumentFolder.fromJson(json);
      },
    },
    getters: {
      'foldername': (visitor, target) => D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder').foldername,
      'workspaceFolderPath': (visitor, target) => D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder').workspaceFolderPath,
      'absoluteFolderPath': (visitor, target) => D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder').absoluteFolderPath,
      'documents': (visitor, target) => D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder').documents,
      'folders': (visitor, target) => D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder').folders,
      'allDocuments': (visitor, target) => D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder').allDocuments,
    },
    methods: {
      'toJson': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder');
        return t.toJson();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_5.DocumentFolder>(target, 'DocumentFolder');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const DocumentFolder({required String foldername, required String workspaceFolderPath, required String absoluteFolderPath, required List<Document> documents, required List<DocumentFolder> folders})',
      'fromJson': 'factory DocumentFolder.fromJson(Map<String, dynamic> json)',
    },
    methodSignatures: {
      'toJson': 'Map<String, dynamic> toJson()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'foldername': 'String get foldername',
      'workspaceFolderPath': 'String get workspaceFolderPath',
      'absoluteFolderPath': 'String get absoluteFolderPath',
      'documents': 'List<Document> get documents',
      'folders': 'List<DocumentFolder> get folders',
      'allDocuments': 'List<Document> get allDocuments',
    },
  );
}

// =============================================================================
// Section Bridge
// =============================================================================

BridgedClass _createSectionBridge() {
  return BridgedClass(
    nativeType: $tom_doc_scanner_6.Section,
    name: 'Section',
    isAssignable: (v) => v is $tom_doc_scanner_6.Section,
    constructors: {
      '': (visitor, positional, named) {
        final index = D4.getRequiredNamedArg<int>(named, 'index', 'Section');
        final lineNumber = D4.getRequiredNamedArg<int>(named, 'lineNumber', 'Section');
        final rawHeadline = D4.getRequiredNamedArg<String>(named, 'rawHeadline', 'Section');
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'Section');
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'Section');
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'Section');
        final fields = named.containsKey('fields') && named['fields'] != null
            ? D4.coerceMap<String, String>(named['fields'], 'fields')
            : const <String, String>{};
        final sections = D4.coerceListOrNull<$tom_doc_scanner_6.Section>(named['sections'], 'sections');
        return $tom_doc_scanner_6.Section(index: index, lineNumber: lineNumber, rawHeadline: rawHeadline, name: name, id: id, text: text, fields: fields, sections: sections);
      },
      'fromJson': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Section');
        if (positional.isEmpty) {
          throw ArgumentError('Section: Missing required argument "json" at position 0');
        }
        final json = D4.coerceMap<String, dynamic>(positional[0], 'json');
        return $tom_doc_scanner_6.Section.fromJson(json);
      },
    },
    getters: {
      'index': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').index,
      'lineNumber': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').lineNumber,
      'rawHeadline': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').rawHeadline,
      'name': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').name,
      'id': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').id,
      'text': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').text,
      'fields': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').fields,
      'sections': (visitor, target) => D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section').sections,
    },
    methods: {
      'toJson': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section');
        return t.toJson();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_scanner_6.Section>(target, 'Section');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const Section({required int index, required int lineNumber, required String rawHeadline, required String name, required String id, required String text, Map<String, String> fields = const {}, List<Section>? sections})',
      'fromJson': 'factory Section.fromJson(Map<String, dynamic> json)',
    },
    methodSignatures: {
      'toJson': 'Map<String, dynamic> toJson()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'index': 'int get index',
      'lineNumber': 'int get lineNumber',
      'rawHeadline': 'String get rawHeadline',
      'name': 'String get name',
      'id': 'String get id',
      'text': 'String get text',
      'fields': 'Map<String, String> get fields',
      'sections': 'List<Section>? get sections',
    },
  );
}

