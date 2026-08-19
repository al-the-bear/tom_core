// D4rt Bridge - Generated file, do not edit
// Source: /Users/alexiskyaw/Desktop/Code/al_the_bear/inhouse/second_wind/enterprise_flutter/tom_agent_container/tom_ai/core/tom_core_d4rt/lib/src/demo_persistence/demo_persistence.dart
// Generated: 2026-08-19T12:06:38.157736

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls, invalid_use_of_protected_member, unnecessary_non_null_assertion, invalid_use_of_visible_for_testing_member, unnecessary_cast, unused_local_variable, no_leading_underscores_for_local_identifiers, prefer_is_empty, unnecessary_question_mark, unreachable_switch_case, unintended_html_in_doc_comment, empty_constructor_bodies, prefer_const_constructors_in_immutables, prefer_final_fields, unused_field, must_call_super, no_logic_in_create_state, use_key_in_widget_constructors, annotate_overrides, non_const_argument_for_const_parameter, unnecessary_import

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';

import 'package:tom_core_d4rt/src/demo_persistence/demo_persistence.dart' as $tom_core_d4rt_1;
import 'package:tom_core_server/src/tomserver/datasources/datasource_initialization.dart' as $tom_core_server_1;
import 'package:tom_core_server/src/tomserver/datasources/queries.dart' as $tom_core_server_2;
import 'package:tom_core_server/src/tomserver/datasources/sql_dialects.dart' as $tom_core_server_3;
import 'package:tom_core_server/src/tomserver/datasources/types_operator.dart' as $tom_core_server_4;
import 'package:tom_core_server/src/tomserver/file_storage/blob_store.dart' as $tom_core_server_5;
import 'package:tom_core_server/src/tomserver/object_persistence/grouped_query.dart' as $tom_core_server_6;
import 'package:tom_core_server/src/tomserver/object_persistence/paging.dart' as $tom_core_server_7;
import 'package:tom_core_server/src/tomserver/object_persistence/persistence_annotations.dart' as $tom_core_server_8;
import 'package:tom_core_server/src/tomserver/object_persistence/crud_repository.dart' as $aux_tom_core_server;

/// Bridge class for demo_persistence module.
class DemoPersistenceBridge {
  /// Returns all bridge class definitions.
  ///
  /// Eager — building every class. Prefer [bridgeClassThunks] +
  /// [bridgeClassTypes] for lazy registration (Step #17); this remains
  /// for diagnostics and callers that need the full list.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createD4rtDemoTaskRecordBridge(),
      _createD4rtDemoTaskRepositoryBridge(),
      _createD4rtDemoApiServiceBridge(),
      _createD4rtDemoApiServerBridge(),
    ];
  }

  /// Returns deferred factory thunks keyed by class name.
  ///
  /// Each thunk builds one class's [BridgedClass] on demand. Plugs into
  /// the interpreter's lazy registry via [registerBridges] (Step #17).
  static Map<String, BridgedClass Function()> bridgeClassThunks() {
    return {
      'D4rtDemoTaskRecord': _createD4rtDemoTaskRecordBridge,
      'D4rtDemoTaskRepository': _createD4rtDemoTaskRepositoryBridge,
      'D4rtDemoApiService': _createD4rtDemoApiServiceBridge,
      'D4rtDemoApiServer': _createD4rtDemoApiServerBridge,
    };
  }

  /// Returns native [Type]s keyed by class name, parallel to
  /// [bridgeClassThunks] (Step #17). Used to register the native-type
  /// lookup thunk without building the BridgedClass.
  static Map<String, Type> bridgeClassTypes() {
    return {
      'D4rtDemoTaskRecord': $tom_core_d4rt_1.D4rtDemoTaskRecord,
      'D4rtDemoTaskRepository': $tom_core_d4rt_1.D4rtDemoTaskRepository,
      'D4rtDemoApiService': $tom_core_d4rt_1.D4rtDemoApiService,
      'D4rtDemoApiServer': $tom_core_d4rt_1.D4rtDemoApiServer,
    };
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'D4rtDemoTaskRecord': 'package:tom_core_d4rt/src/demo_persistence/demo_persistence.dart',
      'D4rtDemoTaskRepository': 'package:tom_core_d4rt/src/demo_persistence/demo_persistence.dart',
      'D4rtDemoApiService': 'package:tom_core_d4rt/src/demo_persistence/demo_persistence.dart',
      'D4rtDemoApiServer': 'package:tom_core_d4rt/src/demo_persistence/demo_persistence.dart',
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
      'D4rtDemoTaskRepository': ['TomSqlDatasourceRepository', 'TomRepository', 'TomFileRepository', 'TomQueryBuilder'],
      'D4rtDemoApiServer': ['D4rtDemoApiService'],
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
      'package:tom_core_d4rt/src/demo_persistence/demo_persistence.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    return "import 'package:tom_core_d4rt/src/demo_persistence/demo_persistence.dart';";
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
// D4rtDemoTaskRecord Bridge
// =============================================================================

BridgedClass _createD4rtDemoTaskRecordBridge() {
  return BridgedClass(
    nativeType: $tom_core_d4rt_1.D4rtDemoTaskRecord,
    name: 'D4rtDemoTaskRecord',
    isAssignable: (v) => v is $tom_core_d4rt_1.D4rtDemoTaskRecord,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_d4rt_1.D4rtDemoTaskRecord();
      },
    },
    getters: {
      'id': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').id,
      'title': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').title,
      'priority': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').priority,
      'done': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').done,
    },
    setters: {
      'id': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').id = D4.extractBridgedArgOrNull<int>(value, 'id'),
      'title': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').title = D4.extractBridgedArgOrNull<String>(value, 'title'),
      'priority': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').priority = D4.extractBridgedArgOrNull<int>(value, 'priority'),
      'done': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRecord>(target, 'D4rtDemoTaskRecord').done = D4.extractBridgedArgOrNull<bool>(value, 'done'),
    },
    constructorSignatures: {
      '': 'D4rtDemoTaskRecord()',
    },
    getterSignatures: {
      'id': 'int? get id',
      'title': 'String? get title',
      'priority': 'int? get priority',
      'done': 'bool? get done',
    },
    setterSignatures: {
      'id': 'set id(dynamic value)',
      'title': 'set title(dynamic value)',
      'priority': 'set priority(dynamic value)',
      'done': 'set done(dynamic value)',
    },
  );
}

// =============================================================================
// D4rtDemoTaskRepository Bridge
// =============================================================================

BridgedClass _createD4rtDemoTaskRepositoryBridge() {
  return BridgedClass(
    nativeType: $tom_core_d4rt_1.D4rtDemoTaskRepository,
    name: 'D4rtDemoTaskRepository',
    isAssignable: (v) => v is $tom_core_d4rt_1.D4rtDemoTaskRepository,
    hierarchyDepth: 4,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_d4rt_1.D4rtDemoTaskRepository();
      },
    },
    getters: {
      'primaryKeyColumnInfo': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').primaryKeyColumnInfo,
      'datasourceInfo': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').datasourceInfo,
      'persistenceInfo': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').persistenceInfo,
      'dbTable': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').dbTable,
      'sqlDialect': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').sqlDialect,
      'queryTypes': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').queryTypes,
      'resultType': (visitor, target) => D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').resultType,
    },
    setters: {
      'primaryKeyColumnInfo': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').primaryKeyColumnInfo = D4.extractBridgedArg<$tom_core_server_8.TomColumnInformation>(value, 'primaryKeyColumnInfo'),
      'datasourceInfo': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').datasourceInfo = D4.extractBridgedArg<$tom_core_server_1.TomDataSourceInfo>(value, 'datasourceInfo'),
      'persistenceInfo': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').persistenceInfo = D4.extractBridgedArg<$tom_core_server_2.TomTypePersistenceInfo>(value, 'persistenceInfo'),
      'dbTable': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').dbTable = D4.extractBridgedArg<$tom_core_server_8.TomDbTable>(value, 'dbTable'),
      'queryTypes': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').queryTypes = D4.coerceList<Type>(value, 'queryTypes'),
      'resultType': (visitor, target, value) => 
        D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository').resultType = D4.extractBridgedArg<Type>(value, 'resultType'),
    },
    methods: {
      'saveFile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 3, 'saveFile');
        final entity = D4.getRequiredArg<$tom_core_d4rt_1.D4rtDemoTaskRecord>(positional, 0, 'entity', 'saveFile');
        final fieldName = D4.getRequiredArg<String>(positional, 1, 'fieldName', 'saveFile');
        final bytes = D4.getRequiredArg<Stream<List<int>>>(positional, 2, 'bytes', 'saveFile');
        final mediaType = D4.getOptionalNamedArg<String?>(named, 'mediaType');
        final fileName = D4.getOptionalNamedArg<String?>(named, 'fileName');
        return t.saveFile(entity, fieldName, bytes, mediaType: mediaType, fileName: fileName);
      },
      'openFile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'openFile');
        final id = D4.getRequiredArg<int>(positional, 0, 'id', 'openFile');
        final fieldName = D4.getRequiredArg<String>(positional, 1, 'fieldName', 'openFile');
        return t.openFile(id, fieldName);
      },
      'describeFile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'describeFile');
        final id = D4.getRequiredArg<int>(positional, 0, 'id', 'describeFile');
        final fieldName = D4.getRequiredArg<String>(positional, 1, 'fieldName', 'describeFile');
        return t.describeFile(id, fieldName);
      },
      'clearFile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'clearFile');
        final entity = D4.getRequiredArg<$tom_core_d4rt_1.D4rtDemoTaskRecord>(positional, 0, 'entity', 'clearFile');
        final fieldName = D4.getRequiredArg<String>(positional, 1, 'fieldName', 'clearFile');
        return t.clearFile(entity, fieldName);
      },
      'delete': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'delete');
        final entity = D4.getRequiredArg<$tom_core_d4rt_1.D4rtDemoTaskRecord>(positional, 0, 'entity', 'delete');
        return t.delete(entity);
      },
      'deleteAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'deleteAllById');
        if (positional.isEmpty) {
          throw ArgumentError('deleteAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<int>(positional[0], 'ids');
        return t.deleteAllById(ids);
      },
      'deleteById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'deleteById');
        final id = D4.getRequiredArg<int>(positional, 0, 'id', 'deleteById');
        return t.deleteById(id);
      },
      'existsById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'existsById');
        if (positional.isEmpty) {
          throw ArgumentError('existsById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<int>(positional[0], 'ids');
        return t.existsById(ids);
      },
      'findAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        final page = D4.getOptionalArg<$tom_core_server_7.TomPageRequest?>(positional, 0, 'page');
        return t.findAll(page);
      },
      'findAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'findAllById');
        if (positional.isEmpty) {
          throw ArgumentError('findAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<int>(positional[0], 'ids');
        final page = D4.getOptionalArg<$tom_core_server_7.TomPageRequest?>(positional, 1, 'page');
        return t.findAllById(ids, page);
      },
      'findById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'findById');
        final id = D4.getRequiredArg<int>(positional, 0, 'id', 'findById');
        return t.findById(id);
      },
      'count': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        return t.count();
      },
      'save': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'save');
        final toSave = D4.getRequiredArg<$tom_core_d4rt_1.D4rtDemoTaskRecord>(positional, 0, 'toSave', 'save');
        return t.save(toSave);
      },
      'saveAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'saveAll');
        if (positional.isEmpty) {
          throw ArgumentError('saveAll: Missing required argument "entities" at position 0');
        }
        final entities = D4.coerceList<$tom_core_d4rt_1.D4rtDemoTaskRecord>(positional[0], 'entities');
        return t.saveAll(entities);
      },
      'findByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'findByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'findByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        final resultType = D4.getOptionalArg<Type?>(positional, 2, 'resultType');
        final page = D4.getOptionalArg<$tom_core_server_7.TomPageRequest?>(positional, 3, 'page');
        return t.findByQuerySentence(querySentence, params, resultType, page);
      },
      'deleteByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'deleteByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuerySentence(querySentence, params);
      },
      'countByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'countByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'countByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuerySentence(querySentence, params);
      },
      'findByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'findByQuery');
        final query = D4.getRequiredArg<$tom_core_server_2.TomSelect>(positional, 0, 'query', 'findByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        final page = D4.getOptionalArg<$tom_core_server_7.TomPageRequest?>(positional, 2, 'page');
        return t.findByQuery(query, params, page);
      },
      'deleteByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuery');
        final query = D4.getRequiredArg<$tom_core_server_2.TomDelete>(positional, 0, 'query', 'deleteByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuery(query, params);
      },
      'countByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'countByQuery');
        final query = D4.getRequiredArg<$tom_core_server_2.TomCount>(positional, 0, 'query', 'countByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuery(query, params);
      },
      'findGroupedByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'findGroupedByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomGroupedSelect>(positional, 0, 'query', 'findGroupedByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('findGroupedByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.findGroupedByQuery(query, params);
      },
      'executeQueryString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'executeQueryString');
        final dbQuery = D4.getRequiredArg<String>(positional, 0, 'dbQuery', 'executeQueryString');
        if (positional.length <= 1) {
          throw ArgumentError('executeQueryString: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.executeQueryString(dbQuery, params);
      },
      'isNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'isNull');
        final what = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'what', 'isNull');
        return t.isNull(what);
      },
      'isNotNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'isNotNull');
        final what = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'what', 'isNotNull');
        return t.isNotNull(what);
      },
      'isIn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'isIn');
        final what = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'what', 'isIn');
        if (positional.length <= 1) {
          throw ArgumentError('isIn: Missing required argument "choices" at position 1');
        }
        final choices = D4.coerceList<$tom_core_server_4.TomOperator<dynamic>>(positional[1], 'choices');
        return t.isIn(what, choices);
      },
      'between': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'between');
        final what = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'what', 'between');
        if (positional.length <= 1) {
          throw ArgumentError('between: Missing required argument "betweenLimits" at position 1');
        }
        final betweenLimits = D4.coerceList<$tom_core_server_4.TomOperator<dynamic>>(positional[1], 'betweenLimits');
        return t.between(what, betweenLimits);
      },
      'like': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'like');
        final text = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 0, 'text', 'like');
        final test = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 1, 'test', 'like');
        return t.like(text, test);
      },
      'notLike': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'notLike');
        final text = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 0, 'text', 'notLike');
        final test = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 1, 'test', 'notLike');
        return t.notLike(text, test);
      },
      'regexp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'regexp');
        final text = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 0, 'text', 'regexp');
        final test = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 1, 'test', 'regexp');
        return t.regexp(text, test);
      },
      'group': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'group');
        final operant = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'operant', 'group');
        return t.group(operant);
      },
      'eq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'operant1', 'eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 1, 'operant2', 'eq');
        return t.eq(operant1, operant2);
      },
      'neq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'operant1', 'neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 1, 'operant2', 'neq');
        return t.neq(operant1, operant2);
      },
      'lt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'operant1', 'lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 1, 'operant2', 'lt');
        return t.lt(operant1, operant2);
      },
      'lte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'operant1', 'lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 1, 'operant2', 'lte');
        return t.lte(operant1, operant2);
      },
      'gt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'operant1', 'gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 1, 'operant2', 'gt');
        return t.gt(operant1, operant2);
      },
      'gte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'operant1', 'gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 1, 'operant2', 'gte');
        return t.gte(operant1, operant2);
      },
      'not': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'not');
        final operant1 = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbBool>>(positional, 0, 'operant1', 'not');
        return t.not(operant1);
      },
      'and': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'and');
        if (positional.isEmpty) {
          throw ArgumentError('and: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbBool>>(positional[0], 'operant1');
        return t.and(operant1);
      },
      'or': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'or');
        if (positional.isEmpty) {
          throw ArgumentError('or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbBool>>(positional[0], 'operant1');
        return t.or(operant1);
      },
      'text': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'text');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'text');
        return t.text(text);
      },
      'intOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'intOp');
        final value = D4.getRequiredArg<int>(positional, 0, 'value', 'intOp');
        return t.intOp(value);
      },
      'doubleOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'doubleOp');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'doubleOp');
        return t.doubleOp(value);
      },
      'boolOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'boolOp');
        final value = D4.getRequiredArg<bool>(positional, 0, 'value', 'boolOp');
        return t.boolOp(value);
      },
      'dateTimeOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'dateTimeOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateTimeOp');
        return t.dateTimeOp(value);
      },
      'dateOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'dateOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateOp');
        return t.dateOp(value);
      },
      'p': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'p');
        final parameterName = D4.getRequiredArg<String>(positional, 0, 'parameterName', 'p');
        return t.p(parameterName);
      },
      'textF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'textF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'textF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_8.TomColumnInformation>(positional, 1, 'columnInformation', 'textF');
        return t.textF(fieldName, columnInformation);
      },
      'intF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'intF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'intF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_8.TomColumnInformation>(positional, 1, 'columnInformation', 'intF');
        return t.intF(fieldName, columnInformation);
      },
      'doubleF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'doubleF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'doubleF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_8.TomColumnInformation>(positional, 1, 'columnInformation', 'doubleF');
        return t.doubleF(fieldName, columnInformation);
      },
      'boolF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'boolF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'boolF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_8.TomColumnInformation>(positional, 1, 'columnInformation', 'boolF');
        return t.boolF(fieldName, columnInformation);
      },
      'dateTimeF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'dateTimeF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateTimeF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_8.TomColumnInformation>(positional, 1, 'columnInformation', 'dateTimeF');
        return t.dateTimeF(fieldName, columnInformation);
      },
      'dateF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'dateF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_8.TomColumnInformation>(positional, 1, 'columnInformation', 'dateF');
        return t.dateF(fieldName, columnInformation);
      },
      'countAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 1, 'countAll');
        final alias = D4.getRequiredArg<String>(positional, 0, 'alias', 'countAll');
        return t.countAll(alias);
      },
      'countOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'countOf');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'value', 'countOf');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'countOf');
        final distinct = D4.getNamedArgWithDefault<bool>(named, 'distinct', false);
        return t.countOf(value, alias, distinct: distinct);
      },
      'sum': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'sum');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'value', 'sum');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'sum');
        final distinct = D4.getNamedArgWithDefault<bool>(named, 'distinct', false);
        return t.sum(value, alias, distinct: distinct);
      },
      'avg': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'avg');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<dynamic>>(positional, 0, 'value', 'avg');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'avg');
        final distinct = D4.getNamedArgWithDefault<bool>(named, 'distinct', false);
        return t.avg(value, alias, distinct: distinct);
      },
      'minInt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'minInt');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbInt>>(positional, 0, 'value', 'minInt');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'minInt');
        return t.minInt(value, alias);
      },
      'maxInt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'maxInt');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbInt>>(positional, 0, 'value', 'maxInt');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'maxInt');
        return t.maxInt(value, alias);
      },
      'minDouble': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'minDouble');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbDouble>>(positional, 0, 'value', 'minDouble');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'minDouble');
        return t.minDouble(value, alias);
      },
      'maxDouble': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'maxDouble');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbDouble>>(positional, 0, 'value', 'maxDouble');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'maxDouble');
        return t.maxDouble(value, alias);
      },
      'minText': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'minText');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 0, 'value', 'minText');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'minText');
        return t.minText(value, alias);
      },
      'maxText': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'maxText');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbString>>(positional, 0, 'value', 'maxText');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'maxText');
        return t.maxText(value, alias);
      },
      'minDateTime': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'minDateTime');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbDateTime>>(positional, 0, 'value', 'minDateTime');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'minDateTime');
        return t.minDateTime(value, alias);
      },
      'maxDateTime': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoTaskRepository>(target, 'D4rtDemoTaskRepository');
        D4.requireMinArgs(positional, 2, 'maxDateTime');
        final value = D4.getRequiredArg<$tom_core_server_4.TomOperator<$tom_core_server_4.TomDbDateTime>>(positional, 0, 'value', 'maxDateTime');
        final alias = D4.getRequiredArg<String>(positional, 1, 'alias', 'maxDateTime');
        return t.maxDateTime(value, alias);
      },
    },
    constructorSignatures: {
      '': 'D4rtDemoTaskRepository()',
    },
    methodSignatures: {
      'saveFile': 'Future<D4rtDemoTaskRecord> saveFile(D4rtDemoTaskRecord entity, String fieldName, Stream<List<int>> bytes, {String? mediaType, String? fileName})',
      'openFile': 'Stream<List<int>> openFile(int id, String fieldName)',
      'describeFile': 'Future<TomStoredBlob?> describeFile(int id, String fieldName)',
      'clearFile': 'Future<D4rtDemoTaskRecord> clearFile(D4rtDemoTaskRecord entity, String fieldName)',
      'delete': 'Future<void> delete(D4rtDemoTaskRecord entity)',
      'deleteAllById': 'Future<void> deleteAllById(Iterable<int> ids)',
      'deleteById': 'Future<int> deleteById(int id)',
      'existsById': 'Future<bool> existsById(Iterable<int> ids)',
      'findAll': 'Future<List<D4rtDemoTaskRecord>> findAll([TomPageRequest? page])',
      'findAllById': 'Future<List<D4rtDemoTaskRecord>> findAllById(Iterable<int> ids, [TomPageRequest? page])',
      'findById': 'Future<D4rtDemoTaskRecord?> findById(int id)',
      'count': 'Future<TomDbInt> count()',
      'save': 'Future<D4rtDemoTaskRecord> save(D4rtDemoTaskRecord toSave)',
      'saveAll': 'Future<Iterable<D4rtDemoTaskRecord>> saveAll(Iterable<D4rtDemoTaskRecord> entities)',
      'findByQuerySentence': 'Future<Iterable<D4rtDemoTaskRecord>> findByQuerySentence(String querySentence, Map<String, Object?> params, [Type? resultType, TomPageRequest? page])',
      'deleteByQuerySentence': 'Future<int> deleteByQuerySentence(String querySentence, Map<String, Object?> params)',
      'countByQuerySentence': 'Future<TomDbInt> countByQuerySentence(String querySentence, Map<String, Object?> params)',
      'findByQuery': 'Future<Iterable<D4rtDemoTaskRecord>> findByQuery(TomSelect query, Map<String, Object?> params, [TomPageRequest? page])',
      'deleteByQuery': 'Future<int> deleteByQuery(TomDelete query, Map<String, Object?> params)',
      'countByQuery': 'Future<TomDbInt> countByQuery(TomCount query, Map<String, Object?> params)',
      'findGroupedByQuery': 'Future<List<TomGroupedRow>> findGroupedByQuery(TomGroupedSelect query, Map<String, Object?> params)',
      'executeQueryString': 'Future<Iterable<D4rtDemoTaskRecord>> executeQueryString(String dbQuery, Map<String, Object?> params)',
      'isNull': 'TomOperator<TomDbBool> isNull(TomOperator<T> what)',
      'isNotNull': 'TomOperator<TomDbBool> isNotNull(TomOperator<T> what)',
      'isIn': 'TomOperator<TomDbBool> isIn(TomOperator<T> what, List<TomOperator<T>> choices)',
      'between': 'TomOperator<TomDbBool> between(TomOperator<T> what, List<TomOperator<T>> betweenLimits)',
      'like': 'TomOperator<TomDbBool> like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'notLike': 'TomOperator<TomDbBool> notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'regexp': 'TomOperator<TomDbBool> regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'group': 'TomOperator<T> group(TomOperator<T> operant)',
      'eq': 'TomOperator<TomDbBool> eq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'neq': 'TomOperator<TomDbBool> neq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lt': 'TomOperator<TomDbBool> lt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lte': 'TomOperator<TomDbBool> lte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gt': 'TomOperator<TomDbBool> gt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gte': 'TomOperator<TomDbBool> gte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'not': 'TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1)',
      'and': 'TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1)',
      'or': 'TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1)',
      'text': 'TomOperator<TomDbString> text(String text)',
      'intOp': 'TomOperator<TomDbInt> intOp(int value)',
      'doubleOp': 'TomOperator<TomDbDouble> doubleOp(double value)',
      'boolOp': 'TomOperator<TomDbBool> boolOp(bool value)',
      'dateTimeOp': 'TomOperator<TomDbDateTime> dateTimeOp(DateTime value)',
      'dateOp': 'TomOperator<TomDbDate> dateOp(DateTime value)',
      'p': 'TomOperator<T> p(String parameterName)',
      'textF': 'TomOperator<TomDbString> textF(String fieldName, TomColumnInformation columnInformation)',
      'intF': 'TomOperator<TomDbInt> intF(String fieldName, TomColumnInformation columnInformation)',
      'doubleF': 'TomOperator<TomDbDouble> doubleF(String fieldName, TomColumnInformation columnInformation)',
      'boolF': 'TomOperator<TomDbBool> boolF(String fieldName, TomColumnInformation columnInformation)',
      'dateTimeF': 'TomOperator<TomDbDateTime> dateTimeF(String fieldName, TomColumnInformation columnInformation)',
      'dateF': 'TomOperator<TomDbDate> dateF(String fieldName, TomColumnInformation columnInformation)',
      'countAll': 'CountAll countAll(String alias)',
      'countOf': 'Count<T> countOf(TomOperator<T> value, String alias, {bool distinct = false})',
      'sum': 'Sum<T> sum(TomOperator<T> value, String alias, {bool distinct = false})',
      'avg': 'Avg<T> avg(TomOperator<T> value, String alias, {bool distinct = false})',
      'minInt': 'Min<TomDbInt, int> minInt(TomOperator<TomDbInt> value, String alias)',
      'maxInt': 'Max<TomDbInt, int> maxInt(TomOperator<TomDbInt> value, String alias)',
      'minDouble': 'Min<TomDbDouble, double> minDouble(TomOperator<TomDbDouble> value, String alias)',
      'maxDouble': 'Max<TomDbDouble, double> maxDouble(TomOperator<TomDbDouble> value, String alias)',
      'minText': 'Min<TomDbString, String> minText(TomOperator<TomDbString> value, String alias)',
      'maxText': 'Max<TomDbString, String> maxText(TomOperator<TomDbString> value, String alias)',
      'minDateTime': 'Min<TomDbDateTime, DateTime> minDateTime(TomOperator<TomDbDateTime> value, String alias)',
      'maxDateTime': 'Max<TomDbDateTime, DateTime> maxDateTime(TomOperator<TomDbDateTime> value, String alias)',
    },
    getterSignatures: {
      'primaryKeyColumnInfo': 'TomColumnInformation get primaryKeyColumnInfo',
      'datasourceInfo': 'TomDataSourceInfo get datasourceInfo',
      'persistenceInfo': 'TomTypePersistenceInfo get persistenceInfo',
      'dbTable': 'TomDbTable get dbTable',
      'sqlDialect': 'TomStandardSqlDialect get sqlDialect',
      'queryTypes': 'List<Type> get queryTypes',
      'resultType': 'Type get resultType',
    },
    setterSignatures: {
      'primaryKeyColumnInfo': 'set primaryKeyColumnInfo(TomColumnInformation value)',
      'datasourceInfo': 'set datasourceInfo(TomDataSourceInfo value)',
      'persistenceInfo': 'set persistenceInfo(TomTypePersistenceInfo value)',
      'dbTable': 'set dbTable(TomDbTable value)',
      'queryTypes': 'set queryTypes(List<Type> value)',
      'resultType': 'set resultType(Type value)',
    },
  );
}

// =============================================================================
// D4rtDemoApiService Bridge
// =============================================================================

BridgedClass _createD4rtDemoApiServiceBridge() {
  return BridgedClass(
    nativeType: $tom_core_d4rt_1.D4rtDemoApiService,
    name: 'D4rtDemoApiService',
    isAssignable: (v) => v is $tom_core_d4rt_1.D4rtDemoApiService,
    isAbstract: true,
    constructors: {
    },
    methods: {
      'health': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoApiService>(target, 'D4rtDemoApiService');
        return t.health();
      },
      'unguarded': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoApiService>(target, 'D4rtDemoApiService');
        return t.unguarded();
      },
    },
    methodSignatures: {
      'health': 'Future<Map<String, Object>> health()',
      'unguarded': 'Future<Map<String, Object>> unguarded()',
    },
  );
}

// =============================================================================
// D4rtDemoApiServer Bridge
// =============================================================================

BridgedClass _createD4rtDemoApiServerBridge() {
  return BridgedClass(
    nativeType: $tom_core_d4rt_1.D4rtDemoApiServer,
    name: 'D4rtDemoApiServer',
    isAssignable: (v) => v is $tom_core_d4rt_1.D4rtDemoApiServer,
    hierarchyDepth: 1,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_d4rt_1.D4rtDemoApiServer();
      },
    },
    methods: {
      'health': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoApiServer>(target, 'D4rtDemoApiServer');
        return t.health();
      },
      'unguarded': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_d4rt_1.D4rtDemoApiServer>(target, 'D4rtDemoApiServer');
        return t.unguarded();
      },
    },
    constructorSignatures: {
      '': 'D4rtDemoApiServer()',
    },
    methodSignatures: {
      'health': 'Future<Map<String, Object>> health()',
      'unguarded': 'Future<Map<String, Object>> unguarded()',
    },
  );
}

