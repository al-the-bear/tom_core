// D4rt Bridge - Generated file, do not edit
// Sources: 17 files
// Generated: 2026-06-15T11:35:46.827261

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls, invalid_use_of_protected_member, unnecessary_non_null_assertion, invalid_use_of_visible_for_testing_member, unnecessary_cast, unused_local_variable, no_leading_underscores_for_local_identifiers, prefer_is_empty, unnecessary_question_mark, unreachable_switch_case, unintended_html_in_doc_comment, empty_constructor_bodies, prefer_const_constructors_in_immutables, prefer_final_fields, unused_field, must_call_super, no_logic_in_create_state, use_key_in_widget_constructors, annotate_overrides, unnecessary_import

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';

import 'package:tom_build/src/analyzer/workspace_analyzer.dart' as $tom_build_1;
import 'package:tom_build/src/reflection_generator/reflection_generator.dart' as $tom_build_2;
import 'package:tom_build/src/scripting/env.dart' as $tom_build_3;
import 'package:tom_build/src/scripting/fs.dart' as $tom_build_4;
import 'package:tom_build/src/scripting/glob.dart' as $tom_build_5;
import 'package:tom_build/src/scripting/maps.dart' as $tom_build_6;
import 'package:tom_build/src/scripting/path.dart' as $tom_build_7;
import 'package:tom_build/src/scripting/shell.dart' as $tom_build_8;
import 'package:tom_build/src/scripting/text.dart' as $tom_build_9;
import 'package:tom_build/src/scripting/workspace.dart' as $tom_build_10;
import 'package:tom_build/src/scripting/yaml.dart' as $tom_build_11;
import 'package:tom_build/src/scripting/zone.dart' as $tom_build_12;
import 'package:tom_build/src/tom/file_object_model/file_object_model.dart' as $tom_build_13;
import 'package:tom_build/src/tom/file_object_model/workspace_parser.dart' as $tom_build_14;
import 'package:tom_build/src/tom/tom_context.dart' as $tom_build_15;
import 'package:tom_build/src/tools/tool_context.dart' as $tom_build_16;
import 'package:tom_build/src/tools/workspace_info.dart' as $tom_build_17;
import 'package:yaml/src/yaml_node.dart' as $yaml_1;

/// Bridge class for tom_build module.
class TomBuildBridge {
  /// Returns all bridge class definitions.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createAnalyzerOptionsBridge(),
      _createWorkspaceAnalyzerBridge(),
      _createProjectInfoBridge(),
      _createPartInfoBridge(),
      _createModuleInfoBridge(),
      _createReflectionGeneratorRunnerBridge(),
      _createReflectionGeneratorRunnerOptionsBridge(),
      _createReflectionGeneratorRunnerResultBridge(),
      _createTomEnvBridge(),
      _createTomEnvironmentExceptionBridge(),
      _createTomFsBridge(),
      _createTomGlobBridge(),
      _createTomMapsBridge(),
      _createTomPthBridge(),
      _createTomShellBridge(),
      _createTomShellExceptionBridge(),
      _createTomTextBridge(),
      _createWorkspaceInfoBridge(),
      _createMetadataModesBridge(),
      _createMetadataModeBridge(),
      _createWorkspaceGroupBridge(),
      _createWorkspaceProjectBridge(),
      _createPlatformInfoBridge(),
      _createToolContextBridge(),
      _createToolContextExceptionBridge(),
      _createModeValidationResultBridge(),
      _createTomWsBridge(),
      _createScriptYamlBridge(),
      _createTomZonedBridge(),
      _createTomWorkspaceBridge(),
      _createTomMasterBridge(),
      _createTomProjectBridge(),
      _createWorkspaceModesBridge(),
      _createSupportedModeBridge(),
      _createModeTypeConfigBridge(),
      _createModeEntryBridge(),
      _createActionModeConfigurationBridge(),
      _createActionModeEntryBridge(),
      _createModeDefinitionsBridge(),
      _createModeDefBridge(),
      _createActionDefBridge(),
      _createActionConfigBridge(),
      _createGroupDefBridge(),
      _createProjectTypeDefBridge(),
      _createFeaturesBridge(),
      _createCrossCompilationBridge(),
      _createBuildOnTargetBridge(),
      _createPipelineBridge(),
      _createPipelineProjectBridge(),
      _createPipelineActionBridge(),
      _createProjectEntryBridge(),
      _createVersionSettingsBridge(),
      _createPackageModuleBridge(),
      _createPartBridge(),
      _createModuleBridge(),
      _createExecutableDefBridge(),
      _createWorkspaceParserBridge(),
      _createTomContextBridge(),
    ];
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'AnalyzerOptions': 'package:tom_build/src/analyzer/workspace_analyzer.dart',
      'WorkspaceAnalyzer': 'package:tom_build/src/analyzer/workspace_analyzer.dart',
      'ProjectInfo': 'package:tom_build/src/analyzer/workspace_analyzer.dart',
      'PartInfo': 'package:tom_build/src/analyzer/workspace_analyzer.dart',
      'ModuleInfo': 'package:tom_build/src/analyzer/workspace_analyzer.dart',
      'ReflectionGeneratorRunner': 'package:tom_build/src/reflection_generator/reflection_generator.dart',
      'ReflectionGeneratorRunnerOptions': 'package:tom_build/src/reflection_generator/reflection_generator.dart',
      'ReflectionGeneratorRunnerResult': 'package:tom_build/src/reflection_generator/reflection_generator.dart',
      'TomEnv': 'package:tom_build/src/scripting/env.dart',
      'TomEnvironmentException': 'package:tom_build/src/scripting/env.dart',
      'TomFs': 'package:tom_build/src/scripting/fs.dart',
      'TomGlob': 'package:tom_build/src/scripting/glob.dart',
      'TomMaps': 'package:tom_build/src/scripting/maps.dart',
      'TomPth': 'package:tom_build/src/scripting/path.dart',
      'TomShell': 'package:tom_build/src/scripting/shell.dart',
      'TomShellException': 'package:tom_build/src/scripting/shell.dart',
      'TomText': 'package:tom_build/src/scripting/text.dart',
      'WorkspaceInfo': 'package:tom_build/src/tools/workspace_info.dart',
      'MetadataModes': 'package:tom_build/src/tools/workspace_info.dart',
      'MetadataMode': 'package:tom_build/src/tools/workspace_info.dart',
      'WorkspaceGroup': 'package:tom_build/src/tools/workspace_info.dart',
      'WorkspaceProject': 'package:tom_build/src/tools/workspace_info.dart',
      'PlatformInfo': 'package:tom_build/src/tools/tool_context.dart',
      'ToolContext': 'package:tom_build/src/tools/tool_context.dart',
      'ToolContextException': 'package:tom_build/src/tools/tool_context.dart',
      'ModeValidationResult': 'package:tom_build/src/tools/tool_context.dart',
      'TomWs': 'package:tom_build/src/scripting/workspace.dart',
      'ScriptYaml': 'package:tom_build/src/scripting/yaml.dart',
      'TomZoned': 'package:tom_build/src/scripting/zone.dart',
      'TomWorkspace': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'TomMaster': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'TomProject': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'WorkspaceModes': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'SupportedMode': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ModeTypeConfig': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ModeEntry': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ActionModeConfiguration': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ActionModeEntry': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ModeDefinitions': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ModeDef': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ActionDef': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ActionConfig': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'GroupDef': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ProjectTypeDef': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'Features': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'CrossCompilation': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'BuildOnTarget': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'Pipeline': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'PipelineProject': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'PipelineAction': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ProjectEntry': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'VersionSettings': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'PackageModule': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'Part': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'Module': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'ExecutableDef': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'WorkspaceParser': 'package:tom_build/src/tom/file_object_model/workspace_parser.dart',
      'TomContext': 'package:tom_build/src/tom/tom_context.dart',
    };
  }

  /// Returns a map of class names to their flattened (transitive)
  /// native supertype names (superclasses, interfaces and mixins).
  ///
  /// Fed to `BridgedClass.registerSupertypes` so interpreted subclasses
  /// of bridged classes pass `is`/subtype checks against bridged
  /// ancestors and the interface-proxy supertype walk resolves up the
  /// chain (MCI#1 / A1).
  static Map<String, List<String>> classSupertypes() {
    return {
      'TomEnvironmentException': ['Exception'],
      'TomShellException': ['Exception'],
      'ToolContextException': ['Exception'],
      'TomMaster': ['TomWorkspace'],
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
      BridgedEnumDefinition<$tom_build_16.CpuArchitecture>(
        name: 'CpuArchitecture',
        values: $tom_build_16.CpuArchitecture.values,
        methods: {
          'toString': (visitor, target, positional, named, typeArgs) {
            final t = target as $tom_build_16.CpuArchitecture;
            return Function.apply(t.toString, positional, named.map((k, v) => MapEntry(Symbol(k), v)));
          },
        },
      ),
      BridgedEnumDefinition<$tom_build_16.OperatingSystem>(
        name: 'OperatingSystem',
        values: $tom_build_16.OperatingSystem.values,
        methods: {
          'toString': (visitor, target, positional, named, typeArgs) {
            final t = target as $tom_build_16.OperatingSystem;
            return Function.apply(t.toString, positional, named.map((k, v) => MapEntry(Symbol(k), v)));
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
      'CpuArchitecture': 'package:tom_build/src/tools/tool_context.dart',
      'OperatingSystem': 'package:tom_build/src/tools/tool_context.dart',
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
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/analyzer/workspace_analyzer.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/reflection_generator/reflection_generator.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/env.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/fs.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/glob.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/maps.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/path.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/shell.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/text.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/workspace.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/yaml.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/scripting/zone.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/tom/file_object_model/file_object_model.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/tom/file_object_model/workspace_parser.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/tom/tom_context.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/tools/tool_context.dart', show: null, hide: null),
      (source: 'package:tom_build/tom_build.dart', target: 'package:tom_build/src/tools/workspace_info.dart', show: null, hide: null),
      (source: 'package:tom_build/src/tools/tool_context.dart', target: 'package:tom_build/src/tools/workspace_info.dart', show: null, hide: null),
      (source: 'package:tom_build/src/scripting/workspace.dart', target: 'package:tom_build/src/tools/tool_context.dart', show: {'PlatformInfo', 'OperatingSystem', 'CpuArchitecture'}, hide: null),
      (source: 'package:tom_build/src/scripting/workspace.dart', target: 'package:tom_build/src/tools/workspace_info.dart', show: {'WorkspaceInfo', 'WorkspaceGroup', 'WorkspaceProject', 'MetadataModes', 'MetadataMode'}, hide: null),
    ];
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

    // MCI#1 / A1: Register the flattened native supertype table so
    // interpreted subclasses pass subtype checks against bridged
    // ancestors. Idempotent — safe to call per barrel.
    BridgedClass.registerSupertypes(classSupertypes());

    // Register bridged enums with source URIs for deduplication
    final enums = bridgedEnums();
    final enumSources = enumSourceUris();
    for (final enumDef in enums) {
      interpreter.registerBridgedEnum(enumDef, importPath, sourceUri: enumSources[enumDef.name]);
    }

    // Register global variables
    registerGlobalVariables(interpreter, importPath);

    // Register global functions with source URIs for deduplication
    final funcs = globalFunctions();
    final funcSources = globalFunctionSourceUris();
    final funcSigs = globalFunctionSignatures();
    for (final entry in funcs.entries) {
      interpreter.registertopLevelFunction(entry.key, entry.value, importPath, sourceUri: funcSources[entry.key], signature: funcSigs[entry.key]);
    }

    // GEN-107: Register library re-exports
    for (final r in bridgeReExports()) {
      interpreter.registerLibraryReExport(r.source, r.target, show: r.show, hide: r.hide);
    }
  }

  /// Registers all global variables with the interpreter.
  ///
  /// [importPath] is the package import path for library-scoped registration.
  /// Collects all registration errors and throws a single exception
  /// with all error details if any registrations fail.
  static void registerGlobalVariables(D4rt interpreter, String importPath) {
    final errors = <String>[];

    try {
      interpreter.registerGlobalVariable('tom', $tom_build_15.tom, importPath, sourceUri: 'package:tom_build/src/tom/tom_context.dart');
    } catch (e) {
      errors.add('Failed to register variable "tom": $e');
    }

    if (errors.isNotEmpty) {
      throw StateError('Bridge registration errors (tom_build):\n${errors.join("\n")}');
    }
  }

  /// Returns a map of global function names to their native implementations.
  static Map<String, NativeFunctionImpl> globalFunctions() {
    return {
      'loadYamlFile': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadYamlFile');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'loadYamlFile');
        return $tom_build_13.loadYamlFile(path);
      },
      'makeCleanMap': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'makeCleanMap');
        final data = D4.getRequiredArg<dynamic>(positional, 0, 'data', 'makeCleanMap');
        return $tom_build_13.makeCleanMap(data);
      },
      'toYamlString': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'toYamlString');
        final data = D4.getRequiredArg<Map<String, dynamic>>(positional, 0, 'data', 'toYamlString');
        final indent = D4.getNamedArgWithDefault<int>(named, 'indent', 0);
        return $tom_build_13.toYamlString(data, indent: indent);
      },
      'initializeTomContext': (visitor, positional, named, typeArgs) {
        final workspace = D4.getRequiredNamedArg<$tom_build_13.TomWorkspace>(named, 'workspace', 'initializeTomContext');
        final workspaceContext = D4.getOptionalNamedArg<Object?>(named, 'workspaceContext');
        final currentProject = D4.getOptionalNamedArg<$tom_build_13.TomProject?>(named, 'currentProject');
        final workspacePath = D4.getOptionalNamedArg<String?>(named, 'workspacePath');
        return $tom_build_15.initializeTomContext(workspace: workspace, workspaceContext: workspaceContext, currentProject: currentProject, workspacePath: workspacePath);
      },
      'resetTomContext': (visitor, positional, named, typeArgs) {
        return $tom_build_15.resetTomContext();
      },
    };
  }

  /// Returns a map of global function names to their canonical source URIs.
  ///
  /// Used for deduplication when the same function is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> globalFunctionSourceUris() {
    return {
      'loadYamlFile': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'makeCleanMap': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'toYamlString': 'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'initializeTomContext': 'package:tom_build/src/tom/tom_context.dart',
      'resetTomContext': 'package:tom_build/src/tom/tom_context.dart',
    };
  }

  /// Returns a map of global function names to their display signatures.
  static Map<String, String> globalFunctionSignatures() {
    return {
      'loadYamlFile': 'Map<String, dynamic> loadYamlFile(String path)',
      'makeCleanMap': 'Map<String, dynamic> makeCleanMap(dynamic data)',
      'toYamlString': 'String toYamlString(Map<String, dynamic> data, {int indent = 0})',
      'initializeTomContext': 'void initializeTomContext({required TomWorkspace workspace, Object? workspaceContext, TomProject? currentProject, String? workspacePath})',
      'resetTomContext': 'void resetTomContext()',
    };
  }

  /// Returns the list of canonical source library URIs.
  ///
  /// These are the actual source locations of all elements in this bridge,
  /// used for deduplication when the same libraries are exported through
  /// multiple barrels.
  static List<String> sourceLibraries() {
    return [
      'package:tom_build/src/analyzer/workspace_analyzer.dart',
      'package:tom_build/src/reflection_generator/reflection_generator.dart',
      'package:tom_build/src/scripting/env.dart',
      'package:tom_build/src/scripting/fs.dart',
      'package:tom_build/src/scripting/glob.dart',
      'package:tom_build/src/scripting/maps.dart',
      'package:tom_build/src/scripting/path.dart',
      'package:tom_build/src/scripting/shell.dart',
      'package:tom_build/src/scripting/text.dart',
      'package:tom_build/src/scripting/workspace.dart',
      'package:tom_build/src/scripting/yaml.dart',
      'package:tom_build/src/scripting/zone.dart',
      'package:tom_build/src/tom/file_object_model/file_object_model.dart',
      'package:tom_build/src/tom/file_object_model/workspace_parser.dart',
      'package:tom_build/src/tom/tom_context.dart',
      'package:tom_build/src/tools/tool_context.dart',
      'package:tom_build/src/tools/workspace_info.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    return "import 'package:tom_build/tom_build.dart';";
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
    'CpuArchitecture',
    'OperatingSystem',
  ];

}

// =============================================================================
// AnalyzerOptions Bridge
// =============================================================================

BridgedClass _createAnalyzerOptionsBridge() {
  return BridgedClass(
    nativeType: $tom_build_1.AnalyzerOptions,
    name: 'AnalyzerOptions',
    isAssignable: (v) => v is $tom_build_1.AnalyzerOptions,
    constructors: {
      '': (visitor, positional, named) {
        final includeTestProjects = D4.getNamedArgWithDefault<bool>(named, 'includeTestProjects', false);
        return $tom_build_1.AnalyzerOptions(includeTestProjects: includeTestProjects);
      },
    },
    getters: {
      'includeTestProjects': (visitor, target) => D4.validateTarget<$tom_build_1.AnalyzerOptions>(target, 'AnalyzerOptions').includeTestProjects,
    },
    staticGetters: {
      'all': (visitor) => $tom_build_1.AnalyzerOptions.all,
      'production': (visitor) => $tom_build_1.AnalyzerOptions.production,
    },
    constructorSignatures: {
      '': 'const AnalyzerOptions({bool includeTestProjects = false})',
    },
    getterSignatures: {
      'includeTestProjects': 'bool get includeTestProjects',
    },
    staticGetterSignatures: {
      'all': 'AnalyzerOptions get all',
      'production': 'AnalyzerOptions get production',
    },
  );
}

// =============================================================================
// WorkspaceAnalyzer Bridge
// =============================================================================

BridgedClass _createWorkspaceAnalyzerBridge() {
  return BridgedClass(
    nativeType: $tom_build_1.WorkspaceAnalyzer,
    name: 'WorkspaceAnalyzer',
    isAssignable: (v) => v is $tom_build_1.WorkspaceAnalyzer,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'WorkspaceAnalyzer');
        final workspaceRoot = D4.getRequiredArg<String>(positional, 0, 'workspaceRoot', 'WorkspaceAnalyzer');
        final options = D4.getNamedArgWithDefault<$tom_build_1.AnalyzerOptions>(named, 'options', const $tom_build_1.AnalyzerOptions());
        return $tom_build_1.WorkspaceAnalyzer(workspaceRoot, options: options);
      },
    },
    getters: {
      'workspaceRoot': (visitor, target) => D4.validateTarget<$tom_build_1.WorkspaceAnalyzer>(target, 'WorkspaceAnalyzer').workspaceRoot,
      'options': (visitor, target) => D4.validateTarget<$tom_build_1.WorkspaceAnalyzer>(target, 'WorkspaceAnalyzer').options,
      'projects': (visitor, target) => D4.validateTarget<$tom_build_1.WorkspaceAnalyzer>(target, 'WorkspaceAnalyzer').projects,
      'workspaceSettings': (visitor, target) => D4.validateTarget<$tom_build_1.WorkspaceAnalyzer>(target, 'WorkspaceAnalyzer').workspaceSettings,
      'buildOrder': (visitor, target) => D4.validateTarget<$tom_build_1.WorkspaceAnalyzer>(target, 'WorkspaceAnalyzer').buildOrder,
    },
    setters: {
      'buildOrder': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.WorkspaceAnalyzer>(target, 'WorkspaceAnalyzer').buildOrder = D4.coerceList<String>(value, 'buildOrder'),
    },
    methods: {
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_1.WorkspaceAnalyzer>(target, 'WorkspaceAnalyzer');
        return t.analyze();
      },
    },
    staticGetters: {
      'defaultWorkspaceSettings': (visitor) => $tom_build_1.WorkspaceAnalyzer.defaultWorkspaceSettings,
      'defaultBuildConfig': (visitor) => $tom_build_1.WorkspaceAnalyzer.defaultBuildConfig,
      'defaultRunConfig': (visitor) => $tom_build_1.WorkspaceAnalyzer.defaultRunConfig,
      'defaultDeployConfig': (visitor) => $tom_build_1.WorkspaceAnalyzer.defaultDeployConfig,
    },
    constructorSignatures: {
      '': 'WorkspaceAnalyzer(String workspaceRoot, {AnalyzerOptions options = const AnalyzerOptions()})',
    },
    methodSignatures: {
      'analyze': 'Future<void> analyze()',
    },
    getterSignatures: {
      'workspaceRoot': 'String get workspaceRoot',
      'options': 'AnalyzerOptions get options',
      'projects': 'List<ProjectInfo> get projects',
      'workspaceSettings': 'Map<String, dynamic> get workspaceSettings',
      'buildOrder': 'List<String> get buildOrder',
    },
    setterSignatures: {
      'workspaceSettings': 'set workspaceSettings(dynamic value)',
      'buildOrder': 'set buildOrder(dynamic value)',
    },
    staticGetterSignatures: {
      'defaultWorkspaceSettings': 'Map<String, Object> get defaultWorkspaceSettings',
      'defaultBuildConfig': 'Map<String, Map<String, dynamic>> get defaultBuildConfig',
      'defaultRunConfig': 'Map<String, Map<String, dynamic>> get defaultRunConfig',
      'defaultDeployConfig': 'Map<String, Map<String, dynamic>> get defaultDeployConfig',
    },
  );
}

// =============================================================================
// ProjectInfo Bridge
// =============================================================================

BridgedClass _createProjectInfoBridge() {
  return BridgedClass(
    nativeType: $tom_build_1.ProjectInfo,
    name: 'ProjectInfo',
    isAssignable: (v) => v is $tom_build_1.ProjectInfo,
    constructors: {
      '': (visitor, positional, named) {
        final path = D4.getRequiredNamedArg<String>(named, 'path', 'ProjectInfo');
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'ProjectInfo');
        final displayName = D4.getRequiredNamedArg<String>(named, 'displayName', 'ProjectInfo');
        final projectName = D4.getOptionalNamedArg<String?>(named, 'projectName');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final type = D4.getRequiredNamedArg<String>(named, 'type', 'ProjectInfo');
        final projectFolder = D4.getOptionalNamedArg<String?>(named, 'projectFolder');
        return $tom_build_1.ProjectInfo(path: path, name: name, displayName: displayName, projectName: projectName, description: description, type: type, projectFolder: projectFolder);
      },
    },
    getters: {
      'path': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').path,
      'name': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').name,
      'displayName': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').displayName,
      'projectName': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').projectName,
      'description': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').description,
      'type': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').type,
      'projectFolder': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').projectFolder,
      'packageModule': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').packageModule,
      'appModule': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').appModule,
      'parts': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').parts,
      'copilotGuidelines': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').copilotGuidelines,
      'docs': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').docs,
      'tests': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').tests,
      'examples': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').examples,
      'localIndexEntries': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').localIndexEntries,
      'buildAfter': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').buildAfter,
      'features': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').features,
      'pubspec': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').pubspec,
      'packageJson': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').packageJson,
      'pyproject': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').pyproject,
      'buildConfig': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').buildConfig,
      'runConfig': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').runConfig,
      'deployConfig': (visitor, target) => D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').deployConfig,
    },
    setters: {
      'packageModule': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').packageModule = D4.extractBridgedArgOrNull<$tom_build_1.ModuleInfo>(value, 'packageModule'),
      'appModule': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').appModule = D4.extractBridgedArgOrNull<$tom_build_1.ModuleInfo>(value, 'appModule'),
      'copilotGuidelines': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').copilotGuidelines = D4.coerceList<String>(value, 'copilotGuidelines'),
      'docs': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').docs = D4.coerceList<String>(value, 'docs'),
      'tests': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').tests = D4.coerceList<String>(value, 'tests'),
      'examples': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').examples = D4.coerceList<String>(value, 'examples'),
      'buildAfter': (visitor, target, value) => 
        D4.validateTarget<$tom_build_1.ProjectInfo>(target, 'ProjectInfo').buildAfter = D4.coerceList<String>(value, 'buildAfter'),
    },
    constructorSignatures: {
      '': 'ProjectInfo({required String path, required String name, required String displayName, String? projectName, String? description, required String type, String? projectFolder})',
    },
    getterSignatures: {
      'path': 'String get path',
      'name': 'String get name',
      'displayName': 'String get displayName',
      'projectName': 'String? get projectName',
      'description': 'String? get description',
      'type': 'String get type',
      'projectFolder': 'String? get projectFolder',
      'packageModule': 'ModuleInfo? get packageModule',
      'appModule': 'ModuleInfo? get appModule',
      'parts': 'List<PartInfo> get parts',
      'copilotGuidelines': 'List<String> get copilotGuidelines',
      'docs': 'List<String> get docs',
      'tests': 'List<String> get tests',
      'examples': 'List<String> get examples',
      'localIndexEntries': 'Map<String, dynamic> get localIndexEntries',
      'buildAfter': 'List<String> get buildAfter',
      'features': 'Map<String, bool> get features',
      'pubspec': 'Map<String, dynamic> get pubspec',
      'packageJson': 'Map<String, dynamic> get packageJson',
      'pyproject': 'Map<String, dynamic> get pyproject',
      'buildConfig': 'Map<String, dynamic> get buildConfig',
      'runConfig': 'Map<String, dynamic> get runConfig',
      'deployConfig': 'Map<String, dynamic> get deployConfig',
    },
    setterSignatures: {
      'packageModule': 'set packageModule(dynamic value)',
      'appModule': 'set appModule(dynamic value)',
      'copilotGuidelines': 'set copilotGuidelines(dynamic value)',
      'docs': 'set docs(dynamic value)',
      'tests': 'set tests(dynamic value)',
      'examples': 'set examples(dynamic value)',
      'localIndexEntries': 'set localIndexEntries(dynamic value)',
      'buildAfter': 'set buildAfter(dynamic value)',
      'features': 'set features(dynamic value)',
      'pubspec': 'set pubspec(dynamic value)',
      'packageJson': 'set packageJson(dynamic value)',
      'pyproject': 'set pyproject(dynamic value)',
      'buildConfig': 'set buildConfig(dynamic value)',
      'runConfig': 'set runConfig(dynamic value)',
      'deployConfig': 'set deployConfig(dynamic value)',
    },
  );
}

// =============================================================================
// PartInfo Bridge
// =============================================================================

BridgedClass _createPartInfoBridge() {
  return BridgedClass(
    nativeType: $tom_build_1.PartInfo,
    name: 'PartInfo',
    isAssignable: (v) => v is $tom_build_1.PartInfo,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'PartInfo');
        final displayName = D4.getRequiredNamedArg<String>(named, 'displayName', 'PartInfo');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final sources = D4.coerceListOrNull<String>(named['sources'], 'sources');
        return $tom_build_1.PartInfo(name: name, displayName: displayName, description: description, sources: sources);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_1.PartInfo>(target, 'PartInfo').name,
      'displayName': (visitor, target) => D4.validateTarget<$tom_build_1.PartInfo>(target, 'PartInfo').displayName,
      'description': (visitor, target) => D4.validateTarget<$tom_build_1.PartInfo>(target, 'PartInfo').description,
      'sources': (visitor, target) => D4.validateTarget<$tom_build_1.PartInfo>(target, 'PartInfo').sources,
      'modules': (visitor, target) => D4.validateTarget<$tom_build_1.PartInfo>(target, 'PartInfo').modules,
    },
    constructorSignatures: {
      '': 'PartInfo({required String name, required String displayName, String? description, List<String>? sources})',
    },
    getterSignatures: {
      'name': 'String get name',
      'displayName': 'String get displayName',
      'description': 'String? get description',
      'sources': 'List<String> get sources',
      'modules': 'List<ModuleInfo> get modules',
    },
  );
}

// =============================================================================
// ModuleInfo Bridge
// =============================================================================

BridgedClass _createModuleInfoBridge() {
  return BridgedClass(
    nativeType: $tom_build_1.ModuleInfo,
    name: 'ModuleInfo',
    isAssignable: (v) => v is $tom_build_1.ModuleInfo,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'ModuleInfo');
        final displayName = D4.getRequiredNamedArg<String>(named, 'displayName', 'ModuleInfo');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final sources = D4.coerceListOrNull<String>(named['sources'], 'sources');
        final subfolders = D4.coerceListOrNull<$tom_build_1.ModuleInfo>(named['subfolders'], 'subfolders');
        return $tom_build_1.ModuleInfo(name: name, displayName: displayName, description: description, sources: sources, subfolders: subfolders);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_1.ModuleInfo>(target, 'ModuleInfo').name,
      'displayName': (visitor, target) => D4.validateTarget<$tom_build_1.ModuleInfo>(target, 'ModuleInfo').displayName,
      'description': (visitor, target) => D4.validateTarget<$tom_build_1.ModuleInfo>(target, 'ModuleInfo').description,
      'sources': (visitor, target) => D4.validateTarget<$tom_build_1.ModuleInfo>(target, 'ModuleInfo').sources,
      'subfolders': (visitor, target) => D4.validateTarget<$tom_build_1.ModuleInfo>(target, 'ModuleInfo').subfolders,
    },
    constructorSignatures: {
      '': 'ModuleInfo({required String name, required String displayName, String? description, List<String>? sources, List<ModuleInfo>? subfolders})',
    },
    getterSignatures: {
      'name': 'String get name',
      'displayName': 'String get displayName',
      'description': 'String? get description',
      'sources': 'List<String> get sources',
      'subfolders': 'List<ModuleInfo> get subfolders',
    },
  );
}

// =============================================================================
// ReflectionGeneratorRunner Bridge
// =============================================================================

BridgedClass _createReflectionGeneratorRunnerBridge() {
  return BridgedClass(
    nativeType: $tom_build_2.ReflectionGeneratorRunner,
    name: 'ReflectionGeneratorRunner',
    isAssignable: (v) => v is $tom_build_2.ReflectionGeneratorRunner,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ReflectionGeneratorRunner');
        final projectPath = D4.getRequiredArg<String>(positional, 0, 'projectPath', 'ReflectionGeneratorRunner');
        final options = D4.getOptionalNamedArg<$tom_build_2.ReflectionGeneratorRunnerOptions?>(named, 'options');
        final workspacePath = D4.getOptionalNamedArg<String?>(named, 'workspacePath');
        return $tom_build_2.ReflectionGeneratorRunner(projectPath, options: options, workspacePath: workspacePath);
      },
    },
    getters: {
      'projectPath': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunner>(target, 'ReflectionGeneratorRunner').projectPath,
      'options': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunner>(target, 'ReflectionGeneratorRunner').options,
      'workspacePath': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunner>(target, 'ReflectionGeneratorRunner').workspacePath,
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_2.ReflectionGeneratorRunner>(target, 'ReflectionGeneratorRunner');
        final target_ = D4.getNamedArgWithDefault<String>(named, 'target', 'lib/');
        final all = D4.getNamedArgWithDefault<bool>(named, 'all', false);
        return t.generate(target: target_, all: all);
      },
      'build': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_2.ReflectionGeneratorRunner>(target, 'ReflectionGeneratorRunner');
        final configFile = D4.getOptionalNamedArg<String?>(named, 'configFile');
        return (t as dynamic).build(configFile: configFile);
      },
    },
    constructorSignatures: {
      '': 'ReflectionGeneratorRunner(String projectPath, {ReflectionGeneratorRunnerOptions? options, String? workspacePath})',
    },
    methodSignatures: {
      'generate': 'Future<ReflectionGeneratorRunnerResult> generate({String target = \'lib/\', bool all = false})',
      'build': 'Future<ReflectionGeneratorRunnerResult> build({String? configFile})',
    },
    getterSignatures: {
      'projectPath': 'String get projectPath',
      'options': 'ReflectionGeneratorRunnerOptions get options',
      'workspacePath': 'String? get workspacePath',
    },
  );
}

// =============================================================================
// ReflectionGeneratorRunnerOptions Bridge
// =============================================================================

BridgedClass _createReflectionGeneratorRunnerOptionsBridge() {
  return BridgedClass(
    nativeType: $tom_build_2.ReflectionGeneratorRunnerOptions,
    name: 'ReflectionGeneratorRunnerOptions',
    isAssignable: (v) => v is $tom_build_2.ReflectionGeneratorRunnerOptions,
    constructors: {
      '': (visitor, positional, named) {
        final verbose = D4.getNamedArgWithDefault<bool>(named, 'verbose', false);
        final packageName = D4.getOptionalNamedArg<String?>(named, 'packageName');
        final extension = D4.getOptionalNamedArg<String?>(named, 'extension');
        return $tom_build_2.ReflectionGeneratorRunnerOptions(verbose: verbose, packageName: packageName, extension: extension);
      },
    },
    getters: {
      'verbose': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerOptions>(target, 'ReflectionGeneratorRunnerOptions').verbose,
      'packageName': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerOptions>(target, 'ReflectionGeneratorRunnerOptions').packageName,
      'extension': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerOptions>(target, 'ReflectionGeneratorRunnerOptions').extension,
    },
    constructorSignatures: {
      '': 'const ReflectionGeneratorRunnerOptions({bool verbose = false, String? packageName, String? extension})',
    },
    getterSignatures: {
      'verbose': 'bool get verbose',
      'packageName': 'String? get packageName',
      'extension': 'String? get extension',
    },
  );
}

// =============================================================================
// ReflectionGeneratorRunnerResult Bridge
// =============================================================================

BridgedClass _createReflectionGeneratorRunnerResultBridge() {
  return BridgedClass(
    nativeType: $tom_build_2.ReflectionGeneratorRunnerResult,
    name: 'ReflectionGeneratorRunnerResult',
    isAssignable: (v) => v is $tom_build_2.ReflectionGeneratorRunnerResult,
    constructors: {
      '': (visitor, positional, named) {
        final success = D4.getRequiredNamedArg<bool>(named, 'success', 'ReflectionGeneratorRunnerResult');
        final projectPath = D4.getRequiredNamedArg<String>(named, 'projectPath', 'ReflectionGeneratorRunnerResult');
        final message = D4.getOptionalNamedArg<String?>(named, 'message');
        final error = D4.getOptionalNamedArg<String?>(named, 'error');
        final stackTrace = D4.getOptionalNamedArg<StackTrace?>(named, 'stackTrace');
        return $tom_build_2.ReflectionGeneratorRunnerResult(success: success, projectPath: projectPath, message: message, error: error, stackTrace: stackTrace);
      },
    },
    getters: {
      'success': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerResult>(target, 'ReflectionGeneratorRunnerResult').success,
      'projectPath': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerResult>(target, 'ReflectionGeneratorRunnerResult').projectPath,
      'message': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerResult>(target, 'ReflectionGeneratorRunnerResult').message,
      'error': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerResult>(target, 'ReflectionGeneratorRunnerResult').error,
      'stackTrace': (visitor, target) => D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerResult>(target, 'ReflectionGeneratorRunnerResult').stackTrace,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_2.ReflectionGeneratorRunnerResult>(target, 'ReflectionGeneratorRunnerResult');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const ReflectionGeneratorRunnerResult({required bool success, required String projectPath, String? message, String? error, StackTrace? stackTrace})',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'success': 'bool get success',
      'projectPath': 'String get projectPath',
      'message': 'String? get message',
      'error': 'String? get error',
      'stackTrace': 'StackTrace? get stackTrace',
    },
  );
}

// =============================================================================
// TomEnv Bridge
// =============================================================================

BridgedClass _createTomEnvBridge() {
  return BridgedClass(
    nativeType: $tom_build_3.TomEnv,
    name: 'TomEnv',
    isAssignable: (v) => v is $tom_build_3.TomEnv,
    constructors: {
    },
    staticGetters: {
      'home': (visitor) => $tom_build_3.TomEnv.home,
      'path': (visitor) => $tom_build_3.TomEnv.path,
      'shell': (visitor) => $tom_build_3.TomEnv.shell,
      'user': (visitor) => $tom_build_3.TomEnv.user,
      'temp': (visitor) => $tom_build_3.TomEnv.temp,
      'cwd': (visitor) => $tom_build_3.TomEnv.cwd,
      'isCI': (visitor) => $tom_build_3.TomEnv.isCI,
      'isDev': (visitor) => $tom_build_3.TomEnv.isDev,
      'isProd': (visitor) => $tom_build_3.TomEnv.isProd,
      'os': (visitor) => $tom_build_3.TomEnv.os,
      'osVersion': (visitor) => $tom_build_3.TomEnv.osVersion,
      'processors': (visitor) => $tom_build_3.TomEnv.processors,
      'dartVersion': (visitor) => $tom_build_3.TomEnv.dartVersion,
      'hostname': (visitor) => $tom_build_3.TomEnv.hostname,
      'isMacOS': (visitor) => $tom_build_3.TomEnv.isMacOS,
      'isLinux': (visitor) => $tom_build_3.TomEnv.isLinux,
      'isWindows': (visitor) => $tom_build_3.TomEnv.isWindows,
    },
    staticMethods: {
      'load': (visitor, positional, named, typeArgs) {
        final directory = D4.getOptionalArg<String?>(positional, 0, 'directory');
        return $tom_build_3.TomEnv.load(directory);
      },
      'reload': (visitor, positional, named, typeArgs) {
        final directory = D4.getOptionalArg<String?>(positional, 0, 'directory');
        return $tom_build_3.TomEnv.reload(directory);
      },
      'loadFile': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadFile');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'loadFile');
        return $tom_build_3.TomEnv.loadFile(path);
      },
      'resolve': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'resolve');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'resolve');
        final workingDir = D4.getOptionalNamedArg<String?>(named, 'workingDir');
        return $tom_build_3.TomEnv.resolve(text, workingDir: workingDir);
      },
      'resolveWith': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'resolveWith');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'resolveWith');
        if (positional.length <= 1) {
          throw ArgumentError('resolveWith: Missing required argument "environment" at position 1');
        }
        final environment = D4.coerceMap<String, String>(positional[1], 'environment');
        return $tom_build_3.TomEnv.resolveWith(text, environment);
      },
      'resolveMap': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'resolveMap');
        if (positional.isEmpty) {
          throw ArgumentError('resolveMap: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        final workingDir = D4.getOptionalNamedArg<String?>(named, 'workingDir');
        return $tom_build_3.TomEnv.resolveMap(map, workingDir: workingDir);
      },
      'resolveMapWith': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'resolveMapWith');
        if (positional.isEmpty) {
          throw ArgumentError('resolveMapWith: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        if (positional.length <= 1) {
          throw ArgumentError('resolveMapWith: Missing required argument "environment" at position 1');
        }
        final environment = D4.coerceMap<String, String>(positional[1], 'environment');
        return $tom_build_3.TomEnv.resolveMapWith(map, environment);
      },
      'get': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'get');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'get');
        final defaultValue = D4.getOptionalArg<String?>(positional, 1, 'defaultValue');
        return $tom_build_3.TomEnv.get(name, defaultValue);
      },
      'require': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'require');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'require');
        final message = D4.getOptionalNamedArg<String?>(named, 'message');
        return $tom_build_3.TomEnv.require(name, message: message);
      },
      'has': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'has');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'has');
        return $tom_build_3.TomEnv.has(name);
      },
      'isSet': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'isSet');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'isSet');
        return $tom_build_3.TomEnv.isSet(name);
      },
      'all': (visitor, positional, named, typeArgs) {
        return $tom_build_3.TomEnv.all();
      },
      'withPrefix': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'withPrefix');
        final prefix = D4.getRequiredArg<String>(positional, 0, 'prefix', 'withPrefix');
        final strip = D4.getNamedArgWithDefault<bool>(named, 'strip', false);
        return $tom_build_3.TomEnv.withPrefix(prefix, strip: strip);
      },
      'getInt': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getInt');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getInt');
        final defaultValue = D4.getOptionalArg<int?>(positional, 1, 'defaultValue');
        return $tom_build_3.TomEnv.getInt(name, defaultValue);
      },
      'getBool': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getBool');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getBool');
        final defaultValue = D4.getOptionalArgWithDefault<bool>(positional, 1, 'defaultValue', false);
        return $tom_build_3.TomEnv.getBool(name, defaultValue);
      },
      'getList': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getList');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getList');
        final separator = D4.getOptionalNamedArg<String?>(named, 'separator');
        return $tom_build_3.TomEnv.getList(name, separator: separator);
      },
      'expand': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'expand');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'expand');
        return $tom_build_3.TomEnv.expand(text);
      },
      'expandWithDefaults': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'expandWithDefaults');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'expandWithDefaults');
        return $tom_build_3.TomEnv.expandWithDefaults(text);
      },
    },
    staticMethodSignatures: {
      'load': 'Map<String, String> load([String? directory])',
      'reload': 'Map<String, String> reload([String? directory])',
      'loadFile': 'Map<String, String> loadFile(String path)',
      'resolve': 'String resolve(String text, {String? workingDir})',
      'resolveWith': 'String resolveWith(String text, Map<String, String> environment)',
      'resolveMap': 'Map<String, dynamic> resolveMap(Map<String, dynamic> map, {String? workingDir})',
      'resolveMapWith': 'Map<String, dynamic> resolveMapWith(Map<String, dynamic> map, Map<String, String> environment)',
      'get': 'String? get(String name, [String? defaultValue])',
      'require': 'String require(String name, {String? message})',
      'has': 'bool has(String name)',
      'isSet': 'bool isSet(String name)',
      'all': 'Map<String, String> all()',
      'withPrefix': 'Map<String, String> withPrefix(String prefix, {bool strip = false})',
      'getInt': 'int? getInt(String name, [int? defaultValue])',
      'getBool': 'bool getBool(String name, [bool defaultValue = false])',
      'getList': 'List<String> getList(String name, {String? separator})',
      'expand': 'String expand(String text)',
      'expandWithDefaults': 'String expandWithDefaults(String text)',
    },
    staticGetterSignatures: {
      'home': 'String? get home',
      'path': 'List<String> get path',
      'shell': 'String? get shell',
      'user': 'String? get user',
      'temp': 'String? get temp',
      'cwd': 'String get cwd',
      'isCI': 'bool get isCI',
      'isDev': 'bool get isDev',
      'isProd': 'bool get isProd',
      'os': 'String get os',
      'osVersion': 'String get osVersion',
      'processors': 'int get processors',
      'dartVersion': 'String get dartVersion',
      'hostname': 'String get hostname',
      'isMacOS': 'bool get isMacOS',
      'isLinux': 'bool get isLinux',
      'isWindows': 'bool get isWindows',
    },
  );
}

// =============================================================================
// TomEnvironmentException Bridge
// =============================================================================

BridgedClass _createTomEnvironmentExceptionBridge() {
  return BridgedClass(
    nativeType: $tom_build_3.TomEnvironmentException,
    name: 'TomEnvironmentException',
    isAssignable: (v) => v is $tom_build_3.TomEnvironmentException,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomEnvironmentException');
        final message = D4.getRequiredArg<String>(positional, 0, 'message', 'TomEnvironmentException');
        return $tom_build_3.TomEnvironmentException(message);
      },
    },
    getters: {
      'message': (visitor, target) => D4.validateTarget<$tom_build_3.TomEnvironmentException>(target, 'TomEnvironmentException').message,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_3.TomEnvironmentException>(target, 'TomEnvironmentException');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const TomEnvironmentException(String message)',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'message': 'String get message',
    },
  );
}

// =============================================================================
// TomFs Bridge
// =============================================================================

BridgedClass _createTomFsBridge() {
  return BridgedClass(
    nativeType: $tom_build_4.TomFs,
    name: 'TomFs',
    isAssignable: (v) => v is $tom_build_4.TomFs,
    constructors: {
    },
    staticMethods: {
      'read': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'read');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'read');
        return $tom_build_4.TomFs.read(path);
      },
      'readBytes': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'readBytes');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'readBytes');
        return $tom_build_4.TomFs.readBytes(path);
      },
      'readLines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'readLines');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'readLines');
        return $tom_build_4.TomFs.readLines(path);
      },
      'tryRead': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'tryRead');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'tryRead');
        return $tom_build_4.TomFs.tryRead(path);
      },
      'write': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'write');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'write');
        final content = D4.getRequiredArg<String>(positional, 1, 'content', 'write');
        return $tom_build_4.TomFs.write(path, content);
      },
      'writeBytes': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'writeBytes');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'writeBytes');
        if (positional.length <= 1) {
          throw ArgumentError('writeBytes: Missing required argument "bytes" at position 1');
        }
        final bytes = D4.coerceList<int>(positional[1], 'bytes');
        return $tom_build_4.TomFs.writeBytes(path, bytes);
      },
      'append': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'append');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'append');
        final content = D4.getRequiredArg<String>(positional, 1, 'content', 'append');
        return $tom_build_4.TomFs.append(path, content);
      },
      'appendLine': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'appendLine');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'appendLine');
        final line = D4.getRequiredArg<String>(positional, 1, 'line', 'appendLine');
        return $tom_build_4.TomFs.appendLine(path, line);
      },
      'exists': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'exists');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'exists');
        return $tom_build_4.TomFs.exists(path);
      },
      'isFile': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'isFile');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'isFile');
        return $tom_build_4.TomFs.isFile(path);
      },
      'isDir': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'isDir');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'isDir');
        return $tom_build_4.TomFs.isDir(path);
      },
      'isEmpty': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'isEmpty');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'isEmpty');
        return $tom_build_4.TomFs.isEmpty(path);
      },
      'copy': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'copy');
        final from = D4.getRequiredArg<String>(positional, 0, 'from', 'copy');
        final to = D4.getRequiredArg<String>(positional, 1, 'to', 'copy');
        final overwrite = D4.getNamedArgWithDefault<bool>(named, 'overwrite', true);
        return $tom_build_4.TomFs.copy(from, to, overwrite: overwrite);
      },
      'move': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'move');
        final from = D4.getRequiredArg<String>(positional, 0, 'from', 'move');
        final to = D4.getRequiredArg<String>(positional, 1, 'to', 'move');
        return $tom_build_4.TomFs.move(from, to);
      },
      'delete': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'delete');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'delete');
        final recursive = D4.getNamedArgWithDefault<bool>(named, 'recursive', false);
        return $tom_build_4.TomFs.delete(path, recursive: recursive);
      },
      'deleteIfExists': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'deleteIfExists');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'deleteIfExists');
        final recursive = D4.getNamedArgWithDefault<bool>(named, 'recursive', false);
        return $tom_build_4.TomFs.deleteIfExists(path, recursive: recursive);
      },
      'mkdir': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'mkdir');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'mkdir');
        return $tom_build_4.TomFs.mkdir(path);
      },
      'ls': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'ls');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'ls');
        final recursive = D4.getNamedArgWithDefault<bool>(named, 'recursive', false);
        final filesOnly = D4.getNamedArgWithDefault<bool>(named, 'filesOnly', false);
        final dirsOnly = D4.getNamedArgWithDefault<bool>(named, 'dirsOnly', false);
        return $tom_build_4.TomFs.ls(path, recursive: recursive, filesOnly: filesOnly, dirsOnly: dirsOnly);
      },
      'files': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'files');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'files');
        final recursive = D4.getNamedArgWithDefault<bool>(named, 'recursive', false);
        return $tom_build_4.TomFs.files(path, recursive: recursive);
      },
      'dirs': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'dirs');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'dirs');
        final recursive = D4.getNamedArgWithDefault<bool>(named, 'recursive', false);
        return $tom_build_4.TomFs.dirs(path, recursive: recursive);
      },
      'size': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'size');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'size');
        return $tom_build_4.TomFs.size(path);
      },
      'mtime': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'mtime');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'mtime');
        return $tom_build_4.TomFs.mtime(path);
      },
      'atime': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'atime');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'atime');
        return $tom_build_4.TomFs.atime(path);
      },
      'touch': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'touch');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'touch');
        final time = D4.getOptionalArg<DateTime?>(positional, 1, 'time');
        return $tom_build_4.TomFs.touch(path, time);
      },
      'temp': (visitor, positional, named, typeArgs) {
        final prefix = D4.getOptionalNamedArg<String?>(named, 'prefix');
        final suffix = D4.getOptionalNamedArg<String?>(named, 'suffix');
        final content = D4.getOptionalNamedArg<String?>(named, 'content');
        return $tom_build_4.TomFs.temp(prefix: prefix, suffix: suffix, content: content);
      },
      'tempDir': (visitor, positional, named, typeArgs) {
        final prefix = D4.getOptionalNamedArg<String?>(named, 'prefix');
        return $tom_build_4.TomFs.tempDir(prefix: prefix);
      },
    },
    staticMethodSignatures: {
      'read': 'String read(String path)',
      'readBytes': 'List<int> readBytes(String path)',
      'readLines': 'List<String> readLines(String path)',
      'tryRead': 'String? tryRead(String path)',
      'write': 'void write(String path, String content)',
      'writeBytes': 'void writeBytes(String path, List<int> bytes)',
      'append': 'void append(String path, String content)',
      'appendLine': 'void appendLine(String path, String line)',
      'exists': 'bool exists(String path)',
      'isFile': 'bool isFile(String path)',
      'isDir': 'bool isDir(String path)',
      'isEmpty': 'bool isEmpty(String path)',
      'copy': 'void copy(String from, String to, {bool overwrite = true})',
      'move': 'void move(String from, String to)',
      'delete': 'void delete(String path, {bool recursive = false})',
      'deleteIfExists': 'void deleteIfExists(String path, {bool recursive = false})',
      'mkdir': 'void mkdir(String path)',
      'ls': 'List<String> ls(String path, {bool recursive = false, bool filesOnly = false, bool dirsOnly = false})',
      'files': 'List<String> files(String path, {bool recursive = false})',
      'dirs': 'List<String> dirs(String path, {bool recursive = false})',
      'size': 'int size(String path)',
      'mtime': 'DateTime mtime(String path)',
      'atime': 'DateTime atime(String path)',
      'touch': 'void touch(String path, [DateTime? time])',
      'temp': 'String temp({String? prefix, String? suffix, String? content})',
      'tempDir': 'String tempDir({String? prefix})',
    },
  );
}

// =============================================================================
// TomGlob Bridge
// =============================================================================

BridgedClass _createTomGlobBridge() {
  return BridgedClass(
    nativeType: $tom_build_5.TomGlob,
    name: 'TomGlob',
    isAssignable: (v) => v is $tom_build_5.TomGlob,
    constructors: {
    },
    staticMethods: {
      'find': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'find');
        final pattern = D4.getRequiredArg<String>(positional, 0, 'pattern', 'find');
        final root = D4.getOptionalNamedArg<String?>(named, 'root');
        final followLinks = D4.getNamedArgWithDefault<bool>(named, 'followLinks', true);
        return $tom_build_5.TomGlob.find(pattern, root: root, followLinks: followLinks);
      },
      'findAny': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'findAny');
        if (positional.isEmpty) {
          throw ArgumentError('findAny: Missing required argument "patterns" at position 0');
        }
        final patterns = D4.coerceList<String>(positional[0], 'patterns');
        final root = D4.getOptionalNamedArg<String?>(named, 'root');
        final followLinks = D4.getNamedArgWithDefault<bool>(named, 'followLinks', true);
        return $tom_build_5.TomGlob.findAny(patterns, root: root, followLinks: followLinks);
      },
      'findFiles': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'findFiles');
        final pattern = D4.getRequiredArg<String>(positional, 0, 'pattern', 'findFiles');
        final root = D4.getOptionalNamedArg<String?>(named, 'root');
        return $tom_build_5.TomGlob.findFiles(pattern, root: root);
      },
      'findDirs': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'findDirs');
        final pattern = D4.getRequiredArg<String>(positional, 0, 'pattern', 'findDirs');
        final root = D4.getOptionalNamedArg<String?>(named, 'root');
        return $tom_build_5.TomGlob.findDirs(pattern, root: root);
      },
      'matches': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'matches');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'matches');
        final pattern = D4.getRequiredArg<String>(positional, 1, 'pattern', 'matches');
        return $tom_build_5.TomGlob.matches(path, pattern);
      },
      'matchesAny': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'matchesAny');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'matchesAny');
        if (positional.length <= 1) {
          throw ArgumentError('matchesAny: Missing required argument "patterns" at position 1');
        }
        final patterns = D4.coerceList<String>(positional[1], 'patterns');
        return $tom_build_5.TomGlob.matchesAny(path, patterns);
      },
      'filter': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'filter');
        if (positional.isEmpty) {
          throw ArgumentError('filter: Missing required argument "paths" at position 0');
        }
        final paths = D4.coerceList<String>(positional[0], 'paths');
        final pattern = D4.getRequiredArg<String>(positional, 1, 'pattern', 'filter');
        return $tom_build_5.TomGlob.filter(paths, pattern);
      },
      'exclude': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'exclude');
        if (positional.isEmpty) {
          throw ArgumentError('exclude: Missing required argument "paths" at position 0');
        }
        final paths = D4.coerceList<String>(positional[0], 'paths');
        final pattern = D4.getRequiredArg<String>(positional, 1, 'pattern', 'exclude');
        return $tom_build_5.TomGlob.exclude(paths, pattern);
      },
    },
    staticMethodSignatures: {
      'find': 'List<String> find(String pattern, {String? root, bool followLinks = true})',
      'findAny': 'List<String> findAny(List<String> patterns, {String? root, bool followLinks = true})',
      'findFiles': 'List<String> findFiles(String pattern, {String? root})',
      'findDirs': 'List<String> findDirs(String pattern, {String? root})',
      'matches': 'bool matches(String path, String pattern)',
      'matchesAny': 'bool matchesAny(String path, List<String> patterns)',
      'filter': 'List<String> filter(List<String> paths, String pattern)',
      'exclude': 'List<String> exclude(List<String> paths, String pattern)',
    },
  );
}

// =============================================================================
// TomMaps Bridge
// =============================================================================

BridgedClass _createTomMapsBridge() {
  return BridgedClass(
    nativeType: $tom_build_6.TomMaps,
    name: 'TomMaps',
    isAssignable: (v) => v is $tom_build_6.TomMaps,
    constructors: {
    },
    staticMethods: {
      'mergeOneSided': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'mergeOneSided');
        if (positional.isEmpty) {
          throw ArgumentError('mergeOneSided: Missing required argument "target" at position 0');
        }
        final target_ = D4.coerceMap<String, dynamic>(positional[0], 'target');
        if (positional.length <= 1) {
          throw ArgumentError('mergeOneSided: Missing required argument "source" at position 1');
        }
        final source = D4.coerceMap<String, dynamic>(positional[1], 'source');
        return $tom_build_6.TomMaps.mergeOneSided(target_, source);
      },
      'merge': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'merge');
        if (positional.isEmpty) {
          throw ArgumentError('merge: Missing required argument "base" at position 0');
        }
        final base = D4.coerceMap<String, dynamic>(positional[0], 'base');
        if (positional.length <= 1) {
          throw ArgumentError('merge: Missing required argument "overrides" at position 1');
        }
        final overrides = D4.coerceMap<String, dynamic>(positional[1], 'overrides');
        return $tom_build_6.TomMaps.merge(base, overrides);
      },
      'mergeAll': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'mergeAll');
        if (positional.isEmpty) {
          throw ArgumentError('mergeAll: Missing required argument "maps" at position 0');
        }
        final maps = D4.coerceList<Map<String, dynamic>>(positional[0], 'maps');
        return $tom_build_6.TomMaps.mergeAll(maps);
      },
      'traverse': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'traverse');
        if (positional.isEmpty) {
          throw ArgumentError('traverse: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        if (positional.length <= 1) {
          throw ArgumentError('traverse: Missing required argument "processor" at position 1');
        }
        final processorRaw = positional[1];
        final processor = (String p0, dynamic p1) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, processorRaw, [p0, p1])); };
        final prefix = D4.getNamedArgWithDefault<String>(named, 'prefix', '');
        return $tom_build_6.TomMaps.traverse(map, processor, prefix: prefix);
      },
      'flatten': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'flatten');
        if (positional.isEmpty) {
          throw ArgumentError('flatten: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        return $tom_build_6.TomMaps.flatten(map);
      },
      'unflatten': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'unflatten');
        if (positional.isEmpty) {
          throw ArgumentError('unflatten: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        return $tom_build_6.TomMaps.unflatten(map);
      },
      'get': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'get');
        if (positional.isEmpty) {
          throw ArgumentError('get: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        final path = D4.getRequiredArg<String>(positional, 1, 'path', 'get');
        return $tom_build_6.TomMaps.get(map, path);
      },
      'getOr': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'getOr');
        if (positional.isEmpty) {
          throw ArgumentError('getOr: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        final path = D4.getRequiredArg<String>(positional, 1, 'path', 'getOr');
        final defaultValue = D4.getRequiredArg<dynamic>(positional, 2, 'defaultValue', 'getOr');
        return $tom_build_6.TomMaps.getOr(map, path, defaultValue);
      },
      'set': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'set');
        if (positional.isEmpty) {
          throw ArgumentError('set: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        final path = D4.getRequiredArg<String>(positional, 1, 'path', 'set');
        final value = D4.getRequiredArg<dynamic>(positional, 2, 'value', 'set');
        return $tom_build_6.TomMaps.set(map, path, value);
      },
      'has': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'has');
        if (positional.isEmpty) {
          throw ArgumentError('has: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        final path = D4.getRequiredArg<String>(positional, 1, 'path', 'has');
        return $tom_build_6.TomMaps.has(map, path);
      },
      'remove': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'remove');
        if (positional.isEmpty) {
          throw ArgumentError('remove: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        final path = D4.getRequiredArg<String>(positional, 1, 'path', 'remove');
        return $tom_build_6.TomMaps.remove(map, path);
      },
      'copy': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'copy');
        if (positional.isEmpty) {
          throw ArgumentError('copy: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        return $tom_build_6.TomMaps.copy(map);
      },
      'clean': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'clean');
        final map = D4.getRequiredArg<Map>(positional, 0, 'map', 'clean');
        return $tom_build_6.TomMaps.clean(map);
      },
      'pick': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'pick');
        if (positional.isEmpty) {
          throw ArgumentError('pick: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        if (positional.length <= 1) {
          throw ArgumentError('pick: Missing required argument "keys" at position 1');
        }
        final keys = D4.coerceList<String>(positional[1], 'keys');
        return $tom_build_6.TomMaps.pick(map, keys);
      },
      'omit': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'omit');
        if (positional.isEmpty) {
          throw ArgumentError('omit: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, dynamic>(positional[0], 'map');
        if (positional.length <= 1) {
          throw ArgumentError('omit: Missing required argument "keys" at position 1');
        }
        final keys = D4.coerceList<String>(positional[1], 'keys');
        return $tom_build_6.TomMaps.omit(map, keys);
      },
    },
    staticMethodSignatures: {
      'mergeOneSided': 'Map<String, dynamic> mergeOneSided(Map<String, dynamic> target, Map<String, dynamic> source)',
      'merge': 'Map<String, dynamic> merge(Map<String, dynamic> base, Map<String, dynamic> overrides)',
      'mergeAll': 'Map<String, dynamic> mergeAll(List<Map<String, dynamic>> maps)',
      'traverse': 'Map<String, dynamic> traverse(Map<String, dynamic> map, dynamic Function(String key, dynamic value) processor, {String prefix = \'\'})',
      'flatten': 'Map<String, dynamic> flatten(Map<String, dynamic> map)',
      'unflatten': 'Map<String, dynamic> unflatten(Map<String, dynamic> map)',
      'get': 'T? get(Map<String, dynamic> map, String path)',
      'getOr': 'T getOr(Map<String, dynamic> map, String path, T defaultValue)',
      'set': 'void set(Map<String, dynamic> map, String path, dynamic value)',
      'has': 'bool has(Map<String, dynamic> map, String path)',
      'remove': 'dynamic remove(Map<String, dynamic> map, String path)',
      'copy': 'Map<String, dynamic> copy(Map<String, dynamic> map)',
      'clean': 'Map<String, dynamic> clean(Map map)',
      'pick': 'Map<String, dynamic> pick(Map<String, dynamic> map, List<String> keys)',
      'omit': 'Map<String, dynamic> omit(Map<String, dynamic> map, List<String> keys)',
    },
  );
}

// =============================================================================
// TomPth Bridge
// =============================================================================

BridgedClass _createTomPthBridge() {
  return BridgedClass(
    nativeType: $tom_build_7.TomPth,
    name: 'TomPth',
    isAssignable: (v) => v is $tom_build_7.TomPth,
    constructors: {
    },
    staticGetters: {
      'cwd': (visitor) => $tom_build_7.TomPth.cwd,
      'home': (visitor) => $tom_build_7.TomPth.home,
      'temp': (visitor) => $tom_build_7.TomPth.temp,
      'separator': (visitor) => $tom_build_7.TomPth.separator,
    },
    staticMethods: {
      'join': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'join');
        final part1 = D4.getRequiredArg<String>(positional, 0, 'part1', 'join');
        final part2 = D4.getOptionalArg<String?>(positional, 1, 'part2');
        final part3 = D4.getOptionalArg<String?>(positional, 2, 'part3');
        final part4 = D4.getOptionalArg<String?>(positional, 3, 'part4');
        final part5 = D4.getOptionalArg<String?>(positional, 4, 'part5');
        final part6 = D4.getOptionalArg<String?>(positional, 5, 'part6');
        return $tom_build_7.TomPth.join(part1, part2, part3, part4, part5, part6);
      },
      'joinAll': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'joinAll');
        if (positional.isEmpty) {
          throw ArgumentError('joinAll: Missing required argument "parts" at position 0');
        }
        final parts = D4.coerceList<String>(positional[0], 'parts');
        return $tom_build_7.TomPth.joinAll(parts);
      },
      'dirname': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'dirname');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'dirname');
        return $tom_build_7.TomPth.dirname(path);
      },
      'basename': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'basename');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'basename');
        return $tom_build_7.TomPth.basename(path);
      },
      'basenameNoExt': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'basenameNoExt');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'basenameNoExt');
        return $tom_build_7.TomPth.basenameNoExt(path);
      },
      'extension': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'extension');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'extension');
        return $tom_build_7.TomPth.extension(path);
      },
      'split': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'split');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'split');
        return $tom_build_7.TomPth.split(path);
      },
      'absolute': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'absolute');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'absolute');
        return $tom_build_7.TomPth.absolute(path);
      },
      'relative': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'relative');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'relative');
        final from = D4.getOptionalNamedArg<String?>(named, 'from');
        return $tom_build_7.TomPth.relative(path, from: from);
      },
      'normalize': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'normalize');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'normalize');
        return $tom_build_7.TomPth.normalize(path);
      },
      'canonical': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'canonical');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'canonical');
        return $tom_build_7.TomPth.canonical(path);
      },
      'setExtension': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'setExtension');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'setExtension');
        final extension = D4.getRequiredArg<String>(positional, 1, 'extension', 'setExtension');
        return $tom_build_7.TomPth.setExtension(path, extension);
      },
      'withoutExtension': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'withoutExtension');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'withoutExtension');
        return $tom_build_7.TomPth.withoutExtension(path);
      },
      'isAbsolute': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'isAbsolute');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'isAbsolute');
        return $tom_build_7.TomPth.isAbsolute(path);
      },
      'isRelative': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'isRelative');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'isRelative');
        return $tom_build_7.TomPth.isRelative(path);
      },
      'isWithin': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'isWithin');
        final parent = D4.getRequiredArg<String>(positional, 0, 'parent', 'isWithin');
        final child = D4.getRequiredArg<String>(positional, 1, 'child', 'isWithin');
        return $tom_build_7.TomPth.isWithin(parent, child);
      },
      'equals': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'equals');
        final path1 = D4.getRequiredArg<String>(positional, 0, 'path1', 'equals');
        final path2 = D4.getRequiredArg<String>(positional, 1, 'path2', 'equals');
        return $tom_build_7.TomPth.equals(path1, path2);
      },
      'expandHome': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'expandHome');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'expandHome');
        return $tom_build_7.TomPth.expandHome(path);
      },
    },
    staticMethodSignatures: {
      'join': 'String join(String part1, [String? part2, String? part3, String? part4, String? part5, String? part6])',
      'joinAll': 'String joinAll(List<String> parts)',
      'dirname': 'String dirname(String path)',
      'basename': 'String basename(String path)',
      'basenameNoExt': 'String basenameNoExt(String path)',
      'extension': 'String extension(String path)',
      'split': 'List<String> split(String path)',
      'absolute': 'String absolute(String path)',
      'relative': 'String relative(String path, {String? from})',
      'normalize': 'String normalize(String path)',
      'canonical': 'String canonical(String path)',
      'setExtension': 'String setExtension(String path, String extension)',
      'withoutExtension': 'String withoutExtension(String path)',
      'isAbsolute': 'bool isAbsolute(String path)',
      'isRelative': 'bool isRelative(String path)',
      'isWithin': 'bool isWithin(String parent, String child)',
      'equals': 'bool equals(String path1, String path2)',
      'expandHome': 'String expandHome(String path)',
    },
    staticGetterSignatures: {
      'cwd': 'String get cwd',
      'home': 'String get home',
      'temp': 'String get temp',
      'separator': 'String get separator',
    },
  );
}

// =============================================================================
// TomShell Bridge
// =============================================================================

BridgedClass _createTomShellBridge() {
  return BridgedClass(
    nativeType: $tom_build_8.TomShell,
    name: 'TomShell',
    isAssignable: (v) => v is $tom_build_8.TomShell,
    constructors: {
    },
    staticMethods: {
      'run': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'run');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'run');
        final workingDir = D4.getOptionalNamedArg<String?>(named, 'workingDir');
        final quiet = D4.getNamedArgWithDefault<bool>(named, 'quiet', false);
        final env = D4.coerceMapOrNull<String, String>(named['env'], 'env');
        final resolveEnv = D4.getNamedArgWithDefault<bool>(named, 'resolveEnv', true);
        return $tom_build_8.TomShell.run(command, workingDir: workingDir, quiet: quiet, env: env, resolveEnv: resolveEnv);
      },
      'exec': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'exec');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'exec');
        final workingDir = D4.getOptionalNamedArg<String?>(named, 'workingDir');
        final env = D4.coerceMapOrNull<String, String>(named['env'], 'env');
        final resolveEnv = D4.getNamedArgWithDefault<bool>(named, 'resolveEnv', true);
        return $tom_build_8.TomShell.exec(command, workingDir: workingDir, env: env, resolveEnv: resolveEnv);
      },
      'capture': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'capture');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'capture');
        final workingDir = D4.getOptionalNamedArg<String?>(named, 'workingDir');
        final env = D4.coerceMapOrNull<String, String>(named['env'], 'env');
        final resolveEnv = D4.getNamedArgWithDefault<bool>(named, 'resolveEnv', true);
        return $tom_build_8.TomShell.capture(command, workingDir: workingDir, env: env, resolveEnv: resolveEnv);
      },
      'runAll': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'runAll');
        if (positional.isEmpty) {
          throw ArgumentError('runAll: Missing required argument "commands" at position 0');
        }
        final commands = D4.coerceList<String>(positional[0], 'commands');
        final workingDir = D4.getOptionalNamedArg<String?>(named, 'workingDir');
        final stopOnError = D4.getNamedArgWithDefault<bool>(named, 'stopOnError', true);
        final resolveEnv = D4.getNamedArgWithDefault<bool>(named, 'resolveEnv', true);
        return $tom_build_8.TomShell.runAll(commands, workingDir: workingDir, stopOnError: stopOnError, resolveEnv: resolveEnv);
      },
      'pipe': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'pipe');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'pipe');
        final input = D4.getRequiredArg<String>(positional, 1, 'input', 'pipe');
        final workingDir = D4.getOptionalNamedArg<String?>(named, 'workingDir');
        final resolveEnv = D4.getNamedArgWithDefault<bool>(named, 'resolveEnv', true);
        return $tom_build_8.TomShell.pipe(command, input, workingDir: workingDir, resolveEnv: resolveEnv);
      },
      'hasCommand': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'hasCommand');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'hasCommand');
        return $tom_build_8.TomShell.hasCommand(command);
      },
      'which': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'which');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'which');
        return $tom_build_8.TomShell.which(command);
      },
    },
    staticMethodSignatures: {
      'run': 'String run(String command, {String? workingDir, bool quiet = false, Map<String, String>? env, bool resolveEnv = true})',
      'exec': 'int exec(String command, {String? workingDir, Map<String, String>? env, bool resolveEnv = true})',
      'capture': 'String capture(String command, {String? workingDir, Map<String, String>? env, bool resolveEnv = true})',
      'runAll': 'List<String> runAll(List<String> commands, {String? workingDir, bool stopOnError = true, bool resolveEnv = true})',
      'pipe': 'String pipe(String command, String input, {String? workingDir, bool resolveEnv = true})',
      'hasCommand': 'bool hasCommand(String command)',
      'which': 'String? which(String command)',
    },
  );
}

// =============================================================================
// TomShellException Bridge
// =============================================================================

BridgedClass _createTomShellExceptionBridge() {
  return BridgedClass(
    nativeType: $tom_build_8.TomShellException,
    name: 'TomShellException',
    isAssignable: (v) => v is $tom_build_8.TomShellException,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final command = D4.getRequiredNamedArg<String>(named, 'command', 'TomShellException');
        final exitCode = D4.getRequiredNamedArg<int>(named, 'exitCode', 'TomShellException');
        final stderr = D4.getRequiredNamedArg<String>(named, 'stderr', 'TomShellException');
        final stdout = D4.getRequiredNamedArg<String>(named, 'stdout', 'TomShellException');
        return $tom_build_8.TomShellException(command: command, exitCode: exitCode, stderr: stderr, stdout: stdout);
      },
    },
    getters: {
      'command': (visitor, target) => D4.validateTarget<$tom_build_8.TomShellException>(target, 'TomShellException').command,
      'exitCode': (visitor, target) => D4.validateTarget<$tom_build_8.TomShellException>(target, 'TomShellException').exitCode,
      'stderr': (visitor, target) => D4.validateTarget<$tom_build_8.TomShellException>(target, 'TomShellException').stderr,
      'stdout': (visitor, target) => D4.validateTarget<$tom_build_8.TomShellException>(target, 'TomShellException').stdout,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_8.TomShellException>(target, 'TomShellException');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomShellException({required String command, required int exitCode, required String stderr, required String stdout})',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'command': 'String get command',
      'exitCode': 'int get exitCode',
      'stderr': 'String get stderr',
      'stdout': 'String get stdout',
    },
  );
}

// =============================================================================
// TomText Bridge
// =============================================================================

BridgedClass _createTomTextBridge() {
  return BridgedClass(
    nativeType: $tom_build_9.TomText,
    name: 'TomText',
    isAssignable: (v) => v is $tom_build_9.TomText,
    constructors: {
    },
    staticMethods: {
      'template': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'template');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'template');
        if (positional.length <= 1) {
          throw ArgumentError('template: Missing required argument "values" at position 1');
        }
        final values = D4.coerceMap<String, dynamic>(positional[1], 'values');
        final open = D4.getNamedArgWithDefault<String>(named, 'open', '{{');
        final close = D4.getNamedArgWithDefault<String>(named, 'close', '}}');
        return $tom_build_9.TomText.template(text, values, open: open, close: close);
      },
      'indent': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'indent');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'indent');
        final spaces = D4.getRequiredArg<int>(positional, 1, 'spaces', 'indent');
        final char = D4.getNamedArgWithDefault<String>(named, 'char', ' ');
        return $tom_build_9.TomText.indent(text, spaces, char: char);
      },
      'dedent': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'dedent');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'dedent');
        return $tom_build_9.TomText.dedent(text);
      },
      'wrap': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'wrap');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'wrap');
        final width = D4.getRequiredArg<int>(positional, 1, 'width', 'wrap');
        final lineBreak = D4.getNamedArgWithDefault<String>(named, 'lineBreak', '\n');
        return $tom_build_9.TomText.wrap(text, width, lineBreak: lineBreak);
      },
      'truncate': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'truncate');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'truncate');
        final maxLength = D4.getRequiredArg<int>(positional, 1, 'maxLength', 'truncate');
        final suffix = D4.getNamedArgWithDefault<String>(named, 'suffix', '...');
        return $tom_build_9.TomText.truncate(text, maxLength, suffix: suffix);
      },
      'lines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'lines');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'lines');
        return $tom_build_9.TomText.lines(text);
      },
      'joinLines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'joinLines');
        if (positional.isEmpty) {
          throw ArgumentError('joinLines: Missing required argument "lines" at position 0');
        }
        final lines = D4.coerceList<String>(positional[0], 'lines');
        final separator = D4.getNamedArgWithDefault<String>(named, 'separator', '\n');
        return $tom_build_9.TomText.joinLines(lines, separator: separator);
      },
      'filterLines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'filterLines');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'filterLines');
        if (positional.length <= 1) {
          throw ArgumentError('filterLines: Missing required argument "predicate" at position 1');
        }
        final predicateRaw = positional[1];
        final predicate = ((String p0) { return D4.callInterpreterCallback(visitor!, predicateRaw, [p0]) as bool; }) as bool Function(String);
        return $tom_build_9.TomText.filterLines(text, predicate);
      },
      'mapLines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'mapLines');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'mapLines');
        if (positional.length <= 1) {
          throw ArgumentError('mapLines: Missing required argument "mapper" at position 1');
        }
        final mapperRaw = positional[1];
        final mapper = ((String p0) { return D4.callInterpreterCallback(visitor!, mapperRaw, [p0]) as String; }) as String Function(String);
        return $tom_build_9.TomText.mapLines(text, mapper);
      },
      'head': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'head');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'head');
        final n = D4.getRequiredArg<int>(positional, 1, 'n', 'head');
        return $tom_build_9.TomText.head(text, n);
      },
      'tail': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'tail');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'tail');
        final n = D4.getRequiredArg<int>(positional, 1, 'n', 'tail');
        return $tom_build_9.TomText.tail(text, n);
      },
      'lineCount': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'lineCount');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'lineCount');
        return $tom_build_9.TomText.lineCount(text);
      },
      'wordCount': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'wordCount');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'wordCount');
        return $tom_build_9.TomText.wordCount(text);
      },
      'charCount': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'charCount');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'charCount');
        final excludeWhitespace = D4.getNamedArgWithDefault<bool>(named, 'excludeWhitespace', true);
        return $tom_build_9.TomText.charCount(text, excludeWhitespace: excludeWhitespace);
      },
      'between': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'between');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'between');
        final start = D4.getRequiredArg<String>(positional, 1, 'start', 'between');
        final end = D4.getRequiredArg<String>(positional, 2, 'end', 'between');
        return $tom_build_9.TomText.between(text, start, end);
      },
      'allBetween': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'allBetween');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'allBetween');
        final start = D4.getRequiredArg<String>(positional, 1, 'start', 'allBetween');
        final end = D4.getRequiredArg<String>(positional, 2, 'end', 'allBetween');
        return $tom_build_9.TomText.allBetween(text, start, end);
      },
      'slug': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'slug');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'slug');
        return $tom_build_9.TomText.slug(text);
      },
      'camelCase': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'camelCase');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'camelCase');
        return $tom_build_9.TomText.camelCase(text);
      },
      'pascalCase': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'pascalCase');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'pascalCase');
        return $tom_build_9.TomText.pascalCase(text);
      },
      'snakeCase': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'snakeCase');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'snakeCase');
        return $tom_build_9.TomText.snakeCase(text);
      },
      'kebabCase': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'kebabCase');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'kebabCase');
        return $tom_build_9.TomText.kebabCase(text);
      },
      'titleCase': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'titleCase');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'titleCase');
        return $tom_build_9.TomText.titleCase(text);
      },
      'padLeft': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'padLeft');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'padLeft');
        final width = D4.getRequiredArg<int>(positional, 1, 'width', 'padLeft');
        final char = D4.getNamedArgWithDefault<String>(named, 'char', ' ');
        return $tom_build_9.TomText.padLeft(text, width, char: char);
      },
      'padRight': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'padRight');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'padRight');
        final width = D4.getRequiredArg<int>(positional, 1, 'width', 'padRight');
        final char = D4.getNamedArgWithDefault<String>(named, 'char', ' ');
        return $tom_build_9.TomText.padRight(text, width, char: char);
      },
      'center': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'center');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'center');
        final width = D4.getRequiredArg<int>(positional, 1, 'width', 'center');
        final char = D4.getNamedArgWithDefault<String>(named, 'char', ' ');
        return $tom_build_9.TomText.center(text, width, char: char);
      },
      'removeBlankLines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'removeBlankLines');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'removeBlankLines');
        return $tom_build_9.TomText.removeBlankLines(text);
      },
      'collapseBlankLines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'collapseBlankLines');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'collapseBlankLines');
        return $tom_build_9.TomText.collapseBlankLines(text);
      },
      'trimLines': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'trimLines');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'trimLines');
        return $tom_build_9.TomText.trimLines(text);
      },
      'containsAll': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'containsAll');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'containsAll');
        if (positional.length <= 1) {
          throw ArgumentError('containsAll: Missing required argument "patterns" at position 1');
        }
        final patterns = D4.coerceList<String>(positional[1], 'patterns');
        return $tom_build_9.TomText.containsAll(text, patterns);
      },
      'containsAny': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'containsAny');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'containsAny');
        if (positional.length <= 1) {
          throw ArgumentError('containsAny: Missing required argument "patterns" at position 1');
        }
        final patterns = D4.coerceList<String>(positional[1], 'patterns');
        return $tom_build_9.TomText.containsAny(text, patterns);
      },
      'replaceAll': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'replaceAll');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'replaceAll');
        if (positional.length <= 1) {
          throw ArgumentError('replaceAll: Missing required argument "replacements" at position 1');
        }
        final replacements = D4.coerceMap<String, String>(positional[1], 'replacements');
        return $tom_build_9.TomText.replaceAll(text, replacements);
      },
      'escapeHtml': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'escapeHtml');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'escapeHtml');
        return $tom_build_9.TomText.escapeHtml(text);
      },
      'unescapeHtml': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'unescapeHtml');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'unescapeHtml');
        return $tom_build_9.TomText.unescapeHtml(text);
      },
      'escapeJson': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'escapeJson');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'escapeJson');
        return $tom_build_9.TomText.escapeJson(text);
      },
      'escapeRegex': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'escapeRegex');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'escapeRegex');
        return $tom_build_9.TomText.escapeRegex(text);
      },
      'escapeShell': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'escapeShell');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'escapeShell');
        return $tom_build_9.TomText.escapeShell(text);
      },
    },
    staticMethodSignatures: {
      'template': 'String template(String text, Map<String, dynamic> values, {String open = \'{{\', String close = \'}}\'})',
      'indent': 'String indent(String text, int spaces, {String char = \' \'})',
      'dedent': 'String dedent(String text)',
      'wrap': 'String wrap(String text, int width, {String lineBreak = \'\\n\'})',
      'truncate': 'String truncate(String text, int maxLength, {String suffix = \'...\'})',
      'lines': 'List<String> lines(String text)',
      'joinLines': 'String joinLines(List<String> lines, {String separator = \'\\n\'})',
      'filterLines': 'String filterLines(String text, bool Function(String) predicate)',
      'mapLines': 'String mapLines(String text, String Function(String) mapper)',
      'head': 'String head(String text, int n)',
      'tail': 'String tail(String text, int n)',
      'lineCount': 'int lineCount(String text)',
      'wordCount': 'int wordCount(String text)',
      'charCount': 'int charCount(String text, {bool excludeWhitespace = true})',
      'between': 'String? between(String text, String start, String end)',
      'allBetween': 'List<String> allBetween(String text, String start, String end)',
      'slug': 'String slug(String text)',
      'camelCase': 'String camelCase(String text)',
      'pascalCase': 'String pascalCase(String text)',
      'snakeCase': 'String snakeCase(String text)',
      'kebabCase': 'String kebabCase(String text)',
      'titleCase': 'String titleCase(String text)',
      'padLeft': 'String padLeft(String text, int width, {String char = \' \'})',
      'padRight': 'String padRight(String text, int width, {String char = \' \'})',
      'center': 'String center(String text, int width, {String char = \' \'})',
      'removeBlankLines': 'String removeBlankLines(String text)',
      'collapseBlankLines': 'String collapseBlankLines(String text)',
      'trimLines': 'String trimLines(String text)',
      'containsAll': 'bool containsAll(String text, List<String> patterns)',
      'containsAny': 'bool containsAny(String text, List<String> patterns)',
      'replaceAll': 'String replaceAll(String text, Map<String, String> replacements)',
      'escapeHtml': 'String escapeHtml(String text)',
      'unescapeHtml': 'String unescapeHtml(String text)',
      'escapeJson': 'String escapeJson(String text)',
      'escapeRegex': 'String escapeRegex(String text)',
      'escapeShell': 'String escapeShell(String text)',
    },
  );
}

// =============================================================================
// WorkspaceInfo Bridge
// =============================================================================

BridgedClass _createWorkspaceInfoBridge() {
  return BridgedClass(
    nativeType: $tom_build_17.WorkspaceInfo,
    name: 'WorkspaceInfo',
    isAssignable: (v) => v is $tom_build_17.WorkspaceInfo,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getOptionalNamedArg<String?>(named, 'name');
        final settings = named.containsKey('settings') && named['settings'] != null
            ? D4.coerceMap<String, dynamic>(named['settings'], 'settings')
            : const <String, dynamic>{};
        final workspaceModes = D4.getOptionalNamedArg<$tom_build_17.MetadataModes?>(named, 'workspaceModes');
        final groups = named.containsKey('groups') && named['groups'] != null
            ? D4.coerceMap<String, $tom_build_17.WorkspaceGroup>(named['groups'], 'groups')
            : const <String, $tom_build_17.WorkspaceGroup>{};
        final buildOrder = named.containsKey('buildOrder') && named['buildOrder'] != null
            ? D4.coerceList<String>(named['buildOrder'], 'buildOrder')
            : const <String>[];
        final projects = named.containsKey('projects') && named['projects'] != null
            ? D4.coerceMap<String, $tom_build_17.WorkspaceProject>(named['projects'], 'projects')
            : const <String, $tom_build_17.WorkspaceProject>{};
        return $tom_build_17.WorkspaceInfo(name: name, settings: settings, workspaceModes: workspaceModes, groups: groups, buildOrder: buildOrder, projects: projects);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'WorkspaceInfo');
        final yaml = D4.getRequiredArg<$yaml_1.YamlMap>(positional, 0, 'yaml', 'WorkspaceInfo');
        return $tom_build_17.WorkspaceInfo.fromYaml(yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceInfo>(target, 'WorkspaceInfo').name,
      'settings': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceInfo>(target, 'WorkspaceInfo').settings,
      'workspaceModes': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceInfo>(target, 'WorkspaceInfo').workspaceModes,
      'groups': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceInfo>(target, 'WorkspaceInfo').groups,
      'buildOrder': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceInfo>(target, 'WorkspaceInfo').buildOrder,
      'projects': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceInfo>(target, 'WorkspaceInfo').projects,
    },
    constructorSignatures: {
      '': 'WorkspaceInfo({String? name, Map<String, dynamic> settings = const {}, MetadataModes? workspaceModes, Map<String, WorkspaceGroup> groups = const {}, List<String> buildOrder = const [], Map<String, WorkspaceProject> projects = const {}})',
      'fromYaml': 'factory WorkspaceInfo.fromYaml(YamlMap yaml)',
    },
    getterSignatures: {
      'name': 'String? get name',
      'settings': 'Map<String, dynamic> get settings',
      'workspaceModes': 'MetadataModes? get workspaceModes',
      'groups': 'Map<String, WorkspaceGroup> get groups',
      'buildOrder': 'List<String> get buildOrder',
      'projects': 'Map<String, WorkspaceProject> get projects',
    },
  );
}

// =============================================================================
// MetadataModes Bridge
// =============================================================================

BridgedClass _createMetadataModesBridge() {
  return BridgedClass(
    nativeType: $tom_build_17.MetadataModes,
    name: 'MetadataModes',
    isAssignable: (v) => v is $tom_build_17.MetadataModes,
    constructors: {
      '': (visitor, positional, named) {
        final supportedModes = named.containsKey('supportedModes') && named['supportedModes'] != null
            ? D4.coerceList<$tom_build_17.MetadataMode>(named['supportedModes'], 'supportedModes')
            : const <$tom_build_17.MetadataMode>[];
        final defaultMode = D4.getOptionalNamedArg<String?>(named, 'defaultMode');
        return $tom_build_17.MetadataModes(supportedModes: supportedModes, defaultMode: defaultMode);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'MetadataModes');
        final yaml = D4.getRequiredArg<$yaml_1.YamlMap>(positional, 0, 'yaml', 'MetadataModes');
        return $tom_build_17.MetadataModes.fromYaml(yaml);
      },
    },
    getters: {
      'supportedModes': (visitor, target) => D4.validateTarget<$tom_build_17.MetadataModes>(target, 'MetadataModes').supportedModes,
      'defaultMode': (visitor, target) => D4.validateTarget<$tom_build_17.MetadataModes>(target, 'MetadataModes').defaultMode,
    },
    constructorSignatures: {
      '': 'MetadataModes({List<MetadataMode> supportedModes = const [], String? defaultMode})',
      'fromYaml': 'factory MetadataModes.fromYaml(YamlMap yaml)',
    },
    getterSignatures: {
      'supportedModes': 'List<MetadataMode> get supportedModes',
      'defaultMode': 'String? get defaultMode',
    },
  );
}

// =============================================================================
// MetadataMode Bridge
// =============================================================================

BridgedClass _createMetadataModeBridge() {
  return BridgedClass(
    nativeType: $tom_build_17.MetadataMode,
    name: 'MetadataMode',
    isAssignable: (v) => v is $tom_build_17.MetadataMode,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'MetadataMode');
        final implies = named.containsKey('implies') && named['implies'] != null
            ? D4.coerceList<String>(named['implies'], 'implies')
            : const <String>[];
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        return $tom_build_17.MetadataMode(name: name, implies: implies, description: description);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'MetadataMode');
        final yaml = D4.getRequiredArg<$yaml_1.YamlMap>(positional, 0, 'yaml', 'MetadataMode');
        return $tom_build_17.MetadataMode.fromYaml(yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_17.MetadataMode>(target, 'MetadataMode').name,
      'implies': (visitor, target) => D4.validateTarget<$tom_build_17.MetadataMode>(target, 'MetadataMode').implies,
      'description': (visitor, target) => D4.validateTarget<$tom_build_17.MetadataMode>(target, 'MetadataMode').description,
    },
    constructorSignatures: {
      '': 'MetadataMode({required String name, List<String> implies = const [], String? description})',
      'fromYaml': 'factory MetadataMode.fromYaml(YamlMap yaml)',
    },
    getterSignatures: {
      'name': 'String get name',
      'implies': 'List<String> get implies',
      'description': 'String? get description',
    },
  );
}

// =============================================================================
// WorkspaceGroup Bridge
// =============================================================================

BridgedClass _createWorkspaceGroupBridge() {
  return BridgedClass(
    nativeType: $tom_build_17.WorkspaceGroup,
    name: 'WorkspaceGroup',
    isAssignable: (v) => v is $tom_build_17.WorkspaceGroup,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'WorkspaceGroup');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final projects = named.containsKey('projects') && named['projects'] != null
            ? D4.coerceList<String>(named['projects'], 'projects')
            : const <String>[];
        return $tom_build_17.WorkspaceGroup(name: name, description: description, projects: projects);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'WorkspaceGroup');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'WorkspaceGroup');
        final yaml = D4.getRequiredArg<$yaml_1.YamlMap>(positional, 1, 'yaml', 'WorkspaceGroup');
        return $tom_build_17.WorkspaceGroup.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceGroup>(target, 'WorkspaceGroup').name,
      'description': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceGroup>(target, 'WorkspaceGroup').description,
      'projects': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceGroup>(target, 'WorkspaceGroup').projects,
    },
    constructorSignatures: {
      '': 'WorkspaceGroup({required String name, String? description, List<String> projects = const []})',
      'fromYaml': 'factory WorkspaceGroup.fromYaml(String name, YamlMap yaml)',
    },
    getterSignatures: {
      'name': 'String get name',
      'description': 'String? get description',
      'projects': 'List<String> get projects',
    },
  );
}

// =============================================================================
// WorkspaceProject Bridge
// =============================================================================

BridgedClass _createWorkspaceProjectBridge() {
  return BridgedClass(
    nativeType: $tom_build_17.WorkspaceProject,
    name: 'WorkspaceProject',
    isAssignable: (v) => v is $tom_build_17.WorkspaceProject,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'WorkspaceProject');
        final displayName = D4.getOptionalNamedArg<String?>(named, 'displayName');
        final projectName = D4.getOptionalNamedArg<String?>(named, 'projectName');
        final type = D4.getOptionalNamedArg<String?>(named, 'type');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final buildAfter = named.containsKey('buildAfter') && named['buildAfter'] != null
            ? D4.coerceList<String>(named['buildAfter'], 'buildAfter')
            : const <String>[];
        final features = named.containsKey('features') && named['features'] != null
            ? D4.coerceMap<String, bool>(named['features'], 'features')
            : const <String, bool>{};
        final build = named.containsKey('build') && named['build'] != null
            ? D4.coerceMap<String, dynamic>(named['build'], 'build')
            : const <String, dynamic>{};
        final run = named.containsKey('run') && named['run'] != null
            ? D4.coerceMap<String, dynamic>(named['run'], 'run')
            : const <String, dynamic>{};
        final deploy = named.containsKey('deploy') && named['deploy'] != null
            ? D4.coerceMap<String, dynamic>(named['deploy'], 'deploy')
            : const <String, dynamic>{};
        final binaries = named.containsKey('binaries') && named['binaries'] != null
            ? D4.coerceList<String>(named['binaries'], 'binaries')
            : const <String>[];
        final docs = named.containsKey('docs') && named['docs'] != null
            ? D4.coerceList<String>(named['docs'], 'docs')
            : const <String>[];
        final tests = named.containsKey('tests') && named['tests'] != null
            ? D4.coerceList<String>(named['tests'], 'tests')
            : const <String>[];
        final examples = named.containsKey('examples') && named['examples'] != null
            ? D4.coerceList<String>(named['examples'], 'examples')
            : const <String>[];
        final copilotGuidelines = named.containsKey('copilotGuidelines') && named['copilotGuidelines'] != null
            ? D4.coerceList<String>(named['copilotGuidelines'], 'copilotGuidelines')
            : const <String>[];
        return $tom_build_17.WorkspaceProject(name: name, displayName: displayName, projectName: projectName, type: type, description: description, buildAfter: buildAfter, features: features, build: build, run: run, deploy: deploy, binaries: binaries, docs: docs, tests: tests, examples: examples, copilotGuidelines: copilotGuidelines);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'WorkspaceProject');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'WorkspaceProject');
        final yaml = D4.getRequiredArg<$yaml_1.YamlMap>(positional, 1, 'yaml', 'WorkspaceProject');
        return $tom_build_17.WorkspaceProject.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').name,
      'displayName': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').displayName,
      'projectName': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').projectName,
      'type': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').type,
      'description': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').description,
      'buildAfter': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').buildAfter,
      'features': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').features,
      'build': (visitor, target) => (D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject') as dynamic).build,
      'run': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').run,
      'deploy': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').deploy,
      'binaries': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').binaries,
      'docs': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').docs,
      'tests': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').tests,
      'examples': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').examples,
      'copilotGuidelines': (visitor, target) => D4.validateTarget<$tom_build_17.WorkspaceProject>(target, 'WorkspaceProject').copilotGuidelines,
    },
    constructorSignatures: {
      '': 'WorkspaceProject({required String name, String? displayName, String? projectName, String? type, String? description, List<String> buildAfter = const [], Map<String, bool> features = const {}, Map<String, dynamic> build = const {}, Map<String, dynamic> run = const {}, Map<String, dynamic> deploy = const {}, List<String> binaries = const [], List<String> docs = const [], List<String> tests = const [], List<String> examples = const [], List<String> copilotGuidelines = const []})',
      'fromYaml': 'factory WorkspaceProject.fromYaml(String name, YamlMap yaml)',
    },
    getterSignatures: {
      'name': 'String get name',
      'displayName': 'String? get displayName',
      'projectName': 'String? get projectName',
      'type': 'String? get type',
      'description': 'String? get description',
      'buildAfter': 'List<String> get buildAfter',
      'features': 'Map<String, bool> get features',
      'build': 'Map<String, dynamic> get build',
      'run': 'Map<String, dynamic> get run',
      'deploy': 'Map<String, dynamic> get deploy',
      'binaries': 'List<String> get binaries',
      'docs': 'List<String> get docs',
      'tests': 'List<String> get tests',
      'examples': 'List<String> get examples',
      'copilotGuidelines': 'List<String> get copilotGuidelines',
    },
  );
}

// =============================================================================
// PlatformInfo Bridge
// =============================================================================

BridgedClass _createPlatformInfoBridge() {
  return BridgedClass(
    nativeType: $tom_build_16.PlatformInfo,
    name: 'PlatformInfo',
    isAssignable: (v) => v is $tom_build_16.PlatformInfo,
    constructors: {
      'detect': (visitor, positional, named) {
        return $tom_build_16.PlatformInfo.detect();
      },
    },
    getters: {
      'os': (visitor, target) => D4.validateTarget<$tom_build_16.PlatformInfo>(target, 'PlatformInfo').os,
      'architecture': (visitor, target) => D4.validateTarget<$tom_build_16.PlatformInfo>(target, 'PlatformInfo').architecture,
      'platform': (visitor, target) => D4.validateTarget<$tom_build_16.PlatformInfo>(target, 'PlatformInfo').platform,
      'dartTargetPlatforms': (visitor, target) => D4.validateTarget<$tom_build_16.PlatformInfo>(target, 'PlatformInfo').dartTargetPlatforms,
    },
    methods: {
      'canBuildFor': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_16.PlatformInfo>(target, 'PlatformInfo');
        D4.requireMinArgs(positional, 1, 'canBuildFor');
        final targetPlatform = D4.getRequiredArg<String>(positional, 0, 'targetPlatform', 'canBuildFor');
        return t.canBuildFor(targetPlatform);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_16.PlatformInfo>(target, 'PlatformInfo');
        return t.toString();
      },
    },
    constructorSignatures: {
      'detect': 'factory PlatformInfo.detect()',
    },
    methodSignatures: {
      'canBuildFor': 'bool canBuildFor(String targetPlatform)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'os': 'OperatingSystem get os',
      'architecture': 'CpuArchitecture get architecture',
      'platform': 'String get platform',
      'dartTargetPlatforms': 'List<String> get dartTargetPlatforms',
    },
  );
}

// =============================================================================
// ToolContext Bridge
// =============================================================================

BridgedClass _createToolContextBridge() {
  return BridgedClass(
    nativeType: $tom_build_16.ToolContext,
    name: 'ToolContext',
    isAssignable: (v) => v is $tom_build_16.ToolContext,
    constructors: {
    },
    getters: {
      'workspaceInfo': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext').workspaceInfo,
      'workspacePath': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext').workspacePath,
      'platformInfo': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext').platformInfo,
      'os': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext').os,
      'architecture': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext').architecture,
      'platform': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext').platform,
      'dartTargetPlatforms': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext').dartTargetPlatforms,
    },
    methods: {
      'validateModes': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_16.ToolContext>(target, 'ToolContext');
        D4.requireMinArgs(positional, 1, 'validateModes');
        if (positional.isEmpty) {
          throw ArgumentError('validateModes: Missing required argument "requestedModes" at position 0');
        }
        final requestedModes = D4.coerceList<String>(positional[0], 'requestedModes');
        return t.validateModes(requestedModes);
      },
    },
    staticGetters: {
      'current': (visitor) => $tom_build_16.ToolContext.current,
      'isInitialized': (visitor) => $tom_build_16.ToolContext.isInitialized,
    },
    staticMethods: {
      'load': (visitor, positional, named, typeArgs) {
        final workspacePath = D4.getOptionalNamedArg<String?>(named, 'workspacePath');
        return $tom_build_16.ToolContext.load(workspacePath: workspacePath);
      },
      'reload': (visitor, positional, named, typeArgs) {
        final workspacePath = D4.getOptionalNamedArg<String?>(named, 'workspacePath');
        return $tom_build_16.ToolContext.reload(workspacePath: workspacePath);
      },
      'clear': (visitor, positional, named, typeArgs) {
        return $tom_build_16.ToolContext.clear();
      },
    },
    methodSignatures: {
      'validateModes': 'ModeValidationResult validateModes(List<String> requestedModes)',
    },
    getterSignatures: {
      'workspaceInfo': 'WorkspaceInfo get workspaceInfo',
      'workspacePath': 'String get workspacePath',
      'platformInfo': 'PlatformInfo get platformInfo',
      'os': 'OperatingSystem get os',
      'architecture': 'CpuArchitecture get architecture',
      'platform': 'String get platform',
      'dartTargetPlatforms': 'List<String> get dartTargetPlatforms',
    },
    staticMethodSignatures: {
      'load': 'Future<ToolContext> load({String? workspacePath})',
      'reload': 'Future<ToolContext> reload({String? workspacePath})',
      'clear': 'void clear()',
    },
    staticGetterSignatures: {
      'current': 'ToolContext get current',
      'isInitialized': 'bool get isInitialized',
    },
  );
}

// =============================================================================
// ToolContextException Bridge
// =============================================================================

BridgedClass _createToolContextExceptionBridge() {
  return BridgedClass(
    nativeType: $tom_build_16.ToolContextException,
    name: 'ToolContextException',
    isAssignable: (v) => v is $tom_build_16.ToolContextException,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ToolContextException');
        final message = D4.getRequiredArg<String>(positional, 0, 'message', 'ToolContextException');
        return $tom_build_16.ToolContextException(message);
      },
    },
    getters: {
      'message': (visitor, target) => D4.validateTarget<$tom_build_16.ToolContextException>(target, 'ToolContextException').message,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_16.ToolContextException>(target, 'ToolContextException');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'ToolContextException(String message)',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'message': 'String get message',
    },
  );
}

// =============================================================================
// ModeValidationResult Bridge
// =============================================================================

BridgedClass _createModeValidationResultBridge() {
  return BridgedClass(
    nativeType: $tom_build_16.ModeValidationResult,
    name: 'ModeValidationResult',
    isAssignable: (v) => v is $tom_build_16.ModeValidationResult,
    constructors: {
      'success': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ModeValidationResult');
        if (positional.isEmpty) {
          throw ArgumentError('ModeValidationResult: Missing required argument "resolvedModes" at position 0');
        }
        final resolvedModes = D4.coerceList<String>(positional[0], 'resolvedModes');
        return $tom_build_16.ModeValidationResult.success(resolvedModes);
      },
      'error': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ModeValidationResult');
        final message = D4.getRequiredArg<String>(positional, 0, 'message', 'ModeValidationResult');
        return $tom_build_16.ModeValidationResult.error(message);
      },
    },
    getters: {
      'isValid': (visitor, target) => D4.validateTarget<$tom_build_16.ModeValidationResult>(target, 'ModeValidationResult').isValid,
      'errorMessage': (visitor, target) => D4.validateTarget<$tom_build_16.ModeValidationResult>(target, 'ModeValidationResult').errorMessage,
      'resolvedModes': (visitor, target) => D4.validateTarget<$tom_build_16.ModeValidationResult>(target, 'ModeValidationResult').resolvedModes,
    },
    constructorSignatures: {
      'success': 'factory ModeValidationResult.success(List<String> resolvedModes)',
      'error': 'factory ModeValidationResult.error(String message)',
    },
    getterSignatures: {
      'isValid': 'bool get isValid',
      'errorMessage': 'String? get errorMessage',
      'resolvedModes': 'List<String> get resolvedModes',
    },
  );
}

// =============================================================================
// TomWs Bridge
// =============================================================================

BridgedClass _createTomWsBridge() {
  return BridgedClass(
    nativeType: $tom_build_10.TomWs,
    name: 'TomWs',
    isAssignable: (v) => v is $tom_build_10.TomWs,
    constructors: {
    },
    staticGetters: {
      'context': (visitor) => $tom_build_10.TomWs.context,
      'info': (visitor) => $tom_build_10.TomWs.info,
      'path': (visitor) => $tom_build_10.TomWs.path,
      'platform': (visitor) => $tom_build_10.TomWs.platform,
      'projects': (visitor) => $tom_build_10.TomWs.projects,
      'projectsMap': (visitor) => $tom_build_10.TomWs.projectsMap,
      'groups': (visitor) => $tom_build_10.TomWs.groups,
      'groupsMap': (visitor) => $tom_build_10.TomWs.groupsMap,
      'name': (visitor) => $tom_build_10.TomWs.name,
      'buildOrder': (visitor) => $tom_build_10.TomWs.buildOrder,
      'projectNames': (visitor) => $tom_build_10.TomWs.projectNames,
      'groupNames': (visitor) => $tom_build_10.TomWs.groupNames,
      'dartPackages': (visitor) => $tom_build_10.TomWs.dartPackages,
      'flutterApps': (visitor) => $tom_build_10.TomWs.flutterApps,
      'dartServers': (visitor) => $tom_build_10.TomWs.dartServers,
      'vscodeExtensions': (visitor) => $tom_build_10.TomWs.vscodeExtensions,
      'isMacOS': (visitor) => $tom_build_10.TomWs.isMacOS,
      'isLinux': (visitor) => $tom_build_10.TomWs.isLinux,
      'isWindows': (visitor) => $tom_build_10.TomWs.isWindows,
      'osName': (visitor) => $tom_build_10.TomWs.osName,
      'arch': (visitor) => $tom_build_10.TomWs.arch,
      'isLoaded': (visitor) => $tom_build_10.TomWs.isLoaded,
    },
    staticMethods: {
      'project': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'project');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'project');
        return $tom_build_10.TomWs.project(name);
      },
      'hasProject': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'hasProject');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'hasProject');
        return $tom_build_10.TomWs.hasProject(name);
      },
      'projectsInGroup': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'projectsInGroup');
        final groupName = D4.getRequiredArg<String>(positional, 0, 'groupName', 'projectsInGroup');
        return $tom_build_10.TomWs.projectsInGroup(groupName);
      },
      'group': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'group');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'group');
        return $tom_build_10.TomWs.group(name);
      },
      'hasGroup': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'hasGroup');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'hasGroup');
        return $tom_build_10.TomWs.hasGroup(name);
      },
      'where': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'where');
        if (positional.isEmpty) {
          throw ArgumentError('where: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final test = (($tom_build_17.WorkspaceProject p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }) as bool Function($tom_build_17.WorkspaceProject);
        return $tom_build_10.TomWs.where(test);
      },
      'ofType': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'ofType');
        final type = D4.getRequiredArg<String>(positional, 0, 'type', 'ofType');
        return $tom_build_10.TomWs.ofType(type);
      },
      'reload': (visitor, positional, named, typeArgs) {
        return $tom_build_10.TomWs.reload();
      },
    },
    staticMethodSignatures: {
      'project': 'WorkspaceProject? project(String name)',
      'hasProject': 'bool hasProject(String name)',
      'projectsInGroup': 'List<WorkspaceProject> projectsInGroup(String groupName)',
      'group': 'WorkspaceGroup? group(String name)',
      'hasGroup': 'bool hasGroup(String name)',
      'where': 'List<WorkspaceProject> where(bool Function(WorkspaceProject) test)',
      'ofType': 'List<WorkspaceProject> ofType(String type)',
      'reload': 'Future<void> reload()',
    },
    staticGetterSignatures: {
      'context': 'ToolContext get context',
      'info': 'WorkspaceInfo get info',
      'path': 'String get path',
      'platform': 'PlatformInfo get platform',
      'projects': 'List<WorkspaceProject> get projects',
      'projectsMap': 'Map<String, WorkspaceProject> get projectsMap',
      'groups': 'List<WorkspaceGroup> get groups',
      'groupsMap': 'Map<String, WorkspaceGroup> get groupsMap',
      'name': 'String? get name',
      'buildOrder': 'List<String> get buildOrder',
      'projectNames': 'List<String> get projectNames',
      'groupNames': 'List<String> get groupNames',
      'dartPackages': 'List<WorkspaceProject> get dartPackages',
      'flutterApps': 'List<WorkspaceProject> get flutterApps',
      'dartServers': 'List<WorkspaceProject> get dartServers',
      'vscodeExtensions': 'List<WorkspaceProject> get vscodeExtensions',
      'isMacOS': 'bool get isMacOS',
      'isLinux': 'bool get isLinux',
      'isWindows': 'bool get isWindows',
      'osName': 'String get osName',
      'arch': 'String get arch',
      'isLoaded': 'bool get isLoaded',
    },
  );
}

// =============================================================================
// ScriptYaml Bridge
// =============================================================================

BridgedClass _createScriptYamlBridge() {
  return BridgedClass(
    nativeType: $tom_build_11.ScriptYaml,
    name: 'ScriptYaml',
    isAssignable: (v) => v is $tom_build_11.ScriptYaml,
    constructors: {
    },
    staticMethods: {
      'load': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'load');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'load');
        return $tom_build_11.ScriptYaml.load(path);
      },
      'loadWithEnv': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadWithEnv');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'loadWithEnv');
        final environment = D4.coerceMapOrNull<String, String>(named['environment'], 'environment');
        return $tom_build_11.ScriptYaml.loadWithEnv(path, environment: environment);
      },
      'parse': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parse');
        final yamlContent = D4.getRequiredArg<String>(positional, 0, 'yamlContent', 'parse');
        return $tom_build_11.ScriptYaml.parse(yamlContent);
      },
      'parseList': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parseList');
        final yamlContent = D4.getRequiredArg<String>(positional, 0, 'yamlContent', 'parseList');
        return $tom_build_11.ScriptYaml.parseList(yamlContent);
      },
      'parseAny': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parseAny');
        final yamlContent = D4.getRequiredArg<String>(positional, 0, 'yamlContent', 'parseAny');
        return $tom_build_11.ScriptYaml.parseAny(yamlContent);
      },
      'loadAny': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadAny');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'loadAny');
        return $tom_build_11.ScriptYaml.loadAny(path);
      },
      'loadList': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadList');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'loadList');
        return $tom_build_11.ScriptYaml.loadList(path);
      },
      'loadAndMerge': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadAndMerge');
        if (positional.isEmpty) {
          throw ArgumentError('loadAndMerge: Missing required argument "paths" at position 0');
        }
        final paths = D4.coerceList<String>(positional[0], 'paths');
        return $tom_build_11.ScriptYaml.loadAndMerge(paths);
      },
      'loadAndMergeWithEnv': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadAndMergeWithEnv');
        if (positional.isEmpty) {
          throw ArgumentError('loadAndMergeWithEnv: Missing required argument "paths" at position 0');
        }
        final paths = D4.coerceList<String>(positional[0], 'paths');
        final environment = D4.coerceMapOrNull<String, String>(named['environment'], 'environment');
        return $tom_build_11.ScriptYaml.loadAndMergeWithEnv(paths, environment: environment);
      },
      'isValidFile': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'isValidFile');
        final path = D4.getRequiredArg<String>(positional, 0, 'path', 'isValidFile');
        return $tom_build_11.ScriptYaml.isValidFile(path);
      },
    },
    staticMethodSignatures: {
      'load': 'Map<String, dynamic> load(String path)',
      'loadWithEnv': 'Map<String, dynamic> loadWithEnv(String path, {Map<String, String>? environment})',
      'parse': 'Map<String, dynamic> parse(String yamlContent)',
      'parseList': 'List parseList(String yamlContent)',
      'parseAny': 'dynamic parseAny(String yamlContent)',
      'loadAny': 'dynamic loadAny(String path)',
      'loadList': 'List loadList(String path)',
      'loadAndMerge': 'Map<String, dynamic> loadAndMerge(List<String> paths)',
      'loadAndMergeWithEnv': 'Map<String, dynamic> loadAndMergeWithEnv(List<String> paths, {Map<String, String>? environment})',
      'isValidFile': 'bool isValidFile(String path)',
    },
  );
}

// =============================================================================
// TomZoned Bridge
// =============================================================================

BridgedClass _createTomZonedBridge() {
  return BridgedClass(
    nativeType: $tom_build_12.TomZoned,
    name: 'TomZoned',
    isAssignable: (v) => v is $tom_build_12.TomZoned,
    constructors: {
    },
    staticGetters: {
      'current': (visitor) => $tom_build_12.TomZoned.current,
      'root': (visitor) => $tom_build_12.TomZoned.root,
    },
    staticMethods: {
      'get': (visitor, positional, named, typeArgs) {
        final name = D4.getOptionalArg<String?>(positional, 0, 'name');
        return $tom_build_12.TomZoned.get(name);
      },
      'getByKey': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getByKey');
        final key = D4.getRequiredArg<Object>(positional, 0, 'key', 'getByKey');
        return $tom_build_12.TomZoned.getByKey(key);
      },
      'run': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'run');
        if (positional.isEmpty) {
          throw ArgumentError('run: Missing required argument "values" at position 0');
        }
        final values = D4.coerceMap<Object, Object?>(positional[0], 'values');
        if (positional.length <= 1) {
          throw ArgumentError('run: Missing required argument "body" at position 1');
        }
        final bodyRaw = positional[1];
        final body = () { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, bodyRaw, [])); };
        return $tom_build_12.TomZoned.run(values, body);
      },
      'runAsync': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'runAsync');
        if (positional.isEmpty) {
          throw ArgumentError('runAsync: Missing required argument "values" at position 0');
        }
        final values = D4.coerceMap<Object, Object?>(positional[0], 'values');
        if (positional.length <= 1) {
          throw ArgumentError('runAsync: Missing required argument "body" at position 1');
        }
        final bodyRaw = positional[1];
        final body = (() { return Future.value(D4.callInterpreterCallback(visitor!, bodyRaw, [])).then((v) => v as dynamic); }) as Future<dynamic> Function();
        return $tom_build_12.TomZoned.runAsync(values, body);
      },
      'runGuarded': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'runGuarded');
        if (positional.isEmpty) {
          throw ArgumentError('runGuarded: Missing required argument "body" at position 0');
        }
        final bodyRaw = positional[0];
        final body = () { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, bodyRaw, [])); };
        if (!named.containsKey('onError') || named['onError'] == null) {
          throw ArgumentError('runGuarded: Missing required named argument "onError"');
        }
        final onErrorRaw = named['onError'];
        final onError = (Object p0, StackTrace p1) { D4.callInterpreterCallback(visitor!, onErrorRaw, [p0, p1]); };
        final values = D4.coerceMapOrNull<Object, Object?>(named['values'], 'values');
        return $tom_build_12.TomZoned.runGuarded(body, onError: onError, values: values);
      },
      'has': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'has');
        final key = D4.getRequiredArg<Object>(positional, 0, 'key', 'has');
        return $tom_build_12.TomZoned.has(key);
      },
      'hasType': (visitor, positional, named, typeArgs) {
        return $tom_build_12.TomZoned.hasType();
      },
    },
    staticMethodSignatures: {
      'get': 'T? get([String? name])',
      'getByKey': 'Object? getByKey(Object key)',
      'run': 'R run(Map<Object, Object?> values, R Function() body)',
      'runAsync': 'Future<R> runAsync(Map<Object, Object?> values, Future<R> Function() body)',
      'runGuarded': 'R runGuarded(R Function() body, {required void Function(Object error, StackTrace stack) onError, Map<Object, Object?>? values})',
      'has': 'bool has(Object key)',
      'hasType': 'bool hasType()',
    },
    staticGetterSignatures: {
      'current': 'Zone get current',
      'root': 'Zone get root',
    },
  );
}

// =============================================================================
// TomWorkspace Bridge
// =============================================================================

BridgedClass _createTomWorkspaceBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.TomWorkspace,
    name: 'TomWorkspace',
    isAssignable: (v) => v is $tom_build_13.TomWorkspace,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getOptionalNamedArg<String?>(named, 'name');
        final binaries = D4.getOptionalNamedArg<String?>(named, 'binaries');
        final operatingSystems = D4.coerceListOrNull<String>(named['operatingSystems'], 'operatingSystems');
        final mobilePlatforms = D4.coerceListOrNull<String>(named['mobilePlatforms'], 'mobilePlatforms');
        final imports = D4.coerceListOrNull<String>(named['imports'], 'imports');
        final workspaceModes = D4.getOptionalNamedArg<$tom_build_13.WorkspaceModes?>(named, 'workspaceModes');
        final crossCompilation = D4.getOptionalNamedArg<$tom_build_13.CrossCompilation?>(named, 'crossCompilation');
        final groups = named.containsKey('groups') && named['groups'] != null
            ? D4.coerceMap<String, $tom_build_13.GroupDef>(named['groups'], 'groups')
            : const <String, $tom_build_13.GroupDef>{};
        final projectTypes = named.containsKey('projectTypes') && named['projectTypes'] != null
            ? D4.coerceMap<String, $tom_build_13.ProjectTypeDef>(named['projectTypes'], 'projectTypes')
            : const <String, $tom_build_13.ProjectTypeDef>{};
        final actions = named.containsKey('actions') && named['actions'] != null
            ? D4.coerceMap<String, $tom_build_13.ActionDef>(named['actions'], 'actions')
            : const <String, $tom_build_13.ActionDef>{};
        final modeDefinitions = named.containsKey('modeDefinitions') && named['modeDefinitions'] != null
            ? D4.coerceMap<String, $tom_build_13.ModeDefinitions>(named['modeDefinitions'], 'modeDefinitions')
            : const <String, $tom_build_13.ModeDefinitions>{};
        final pipelines = named.containsKey('pipelines') && named['pipelines'] != null
            ? D4.coerceMap<String, $tom_build_13.Pipeline>(named['pipelines'], 'pipelines')
            : const <String, $tom_build_13.Pipeline>{};
        final projectInfo = named.containsKey('projectInfo') && named['projectInfo'] != null
            ? D4.coerceMap<String, $tom_build_13.ProjectEntry>(named['projectInfo'], 'projectInfo')
            : const <String, $tom_build_13.ProjectEntry>{};
        final deps = named.containsKey('deps') && named['deps'] != null
            ? D4.coerceMap<String, String>(named['deps'], 'deps')
            : const <String, String>{};
        final depsDev = named.containsKey('depsDev') && named['depsDev'] != null
            ? D4.coerceMap<String, String>(named['depsDev'], 'depsDev')
            : const <String, String>{};
        final versionSettings = D4.getOptionalNamedArg<$tom_build_13.VersionSettings?>(named, 'versionSettings');
        final customTags = named.containsKey('customTags') && named['customTags'] != null
            ? D4.coerceMap<String, dynamic>(named['customTags'], 'customTags')
            : const <String, dynamic>{};
        return $tom_build_13.TomWorkspace(name: name, binaries: binaries, operatingSystems: operatingSystems, mobilePlatforms: mobilePlatforms, imports: imports, workspaceModes: workspaceModes, crossCompilation: crossCompilation, groups: groups, projectTypes: projectTypes, actions: actions, modeDefinitions: modeDefinitions, pipelines: pipelines, projectInfo: projectInfo, deps: deps, depsDev: depsDev, versionSettings: versionSettings, customTags: customTags);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomWorkspace');
        if (positional.isEmpty) {
          throw ArgumentError('TomWorkspace: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.TomWorkspace.fromYaml(yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').name,
      'binaries': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').binaries,
      'operatingSystems': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').operatingSystems,
      'mobilePlatforms': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').mobilePlatforms,
      'imports': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').imports,
      'workspaceModes': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').workspaceModes,
      'crossCompilation': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').crossCompilation,
      'groups': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').groups,
      'projectTypes': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').projectTypes,
      'actions': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').actions,
      'modeDefinitions': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').modeDefinitions,
      'pipelines': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').pipelines,
      'projectInfo': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').projectInfo,
      'deps': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').deps,
      'depsDev': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').depsDev,
      'versionSettings': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').versionSettings,
      'customTags': (visitor, target) => D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace').customTags,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.TomWorkspace>(target, 'TomWorkspace');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'TomWorkspace({String? name, String? binaries, List<String>? operatingSystems, List<String>? mobilePlatforms, List<String>? imports, WorkspaceModes? workspaceModes, CrossCompilation? crossCompilation, Map<String, GroupDef> groups = const {}, Map<String, ProjectTypeDef> projectTypes = const {}, Map<String, ActionDef> actions = const {}, Map<String, ModeDefinitions> modeDefinitions = const {}, Map<String, Pipeline> pipelines = const {}, Map<String, ProjectEntry> projectInfo = const {}, Map<String, String> deps = const {}, Map<String, String> depsDev = const {}, VersionSettings? versionSettings, Map<String, dynamic> customTags = const {}})',
      'fromYaml': 'factory TomWorkspace.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String? get name',
      'binaries': 'String? get binaries',
      'operatingSystems': 'List<String>? get operatingSystems',
      'mobilePlatforms': 'List<String>? get mobilePlatforms',
      'imports': 'List<String>? get imports',
      'workspaceModes': 'WorkspaceModes? get workspaceModes',
      'crossCompilation': 'CrossCompilation? get crossCompilation',
      'groups': 'Map<String, GroupDef> get groups',
      'projectTypes': 'Map<String, ProjectTypeDef> get projectTypes',
      'actions': 'Map<String, ActionDef> get actions',
      'modeDefinitions': 'Map<String, ModeDefinitions> get modeDefinitions',
      'pipelines': 'Map<String, Pipeline> get pipelines',
      'projectInfo': 'Map<String, ProjectEntry> get projectInfo',
      'deps': 'Map<String, String> get deps',
      'depsDev': 'Map<String, String> get depsDev',
      'versionSettings': 'VersionSettings? get versionSettings',
      'customTags': 'Map<String, dynamic> get customTags',
    },
  );
}

// =============================================================================
// TomMaster Bridge
// =============================================================================

BridgedClass _createTomMasterBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.TomMaster,
    name: 'TomMaster',
    isAssignable: (v) => v is $tom_build_13.TomMaster,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getOptionalNamedArg<String?>(named, 'name');
        final binaries = D4.getOptionalNamedArg<String?>(named, 'binaries');
        final operatingSystems = D4.coerceListOrNull<String>(named['operatingSystems'], 'operatingSystems');
        final mobilePlatforms = D4.coerceListOrNull<String>(named['mobilePlatforms'], 'mobilePlatforms');
        final imports = D4.coerceListOrNull<String>(named['imports'], 'imports');
        final workspaceModes = D4.getOptionalNamedArg<$tom_build_13.WorkspaceModes?>(named, 'workspaceModes');
        final crossCompilation = D4.getOptionalNamedArg<$tom_build_13.CrossCompilation?>(named, 'crossCompilation');
        final groups = named.containsKey('groups') && named['groups'] != null
            ? D4.coerceMap<String, $tom_build_13.GroupDef>(named['groups'], 'groups')
            : const <String, $tom_build_13.GroupDef>{};
        final projectTypes = named.containsKey('projectTypes') && named['projectTypes'] != null
            ? D4.coerceMap<String, $tom_build_13.ProjectTypeDef>(named['projectTypes'], 'projectTypes')
            : const <String, $tom_build_13.ProjectTypeDef>{};
        final actions = named.containsKey('actions') && named['actions'] != null
            ? D4.coerceMap<String, $tom_build_13.ActionDef>(named['actions'], 'actions')
            : const <String, $tom_build_13.ActionDef>{};
        final modeDefinitions = named.containsKey('modeDefinitions') && named['modeDefinitions'] != null
            ? D4.coerceMap<String, $tom_build_13.ModeDefinitions>(named['modeDefinitions'], 'modeDefinitions')
            : const <String, $tom_build_13.ModeDefinitions>{};
        final pipelines = named.containsKey('pipelines') && named['pipelines'] != null
            ? D4.coerceMap<String, $tom_build_13.Pipeline>(named['pipelines'], 'pipelines')
            : const <String, $tom_build_13.Pipeline>{};
        final projectInfo = named.containsKey('projectInfo') && named['projectInfo'] != null
            ? D4.coerceMap<String, $tom_build_13.ProjectEntry>(named['projectInfo'], 'projectInfo')
            : const <String, $tom_build_13.ProjectEntry>{};
        final deps = named.containsKey('deps') && named['deps'] != null
            ? D4.coerceMap<String, String>(named['deps'], 'deps')
            : const <String, String>{};
        final depsDev = named.containsKey('depsDev') && named['depsDev'] != null
            ? D4.coerceMap<String, String>(named['depsDev'], 'depsDev')
            : const <String, String>{};
        final versionSettings = D4.getOptionalNamedArg<$tom_build_13.VersionSettings?>(named, 'versionSettings');
        final customTags = named.containsKey('customTags') && named['customTags'] != null
            ? D4.coerceMap<String, dynamic>(named['customTags'], 'customTags')
            : const <String, dynamic>{};
        final scanTimestamp = D4.getOptionalNamedArg<String?>(named, 'scanTimestamp');
        final projects = named.containsKey('projects') && named['projects'] != null
            ? D4.coerceMap<String, $tom_build_13.TomProject>(named['projects'], 'projects')
            : const <String, $tom_build_13.TomProject>{};
        final buildOrder = named.containsKey('buildOrder') && named['buildOrder'] != null
            ? D4.coerceList<String>(named['buildOrder'], 'buildOrder')
            : const <String>[];
        final actionOrder = named.containsKey('actionOrder') && named['actionOrder'] != null
            ? D4.coerceMap<String, List<String>>(named['actionOrder'], 'actionOrder')
            : const <String, List<String>>{};
        return $tom_build_13.TomMaster(name: name, binaries: binaries, operatingSystems: operatingSystems, mobilePlatforms: mobilePlatforms, imports: imports, workspaceModes: workspaceModes, crossCompilation: crossCompilation, groups: groups, projectTypes: projectTypes, actions: actions, modeDefinitions: modeDefinitions, pipelines: pipelines, projectInfo: projectInfo, deps: deps, depsDev: depsDev, versionSettings: versionSettings, customTags: customTags, scanTimestamp: scanTimestamp, projects: projects, buildOrder: buildOrder, actionOrder: actionOrder);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomMaster');
        if (positional.isEmpty) {
          throw ArgumentError('TomMaster: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.TomMaster.fromYaml(yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').name,
      'binaries': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').binaries,
      'operatingSystems': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').operatingSystems,
      'mobilePlatforms': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').mobilePlatforms,
      'imports': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').imports,
      'workspaceModes': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').workspaceModes,
      'crossCompilation': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').crossCompilation,
      'groups': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').groups,
      'projectTypes': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').projectTypes,
      'actions': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').actions,
      'modeDefinitions': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').modeDefinitions,
      'pipelines': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').pipelines,
      'projectInfo': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').projectInfo,
      'deps': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').deps,
      'depsDev': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').depsDev,
      'versionSettings': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').versionSettings,
      'customTags': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').customTags,
      'scanTimestamp': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').scanTimestamp,
      'projects': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').projects,
      'buildOrder': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').buildOrder,
      'actionOrder': (visitor, target) => D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster').actionOrder,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.TomMaster>(target, 'TomMaster');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'TomMaster({String? name, String? binaries, List<String>? operatingSystems, List<String>? mobilePlatforms, List<String>? imports, WorkspaceModes? workspaceModes, CrossCompilation? crossCompilation, Map<String, GroupDef> groups = const {}, Map<String, ProjectTypeDef> projectTypes = const {}, Map<String, ActionDef> actions = const {}, Map<String, ModeDefinitions> modeDefinitions = const {}, Map<String, Pipeline> pipelines = const {}, Map<String, ProjectEntry> projectInfo = const {}, Map<String, String> deps = const {}, Map<String, String> depsDev = const {}, VersionSettings? versionSettings, Map<String, dynamic> customTags = const {}, String? scanTimestamp, Map<String, TomProject> projects = const {}, List<String> buildOrder = const [], Map<String, List<String>> actionOrder = const {}})',
      'fromYaml': 'factory TomMaster.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String? get name',
      'binaries': 'String? get binaries',
      'operatingSystems': 'List<String>? get operatingSystems',
      'mobilePlatforms': 'List<String>? get mobilePlatforms',
      'imports': 'List<String>? get imports',
      'workspaceModes': 'WorkspaceModes? get workspaceModes',
      'crossCompilation': 'CrossCompilation? get crossCompilation',
      'groups': 'Map<String, GroupDef> get groups',
      'projectTypes': 'Map<String, ProjectTypeDef> get projectTypes',
      'actions': 'Map<String, ActionDef> get actions',
      'modeDefinitions': 'Map<String, ModeDefinitions> get modeDefinitions',
      'pipelines': 'Map<String, Pipeline> get pipelines',
      'projectInfo': 'Map<String, ProjectEntry> get projectInfo',
      'deps': 'Map<String, String> get deps',
      'depsDev': 'Map<String, String> get depsDev',
      'versionSettings': 'VersionSettings? get versionSettings',
      'customTags': 'Map<String, dynamic> get customTags',
      'scanTimestamp': 'String? get scanTimestamp',
      'projects': 'Map<String, TomProject> get projects',
      'buildOrder': 'List<String> get buildOrder',
      'actionOrder': 'Map<String, List<String>> get actionOrder',
    },
  );
}

// =============================================================================
// TomProject Bridge
// =============================================================================

BridgedClass _createTomProjectBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.TomProject,
    name: 'TomProject',
    isAssignable: (v) => v is $tom_build_13.TomProject,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'TomProject');
        final type = D4.getOptionalNamedArg<String?>(named, 'type');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final binaries = D4.getOptionalNamedArg<String?>(named, 'binaries');
        final buildAfter = named.containsKey('buildAfter') && named['buildAfter'] != null
            ? D4.coerceList<String>(named['buildAfter'], 'buildAfter')
            : const <String>[];
        final actionOrder = named.containsKey('actionOrder') && named['actionOrder'] != null
            ? D4.coerceMap<String, List<String>>(named['actionOrder'], 'actionOrder')
            : const <String, List<String>>{};
        final features = D4.getOptionalNamedArg<$tom_build_13.Features?>(named, 'features');
        final actions = named.containsKey('actions') && named['actions'] != null
            ? D4.coerceMap<String, $tom_build_13.ActionDef>(named['actions'], 'actions')
            : const <String, $tom_build_13.ActionDef>{};
        final modeDefinitions = named.containsKey('modeDefinitions') && named['modeDefinitions'] != null
            ? D4.coerceMap<String, $tom_build_13.ModeDefinitions>(named['modeDefinitions'], 'modeDefinitions')
            : const <String, $tom_build_13.ModeDefinitions>{};
        final crossCompilation = D4.getOptionalNamedArg<$tom_build_13.CrossCompilation?>(named, 'crossCompilation');
        final packageModule = D4.getOptionalNamedArg<$tom_build_13.PackageModule?>(named, 'packageModule');
        final parts = named.containsKey('parts') && named['parts'] != null
            ? D4.coerceMap<String, $tom_build_13.Part>(named['parts'], 'parts')
            : const <String, $tom_build_13.Part>{};
        final tests = D4.coerceListOrNull<String>(named['tests'], 'tests');
        final examples = D4.coerceListOrNull<String>(named['examples'], 'examples');
        final docs = D4.coerceListOrNull<String>(named['docs'], 'docs');
        final copilotGuidelines = D4.coerceListOrNull<String>(named['copilotGuidelines'], 'copilotGuidelines');
        final binaryFiles = D4.coerceListOrNull<String>(named['binaryFiles'], 'binaryFiles');
        final executables = named.containsKey('executables') && named['executables'] != null
            ? D4.coerceList<$tom_build_13.ExecutableDef>(named['executables'], 'executables')
            : const <$tom_build_13.ExecutableDef>[];
        final metadataFiles = named.containsKey('metadataFiles') && named['metadataFiles'] != null
            ? D4.coerceMap<String, dynamic>(named['metadataFiles'], 'metadataFiles')
            : const <String, dynamic>{};
        final actionModeDefinitions = D4.coerceMapOrNull<String, dynamic>(named['actionModeDefinitions'], 'actionModeDefinitions');
        final customTags = named.containsKey('customTags') && named['customTags'] != null
            ? D4.coerceMap<String, dynamic>(named['customTags'], 'customTags')
            : const <String, dynamic>{};
        return $tom_build_13.TomProject(name: name, type: type, description: description, binaries: binaries, buildAfter: buildAfter, actionOrder: actionOrder, features: features, actions: actions, modeDefinitions: modeDefinitions, crossCompilation: crossCompilation, packageModule: packageModule, parts: parts, tests: tests, examples: examples, docs: docs, copilotGuidelines: copilotGuidelines, binaryFiles: binaryFiles, executables: executables, metadataFiles: metadataFiles, actionModeDefinitions: actionModeDefinitions, customTags: customTags);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomProject');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'TomProject');
        if (positional.length <= 1) {
          throw ArgumentError('TomProject: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        final defaultActions = D4.coerceMapOrNull<String, $tom_build_13.ActionDef>(named['defaultActions'], 'defaultActions');
        return $tom_build_13.TomProject.fromYaml(name, yaml, defaultActions: defaultActions);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').name,
      'type': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').type,
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').description,
      'binaries': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').binaries,
      'buildAfter': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').buildAfter,
      'actionOrder': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').actionOrder,
      'features': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').features,
      'actions': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').actions,
      'modeDefinitions': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').modeDefinitions,
      'crossCompilation': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').crossCompilation,
      'packageModule': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').packageModule,
      'parts': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').parts,
      'tests': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').tests,
      'examples': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').examples,
      'docs': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').docs,
      'copilotGuidelines': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').copilotGuidelines,
      'binaryFiles': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').binaryFiles,
      'executables': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').executables,
      'metadataFiles': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').metadataFiles,
      'actionModeDefinitions': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').actionModeDefinitions,
      'customTags': (visitor, target) => D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject').customTags,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject');
        return t.toYaml();
      },
      'toYamlCompact': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.TomProject>(target, 'TomProject');
        final workspaceCrossCompilation = D4.getOptionalNamedArg<$tom_build_13.CrossCompilation?>(named, 'workspaceCrossCompilation');
        final workspaceModeDefinitions = D4.coerceMapOrNull<String, $tom_build_13.ModeDefinitions>(named['workspaceModeDefinitions'], 'workspaceModeDefinitions');
        final workspaceActions = D4.coerceMapOrNull<String, $tom_build_13.ActionDef>(named['workspaceActions'], 'workspaceActions');
        return t.toYamlCompact(workspaceCrossCompilation: workspaceCrossCompilation, workspaceModeDefinitions: workspaceModeDefinitions, workspaceActions: workspaceActions);
      },
    },
    constructorSignatures: {
      '': 'TomProject({required String name, String? type, String? description, String? binaries, List<String> buildAfter = const [], Map<String, List<String>> actionOrder = const {}, Features? features, Map<String, ActionDef> actions = const {}, Map<String, ModeDefinitions> modeDefinitions = const {}, CrossCompilation? crossCompilation, PackageModule? packageModule, Map<String, Part> parts = const {}, List<String>? tests, List<String>? examples, List<String>? docs, List<String>? copilotGuidelines, List<String>? binaryFiles, List<ExecutableDef> executables = const [], Map<String, dynamic> metadataFiles = const {}, Map<String, dynamic>? actionModeDefinitions, Map<String, dynamic> customTags = const {}})',
      'fromYaml': 'factory TomProject.fromYaml(String name, Map<String, dynamic> yaml, {Map<String, ActionDef>? defaultActions})',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
      'toYamlCompact': 'Map<String, dynamic> toYamlCompact({CrossCompilation? workspaceCrossCompilation, Map<String, ModeDefinitions>? workspaceModeDefinitions, Map<String, ActionDef>? workspaceActions})',
    },
    getterSignatures: {
      'name': 'String get name',
      'type': 'String? get type',
      'description': 'String? get description',
      'binaries': 'String? get binaries',
      'buildAfter': 'List<String> get buildAfter',
      'actionOrder': 'Map<String, List<String>> get actionOrder',
      'features': 'Features? get features',
      'actions': 'Map<String, ActionDef> get actions',
      'modeDefinitions': 'Map<String, ModeDefinitions> get modeDefinitions',
      'crossCompilation': 'CrossCompilation? get crossCompilation',
      'packageModule': 'PackageModule? get packageModule',
      'parts': 'Map<String, Part> get parts',
      'tests': 'List<String>? get tests',
      'examples': 'List<String>? get examples',
      'docs': 'List<String>? get docs',
      'copilotGuidelines': 'List<String>? get copilotGuidelines',
      'binaryFiles': 'List<String>? get binaryFiles',
      'executables': 'List<ExecutableDef> get executables',
      'metadataFiles': 'Map<String, dynamic> get metadataFiles',
      'actionModeDefinitions': 'Map<String, dynamic>? get actionModeDefinitions',
      'customTags': 'Map<String, dynamic> get customTags',
    },
  );
}

// =============================================================================
// WorkspaceModes Bridge
// =============================================================================

BridgedClass _createWorkspaceModesBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.WorkspaceModes,
    name: 'WorkspaceModes',
    isAssignable: (v) => v is $tom_build_13.WorkspaceModes,
    constructors: {
      '': (visitor, positional, named) {
        final modeTypes = named.containsKey('modeTypes') && named['modeTypes'] != null
            ? D4.coerceList<String>(named['modeTypes'], 'modeTypes')
            : const <String>[];
        final supported = named.containsKey('supported') && named['supported'] != null
            ? D4.coerceList<$tom_build_13.SupportedMode>(named['supported'], 'supported')
            : const <$tom_build_13.SupportedMode>[];
        final modeTypeConfigs = named.containsKey('modeTypeConfigs') && named['modeTypeConfigs'] != null
            ? D4.coerceMap<String, $tom_build_13.ModeTypeConfig>(named['modeTypeConfigs'], 'modeTypeConfigs')
            : const <String, $tom_build_13.ModeTypeConfig>{};
        final actionModeConfiguration = D4.getOptionalNamedArg<$tom_build_13.ActionModeConfiguration?>(named, 'actionModeConfiguration');
        final defaultMode = D4.getOptionalNamedArg<String?>(named, 'defaultMode');
        return $tom_build_13.WorkspaceModes(modeTypes: modeTypes, supported: supported, modeTypeConfigs: modeTypeConfigs, actionModeConfiguration: actionModeConfiguration, defaultMode: defaultMode);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'WorkspaceModes');
        if (positional.isEmpty) {
          throw ArgumentError('WorkspaceModes: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.WorkspaceModes.fromYaml(yaml);
      },
    },
    getters: {
      'modeTypes': (visitor, target) => D4.validateTarget<$tom_build_13.WorkspaceModes>(target, 'WorkspaceModes').modeTypes,
      'supported': (visitor, target) => D4.validateTarget<$tom_build_13.WorkspaceModes>(target, 'WorkspaceModes').supported,
      'modeTypeConfigs': (visitor, target) => D4.validateTarget<$tom_build_13.WorkspaceModes>(target, 'WorkspaceModes').modeTypeConfigs,
      'actionModeConfiguration': (visitor, target) => D4.validateTarget<$tom_build_13.WorkspaceModes>(target, 'WorkspaceModes').actionModeConfiguration,
      'defaultMode': (visitor, target) => D4.validateTarget<$tom_build_13.WorkspaceModes>(target, 'WorkspaceModes').defaultMode,
      'supportedModes': (visitor, target) => D4.validateTarget<$tom_build_13.WorkspaceModes>(target, 'WorkspaceModes').supportedModes,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.WorkspaceModes>(target, 'WorkspaceModes');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'WorkspaceModes({List<String> modeTypes = const [], List<SupportedMode> supported = const [], Map<String, ModeTypeConfig> modeTypeConfigs = const {}, ActionModeConfiguration? actionModeConfiguration, String? defaultMode})',
      'fromYaml': 'factory WorkspaceModes.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'modeTypes': 'List<String> get modeTypes',
      'supported': 'List<SupportedMode> get supported',
      'modeTypeConfigs': 'Map<String, ModeTypeConfig> get modeTypeConfigs',
      'actionModeConfiguration': 'ActionModeConfiguration? get actionModeConfiguration',
      'defaultMode': 'String? get defaultMode',
      'supportedModes': 'List<SupportedMode> get supportedModes',
    },
  );
}

// =============================================================================
// SupportedMode Bridge
// =============================================================================

BridgedClass _createSupportedModeBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.SupportedMode,
    name: 'SupportedMode',
    isAssignable: (v) => v is $tom_build_13.SupportedMode,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'SupportedMode');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final implies = named.containsKey('implies') && named['implies'] != null
            ? D4.coerceList<String>(named['implies'], 'implies')
            : const <String>[];
        return $tom_build_13.SupportedMode(name: name, description: description, implies: implies);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SupportedMode');
        if (positional.isEmpty) {
          throw ArgumentError('SupportedMode: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.SupportedMode.fromYaml(yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.SupportedMode>(target, 'SupportedMode').name,
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.SupportedMode>(target, 'SupportedMode').description,
      'implies': (visitor, target) => D4.validateTarget<$tom_build_13.SupportedMode>(target, 'SupportedMode').implies,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.SupportedMode>(target, 'SupportedMode');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'SupportedMode({required String name, String? description, List<String> implies = const []})',
      'fromYaml': 'factory SupportedMode.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'description': 'String? get description',
      'implies': 'List<String> get implies',
    },
  );
}

// =============================================================================
// ModeTypeConfig Bridge
// =============================================================================

BridgedClass _createModeTypeConfigBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ModeTypeConfig,
    name: 'ModeTypeConfig',
    isAssignable: (v) => v is $tom_build_13.ModeTypeConfig,
    constructors: {
      '': (visitor, positional, named) {
        final defaultMode = D4.getOptionalNamedArg<String?>(named, 'defaultMode');
        final entries = named.containsKey('entries') && named['entries'] != null
            ? D4.coerceMap<String, $tom_build_13.ModeEntry>(named['entries'], 'entries')
            : const <String, $tom_build_13.ModeEntry>{};
        return $tom_build_13.ModeTypeConfig(defaultMode: defaultMode, entries: entries);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ModeTypeConfig');
        if (positional.isEmpty) {
          throw ArgumentError('ModeTypeConfig: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.ModeTypeConfig.fromYaml(yaml);
      },
    },
    getters: {
      'defaultMode': (visitor, target) => D4.validateTarget<$tom_build_13.ModeTypeConfig>(target, 'ModeTypeConfig').defaultMode,
      'entries': (visitor, target) => D4.validateTarget<$tom_build_13.ModeTypeConfig>(target, 'ModeTypeConfig').entries,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ModeTypeConfig>(target, 'ModeTypeConfig');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ModeTypeConfig({String? defaultMode, Map<String, ModeEntry> entries = const {}})',
      'fromYaml': 'factory ModeTypeConfig.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'defaultMode': 'String? get defaultMode',
      'entries': 'Map<String, ModeEntry> get entries',
    },
  );
}

// =============================================================================
// ModeEntry Bridge
// =============================================================================

BridgedClass _createModeEntryBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ModeEntry,
    name: 'ModeEntry',
    isAssignable: (v) => v is $tom_build_13.ModeEntry,
    constructors: {
      '': (visitor, positional, named) {
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final modes = named.containsKey('modes') && named['modes'] != null
            ? D4.coerceList<String>(named['modes'], 'modes')
            : const <String>[];
        final properties = named.containsKey('properties') && named['properties'] != null
            ? D4.coerceMap<String, dynamic>(named['properties'], 'properties')
            : const <String, dynamic>{};
        return $tom_build_13.ModeEntry(description: description, modes: modes, properties: properties);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ModeEntry');
        if (positional.isEmpty) {
          throw ArgumentError('ModeEntry: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.ModeEntry.fromYaml(yaml);
      },
    },
    getters: {
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.ModeEntry>(target, 'ModeEntry').description,
      'modes': (visitor, target) => D4.validateTarget<$tom_build_13.ModeEntry>(target, 'ModeEntry').modes,
      'properties': (visitor, target) => D4.validateTarget<$tom_build_13.ModeEntry>(target, 'ModeEntry').properties,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ModeEntry>(target, 'ModeEntry');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ModeEntry({String? description, List<String> modes = const [], Map<String, dynamic> properties = const {}})',
      'fromYaml': 'factory ModeEntry.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'description': 'String? get description',
      'modes': 'List<String> get modes',
      'properties': 'Map<String, dynamic> get properties',
    },
  );
}

// =============================================================================
// ActionModeConfiguration Bridge
// =============================================================================

BridgedClass _createActionModeConfigurationBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ActionModeConfiguration,
    name: 'ActionModeConfiguration',
    isAssignable: (v) => v is $tom_build_13.ActionModeConfiguration,
    constructors: {
      '': (visitor, positional, named) {
        final entries = named.containsKey('entries') && named['entries'] != null
            ? D4.coerceMap<String, $tom_build_13.ActionModeEntry>(named['entries'], 'entries')
            : const <String, $tom_build_13.ActionModeEntry>{};
        return $tom_build_13.ActionModeConfiguration(entries: entries);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ActionModeConfiguration');
        if (positional.isEmpty) {
          throw ArgumentError('ActionModeConfiguration: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.ActionModeConfiguration.fromYaml(yaml);
      },
    },
    getters: {
      'entries': (visitor, target) => D4.validateTarget<$tom_build_13.ActionModeConfiguration>(target, 'ActionModeConfiguration').entries,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ActionModeConfiguration>(target, 'ActionModeConfiguration');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ActionModeConfiguration({Map<String, ActionModeEntry> entries = const {}})',
      'fromYaml': 'factory ActionModeConfiguration.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'entries': 'Map<String, ActionModeEntry> get entries',
    },
  );
}

// =============================================================================
// ActionModeEntry Bridge
// =============================================================================

BridgedClass _createActionModeEntryBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ActionModeEntry,
    name: 'ActionModeEntry',
    isAssignable: (v) => v is $tom_build_13.ActionModeEntry,
    constructors: {
      '': (visitor, positional, named) {
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final modes = named.containsKey('modes') && named['modes'] != null
            ? D4.coerceMap<String, String>(named['modes'], 'modes')
            : const <String, String>{};
        return $tom_build_13.ActionModeEntry(description: description, modes: modes);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ActionModeEntry');
        if (positional.isEmpty) {
          throw ArgumentError('ActionModeEntry: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.ActionModeEntry.fromYaml(yaml);
      },
    },
    getters: {
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.ActionModeEntry>(target, 'ActionModeEntry').description,
      'modes': (visitor, target) => D4.validateTarget<$tom_build_13.ActionModeEntry>(target, 'ActionModeEntry').modes,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ActionModeEntry>(target, 'ActionModeEntry');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ActionModeEntry({String? description, Map<String, String> modes = const {}})',
      'fromYaml': 'factory ActionModeEntry.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'description': 'String? get description',
      'modes': 'Map<String, String> get modes',
    },
  );
}

// =============================================================================
// ModeDefinitions Bridge
// =============================================================================

BridgedClass _createModeDefinitionsBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ModeDefinitions,
    name: 'ModeDefinitions',
    isAssignable: (v) => v is $tom_build_13.ModeDefinitions,
    constructors: {
      '': (visitor, positional, named) {
        final definitions = named.containsKey('definitions') && named['definitions'] != null
            ? D4.coerceMap<String, $tom_build_13.ModeDef>(named['definitions'], 'definitions')
            : const <String, $tom_build_13.ModeDef>{};
        return $tom_build_13.ModeDefinitions(definitions: definitions);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ModeDefinitions');
        if (positional.isEmpty) {
          throw ArgumentError('ModeDefinitions: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.ModeDefinitions.fromYaml(yaml);
      },
    },
    getters: {
      'definitions': (visitor, target) => D4.validateTarget<$tom_build_13.ModeDefinitions>(target, 'ModeDefinitions').definitions,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ModeDefinitions>(target, 'ModeDefinitions');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ModeDefinitions({Map<String, ModeDef> definitions = const {}})',
      'fromYaml': 'factory ModeDefinitions.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'definitions': 'Map<String, ModeDef> get definitions',
    },
  );
}

// =============================================================================
// ModeDef Bridge
// =============================================================================

BridgedClass _createModeDefBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ModeDef,
    name: 'ModeDef',
    isAssignable: (v) => v is $tom_build_13.ModeDef,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'ModeDef');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final properties = named.containsKey('properties') && named['properties'] != null
            ? D4.coerceMap<String, dynamic>(named['properties'], 'properties')
            : const <String, dynamic>{};
        return $tom_build_13.ModeDef(name: name, description: description, properties: properties);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'ModeDef');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'ModeDef');
        if (positional.length <= 1) {
          throw ArgumentError('ModeDef: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.ModeDef.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.ModeDef>(target, 'ModeDef').name,
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.ModeDef>(target, 'ModeDef').description,
      'properties': (visitor, target) => D4.validateTarget<$tom_build_13.ModeDef>(target, 'ModeDef').properties,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ModeDef>(target, 'ModeDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ModeDef({required String name, String? description, Map<String, dynamic> properties = const {}})',
      'fromYaml': 'factory ModeDef.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'description': 'String? get description',
      'properties': 'Map<String, dynamic> get properties',
    },
  );
}

// =============================================================================
// ActionDef Bridge
// =============================================================================

BridgedClass _createActionDefBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ActionDef,
    name: 'ActionDef',
    isAssignable: (v) => v is $tom_build_13.ActionDef,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'ActionDef');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final skipTypes = D4.coerceListOrNull<String>(named['skipTypes'], 'skipTypes');
        final appliesToTypes = D4.coerceListOrNull<String>(named['appliesToTypes'], 'appliesToTypes');
        final defaultConfig = D4.getOptionalNamedArg<$tom_build_13.ActionConfig?>(named, 'defaultConfig');
        final typeConfigs = named.containsKey('typeConfigs') && named['typeConfigs'] != null
            ? D4.coerceMap<String, $tom_build_13.ActionConfig>(named['typeConfigs'], 'typeConfigs')
            : const <String, $tom_build_13.ActionConfig>{};
        return $tom_build_13.ActionDef(name: name, description: description, skipTypes: skipTypes, appliesToTypes: appliesToTypes, defaultConfig: defaultConfig, typeConfigs: typeConfigs);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'ActionDef');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'ActionDef');
        if (positional.length <= 1) {
          throw ArgumentError('ActionDef: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.ActionDef.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.ActionDef>(target, 'ActionDef').name,
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.ActionDef>(target, 'ActionDef').description,
      'skipTypes': (visitor, target) => D4.validateTarget<$tom_build_13.ActionDef>(target, 'ActionDef').skipTypes,
      'appliesToTypes': (visitor, target) => D4.validateTarget<$tom_build_13.ActionDef>(target, 'ActionDef').appliesToTypes,
      'defaultConfig': (visitor, target) => D4.validateTarget<$tom_build_13.ActionDef>(target, 'ActionDef').defaultConfig,
      'typeConfigs': (visitor, target) => D4.validateTarget<$tom_build_13.ActionDef>(target, 'ActionDef').typeConfigs,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ActionDef>(target, 'ActionDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ActionDef({required String name, String? description, List<String>? skipTypes, List<String>? appliesToTypes, ActionConfig? defaultConfig, Map<String, ActionConfig> typeConfigs = const {}})',
      'fromYaml': 'factory ActionDef.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'description': 'String? get description',
      'skipTypes': 'List<String>? get skipTypes',
      'appliesToTypes': 'List<String>? get appliesToTypes',
      'defaultConfig': 'ActionConfig? get defaultConfig',
      'typeConfigs': 'Map<String, ActionConfig> get typeConfigs',
    },
  );
}

// =============================================================================
// ActionConfig Bridge
// =============================================================================

BridgedClass _createActionConfigBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ActionConfig,
    name: 'ActionConfig',
    isAssignable: (v) => v is $tom_build_13.ActionConfig,
    constructors: {
      '': (visitor, positional, named) {
        final preCommands = D4.getOptionalNamedArg<List?>(named, 'preCommands');
        final commands = D4.getNamedArgWithDefault<List>(named, 'commands', const []);
        final postCommands = D4.getOptionalNamedArg<List?>(named, 'postCommands');
        final customTags = named.containsKey('customTags') && named['customTags'] != null
            ? D4.coerceMap<String, dynamic>(named['customTags'], 'customTags')
            : const <String, dynamic>{};
        return $tom_build_13.ActionConfig(preCommands: preCommands, commands: commands, postCommands: postCommands, customTags: customTags);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ActionConfig');
        if (positional.isEmpty) {
          throw ArgumentError('ActionConfig: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.ActionConfig.fromYaml(yaml);
      },
    },
    getters: {
      'preCommands': (visitor, target) => D4.validateTarget<$tom_build_13.ActionConfig>(target, 'ActionConfig').preCommands,
      'commands': (visitor, target) => D4.validateTarget<$tom_build_13.ActionConfig>(target, 'ActionConfig').commands,
      'postCommands': (visitor, target) => D4.validateTarget<$tom_build_13.ActionConfig>(target, 'ActionConfig').postCommands,
      'customTags': (visitor, target) => D4.validateTarget<$tom_build_13.ActionConfig>(target, 'ActionConfig').customTags,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ActionConfig>(target, 'ActionConfig');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ActionConfig({List? preCommands, List commands = const [], List? postCommands, Map<String, dynamic> customTags = const {}})',
      'fromYaml': 'factory ActionConfig.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'preCommands': 'List? get preCommands',
      'commands': 'List get commands',
      'postCommands': 'List? get postCommands',
      'customTags': 'Map<String, dynamic> get customTags',
    },
  );
}

// =============================================================================
// GroupDef Bridge
// =============================================================================

BridgedClass _createGroupDefBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.GroupDef,
    name: 'GroupDef',
    isAssignable: (v) => v is $tom_build_13.GroupDef,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'GroupDef');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final projects = named.containsKey('projects') && named['projects'] != null
            ? D4.coerceList<String>(named['projects'], 'projects')
            : const <String>[];
        final projectInfoOverrides = D4.coerceMapOrNull<String, dynamic>(named['projectInfoOverrides'], 'projectInfoOverrides');
        return $tom_build_13.GroupDef(name: name, description: description, projects: projects, projectInfoOverrides: projectInfoOverrides);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'GroupDef');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'GroupDef');
        if (positional.length <= 1) {
          throw ArgumentError('GroupDef: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.GroupDef.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.GroupDef>(target, 'GroupDef').name,
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.GroupDef>(target, 'GroupDef').description,
      'projects': (visitor, target) => D4.validateTarget<$tom_build_13.GroupDef>(target, 'GroupDef').projects,
      'projectInfoOverrides': (visitor, target) => D4.validateTarget<$tom_build_13.GroupDef>(target, 'GroupDef').projectInfoOverrides,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.GroupDef>(target, 'GroupDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'GroupDef({required String name, String? description, List<String> projects = const [], Map<String, dynamic>? projectInfoOverrides})',
      'fromYaml': 'factory GroupDef.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'description': 'String? get description',
      'projects': 'List<String> get projects',
      'projectInfoOverrides': 'Map<String, dynamic>? get projectInfoOverrides',
    },
  );
}

// =============================================================================
// ProjectTypeDef Bridge
// =============================================================================

BridgedClass _createProjectTypeDefBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ProjectTypeDef,
    name: 'ProjectTypeDef',
    isAssignable: (v) => v is $tom_build_13.ProjectTypeDef,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'ProjectTypeDef');
        final description = D4.getOptionalNamedArg<String?>(named, 'description');
        final metadataFiles = named.containsKey('metadataFiles') && named['metadataFiles'] != null
            ? D4.coerceMap<String, String>(named['metadataFiles'], 'metadataFiles')
            : const <String, String>{};
        final projectInfoOverrides = D4.coerceMapOrNull<String, dynamic>(named['projectInfoOverrides'], 'projectInfoOverrides');
        return $tom_build_13.ProjectTypeDef(name: name, description: description, metadataFiles: metadataFiles, projectInfoOverrides: projectInfoOverrides);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'ProjectTypeDef');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'ProjectTypeDef');
        if (positional.length <= 1) {
          throw ArgumentError('ProjectTypeDef: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.ProjectTypeDef.fromYaml(key, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.ProjectTypeDef>(target, 'ProjectTypeDef').name,
      'description': (visitor, target) => D4.validateTarget<$tom_build_13.ProjectTypeDef>(target, 'ProjectTypeDef').description,
      'metadataFiles': (visitor, target) => D4.validateTarget<$tom_build_13.ProjectTypeDef>(target, 'ProjectTypeDef').metadataFiles,
      'projectInfoOverrides': (visitor, target) => D4.validateTarget<$tom_build_13.ProjectTypeDef>(target, 'ProjectTypeDef').projectInfoOverrides,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ProjectTypeDef>(target, 'ProjectTypeDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ProjectTypeDef({required String name, String? description, Map<String, String> metadataFiles = const {}, Map<String, dynamic>? projectInfoOverrides})',
      'fromYaml': 'factory ProjectTypeDef.fromYaml(String key, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'description': 'String? get description',
      'metadataFiles': 'Map<String, String> get metadataFiles',
      'projectInfoOverrides': 'Map<String, dynamic>? get projectInfoOverrides',
    },
  );
}

// =============================================================================
// Features Bridge
// =============================================================================

BridgedClass _createFeaturesBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.Features,
    name: 'Features',
    isAssignable: (v) => v is $tom_build_13.Features,
    constructors: {
      '': (visitor, positional, named) {
        final flags = named.containsKey('flags') && named['flags'] != null
            ? D4.coerceMap<String, bool>(named['flags'], 'flags')
            : const <String, bool>{};
        return $tom_build_13.Features(flags: flags);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Features');
        if (positional.isEmpty) {
          throw ArgumentError('Features: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.Features.fromYaml(yaml);
      },
    },
    getters: {
      'flags': (visitor, target) => D4.validateTarget<$tom_build_13.Features>(target, 'Features').flags,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.Features>(target, 'Features');
        return t.toYaml();
      },
      '[]': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.Features>(target, 'Features');
        final index = D4.getRequiredArg<String>(positional, 0, 'index', 'operator[]');
        return t[index];
      },
    },
    constructorSignatures: {
      '': 'Features({Map<String, bool> flags = const {}})',
      'fromYaml': 'factory Features.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'flags': 'Map<String, bool> get flags',
    },
  );
}

// =============================================================================
// CrossCompilation Bridge
// =============================================================================

BridgedClass _createCrossCompilationBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.CrossCompilation,
    name: 'CrossCompilation',
    isAssignable: (v) => v is $tom_build_13.CrossCompilation,
    constructors: {
      '': (visitor, positional, named) {
        final allTargets = named.containsKey('allTargets') && named['allTargets'] != null
            ? D4.coerceList<String>(named['allTargets'], 'allTargets')
            : const <String>[];
        final buildOn = named.containsKey('buildOn') && named['buildOn'] != null
            ? D4.coerceMap<String, $tom_build_13.BuildOnTarget>(named['buildOn'], 'buildOn')
            : const <String, $tom_build_13.BuildOnTarget>{};
        return $tom_build_13.CrossCompilation(allTargets: allTargets, buildOn: buildOn);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'CrossCompilation');
        if (positional.isEmpty) {
          throw ArgumentError('CrossCompilation: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.CrossCompilation.fromYaml(yaml);
      },
    },
    getters: {
      'allTargets': (visitor, target) => D4.validateTarget<$tom_build_13.CrossCompilation>(target, 'CrossCompilation').allTargets,
      'buildOn': (visitor, target) => D4.validateTarget<$tom_build_13.CrossCompilation>(target, 'CrossCompilation').buildOn,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.CrossCompilation>(target, 'CrossCompilation');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'CrossCompilation({List<String> allTargets = const [], Map<String, BuildOnTarget> buildOn = const {}})',
      'fromYaml': 'factory CrossCompilation.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'allTargets': 'List<String> get allTargets',
      'buildOn': 'Map<String, BuildOnTarget> get buildOn',
    },
  );
}

// =============================================================================
// BuildOnTarget Bridge
// =============================================================================

BridgedClass _createBuildOnTargetBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.BuildOnTarget,
    name: 'BuildOnTarget',
    isAssignable: (v) => v is $tom_build_13.BuildOnTarget,
    constructors: {
      '': (visitor, positional, named) {
        final targets = named.containsKey('targets') && named['targets'] != null
            ? D4.coerceList<String>(named['targets'], 'targets')
            : const <String>[];
        return $tom_build_13.BuildOnTarget(targets: targets);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'BuildOnTarget');
        if (positional.isEmpty) {
          throw ArgumentError('BuildOnTarget: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.BuildOnTarget.fromYaml(yaml);
      },
    },
    getters: {
      'targets': (visitor, target) => D4.validateTarget<$tom_build_13.BuildOnTarget>(target, 'BuildOnTarget').targets,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.BuildOnTarget>(target, 'BuildOnTarget');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'BuildOnTarget({List<String> targets = const []})',
      'fromYaml': 'factory BuildOnTarget.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'targets': 'List<String> get targets',
    },
  );
}

// =============================================================================
// Pipeline Bridge
// =============================================================================

BridgedClass _createPipelineBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.Pipeline,
    name: 'Pipeline',
    isAssignable: (v) => v is $tom_build_13.Pipeline,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'Pipeline');
        final globalParameters = D4.coerceListOrNull<String>(named['globalParameters'], 'globalParameters');
        final projects = named.containsKey('projects') && named['projects'] != null
            ? D4.coerceList<$tom_build_13.PipelineProject>(named['projects'], 'projects')
            : const <$tom_build_13.PipelineProject>[];
        final actions = named.containsKey('actions') && named['actions'] != null
            ? D4.coerceList<$tom_build_13.PipelineAction>(named['actions'], 'actions')
            : const <$tom_build_13.PipelineAction>[];
        return $tom_build_13.Pipeline(name: name, globalParameters: globalParameters, projects: projects, actions: actions);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Pipeline');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'Pipeline');
        if (positional.length <= 1) {
          throw ArgumentError('Pipeline: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.Pipeline.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.Pipeline>(target, 'Pipeline').name,
      'globalParameters': (visitor, target) => D4.validateTarget<$tom_build_13.Pipeline>(target, 'Pipeline').globalParameters,
      'projects': (visitor, target) => D4.validateTarget<$tom_build_13.Pipeline>(target, 'Pipeline').projects,
      'actions': (visitor, target) => D4.validateTarget<$tom_build_13.Pipeline>(target, 'Pipeline').actions,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.Pipeline>(target, 'Pipeline');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'Pipeline({required String name, List<String>? globalParameters, List<PipelineProject> projects = const [], List<PipelineAction> actions = const []})',
      'fromYaml': 'factory Pipeline.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'globalParameters': 'List<String>? get globalParameters',
      'projects': 'List<PipelineProject> get projects',
      'actions': 'List<PipelineAction> get actions',
    },
  );
}

// =============================================================================
// PipelineProject Bridge
// =============================================================================

BridgedClass _createPipelineProjectBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.PipelineProject,
    name: 'PipelineProject',
    isAssignable: (v) => v is $tom_build_13.PipelineProject,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'PipelineProject');
        return $tom_build_13.PipelineProject(name: name);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'PipelineProject');
        if (positional.isEmpty) {
          throw ArgumentError('PipelineProject: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.PipelineProject.fromYaml(yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.PipelineProject>(target, 'PipelineProject').name,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.PipelineProject>(target, 'PipelineProject');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'PipelineProject({required String name})',
      'fromYaml': 'factory PipelineProject.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
    },
  );
}

// =============================================================================
// PipelineAction Bridge
// =============================================================================

BridgedClass _createPipelineActionBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.PipelineAction,
    name: 'PipelineAction',
    isAssignable: (v) => v is $tom_build_13.PipelineAction,
    constructors: {
      '': (visitor, positional, named) {
        final action = D4.getRequiredNamedArg<String>(named, 'action', 'PipelineAction');
        return $tom_build_13.PipelineAction(action: action);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'PipelineAction');
        if (positional.isEmpty) {
          throw ArgumentError('PipelineAction: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.PipelineAction.fromYaml(yaml);
      },
    },
    getters: {
      'action': (visitor, target) => D4.validateTarget<$tom_build_13.PipelineAction>(target, 'PipelineAction').action,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.PipelineAction>(target, 'PipelineAction');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'PipelineAction({required String action})',
      'fromYaml': 'factory PipelineAction.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'action': 'String get action',
    },
  );
}

// =============================================================================
// ProjectEntry Bridge
// =============================================================================

BridgedClass _createProjectEntryBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ProjectEntry,
    name: 'ProjectEntry',
    isAssignable: (v) => v is $tom_build_13.ProjectEntry,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'ProjectEntry');
        final settings = named.containsKey('settings') && named['settings'] != null
            ? D4.coerceMap<String, dynamic>(named['settings'], 'settings')
            : const <String, dynamic>{};
        return $tom_build_13.ProjectEntry(name: name, settings: settings);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'ProjectEntry');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'ProjectEntry');
        if (positional.length <= 1) {
          throw ArgumentError('ProjectEntry: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.ProjectEntry.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.ProjectEntry>(target, 'ProjectEntry').name,
      'settings': (visitor, target) => D4.validateTarget<$tom_build_13.ProjectEntry>(target, 'ProjectEntry').settings,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ProjectEntry>(target, 'ProjectEntry');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ProjectEntry({required String name, Map<String, dynamic> settings = const {}})',
      'fromYaml': 'factory ProjectEntry.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'settings': 'Map<String, dynamic> get settings',
    },
  );
}

// =============================================================================
// VersionSettings Bridge
// =============================================================================

BridgedClass _createVersionSettingsBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.VersionSettings,
    name: 'VersionSettings',
    isAssignable: (v) => v is $tom_build_13.VersionSettings,
    constructors: {
      '': (visitor, positional, named) {
        final prereleaseTag = D4.getOptionalNamedArg<String?>(named, 'prereleaseTag');
        final autoIncrement = D4.getOptionalNamedArg<bool?>(named, 'autoIncrement');
        final minDevBuild = D4.getOptionalNamedArg<int?>(named, 'minDevBuild');
        final actionCounter = D4.getOptionalNamedArg<int?>(named, 'actionCounter');
        return $tom_build_13.VersionSettings(prereleaseTag: prereleaseTag, autoIncrement: autoIncrement, minDevBuild: minDevBuild, actionCounter: actionCounter);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'VersionSettings');
        if (positional.isEmpty) {
          throw ArgumentError('VersionSettings: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.VersionSettings.fromYaml(yaml);
      },
    },
    getters: {
      'prereleaseTag': (visitor, target) => D4.validateTarget<$tom_build_13.VersionSettings>(target, 'VersionSettings').prereleaseTag,
      'autoIncrement': (visitor, target) => D4.validateTarget<$tom_build_13.VersionSettings>(target, 'VersionSettings').autoIncrement,
      'minDevBuild': (visitor, target) => D4.validateTarget<$tom_build_13.VersionSettings>(target, 'VersionSettings').minDevBuild,
      'actionCounter': (visitor, target) => D4.validateTarget<$tom_build_13.VersionSettings>(target, 'VersionSettings').actionCounter,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.VersionSettings>(target, 'VersionSettings');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'VersionSettings({String? prereleaseTag, bool? autoIncrement, int? minDevBuild, int? actionCounter})',
      'fromYaml': 'factory VersionSettings.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'prereleaseTag': 'String? get prereleaseTag',
      'autoIncrement': 'bool? get autoIncrement',
      'minDevBuild': 'int? get minDevBuild',
      'actionCounter': 'int? get actionCounter',
    },
  );
}

// =============================================================================
// PackageModule Bridge
// =============================================================================

BridgedClass _createPackageModuleBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.PackageModule,
    name: 'PackageModule',
    isAssignable: (v) => v is $tom_build_13.PackageModule,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'PackageModule');
        final libraryFile = D4.getOptionalNamedArg<String?>(named, 'libraryFile');
        final sourceFolders = D4.coerceListOrNull<String>(named['sourceFolders'], 'sourceFolders');
        return $tom_build_13.PackageModule(name: name, libraryFile: libraryFile, sourceFolders: sourceFolders);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'PackageModule');
        if (positional.isEmpty) {
          throw ArgumentError('PackageModule: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.PackageModule.fromYaml(yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.PackageModule>(target, 'PackageModule').name,
      'libraryFile': (visitor, target) => D4.validateTarget<$tom_build_13.PackageModule>(target, 'PackageModule').libraryFile,
      'sourceFolders': (visitor, target) => D4.validateTarget<$tom_build_13.PackageModule>(target, 'PackageModule').sourceFolders,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.PackageModule>(target, 'PackageModule');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'PackageModule({required String name, String? libraryFile, List<String>? sourceFolders})',
      'fromYaml': 'factory PackageModule.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'libraryFile': 'String? get libraryFile',
      'sourceFolders': 'List<String>? get sourceFolders',
    },
  );
}

// =============================================================================
// Part Bridge
// =============================================================================

BridgedClass _createPartBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.Part,
    name: 'Part',
    isAssignable: (v) => v is $tom_build_13.Part,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'Part');
        final libraryFile = D4.getOptionalNamedArg<String?>(named, 'libraryFile');
        final modules = named.containsKey('modules') && named['modules'] != null
            ? D4.coerceMap<String, $tom_build_13.Module>(named['modules'], 'modules')
            : const <String, $tom_build_13.Module>{};
        return $tom_build_13.Part(name: name, libraryFile: libraryFile, modules: modules);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Part');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'Part');
        if (positional.length <= 1) {
          throw ArgumentError('Part: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.Part.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.Part>(target, 'Part').name,
      'libraryFile': (visitor, target) => D4.validateTarget<$tom_build_13.Part>(target, 'Part').libraryFile,
      'modules': (visitor, target) => D4.validateTarget<$tom_build_13.Part>(target, 'Part').modules,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.Part>(target, 'Part');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'Part({required String name, String? libraryFile, Map<String, Module> modules = const {}})',
      'fromYaml': 'factory Part.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'libraryFile': 'String? get libraryFile',
      'modules': 'Map<String, Module> get modules',
    },
  );
}

// =============================================================================
// Module Bridge
// =============================================================================

BridgedClass _createModuleBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.Module,
    name: 'Module',
    isAssignable: (v) => v is $tom_build_13.Module,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'Module');
        final libraryFile = D4.getOptionalNamedArg<String?>(named, 'libraryFile');
        return $tom_build_13.Module(name: name, libraryFile: libraryFile);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Module');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'Module');
        if (positional.length <= 1) {
          throw ArgumentError('Module: Missing required argument "yaml" at position 1');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[1], 'yaml');
        return $tom_build_13.Module.fromYaml(name, yaml);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_build_13.Module>(target, 'Module').name,
      'libraryFile': (visitor, target) => D4.validateTarget<$tom_build_13.Module>(target, 'Module').libraryFile,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.Module>(target, 'Module');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'Module({required String name, String? libraryFile})',
      'fromYaml': 'factory Module.fromYaml(String name, Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'name': 'String get name',
      'libraryFile': 'String? get libraryFile',
    },
  );
}

// =============================================================================
// ExecutableDef Bridge
// =============================================================================

BridgedClass _createExecutableDefBridge() {
  return BridgedClass(
    nativeType: $tom_build_13.ExecutableDef,
    name: 'ExecutableDef',
    isAssignable: (v) => v is $tom_build_13.ExecutableDef,
    constructors: {
      '': (visitor, positional, named) {
        final source = D4.getRequiredNamedArg<String>(named, 'source', 'ExecutableDef');
        final output = D4.getRequiredNamedArg<String>(named, 'output', 'ExecutableDef');
        return $tom_build_13.ExecutableDef(source: source, output: output);
      },
      'fromYaml': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ExecutableDef');
        if (positional.isEmpty) {
          throw ArgumentError('ExecutableDef: Missing required argument "yaml" at position 0');
        }
        final yaml = D4.coerceMap<String, dynamic>(positional[0], 'yaml');
        return $tom_build_13.ExecutableDef.fromYaml(yaml);
      },
    },
    getters: {
      'source': (visitor, target) => D4.validateTarget<$tom_build_13.ExecutableDef>(target, 'ExecutableDef').source,
      'output': (visitor, target) => D4.validateTarget<$tom_build_13.ExecutableDef>(target, 'ExecutableDef').output,
    },
    methods: {
      'toYaml': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_13.ExecutableDef>(target, 'ExecutableDef');
        return t.toYaml();
      },
    },
    constructorSignatures: {
      '': 'ExecutableDef({required String source, required String output})',
      'fromYaml': 'factory ExecutableDef.fromYaml(Map<String, dynamic> yaml)',
    },
    methodSignatures: {
      'toYaml': 'Map<String, dynamic> toYaml()',
    },
    getterSignatures: {
      'source': 'String get source',
      'output': 'String get output',
    },
  );
}

// =============================================================================
// WorkspaceParser Bridge
// =============================================================================

BridgedClass _createWorkspaceParserBridge() {
  return BridgedClass(
    nativeType: $tom_build_14.WorkspaceParser,
    name: 'WorkspaceParser',
    isAssignable: (v) => v is $tom_build_14.WorkspaceParser,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'WorkspaceParser');
        final workspacePath = D4.getRequiredArg<String>(positional, 0, 'workspacePath', 'WorkspaceParser');
        return $tom_build_14.WorkspaceParser(workspacePath);
      },
    },
    getters: {
      'workspacePath': (visitor, target) => D4.validateTarget<$tom_build_14.WorkspaceParser>(target, 'WorkspaceParser').workspacePath,
    },
    methods: {
      'parse': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_14.WorkspaceParser>(target, 'WorkspaceParser');
        return t.parse();
      },
    },
    constructorSignatures: {
      '': 'WorkspaceParser(String workspacePath)',
    },
    methodSignatures: {
      'parse': 'TomMaster parse()',
    },
    getterSignatures: {
      'workspacePath': 'String get workspacePath',
    },
  );
}

// =============================================================================
// TomContext Bridge
// =============================================================================

BridgedClass _createTomContextBridge() {
  return BridgedClass(
    nativeType: $tom_build_15.TomContext,
    name: 'TomContext',
    isAssignable: (v) => v is $tom_build_15.TomContext,
    constructors: {
      '': (visitor, positional, named) {
        final workspace = D4.getRequiredNamedArg<$tom_build_13.TomWorkspace>(named, 'workspace', 'TomContext');
        final workspaceContext = D4.getOptionalNamedArg<Object?>(named, 'workspaceContext');
        final currentProject = D4.getOptionalNamedArg<$tom_build_13.TomProject?>(named, 'currentProject');
        final workspacePath = D4.getOptionalNamedArg<String?>(named, 'workspacePath');
        return $tom_build_15.TomContext(workspace: workspace, workspaceContext: workspaceContext, currentProject: currentProject, workspacePath: workspacePath);
      },
    },
    getters: {
      'isInitialized': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').isInitialized,
      'workspace': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').workspace,
      'workspaceContext': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').workspaceContext,
      'workspacePath': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').workspacePath,
      'cwd': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').cwd,
      'project': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').project,
      'projectInfo': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').projectInfo,
      'groups': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').groups,
      'actions': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').actions,
      'modeDefinitions': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').modeDefinitions,
      'deps': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').deps,
      'depsDev': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').depsDev,
      'workspaceModes': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').workspaceModes,
      'projectTypes': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').projectTypes,
      'pipelines': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').pipelines,
      'customTags': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').customTags,
      'env': (visitor, target) => D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext').env,
    },
    methods: {
      'getProjectInfo': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext');
        D4.requireMinArgs(positional, 1, 'getProjectInfo');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getProjectInfo');
        return t.getProjectInfo(name);
      },
      'getGroup': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext');
        D4.requireMinArgs(positional, 1, 'getGroup');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getGroup');
        return t.getGroup(name);
      },
      'getAction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext');
        D4.requireMinArgs(positional, 1, 'getAction');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getAction');
        return t.getAction(name);
      },
      'getDep': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext');
        D4.requireMinArgs(positional, 1, 'getDep');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getDep');
        return t.getDep(name);
      },
      'getCustomTag': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext');
        D4.requireMinArgs(positional, 1, 'getCustomTag');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'getCustomTag');
        return t.getCustomTag(key);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_build_15.TomContext>(target, 'TomContext');
        return t.toString();
      },
    },
    staticGetters: {
      'current': (visitor) => $tom_build_15.TomContext.current,
    },
    constructorSignatures: {
      '': 'TomContext({required TomWorkspace workspace, Object? workspaceContext, TomProject? currentProject, String? workspacePath})',
    },
    methodSignatures: {
      'getProjectInfo': 'ProjectEntry? getProjectInfo(String name)',
      'getGroup': 'GroupDef? getGroup(String name)',
      'getAction': 'ActionDef? getAction(String name)',
      'getDep': 'String? getDep(String name)',
      'getCustomTag': 'dynamic getCustomTag(String key)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'isInitialized': 'bool get isInitialized',
      'workspace': 'TomWorkspace get workspace',
      'workspaceContext': 'Object? get workspaceContext',
      'workspacePath': 'String get workspacePath',
      'cwd': 'String get cwd',
      'project': 'TomProject? get project',
      'projectInfo': 'Map<String, ProjectEntry> get projectInfo',
      'groups': 'Map<String, GroupDef> get groups',
      'actions': 'Map<String, ActionDef> get actions',
      'modeDefinitions': 'Map<String, ModeDefinitions> get modeDefinitions',
      'deps': 'Map<String, String> get deps',
      'depsDev': 'Map<String, String> get depsDev',
      'workspaceModes': 'WorkspaceModes? get workspaceModes',
      'projectTypes': 'Map<String, ProjectTypeDef> get projectTypes',
      'pipelines': 'Map<String, Pipeline> get pipelines',
      'customTags': 'Map<String, dynamic> get customTags',
      'env': 'Map<String, String> get env',
    },
    staticGetterSignatures: {
      'current': 'TomContext get current',
    },
  );
}

