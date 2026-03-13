// D4rt Bridge - Generated file, do not edit
// Sources: 13 files
// Generated: 2026-03-12T17:01:55.156910

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';

import 'package:tom_doc_scanner/src/models/document.dart' as $tom_doc_scanner_1;
import 'package:tom_doc_scanner/src/models/document_folder.dart' as $tom_doc_scanner_2;
import 'package:tom_doc_scanner/src/models/section.dart' as $tom_doc_scanner_3;
import 'package:tom_doc_specs/src/models/schema/doc_spec_schema.dart' as $tom_doc_specs_1;
import 'package:tom_doc_specs/src/models/schema/document_structure.dart' as $tom_doc_specs_2;
import 'package:tom_doc_specs/src/models/schema/form_type_def.dart' as $tom_doc_specs_3;
import 'package:tom_doc_specs/src/models/schema/schema_info.dart' as $tom_doc_specs_4;
import 'package:tom_doc_specs/src/models/schema/section_type_def.dart' as $tom_doc_specs_5;
import 'package:tom_doc_specs/src/models/spec_doc.dart' as $tom_doc_specs_6;
import 'package:tom_doc_specs/src/models/spec_section.dart' as $tom_doc_specs_7;
import 'package:tom_doc_specs/src/models/spec_section_type.dart' as $tom_doc_specs_8;
import 'package:tom_doc_specs/src/validation/validation_error.dart' as $tom_doc_specs_9;
import 'package:tom_doc_scanner/src/doc_scanner_factory.dart' as $aux_tom_doc_scanner;

/// Bridge class for tom_doc_specs module.
class TomDocSpecsBridge {
  /// Returns all bridge class definitions.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createDocSpecsBridge(),
      _createDocSpecsFactoryBridge(),
      _createSpecSectionBridge(),
      _createSpecDocBridge(),
      _createSpecSectionTypeBridge(),
      _createDocSpecSchemaBridge(),
      _createPatternCheckDefBridge(),
      _createSubsectionConstraintBridge(),
      _createSectionTypeDefBridge(),
      _createForEachDefBridge(),
      _createSectionDefBridge(),
      _createSubsectionDefBridge(),
      _createDocumentStructureBridge(),
      _createFormFieldDefBridge(),
      _createFormTypeDefBridge(),
      _createSchemaInfoBridge(),
      _createSchemaFilenameParserBridge(),
      _createSchemaLoaderBridge(),
      _createSchemaResolverBridge(),
      _createSchemaDiscoveryBridge(),
      _createValidationErrorBridge(),
      _createDocSpecsValidatorBridge(),
    ];
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'DocSpecs': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\doc_specs.dart',
      'DocSpecsFactory': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\doc_specs_factory.dart',
      'SpecSection': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\spec_section.dart',
      'SpecDoc': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\spec_doc.dart',
      'SpecSectionType': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\spec_section_type.dart',
      'DocSpecSchema': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\doc_spec_schema.dart',
      'PatternCheckDef': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\section_type_def.dart',
      'SubsectionConstraint': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\section_type_def.dart',
      'SectionTypeDef': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\section_type_def.dart',
      'ForEachDef': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\document_structure.dart',
      'SectionDef': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\document_structure.dart',
      'SubsectionDef': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\document_structure.dart',
      'DocumentStructure': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\document_structure.dart',
      'FormFieldDef': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\form_type_def.dart',
      'FormTypeDef': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\form_type_def.dart',
      'SchemaInfo': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\schema_info.dart',
      'SchemaFilenameParser': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\schema\schema_loader.dart',
      'SchemaLoader': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\schema\schema_loader.dart',
      'SchemaResolver': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\schema\schema_loader.dart',
      'SchemaDiscovery': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\schema\schema_loader.dart',
      'ValidationError': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\validation\validation_error.dart',
      'DocSpecsValidator': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\validation\validator.dart',
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
      BridgedEnumDefinition<$tom_doc_specs_4.SchemaSource>(
        name: 'SchemaSource',
        values: $tom_doc_specs_4.SchemaSource.values,
      ),
      BridgedEnumDefinition<$tom_doc_specs_9.ValidationErrorCategory>(
        name: 'ValidationErrorCategory',
        values: $tom_doc_specs_9.ValidationErrorCategory.values,
      ),
    ];
  }

  /// Returns a map of enum names to their canonical source URIs.
  ///
  /// Used for deduplication when the same enum is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> enumSourceUris() {
    return {
      'SchemaSource': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\schema_info.dart',
      'ValidationErrorCategory': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\validation\validation_error.dart',
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

    // Register bridged enums with source URIs for deduplication
    final enums = bridgedEnums();
    final enumSources = enumSourceUris();
    for (final enumDef in enums) {
      interpreter.registerBridgedEnum(enumDef, importPath, sourceUri: enumSources[enumDef.name]);
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
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\doc_specs.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\doc_specs_factory.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\doc_spec_schema.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\document_structure.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\form_type_def.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\schema_info.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\schema\section_type_def.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\spec_doc.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\spec_section.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\models\spec_section_type.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\schema\schema_loader.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\validation\validation_error.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\ai_build\tom_doc_specs\lib\src\validation\validator.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    return "import 'package:tom_doc_specs/tom_doc_specs.dart';";
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
    'SchemaSource',
    'ValidationErrorCategory',
  ];

}

// =============================================================================
// DocSpecs Bridge
// =============================================================================

BridgedClass _createDocSpecsBridge() {
  return BridgedClass(
    nativeType: DocSpecs,
    name: 'DocSpecs',
    isAssignable: (v) => v is DocSpecs,
    constructors: {
    },
    staticMethods: {
      'scanDocument': (visitor, positional, named, typeArgs) {
        final filePath = D4.getRequiredNamedArg<String>(named, 'filePath', 'scanDocument');
        final schemaId = D4.getOptionalNamedArg<String?>(named, 'schemaId');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.scanDocument(filePath: filePath, schemaId: schemaId, workspaceRoot: workspaceRoot);
      },
      'scanDocumentSync': (visitor, positional, named, typeArgs) {
        final filePath = D4.getRequiredNamedArg<String>(named, 'filePath', 'scanDocumentSync');
        final schemaId = D4.getOptionalNamedArg<String?>(named, 'schemaId');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.scanDocumentSync(filePath: filePath, schemaId: schemaId, workspaceRoot: workspaceRoot);
      },
      'scanDocuments': (visitor, positional, named, typeArgs) {
        if (!named.containsKey('filePaths') || named['filePaths'] == null) {
          throw ArgumentError('scanDocuments: Missing required named argument "filePaths"');
        }
        final filePaths = D4.coerceList<String>(named['filePaths'], 'filePaths');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.scanDocuments(filePaths: filePaths, workspaceRoot: workspaceRoot);
      },
      'scanDocumentsSync': (visitor, positional, named, typeArgs) {
        if (!named.containsKey('filePaths') || named['filePaths'] == null) {
          throw ArgumentError('scanDocumentsSync: Missing required named argument "filePaths"');
        }
        final filePaths = D4.coerceList<String>(named['filePaths'], 'filePaths');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.scanDocumentsSync(filePaths: filePaths, workspaceRoot: workspaceRoot);
      },
      'scanTree': (visitor, positional, named, typeArgs) {
        final dirPath = D4.getRequiredNamedArg<String>(named, 'dirPath', 'scanTree');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.scanTree(dirPath: dirPath, workspaceRoot: workspaceRoot);
      },
      'scanTreeSync': (visitor, positional, named, typeArgs) {
        final dirPath = D4.getRequiredNamedArg<String>(named, 'dirPath', 'scanTreeSync');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.scanTreeSync(dirPath: dirPath, workspaceRoot: workspaceRoot);
      },
      'loadSchema': (visitor, positional, named, typeArgs) {
        final schemaId = D4.getRequiredNamedArg<String>(named, 'schemaId', 'loadSchema');
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.loadSchema(schemaId: schemaId, documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
      'loadSchemaSync': (visitor, positional, named, typeArgs) {
        final schemaId = D4.getRequiredNamedArg<String>(named, 'schemaId', 'loadSchemaSync');
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.loadSchemaSync(schemaId: schemaId, documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
      'validate': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'validate');
        final doc = D4.getRequiredArg<$tom_doc_specs_6.SpecDoc>(positional, 0, 'doc', 'validate');
        final schema = D4.getOptionalNamedArg<$tom_doc_specs_1.DocSpecSchema?>(named, 'schema');
        return DocSpecs.validate(doc, schema: schema);
      },
      'listSchemas': (visitor, positional, named, typeArgs) {
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.listSchemas(documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
      'listSchemasSync': (visitor, positional, named, typeArgs) {
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return DocSpecs.listSchemasSync(documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
      'listSchemasIn': (visitor, positional, named, typeArgs) {
        final dirPath = D4.getRequiredNamedArg<String>(named, 'dirPath', 'listSchemasIn');
        return DocSpecs.listSchemasIn(dirPath: dirPath);
      },
      'listSchemasInSync': (visitor, positional, named, typeArgs) {
        final dirPath = D4.getRequiredNamedArg<String>(named, 'dirPath', 'listSchemasInSync');
        return DocSpecs.listSchemasInSync(dirPath: dirPath);
      },
    },
    staticMethodSignatures: {
      'scanDocument': 'Future<SpecDoc> scanDocument({required String filePath, String? schemaId, String? workspaceRoot})',
      'scanDocumentSync': 'SpecDoc scanDocumentSync({required String filePath, String? schemaId, String? workspaceRoot})',
      'scanDocuments': 'Future<List<SpecDoc>> scanDocuments({required List<String> filePaths, String? workspaceRoot})',
      'scanDocumentsSync': 'List<SpecDoc> scanDocumentsSync({required List<String> filePaths, String? workspaceRoot})',
      'scanTree': 'Future<DocumentFolder> scanTree({required String dirPath, String? workspaceRoot})',
      'scanTreeSync': 'DocumentFolder scanTreeSync({required String dirPath, String? workspaceRoot})',
      'loadSchema': 'Future<DocSpecSchema> loadSchema({required String schemaId, String? documentPath, String? workspaceRoot})',
      'loadSchemaSync': 'DocSpecSchema loadSchemaSync({required String schemaId, String? documentPath, String? workspaceRoot})',
      'validate': 'List<String> validate(SpecDoc doc, {DocSpecSchema? schema})',
      'listSchemas': 'Future<List<SchemaInfo>> listSchemas({String? documentPath, String? workspaceRoot})',
      'listSchemasSync': 'List<SchemaInfo> listSchemasSync({String? documentPath, String? workspaceRoot})',
      'listSchemasIn': 'Future<List<SchemaInfo>> listSchemasIn({required String dirPath})',
      'listSchemasInSync': 'List<SchemaInfo> listSchemasInSync({required String dirPath})',
    },
  );
}

// =============================================================================
// DocSpecsFactory Bridge
// =============================================================================

BridgedClass _createDocSpecsFactoryBridge() {
  return BridgedClass(
    nativeType: DocSpecsFactory,
    name: 'DocSpecsFactory',
    isAssignable: (v) => v is DocSpecsFactory,
    constructors: {
      '': (visitor, positional, named) {
        final schema = D4.getOptionalNamedArg<$tom_doc_specs_1.DocSpecSchema?>(named, 'schema');
        return DocSpecsFactory(schema: schema);
      },
    },
    getters: {
      'schema': (visitor, target) => D4.validateTarget<DocSpecsFactory>(target, 'DocSpecsFactory').schema,
    },
    methods: {
      'createSection': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DocSpecsFactory>(target, 'DocSpecsFactory');
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
        final sections = D4.coerceListOrNull<$tom_doc_scanner_3.Section>(named['sections'], 'sections');
        return t.createSection(index: index, lineNumber: lineNumber, rawHeadline: rawHeadline, name: name, id: id, text: text, fields: fields, sections: sections);
      },
      'createDocument': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DocSpecsFactory>(target, 'DocSpecsFactory');
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
        final sections = D4.coerceListOrNull<$tom_doc_scanner_3.Section>(named['sections'], 'sections');
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
      '': 'DocSpecsFactory({DocSpecSchema? schema})',
    },
    methodSignatures: {
      'createSection': 'Section createSection({required int index, required int lineNumber, required String rawHeadline, required String name, required String id, required String text, required Map<String, String> fields, List<Section>? sections})',
      'createDocument': 'Document createDocument({required int index, required int lineNumber, required String rawHeadline, required String name, required String id, required String text, required Map<String, String> fields, List<Section>? sections, required String filenameWithPath, required String loadTimestamp, required String filename, required String fullPath, required String workspacePath, required String project, required String projectPath, required String workspaceRoot, required String projectRoot, required int hierarchyDepth})',
    },
    getterSignatures: {
      'schema': 'DocSpecSchema? get schema',
    },
  );
}

// =============================================================================
// SpecSection Bridge
// =============================================================================

BridgedClass _createSpecSectionBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_7.SpecSection,
    name: 'SpecSection',
    isAssignable: (v) => v is $tom_doc_specs_7.SpecSection,
    constructors: {
      '': (visitor, positional, named) {
        final index = D4.getRequiredNamedArg<int>(named, 'index', 'SpecSection');
        final lineNumber = D4.getRequiredNamedArg<int>(named, 'lineNumber', 'SpecSection');
        final rawHeadline = D4.getRequiredNamedArg<String>(named, 'rawHeadline', 'SpecSection');
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'SpecSection');
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'SpecSection');
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'SpecSection');
        final fields = named.containsKey('fields') && named['fields'] != null
            ? D4.coerceMap<String, String>(named['fields'], 'fields')
            : const <String, String>{};
        final sections = D4.coerceListOrNull<$tom_doc_scanner_3.Section>(named['sections'], 'sections');
        final type = D4.getOptionalNamedArg<String?>(named, 'type');
        final tags = D4.coerceListOrNull<String>(named['tags'], 'tags');
        final format = D4.getOptionalNamedArg<String?>(named, 'format');
        return $tom_doc_specs_7.SpecSection(index: index, lineNumber: lineNumber, rawHeadline: rawHeadline, name: name, id: id, text: text, fields: fields, sections: sections, type: type, tags: tags, format: format);
      },
      'fromSection': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SpecSection');
        final section = D4.getRequiredArg<$tom_doc_scanner_3.Section>(positional, 0, 'section', 'SpecSection');
        final type = D4.getOptionalNamedArg<String?>(named, 'type');
        final tags = D4.coerceListOrNull<String>(named['tags'], 'tags');
        final format = D4.getOptionalNamedArg<String?>(named, 'format');
        return $tom_doc_specs_7.SpecSection.fromSection(section, type: type, tags: tags, format: format);
      },
      'fromJson': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SpecSection');
        if (positional.isEmpty) {
          throw ArgumentError('SpecSection: Missing required argument "json" at position 0');
        }
        final json = D4.coerceMap<String, dynamic>(positional[0], 'json');
        return $tom_doc_specs_7.SpecSection.fromJson(json);
      },
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').type,
      'tags': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').tags,
      'format': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').format,
      'preamble': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').preamble,
      'index': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').index,
      'lineNumber': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').lineNumber,
      'rawHeadline': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').rawHeadline,
      'name': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').name,
      'id': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').id,
      'text': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').text,
      'fields': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').fields,
      'sections': (visitor, target) => D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection').sections,
    },
    methods: {
      'getFormField': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection');
        D4.requireMinArgs(positional, 1, 'getFormField');
        final fieldname = D4.getRequiredArg<String>(positional, 0, 'fieldname', 'getFormField');
        return t.getFormField(fieldname);
      },
      'getSubsectionsByType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection');
        D4.requireMinArgs(positional, 1, 'getSubsectionsByType');
        final typeName = D4.getRequiredArg<String>(positional, 0, 'typeName', 'getSubsectionsByType');
        return t.getSubsectionsByType(typeName);
      },
      'getSubsections': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection');
        return t.getSubsections();
      },
      'toJson': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection');
        return t.toJson();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_7.SpecSection>(target, 'SpecSection');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'SpecSection({required int index, required int lineNumber, required String rawHeadline, required String name, required String id, required String text, Map<String, String> fields = const {}, List<Section>? sections, String? type, List<String>? tags, String? format})',
      'fromSection': 'factory SpecSection.fromSection(Section section, {String? type, List<String>? tags, String? format})',
      'fromJson': 'factory SpecSection.fromJson(Map<String, dynamic> json)',
    },
    methodSignatures: {
      'getFormField': 'String? getFormField(String fieldname)',
      'getSubsectionsByType': 'List<SpecSection> getSubsectionsByType(String typeName)',
      'getSubsections': 'List<SpecSection> getSubsections()',
      'toJson': 'Map<String, dynamic> toJson()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'type': 'String? get type',
      'tags': 'List<String> get tags',
      'format': 'String? get format',
      'preamble': 'String? get preamble',
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

// =============================================================================
// SpecDoc Bridge
// =============================================================================

BridgedClass _createSpecDocBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_6.SpecDoc,
    name: 'SpecDoc',
    isAssignable: (v) => v is $tom_doc_specs_6.SpecDoc,
    constructors: {
      '': (visitor, positional, named) {
        final index = D4.getRequiredNamedArg<int>(named, 'index', 'SpecDoc');
        final lineNumber = D4.getRequiredNamedArg<int>(named, 'lineNumber', 'SpecDoc');
        final rawHeadline = D4.getRequiredNamedArg<String>(named, 'rawHeadline', 'SpecDoc');
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'SpecDoc');
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'SpecDoc');
        final text = D4.getRequiredNamedArg<String>(named, 'text', 'SpecDoc');
        final fields = named.containsKey('fields') && named['fields'] != null
            ? D4.coerceMap<String, String>(named['fields'], 'fields')
            : const <String, String>{};
        final sections = D4.coerceListOrNull<$tom_doc_scanner_3.Section>(named['sections'], 'sections');
        final filenameWithPath = D4.getRequiredNamedArg<String>(named, 'filenameWithPath', 'SpecDoc');
        final loadTimestamp = D4.getRequiredNamedArg<String>(named, 'loadTimestamp', 'SpecDoc');
        final filename = D4.getRequiredNamedArg<String>(named, 'filename', 'SpecDoc');
        final fullPath = D4.getRequiredNamedArg<String>(named, 'fullPath', 'SpecDoc');
        final workspacePath = D4.getRequiredNamedArg<String>(named, 'workspacePath', 'SpecDoc');
        final project = D4.getRequiredNamedArg<String>(named, 'project', 'SpecDoc');
        final projectPath = D4.getRequiredNamedArg<String>(named, 'projectPath', 'SpecDoc');
        final workspaceRoot = D4.getRequiredNamedArg<String>(named, 'workspaceRoot', 'SpecDoc');
        final projectRoot = D4.getRequiredNamedArg<String>(named, 'projectRoot', 'SpecDoc');
        final hierarchyDepth = D4.getRequiredNamedArg<int>(named, 'hierarchyDepth', 'SpecDoc');
        final schemaId = D4.getNamedArgWithDefault<String>(named, 'schemaId', '');
        final validationErrors = D4.coerceListOrNull<String>(named['validationErrors'], 'validationErrors');
        final accessKeys = D4.coerceMapOrNull<String, String>(named['accessKeys'], 'accessKeys');
        return $tom_doc_specs_6.SpecDoc(index: index, lineNumber: lineNumber, rawHeadline: rawHeadline, name: name, id: id, text: text, fields: fields, sections: sections, filenameWithPath: filenameWithPath, loadTimestamp: loadTimestamp, filename: filename, fullPath: fullPath, workspacePath: workspacePath, project: project, projectPath: projectPath, workspaceRoot: workspaceRoot, projectRoot: projectRoot, hierarchyDepth: hierarchyDepth, schemaId: schemaId, validationErrors: validationErrors, accessKeys: accessKeys);
      },
      'fromDocument': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SpecDoc');
        final document = D4.getRequiredArg<$tom_doc_scanner_1.Document>(positional, 0, 'document', 'SpecDoc');
        final schemaId = D4.getNamedArgWithDefault<String>(named, 'schemaId', '');
        final validationErrors = D4.coerceListOrNull<String>(named['validationErrors'], 'validationErrors');
        final accessKeys = D4.coerceMapOrNull<String, String>(named['accessKeys'], 'accessKeys');
        return $tom_doc_specs_6.SpecDoc.fromDocument(document, schemaId: schemaId, validationErrors: validationErrors, accessKeys: accessKeys);
      },
      'fromJson': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SpecDoc');
        if (positional.isEmpty) {
          throw ArgumentError('SpecDoc: Missing required argument "json" at position 0');
        }
        final json = D4.coerceMap<String, dynamic>(positional[0], 'json');
        return $tom_doc_specs_6.SpecDoc.fromJson(json);
      },
    },
    getters: {
      'schemaId': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').schemaId,
      'validationErrors': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').validationErrors,
      'isValid': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').isValid,
      'filenameWithPath': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').filenameWithPath,
      'loadTimestamp': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').loadTimestamp,
      'filename': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').filename,
      'fullPath': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').fullPath,
      'workspacePath': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').workspacePath,
      'project': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').project,
      'projectPath': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').projectPath,
      'workspaceRoot': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').workspaceRoot,
      'projectRoot': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').projectRoot,
      'hierarchyDepth': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').hierarchyDepth,
      'index': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').index,
      'lineNumber': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').lineNumber,
      'rawHeadline': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').rawHeadline,
      'name': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').name,
      'id': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').id,
      'text': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').text,
      'fields': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').fields,
      'sections': (visitor, target) => D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc').sections,
    },
    methods: {
      'getSection': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc');
        D4.requireMinArgs(positional, 1, 'getSection');
        final sectionName = D4.getRequiredArg<String>(positional, 0, 'sectionName', 'getSection');
        return t.getSection(sectionName);
      },
      'getSpecSectionType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc');
        D4.requireMinArgs(positional, 1, 'getSpecSectionType');
        final typeName = D4.getRequiredArg<String>(positional, 0, 'typeName', 'getSpecSectionType');
        return t.getSpecSectionType(typeName);
      },
      'getSectionsByTag': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc');
        D4.requireMinArgs(positional, 1, 'getSectionsByTag');
        final tag = D4.getRequiredArg<String>(positional, 0, 'tag', 'getSectionsByTag');
        final typeName = D4.getOptionalArg<String?>(positional, 1, 'typeName');
        return t.getSectionsByTag(tag, typeName);
      },
      'toJson': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc');
        return t.toJson();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc');
        return t.toString();
      },
      '[]': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_6.SpecDoc>(target, 'SpecDoc');
        final index = D4.getRequiredArg<String>(positional, 0, 'index', 'operator[]');
        return t[index];
      },
    },
    constructorSignatures: {
      '': 'SpecDoc({required int index, required int lineNumber, required String rawHeadline, required String name, required String id, required String text, Map<String, String> fields = const {}, List<Section>? sections, required String filenameWithPath, required String loadTimestamp, required String filename, required String fullPath, required String workspacePath, required String project, required String projectPath, required String workspaceRoot, required String projectRoot, required int hierarchyDepth, String schemaId = \'\', List<String>? validationErrors, Map<String, String>? accessKeys})',
      'fromDocument': 'factory SpecDoc.fromDocument(Document document, {String schemaId = \'\', List<String>? validationErrors, Map<String, String>? accessKeys})',
      'fromJson': 'factory SpecDoc.fromJson(Map<String, dynamic> json)',
    },
    methodSignatures: {
      'getSection': 'SpecSection? getSection(String sectionName)',
      'getSpecSectionType': 'SpecSectionType getSpecSectionType(String typeName)',
      'getSectionsByTag': 'List<SpecSection> getSectionsByTag(String tag, [String? typeName])',
      'toJson': 'Map<String, dynamic> toJson()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'schemaId': 'String get schemaId',
      'validationErrors': 'List<String> get validationErrors',
      'isValid': 'bool get isValid',
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

// =============================================================================
// SpecSectionType Bridge
// =============================================================================

BridgedClass _createSpecSectionTypeBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_8.SpecSectionType,
    name: 'SpecSectionType',
    isAssignable: (v) => v is $tom_doc_specs_8.SpecSectionType,
    constructors: {
      '': (visitor, positional, named) {
        final type = D4.getRequiredNamedArg<String>(named, 'type', 'SpecSectionType');
        if (!named.containsKey('sections') || named['sections'] == null) {
          throw ArgumentError('SpecSectionType: Missing required named argument "sections"');
        }
        final sections = D4.coerceMap<$tom_doc_specs_7.SpecSection, List<$tom_doc_specs_7.SpecSection>>(named['sections'], 'sections');
        return $tom_doc_specs_8.SpecSectionType(type: type, sections: sections);
      },
      'empty': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SpecSectionType');
        final type = D4.getRequiredArg<String>(positional, 0, 'type', 'SpecSectionType');
        return $tom_doc_specs_8.SpecSectionType.empty(type);
      },
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType').type,
      'sections': (visitor, target) => D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType').sections,
      'sources': (visitor, target) => D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType').sources,
      'isEmpty': (visitor, target) => D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType').isEmpty,
      'isNotEmpty': (visitor, target) => D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType').isNotEmpty,
      'length': (visitor, target) => D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType').length,
    },
    methods: {
      'getAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType');
        return t.getAll();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_8.SpecSectionType>(target, 'SpecSectionType');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const SpecSectionType({required String type, required Map<SpecSection, List<SpecSection>> sections})',
      'empty': 'factory SpecSectionType.empty(String type)',
    },
    methodSignatures: {
      'getAll': 'List<SpecSection> getAll()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'type': 'String get type',
      'sections': 'Map<SpecSection, List<SpecSection>> get sections',
      'sources': 'List<SpecSection> get sources',
      'isEmpty': 'bool get isEmpty',
      'isNotEmpty': 'bool get isNotEmpty',
      'length': 'int get length',
    },
  );
}

// =============================================================================
// DocSpecSchema Bridge
// =============================================================================

BridgedClass _createDocSpecSchemaBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_1.DocSpecSchema,
    name: 'DocSpecSchema',
    isAssignable: (v) => v is $tom_doc_specs_1.DocSpecSchema,
    constructors: {
      '': (visitor, positional, named) {
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'DocSpecSchema');
        final version = D4.getRequiredNamedArg<String>(named, 'version', 'DocSpecSchema');
        if (!named.containsKey('sectionTypes') || named['sectionTypes'] == null) {
          throw ArgumentError('DocSpecSchema: Missing required named argument "sectionTypes"');
        }
        final sectionTypes = D4.coerceMap<String, $tom_doc_specs_5.SectionTypeDef>(named['sectionTypes'], 'sectionTypes');
        final document = D4.getRequiredNamedArg<$tom_doc_specs_2.DocumentStructure>(named, 'document', 'DocSpecSchema');
        final formTypes = D4.coerceMapOrNull<String, $tom_doc_specs_3.FormTypeDef>(named['formTypes'], 'formTypes');
        final subsectionDeclarations = D4.coerceMapOrNull<String, Map<String, $tom_doc_specs_2.SubsectionDef>>(named['subsectionDeclarations'], 'subsectionDeclarations');
        final customTags = named.containsKey('customTags') && named['customTags'] != null
            ? D4.coerceMap<String, dynamic>(named['customTags'], 'customTags')
            : const <String, dynamic>{};
        return $tom_doc_specs_1.DocSpecSchema(id: id, version: version, sectionTypes: sectionTypes, document: document, formTypes: formTypes, subsectionDeclarations: subsectionDeclarations, customTags: customTags);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'DocSpecSchema');
        if (positional.isEmpty) {
          throw ArgumentError('DocSpecSchema: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'DocSpecSchema');
        final version = D4.getRequiredNamedArg<String>(named, 'version', 'DocSpecSchema');
        return $tom_doc_specs_1.DocSpecSchema.fromYaml(yaml, id: id, version: version);
      },
    },
    getters: {
      'id': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').id,
      'version': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').version,
      'sectionTypes': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').sectionTypes,
      'document': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').document,
      'formTypes': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').formTypes,
      'subsectionDeclarations': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').subsectionDeclarations,
      'customTags': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').customTags,
      'fullId': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').fullId,
      'filenameId': (visitor, target) => D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema').filenameId,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema');
        return t.toYaml();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_1.DocSpecSchema>(target, 'DocSpecSchema');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const DocSpecSchema({required String id, required String version, required Map<String, SectionTypeDef> sectionTypes, required DocumentStructure document, Map<String, FormTypeDef>? formTypes, Map<String, Map<String, SubsectionDef>>? subsectionDeclarations, Map<String, dynamic> customTags = const {}})',
      'fromYaml': 'factory DocSpecSchema.fromYaml(Map<String, dynamic> yaml, {required String id, required String version})',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'id': 'String get id',
      'version': 'String get version',
      'sectionTypes': 'Map<String, SectionTypeDef> get sectionTypes',
      'document': 'DocumentStructure get document',
      'formTypes': 'Map<String, FormTypeDef>? get formTypes',
      'subsectionDeclarations': 'Map<String, Map<String, SubsectionDef>>? get subsectionDeclarations',
      'customTags': 'Map<String, dynamic> get customTags',
      'fullId': 'String get fullId',
      'filenameId': 'String get filenameId',
    },
  );
}

// =============================================================================
// PatternCheckDef Bridge
// =============================================================================

BridgedClass _createPatternCheckDefBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_5.PatternCheckDef,
    name: 'PatternCheckDef',
    isAssignable: (v) => v is $tom_doc_specs_5.PatternCheckDef,
    constructors: {
      '': (visitor, positional, named) {
        final pattern = D4.getRequiredNamedArg<String>(named, 'pattern', 'PatternCheckDef');
        final errorMessage = D4.getRequiredNamedArg<String>(named, 'errorMessage', 'PatternCheckDef');
        return $tom_doc_specs_5.PatternCheckDef(pattern: pattern, errorMessage: errorMessage);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'PatternCheckDef');
        if (positional.isEmpty) {
          throw ArgumentError('PatternCheckDef: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_doc_specs_5.PatternCheckDef.fromYaml(yaml);
      },
    },
    getters: {
      'pattern': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.PatternCheckDef>(target, 'PatternCheckDef').pattern,
      'errorMessage': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.PatternCheckDef>(target, 'PatternCheckDef').errorMessage,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_5.PatternCheckDef>(target, 'PatternCheckDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const PatternCheckDef({required String pattern, required String errorMessage})',
      'fromYaml': 'factory PatternCheckDef.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'pattern': 'String get pattern',
      'errorMessage': 'String get errorMessage',
    },
  );
}

// =============================================================================
// SubsectionConstraint Bridge
// =============================================================================

BridgedClass _createSubsectionConstraintBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_5.SubsectionConstraint,
    name: 'SubsectionConstraint',
    isAssignable: (v) => v is $tom_doc_specs_5.SubsectionConstraint,
    constructors: {
      '': (visitor, positional, named) {
        final typeName = D4.getRequiredNamedArg<String>(named, 'typeName', 'SubsectionConstraint');
        final maxCount = D4.getOptionalNamedArg<int?>(named, 'maxCount');
        final minCount = D4.getOptionalNamedArg<int?>(named, 'minCount');
        final required = D4.getOptionalNamedArg<bool?>(named, 'required');
        return $tom_doc_specs_5.SubsectionConstraint(typeName: typeName, maxCount: maxCount, minCount: minCount, required: required);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'SubsectionConstraint');
        final typeName = D4.getRequiredArg<String>(positional, 0, 'typeName', 'SubsectionConstraint');
        if (positional.length <= 1) {
          throw ArgumentError('SubsectionConstraint: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_doc_specs_5.SubsectionConstraint.fromYaml(typeName, yaml);
      },
    },
    getters: {
      'typeName': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SubsectionConstraint>(target, 'SubsectionConstraint').typeName,
      'maxCount': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SubsectionConstraint>(target, 'SubsectionConstraint').maxCount,
      'minCount': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SubsectionConstraint>(target, 'SubsectionConstraint').minCount,
      'required': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SubsectionConstraint>(target, 'SubsectionConstraint').required,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_5.SubsectionConstraint>(target, 'SubsectionConstraint');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const SubsectionConstraint({required String typeName, int? maxCount, int? minCount, bool? required})',
      'fromYaml': 'factory SubsectionConstraint.fromYaml(String typeName, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'typeName': 'String get typeName',
      'maxCount': 'int? get maxCount',
      'minCount': 'int? get minCount',
      'required': 'bool? get required',
    },
  );
}

// =============================================================================
// SectionTypeDef Bridge
// =============================================================================

BridgedClass _createSectionTypeDefBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_5.SectionTypeDef,
    name: 'SectionTypeDef',
    isAssignable: (v) => v is $tom_doc_specs_5.SectionTypeDef,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'SectionTypeDef');
        final prefix = D4.getOptionalNamedArg<String?>(named, 'prefix');
        final maxCountInDocument = D4.getOptionalNamedArg<int?>(named, 'maxCountInDocument');
        final maxSubsectionLevels = D4.getOptionalNamedArg<int?>(named, 'maxSubsectionLevels');
        final subsectionTypes = D4.coerceMapOrNull<String, $tom_doc_specs_5.SubsectionConstraint>(named['subsectionTypes'], 'subsectionTypes');
        final patternCheckId = D4.getOptionalNamedArg<$tom_doc_specs_5.PatternCheckDef?>(named, 'patternCheckId');
        final patternCheckText = D4.getOptionalNamedArg<$tom_doc_specs_5.PatternCheckDef?>(named, 'patternCheckText');
        final format = D4.getOptionalNamedArg<String?>(named, 'format');
        final textRequired = D4.getOptionalNamedArg<bool?>(named, 'textRequired');
        final minTextLength = D4.getOptionalNamedArg<int?>(named, 'minTextLength');
        final maxTextLength = D4.getOptionalNamedArg<int?>(named, 'maxTextLength');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final allowedTags = D4.coerceListOrNull<String>(named['allowedTags'], 'allowedTags');
        final validationPrompt = D4.getOptionalNamedArg<String?>(named, 'validationPrompt');
        final requiredFields = D4.coerceListOrNull<String>(named['requiredFields'], 'requiredFields');
        return $tom_doc_specs_5.SectionTypeDef(name: name, prefix: prefix, maxCountInDocument: maxCountInDocument, maxSubsectionLevels: maxSubsectionLevels, subsectionTypes: subsectionTypes, patternCheckId: patternCheckId, patternCheckText: patternCheckText, format: format, textRequired: textRequired, minTextLength: minTextLength, maxTextLength: maxTextLength, description: description, allowedTags: allowedTags, validationPrompt: validationPrompt, requiredFields: requiredFields);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'SectionTypeDef');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'SectionTypeDef');
        if (positional.length <= 1) {
          throw ArgumentError('SectionTypeDef: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_doc_specs_5.SectionTypeDef.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').name,
      'prefix': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').prefix,
      'maxCountInDocument': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').maxCountInDocument,
      'maxSubsectionLevels': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').maxSubsectionLevels,
      'subsectionTypes': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').subsectionTypes,
      'patternCheckId': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').patternCheckId,
      'patternCheckText': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').patternCheckText,
      'format': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').format,
      'textRequired': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').textRequired,
      'minTextLength': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').minTextLength,
      'maxTextLength': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').maxTextLength,
      'description': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').description,
      'allowedTags': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').allowedTags,
      'validationPrompt': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').validationPrompt,
      'requiredFields': (visitor, target) => D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef').requiredFields,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_5.SectionTypeDef>(target, 'SectionTypeDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const SectionTypeDef({required String name, String? prefix, int? maxCountInDocument, int? maxSubsectionLevels, Map<String, SubsectionConstraint>? subsectionTypes, PatternCheckDef? patternCheckId, PatternCheckDef? patternCheckText, String? format, bool? textRequired, int? minTextLength, int? maxTextLength, String? description, List<String>? allowedTags, String? validationPrompt, List<String>? requiredFields})',
      'fromYaml': 'factory SectionTypeDef.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'prefix': 'String? get prefix',
      'maxCountInDocument': 'int? get maxCountInDocument',
      'maxSubsectionLevels': 'int? get maxSubsectionLevels',
      'subsectionTypes': 'Map<String, SubsectionConstraint>? get subsectionTypes',
      'patternCheckId': 'PatternCheckDef? get patternCheckId',
      'patternCheckText': 'PatternCheckDef? get patternCheckText',
      'format': 'String? get format',
      'textRequired': 'bool? get textRequired',
      'minTextLength': 'int? get minTextLength',
      'maxTextLength': 'int? get maxTextLength',
      'description': 'String? get description',
      'allowedTags': 'List<String>? get allowedTags',
      'validationPrompt': 'String? get validationPrompt',
      'requiredFields': 'List<String>? get requiredFields',
    },
  );
}

// =============================================================================
// ForEachDef Bridge
// =============================================================================

BridgedClass _createForEachDefBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_2.ForEachDef,
    name: 'ForEachDef',
    isAssignable: (v) => v is $tom_doc_specs_2.ForEachDef,
    constructors: {
      '': (visitor, positional, named) {
        final sectionType = D4.getRequiredNamedArg<String>(named, 'sectionType', 'ForEachDef');
        final key = D4.getRequiredNamedArg<String>(named, 'key', 'ForEachDef');
        return $tom_doc_specs_2.ForEachDef(sectionType: sectionType, key: key);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ForEachDef');
        if (positional.isEmpty) {
          throw ArgumentError('ForEachDef: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_doc_specs_2.ForEachDef.fromYaml(yaml);
      },
    },
    getters: {
      'sectionType': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.ForEachDef>(target, 'ForEachDef').sectionType,
      'key': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.ForEachDef>(target, 'ForEachDef').key,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_2.ForEachDef>(target, 'ForEachDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const ForEachDef({required String sectionType, required String key})',
      'fromYaml': 'factory ForEachDef.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'sectionType': 'String get sectionType',
      'key': 'String get key',
    },
  );
}

// =============================================================================
// SectionDef Bridge
// =============================================================================

BridgedClass _createSectionDefBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_2.SectionDef,
    name: 'SectionDef',
    isAssignable: (v) => v is $tom_doc_specs_2.SectionDef,
    constructors: {
      '': (visitor, positional, named) {
        final sectionType = D4.getRequiredNamedArg<String>(named, 'sectionType', 'SectionDef');
        final accessKey = D4.getOptionalNamedArg<String?>(named, 'accessKey');
        final optional = D4.getOptionalNamedArg<bool?>(named, 'optional');
        final validationPrompt = D4.getOptionalNamedArg<String?>(named, 'validationPrompt');
        final subsectionValidationPrompt = D4.getOptionalNamedArg<String?>(named, 'subsectionValidationPrompt');
        final forEach = D4.getOptionalNamedArg<$tom_doc_specs_2.ForEachDef?>(named, 'forEach');
        return $tom_doc_specs_2.SectionDef(sectionType: sectionType, accessKey: accessKey, optional: optional, validationPrompt: validationPrompt, subsectionValidationPrompt: subsectionValidationPrompt, forEach: forEach);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SectionDef');
        if (positional.isEmpty) {
          throw ArgumentError('SectionDef: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_doc_specs_2.SectionDef.fromYaml(yaml);
      },
    },
    getters: {
      'sectionType': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SectionDef>(target, 'SectionDef').sectionType,
      'accessKey': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SectionDef>(target, 'SectionDef').accessKey,
      'optional': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SectionDef>(target, 'SectionDef').optional,
      'validationPrompt': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SectionDef>(target, 'SectionDef').validationPrompt,
      'subsectionValidationPrompt': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SectionDef>(target, 'SectionDef').subsectionValidationPrompt,
      'forEach': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SectionDef>(target, 'SectionDef').forEach,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_2.SectionDef>(target, 'SectionDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const SectionDef({required String sectionType, String? accessKey, bool? optional, String? validationPrompt, String? subsectionValidationPrompt, ForEachDef? forEach})',
      'fromYaml': 'factory SectionDef.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'sectionType': 'String get sectionType',
      'accessKey': 'String? get accessKey',
      'optional': 'bool? get optional',
      'validationPrompt': 'String? get validationPrompt',
      'subsectionValidationPrompt': 'String? get subsectionValidationPrompt',
      'forEach': 'ForEachDef? get forEach',
    },
  );
}

// =============================================================================
// SubsectionDef Bridge
// =============================================================================

BridgedClass _createSubsectionDefBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_2.SubsectionDef,
    name: 'SubsectionDef',
    isAssignable: (v) => v is $tom_doc_specs_2.SubsectionDef,
    constructors: {
      '': (visitor, positional, named) {
        final sectionType = D4.getRequiredNamedArg<String>(named, 'sectionType', 'SubsectionDef');
        final required = D4.getOptionalNamedArg<bool?>(named, 'required');
        final position = D4.getOptionalNamedArg<String?>(named, 'position');
        return $tom_doc_specs_2.SubsectionDef(sectionType: sectionType, required: required, position: position);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SubsectionDef');
        if (positional.isEmpty) {
          throw ArgumentError('SubsectionDef: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_doc_specs_2.SubsectionDef.fromYaml(yaml);
      },
    },
    getters: {
      'sectionType': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SubsectionDef>(target, 'SubsectionDef').sectionType,
      'required': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SubsectionDef>(target, 'SubsectionDef').required,
      'position': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.SubsectionDef>(target, 'SubsectionDef').position,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_2.SubsectionDef>(target, 'SubsectionDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const SubsectionDef({required String sectionType, bool? required, String? position})',
      'fromYaml': 'factory SubsectionDef.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'sectionType': 'String get sectionType',
      'required': 'bool? get required',
      'position': 'String? get position',
    },
  );
}

// =============================================================================
// DocumentStructure Bridge
// =============================================================================

BridgedClass _createDocumentStructureBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_2.DocumentStructure,
    name: 'DocumentStructure',
    isAssignable: (v) => v is $tom_doc_specs_2.DocumentStructure,
    constructors: {
      '': (visitor, positional, named) {
        if (!named.containsKey('sections') || named['sections'] == null) {
          throw ArgumentError('DocumentStructure: Missing required named argument "sections"');
        }
        final sections = D4.coerceMap<String, $tom_doc_specs_2.SectionDef>(named['sections'], 'sections');
        return $tom_doc_specs_2.DocumentStructure(sections: sections);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'DocumentStructure');
        if (positional.isEmpty) {
          throw ArgumentError('DocumentStructure: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_doc_specs_2.DocumentStructure.fromYaml(yaml);
      },
    },
    getters: {
      'sections': (visitor, target) => D4.validateTarget<$tom_doc_specs_2.DocumentStructure>(target, 'DocumentStructure').sections,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_2.DocumentStructure>(target, 'DocumentStructure');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const DocumentStructure({required Map<String, SectionDef> sections})',
      'fromYaml': 'factory DocumentStructure.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'sections': 'Map<String, SectionDef> get sections',
    },
  );
}

// =============================================================================
// FormFieldDef Bridge
// =============================================================================

BridgedClass _createFormFieldDefBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_3.FormFieldDef,
    name: 'FormFieldDef',
    isAssignable: (v) => v is $tom_doc_specs_3.FormFieldDef,
    constructors: {
      '': (visitor, positional, named) {
        final fieldname = D4.getRequiredNamedArg<String>(named, 'fieldname', 'FormFieldDef');
        final required = D4.getOptionalNamedArg<bool?>(named, 'required');
        final patternCheck = D4.getOptionalNamedArg<$tom_doc_specs_5.PatternCheckDef?>(named, 'patternCheck');
        return $tom_doc_specs_3.FormFieldDef(fieldname: fieldname, required: required, patternCheck: patternCheck);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'FormFieldDef');
        if (positional.isEmpty) {
          throw ArgumentError('FormFieldDef: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_doc_specs_3.FormFieldDef.fromYaml(yaml);
      },
    },
    getters: {
      'fieldname': (visitor, target) => D4.validateTarget<$tom_doc_specs_3.FormFieldDef>(target, 'FormFieldDef').fieldname,
      'required': (visitor, target) => D4.validateTarget<$tom_doc_specs_3.FormFieldDef>(target, 'FormFieldDef').required,
      'patternCheck': (visitor, target) => D4.validateTarget<$tom_doc_specs_3.FormFieldDef>(target, 'FormFieldDef').patternCheck,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_3.FormFieldDef>(target, 'FormFieldDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const FormFieldDef({required String fieldname, bool? required, PatternCheckDef? patternCheck})',
      'fromYaml': 'factory FormFieldDef.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'fieldname': 'String get fieldname',
      'required': 'bool? get required',
      'patternCheck': 'PatternCheckDef? get patternCheck',
    },
  );
}

// =============================================================================
// FormTypeDef Bridge
// =============================================================================

BridgedClass _createFormTypeDefBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_3.FormTypeDef,
    name: 'FormTypeDef',
    isAssignable: (v) => v is $tom_doc_specs_3.FormTypeDef,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'FormTypeDef');
        if (!named.containsKey('fields') || named['fields'] == null) {
          throw ArgumentError('FormTypeDef: Missing required named argument "fields"');
        }
        final fields = D4.coerceList<$tom_doc_specs_3.FormFieldDef>(named['fields'], 'fields');
        return $tom_doc_specs_3.FormTypeDef(name: name, fields: fields);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'FormTypeDef');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'FormTypeDef');
        if (positional.length <= 1) {
          throw ArgumentError('FormTypeDef: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_doc_specs_3.FormTypeDef.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_doc_specs_3.FormTypeDef>(target, 'FormTypeDef').name,
      'fields': (visitor, target) => D4.validateTarget<$tom_doc_specs_3.FormTypeDef>(target, 'FormTypeDef').fields,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_3.FormTypeDef>(target, 'FormTypeDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'const FormTypeDef({required String name, required List<FormFieldDef> fields})',
      'fromYaml': 'factory FormTypeDef.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'fields': 'List<FormFieldDef> get fields',
    },
  );
}

// =============================================================================
// SchemaInfo Bridge
// =============================================================================

BridgedClass _createSchemaInfoBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_4.SchemaInfo,
    name: 'SchemaInfo',
    isAssignable: (v) => v is $tom_doc_specs_4.SchemaInfo,
    constructors: {
      '': (visitor, positional, named) {
        final id = D4.getRequiredNamedArg<String>(named, 'id', 'SchemaInfo');
        final version = D4.getRequiredNamedArg<String>(named, 'version', 'SchemaInfo');
        final path = D4.getRequiredNamedArg<String>(named, 'path', 'SchemaInfo');
        final source = D4.getRequiredNamedArg<$tom_doc_specs_4.SchemaSource>(named, 'source', 'SchemaInfo');
        return $tom_doc_specs_4.SchemaInfo(id: id, version: version, path: path, source: source);
      },
    },
    getters: {
      'id': (visitor, target) => D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo').id,
      'version': (visitor, target) => D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo').version,
      'path': (visitor, target) => D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo').path,
      'source': (visitor, target) => D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo').source,
      'fullId': (visitor, target) => D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo').fullId,
      'filenameId': (visitor, target) => D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo').filenameId,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo').hashCode,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo');
        return t.toString();
      },
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_4.SchemaInfo>(target, 'SchemaInfo');
        final other = D4.getRequiredArg<Object>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    constructorSignatures: {
      '': 'const SchemaInfo({required String id, required String version, required String path, required SchemaSource source})',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'id': 'String get id',
      'version': 'String get version',
      'path': 'String get path',
      'source': 'SchemaSource get source',
      'fullId': 'String get fullId',
      'filenameId': 'String get filenameId',
      'hashCode': 'int get hashCode',
    },
  );
}

// =============================================================================
// SchemaFilenameParser Bridge
// =============================================================================

BridgedClass _createSchemaFilenameParserBridge() {
  return BridgedClass(
    nativeType: SchemaFilenameParser,
    name: 'SchemaFilenameParser',
    isAssignable: (v) => v is SchemaFilenameParser,
    constructors: {
      '': (visitor, positional, named) {
        return SchemaFilenameParser();
      },
    },
    staticMethods: {
      'parse': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parse');
        final filename = D4.getRequiredArg<String>(positional, 0, 'filename', 'parse');
        return SchemaFilenameParser.parse(filename);
      },
    },
    constructorSignatures: {
      '': 'SchemaFilenameParser()',
    },
    staticMethodSignatures: {
      'parse': '({String id, String version})? parse(String filename)',
    },
  );
}

// =============================================================================
// SchemaLoader Bridge
// =============================================================================

BridgedClass _createSchemaLoaderBridge() {
  return BridgedClass(
    nativeType: SchemaLoader,
    name: 'SchemaLoader',
    isAssignable: (v) => v is SchemaLoader,
    constructors: {
      '': (visitor, positional, named) {
        return SchemaLoader();
      },
    },
    staticMethods: {
      'load': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'load');
        final filePath = D4.getRequiredArg<String>(positional, 0, 'filePath', 'load');
        return SchemaLoader.load(filePath);
      },
      'loadSync': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadSync');
        final filePath = D4.getRequiredArg<String>(positional, 0, 'filePath', 'loadSync');
        return SchemaLoader.loadSync(filePath);
      },
    },
    constructorSignatures: {
      '': 'SchemaLoader()',
    },
    staticMethodSignatures: {
      'load': 'Future<DocSpecSchema> load(String filePath)',
      'loadSync': 'DocSpecSchema loadSync(String filePath)',
    },
  );
}

// =============================================================================
// SchemaResolver Bridge
// =============================================================================

BridgedClass _createSchemaResolverBridge() {
  return BridgedClass(
    nativeType: SchemaResolver,
    name: 'SchemaResolver',
    isAssignable: (v) => v is SchemaResolver,
    constructors: {
      '': (visitor, positional, named) {
        return SchemaResolver();
      },
    },
    staticGetters: {
      'schemaExtensions': (visitor) => SchemaResolver.schemaExtensions,
    },
    staticMethods: {
      'resolve': (visitor, positional, named, typeArgs) {
        final schemaId = D4.getRequiredNamedArg<String>(named, 'schemaId', 'resolve');
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return SchemaResolver.resolve(schemaId: schemaId, documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
      'resolveSync': (visitor, positional, named, typeArgs) {
        final schemaId = D4.getRequiredNamedArg<String>(named, 'schemaId', 'resolveSync');
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return SchemaResolver.resolveSync(schemaId: schemaId, documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
    },
    constructorSignatures: {
      '': 'SchemaResolver()',
    },
    staticMethodSignatures: {
      'resolve': 'Future<DocSpecSchema?> resolve({required String schemaId, String? documentPath, String? workspaceRoot})',
      'resolveSync': 'DocSpecSchema? resolveSync({required String schemaId, String? documentPath, String? workspaceRoot})',
    },
    staticGetterSignatures: {
      'schemaExtensions': 'dynamic get schemaExtensions',
    },
  );
}

// =============================================================================
// SchemaDiscovery Bridge
// =============================================================================

BridgedClass _createSchemaDiscoveryBridge() {
  return BridgedClass(
    nativeType: SchemaDiscovery,
    name: 'SchemaDiscovery',
    isAssignable: (v) => v is SchemaDiscovery,
    constructors: {
      '': (visitor, positional, named) {
        return SchemaDiscovery();
      },
    },
    staticMethods: {
      'listSchemas': (visitor, positional, named, typeArgs) {
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return SchemaDiscovery.listSchemas(documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
      'listSchemasSync': (visitor, positional, named, typeArgs) {
        final documentPath = D4.getOptionalNamedArg<String?>(named, 'documentPath');
        final workspaceRoot = D4.getOptionalNamedArg<String?>(named, 'workspaceRoot');
        return SchemaDiscovery.listSchemasSync(documentPath: documentPath, workspaceRoot: workspaceRoot);
      },
      'listSchemasIn': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'listSchemasIn');
        final folderPath = D4.getRequiredArg<String>(positional, 0, 'folderPath', 'listSchemasIn');
        return SchemaDiscovery.listSchemasIn(folderPath);
      },
      'listSchemasInSync': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'listSchemasInSync');
        final folderPath = D4.getRequiredArg<String>(positional, 0, 'folderPath', 'listSchemasInSync');
        return SchemaDiscovery.listSchemasInSync(folderPath);
      },
    },
    constructorSignatures: {
      '': 'SchemaDiscovery()',
    },
    staticMethodSignatures: {
      'listSchemas': 'Future<List<SchemaInfo>> listSchemas({String? documentPath, String? workspaceRoot})',
      'listSchemasSync': 'List<SchemaInfo> listSchemasSync({String? documentPath, String? workspaceRoot})',
      'listSchemasIn': 'Future<List<SchemaInfo>> listSchemasIn(String folderPath)',
      'listSchemasInSync': 'List<SchemaInfo> listSchemasInSync(String folderPath)',
    },
  );
}

// =============================================================================
// ValidationError Bridge
// =============================================================================

BridgedClass _createValidationErrorBridge() {
  return BridgedClass(
    nativeType: $tom_doc_specs_9.ValidationError,
    name: 'ValidationError',
    isAssignable: (v) => v is $tom_doc_specs_9.ValidationError,
    constructors: {
      '': (visitor, positional, named) {
        final message = D4.getRequiredNamedArg<String>(named, 'message', 'ValidationError');
        final lineNumber = D4.getOptionalNamedArg<int?>(named, 'lineNumber');
        final sectionId = D4.getOptionalNamedArg<String?>(named, 'sectionId');
        final category = D4.getNamedArgWithDefault<$tom_doc_specs_9.ValidationErrorCategory>(named, 'category', $tom_doc_specs_9.ValidationErrorCategory.general);
        return $tom_doc_specs_9.ValidationError(message: message, lineNumber: lineNumber, sectionId: sectionId, category: category);
      },
    },
    getters: {
      'message': (visitor, target) => D4.validateTarget<$tom_doc_specs_9.ValidationError>(target, 'ValidationError').message,
      'lineNumber': (visitor, target) => D4.validateTarget<$tom_doc_specs_9.ValidationError>(target, 'ValidationError').lineNumber,
      'sectionId': (visitor, target) => D4.validateTarget<$tom_doc_specs_9.ValidationError>(target, 'ValidationError').sectionId,
      'category': (visitor, target) => D4.validateTarget<$tom_doc_specs_9.ValidationError>(target, 'ValidationError').category,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_doc_specs_9.ValidationError>(target, 'ValidationError');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const ValidationError({required String message, int? lineNumber, String? sectionId, ValidationErrorCategory category = ValidationErrorCategory.general})',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'message': 'String get message',
      'lineNumber': 'int? get lineNumber',
      'sectionId': 'String? get sectionId',
      'category': 'ValidationErrorCategory get category',
    },
  );
}

// =============================================================================
// DocSpecsValidator Bridge
// =============================================================================

BridgedClass _createDocSpecsValidatorBridge() {
  return BridgedClass(
    nativeType: DocSpecsValidator,
    name: 'DocSpecsValidator',
    isAssignable: (v) => v is DocSpecsValidator,
    constructors: {
      '': (visitor, positional, named) {
        final schema = D4.getRequiredNamedArg<$tom_doc_specs_1.DocSpecSchema>(named, 'schema', 'DocSpecsValidator');
        return DocSpecsValidator(schema: schema);
      },
    },
    getters: {
      'schema': (visitor, target) => D4.validateTarget<DocSpecsValidator>(target, 'DocSpecsValidator').schema,
    },
    methods: {
      'validate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DocSpecsValidator>(target, 'DocSpecsValidator');
        D4.requireMinArgs(positional, 1, 'validate');
        final doc = D4.getRequiredArg<$tom_doc_scanner_1.Document>(positional, 0, 'doc', 'validate');
        return t.validate(doc);
      },
    },
    constructorSignatures: {
      '': 'const DocSpecsValidator({required DocSpecSchema schema})',
    },
    methodSignatures: {
      'validate': 'List<ValidationError> validate(Document doc)',
    },
    getterSignatures: {
      'schema': 'DocSpecSchema get schema',
    },
  );
}

