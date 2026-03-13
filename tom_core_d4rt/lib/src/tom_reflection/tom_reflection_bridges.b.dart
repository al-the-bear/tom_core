// D4rt Bridge - Generated file, do not edit
// Sources: 3 files
// Generated: 2026-03-12T17:01:44.932295

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';

import 'package:tom_reflection/src/reflection/capability.dart' as $tom_reflection_1;
import 'package:tom_reflection/src/reflection/mirrors.dart' as $tom_reflection_2;
import 'package:tom_reflection/tom_reflection.dart' as $tom_reflection_3;
import 'package:tom_reflection/src/reflection/reflection_builder_based.dart' as $aux_tom_reflection;

/// Bridge class for tom_reflection module.
class TomReflectionBridge {
  /// Returns all bridge class definitions.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createReflectionInterfaceBridge(),
      _createReflectionBridge(),
      _createStringInvocationBridge(),
      _createReflectCapabilityBridge(),
      _createApiReflectCapabilityBridge(),
      _createNamePatternCapabilityBridge(),
      _createMetadataQuantifiedCapabilityBridge(),
      _createInstanceInvokeCapabilityBridge(),
      _createInstanceInvokeMetaCapabilityBridge(),
      _createStaticInvokeCapabilityBridge(),
      _createStaticInvokeMetaCapabilityBridge(),
      _createTopLevelInvokeCapabilityBridge(),
      _createTopLevelInvokeMetaCapabilityBridge(),
      _createNewInstanceCapabilityBridge(),
      _createNewInstanceMetaCapabilityBridge(),
      _createMetadataCapabilityBridge(),
      _createTypeCapabilityBridge(),
      _createTypeRelationsCapabilityBridge(),
      _createLibraryCapabilityBridge(),
      _createDeclarationsCapabilityBridge(),
      _createUriCapabilityBridge(),
      _createLibraryDependenciesCapabilityBridge(),
      _createInvokingCapabilityBridge(),
      _createInvokingMetaCapabilityBridge(),
      _createTypingCapabilityBridge(),
      _createReflecteeQuantifyCapabilityBridge(),
      _createSuperclassQuantifyCapabilityBridge(),
      _createTypeAnnotationQuantifyCapabilityBridge(),
      _createImportAttachedCapabilityBridge(),
      _createGlobalQuantifyCapabilityBridge(),
      _createGlobalQuantifyMetaCapabilityBridge(),
      _createNoSuchCapabilityErrorBridge(),
      _createReflectionNoSuchMethodErrorBridge(),
      _createMirrorBridge(),
      _createDeclarationMirrorBridge(),
      _createObjectMirrorBridge(),
      _createInstanceMirrorBridge(),
      _createClosureMirrorBridge(),
      _createLibraryMirrorBridge(),
      _createLibraryDependencyMirrorBridge(),
      _createCombinatorMirrorBridge(),
      _createTypeMirrorBridge(),
      _createClassMirrorBridge(),
      _createFunctionTypeMirrorBridge(),
      _createTypeVariableMirrorBridge(),
      _createTypedefMirrorBridge(),
      _createMethodMirrorBridge(),
      _createVariableMirrorBridge(),
      _createParameterMirrorBridge(),
      _createSourceLocationBridge(),
      _createCommentBridge(),
      _createTypeValueBridge(),
    ];
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'ReflectionInterface': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\tom_reflection.dart',
      'Reflection': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\tom_reflection.dart',
      'StringInvocation': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\tom_reflection.dart',
      'ReflectCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'ApiReflectCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'NamePatternCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'MetadataQuantifiedCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'InstanceInvokeCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'InstanceInvokeMetaCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'StaticInvokeCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'StaticInvokeMetaCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'TopLevelInvokeCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'TopLevelInvokeMetaCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'NewInstanceCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'NewInstanceMetaCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'MetadataCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'TypeCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'TypeRelationsCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'LibraryCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'DeclarationsCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'UriCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'LibraryDependenciesCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'InvokingCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'InvokingMetaCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'TypingCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'ReflecteeQuantifyCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'SuperclassQuantifyCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'TypeAnnotationQuantifyCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'ImportAttachedCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'GlobalQuantifyCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'GlobalQuantifyMetaCapability': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'NoSuchCapabilityError': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'ReflectionNoSuchMethodError': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'Mirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'DeclarationMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'ObjectMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'InstanceMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'ClosureMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'LibraryMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'LibraryDependencyMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'CombinatorMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'TypeMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'ClassMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'FunctionTypeMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'TypeVariableMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'TypedefMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'MethodMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'VariableMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'ParameterMirror': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'SourceLocation': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'Comment': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'TypeValue': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
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
      BridgedEnumDefinition<$tom_reflection_1.StringInvocationKind>(
        name: 'StringInvocationKind',
        values: $tom_reflection_1.StringInvocationKind.values,
      ),
    ];
  }

  /// Returns a map of enum names to their canonical source URIs.
  ///
  /// Used for deduplication when the same enum is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> enumSourceUris() {
    return {
      'StringInvocationKind': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
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

    // Register global variables
    registerGlobalVariables(interpreter, importPath);

    // Register global functions with source URIs for deduplication
    final funcs = globalFunctions();
    final funcSources = globalFunctionSourceUris();
    final funcSigs = globalFunctionSignatures();
    for (final entry in funcs.entries) {
      interpreter.registertopLevelFunction(entry.key, entry.value, importPath, sourceUri: funcSources[entry.key], signature: funcSigs[entry.key]);
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
      interpreter.registerGlobalVariable('instanceInvokeCapability', instanceInvokeCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "instanceInvokeCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('staticInvokeCapability', staticInvokeCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "staticInvokeCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('topLevelInvokeCapability', topLevelInvokeCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "topLevelInvokeCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('newInstanceCapability', newInstanceCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "newInstanceCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('metadataCapability', metadataCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "metadataCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('typeCapability', typeCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "typeCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('typeRelationsCapability', typeRelationsCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "typeRelationsCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('reflectedTypeCapability', reflectedTypeCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "reflectedTypeCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('libraryCapability', libraryCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "libraryCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('declarationsCapability', declarationsCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "declarationsCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('uriCapability', uriCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "uriCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('libraryDependenciesCapability', libraryDependenciesCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "libraryDependenciesCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('invokingCapability', invokingCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "invokingCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('typingCapability', typingCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "typingCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('delegateCapability', delegateCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "delegateCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('subtypeQuantifyCapability', subtypeQuantifyCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "subtypeQuantifyCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('superclassQuantifyCapability', superclassQuantifyCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "superclassQuantifyCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('typeAnnotationQuantifyCapability', typeAnnotationQuantifyCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "typeAnnotationQuantifyCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('typeAnnotationDeepQuantifyCapability', typeAnnotationDeepQuantifyCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "typeAnnotationDeepQuantifyCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('correspondingSetterQuantifyCapability', correspondingSetterQuantifyCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "correspondingSetterQuantifyCapability": $e');
    }
    try {
      interpreter.registerGlobalVariable('admitSubtypeCapability', admitSubtypeCapability, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart');
    } catch (e) {
      errors.add('Failed to register variable "admitSubtypeCapability": $e');
    }

    if (errors.isNotEmpty) {
      throw StateError('Bridge registration errors (tom_reflection):\n${errors.join("\n")}');
    }
  }

  /// Returns a map of global function names to their native implementations.
  static Map<String, NativeFunctionImpl> globalFunctions() {
    return {
      'reflectionNoSuchInvokableError': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 5, 'reflectionNoSuchInvokableError');
        final receiver = D4.getRequiredArg<Object?>(positional, 0, 'receiver', 'reflectionNoSuchInvokableError');
        final memberName = D4.getRequiredArg<String>(positional, 1, 'memberName', 'reflectionNoSuchInvokableError');
        final positionalArguments = D4.getRequiredArg<List>(positional, 2, 'positionalArguments', 'reflectionNoSuchInvokableError');
        final namedArguments = D4.getRequiredArg<Map<Symbol, dynamic>?>(positional, 3, 'namedArguments', 'reflectionNoSuchInvokableError');
        final kind = D4.getRequiredArg<$tom_reflection_1.StringInvocationKind>(positional, 4, 'kind', 'reflectionNoSuchInvokableError');
        return reflectionNoSuchInvokableError(receiver, memberName, positionalArguments, namedArguments, kind);
      },
      'reflectionNoSuchMethodError': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 4, 'reflectionNoSuchMethodError');
        final receiver = D4.getRequiredArg<Object?>(positional, 0, 'receiver', 'reflectionNoSuchMethodError');
        final memberName = D4.getRequiredArg<String>(positional, 1, 'memberName', 'reflectionNoSuchMethodError');
        final positionalArguments = D4.getRequiredArg<List>(positional, 2, 'positionalArguments', 'reflectionNoSuchMethodError');
        final namedArguments = D4.getRequiredArg<Map<Symbol, dynamic>?>(positional, 3, 'namedArguments', 'reflectionNoSuchMethodError');
        return reflectionNoSuchMethodError(receiver, memberName, positionalArguments, namedArguments);
      },
      'reflectionNoSuchGetterError': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 4, 'reflectionNoSuchGetterError');
        final receiver = D4.getRequiredArg<Object?>(positional, 0, 'receiver', 'reflectionNoSuchGetterError');
        final memberName = D4.getRequiredArg<String>(positional, 1, 'memberName', 'reflectionNoSuchGetterError');
        final positionalArguments = D4.getRequiredArg<List>(positional, 2, 'positionalArguments', 'reflectionNoSuchGetterError');
        final namedArguments = D4.getRequiredArg<Map<Symbol, dynamic>?>(positional, 3, 'namedArguments', 'reflectionNoSuchGetterError');
        return reflectionNoSuchGetterError(receiver, memberName, positionalArguments, namedArguments);
      },
      'reflectionNoSuchSetterError': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 4, 'reflectionNoSuchSetterError');
        final receiver = D4.getRequiredArg<Object?>(positional, 0, 'receiver', 'reflectionNoSuchSetterError');
        final memberName = D4.getRequiredArg<String>(positional, 1, 'memberName', 'reflectionNoSuchSetterError');
        final positionalArguments = D4.getRequiredArg<List>(positional, 2, 'positionalArguments', 'reflectionNoSuchSetterError');
        final namedArguments = D4.getRequiredArg<Map<Symbol, dynamic>?>(positional, 3, 'namedArguments', 'reflectionNoSuchSetterError');
        return reflectionNoSuchSetterError(receiver, memberName, positionalArguments, namedArguments);
      },
      'reflectionNoSuchConstructorError': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 4, 'reflectionNoSuchConstructorError');
        final receiver = D4.getRequiredArg<Object?>(positional, 0, 'receiver', 'reflectionNoSuchConstructorError');
        final constructorName = D4.getRequiredArg<String>(positional, 1, 'constructorName', 'reflectionNoSuchConstructorError');
        final positionalArguments = D4.getRequiredArg<List>(positional, 2, 'positionalArguments', 'reflectionNoSuchConstructorError');
        final namedArguments = D4.getRequiredArg<Map<Symbol, dynamic>?>(positional, 3, 'namedArguments', 'reflectionNoSuchConstructorError');
        return reflectionNoSuchConstructorError(receiver, constructorName, positionalArguments, namedArguments);
      },
    };
  }

  /// Returns a map of global function names to their canonical source URIs.
  ///
  /// Used for deduplication when the same function is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> globalFunctionSourceUris() {
    return {
      'reflectionNoSuchInvokableError': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'reflectionNoSuchMethodError': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'reflectionNoSuchGetterError': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'reflectionNoSuchSetterError': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'reflectionNoSuchConstructorError': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
    };
  }

  /// Returns a map of global function names to their display signatures.
  static Map<String, String> globalFunctionSignatures() {
    return {
      'reflectionNoSuchInvokableError': 'dynamic reflectionNoSuchInvokableError(Object? receiver, String memberName, List positionalArguments, Map<Symbol, dynamic>? namedArguments, StringInvocationKind kind)',
      'reflectionNoSuchMethodError': 'dynamic reflectionNoSuchMethodError(Object? receiver, String memberName, List positionalArguments, Map<Symbol, dynamic>? namedArguments)',
      'reflectionNoSuchGetterError': 'dynamic reflectionNoSuchGetterError(Object? receiver, String memberName, List positionalArguments, Map<Symbol, dynamic>? namedArguments)',
      'reflectionNoSuchSetterError': 'dynamic reflectionNoSuchSetterError(Object? receiver, String memberName, List positionalArguments, Map<Symbol, dynamic>? namedArguments)',
      'reflectionNoSuchConstructorError': 'dynamic reflectionNoSuchConstructorError(Object? receiver, String constructorName, List positionalArguments, Map<Symbol, dynamic>? namedArguments)',
    };
  }

  /// Returns the list of canonical source library URIs.
  ///
  /// These are the actual source locations of all elements in this bridge,
  /// used for deduplication when the same libraries are exported through
  /// multiple barrels.
  static List<String> sourceLibraries() {
    return [
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\capability.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\src\reflection\mirrors.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_reflection-1.0.1\lib\tom_reflection.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    return "import 'package:tom_reflection/tom_reflection.dart';";
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
    'StringInvocationKind',
  ];

}

// =============================================================================
// ReflectionInterface Bridge
// =============================================================================

BridgedClass _createReflectionInterfaceBridge() {
  return BridgedClass(
    nativeType: ReflectionInterface,
    name: 'ReflectionInterface',
    isAssignable: (v) => v is ReflectionInterface,
    constructors: {
    },
    getters: {
      'libraries': (visitor, target) => D4.validateTarget<ReflectionInterface>(target, 'ReflectionInterface').libraries,
      'annotatedClasses': (visitor, target) => D4.validateTarget<ReflectionInterface>(target, 'ReflectionInterface').annotatedClasses,
    },
    methods: {
      'canReflect': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ReflectionInterface>(target, 'ReflectionInterface');
        D4.requireMinArgs(positional, 1, 'canReflect');
        final o = D4.getRequiredArg<Object>(positional, 0, 'o', 'canReflect');
        return t.canReflect(o);
      },
      'reflect': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ReflectionInterface>(target, 'ReflectionInterface');
        D4.requireMinArgs(positional, 1, 'reflect');
        final o = D4.getRequiredArg<Object>(positional, 0, 'o', 'reflect');
        return t.reflect(o);
      },
      'canReflectType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ReflectionInterface>(target, 'ReflectionInterface');
        D4.requireMinArgs(positional, 1, 'canReflectType');
        final type = D4.getRequiredArg<Type>(positional, 0, 'type', 'canReflectType');
        return t.canReflectType(type);
      },
      'reflectType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ReflectionInterface>(target, 'ReflectionInterface');
        D4.requireMinArgs(positional, 1, 'reflectType');
        final type = D4.getRequiredArg<Type>(positional, 0, 'type', 'reflectType');
        return t.reflectType(type);
      },
      'findLibrary': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ReflectionInterface>(target, 'ReflectionInterface');
        D4.requireMinArgs(positional, 1, 'findLibrary');
        final library = D4.getRequiredArg<String>(positional, 0, 'library', 'findLibrary');
        return t.findLibrary(library);
      },
    },
    methodSignatures: {
      'canReflect': 'bool canReflect(Object o)',
      'reflect': 'InstanceMirror reflect(Object o)',
      'canReflectType': 'bool canReflectType(Type type)',
      'reflectType': 'TypeMirror reflectType(Type type)',
      'findLibrary': 'LibraryMirror findLibrary(String library)',
    },
    getterSignatures: {
      'libraries': 'Map<Uri, LibraryMirror> get libraries',
      'annotatedClasses': 'Iterable<ClassMirror> get annotatedClasses',
    },
  );
}

// =============================================================================
// Reflection Bridge
// =============================================================================

BridgedClass _createReflectionBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_3.Reflection,
    name: 'Reflection',
    isAssignable: (v) => v is $tom_reflection_3.Reflection,
    constructors: {
    },
    getters: {
      'libraries': (visitor, target) => D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection').libraries,
      'annotatedClasses': (visitor, target) => D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection').annotatedClasses,
      'capabilities': (visitor, target) => D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection').capabilities,
    },
    methods: {
      'canReflect': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection');
        D4.requireMinArgs(positional, 1, 'canReflect');
        final reflectee = D4.getRequiredArg<Object>(positional, 0, 'reflectee', 'canReflect');
        return t.canReflect(reflectee);
      },
      'reflect': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection');
        D4.requireMinArgs(positional, 1, 'reflect');
        final reflectee = D4.getRequiredArg<Object>(positional, 0, 'reflectee', 'reflect');
        return t.reflect(reflectee);
      },
      'canReflectType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection');
        D4.requireMinArgs(positional, 1, 'canReflectType');
        final type = D4.getRequiredArg<Type>(positional, 0, 'type', 'canReflectType');
        return t.canReflectType(type);
      },
      'reflectType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection');
        D4.requireMinArgs(positional, 1, 'reflectType');
        final type = D4.getRequiredArg<Type>(positional, 0, 'type', 'reflectType');
        return t.reflectType(type);
      },
      'findLibrary': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_3.Reflection>(target, 'Reflection');
        D4.requireMinArgs(positional, 1, 'findLibrary');
        final libraryName = D4.getRequiredArg<String>(positional, 0, 'libraryName', 'findLibrary');
        return t.findLibrary(libraryName);
      },
    },
    staticGetters: {
      'thisClassName': (visitor) => $tom_reflection_3.Reflection.thisClassName,
      'thisClassId': (visitor) => $tom_reflection_3.Reflection.thisClassId,
    },
    staticMethods: {
      'getInstance': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getInstance');
        final type = D4.getRequiredArg<Type>(positional, 0, 'type', 'getInstance');
        return $tom_reflection_3.Reflection.getInstance(type);
      },
    },
    methodSignatures: {
      'canReflect': 'bool canReflect(Object reflectee)',
      'reflect': 'InstanceMirror reflect(Object reflectee)',
      'canReflectType': 'bool canReflectType(Type type)',
      'reflectType': 'TypeMirror<dynamic> reflectType(Type type)',
      'findLibrary': 'LibraryMirror findLibrary(String libraryName)',
    },
    getterSignatures: {
      'libraries': 'Map<Uri, LibraryMirror> get libraries',
      'annotatedClasses': 'Iterable<ClassMirror<dynamic>> get annotatedClasses',
      'capabilities': 'List<ReflectCapability> get capabilities',
    },
    staticMethodSignatures: {
      'getInstance': 'Reflection? getInstance(Type type)',
    },
    staticGetterSignatures: {
      'thisClassName': 'dynamic get thisClassName',
      'thisClassId': 'dynamic get thisClassId',
    },
  );
}

// =============================================================================
// StringInvocation Bridge
// =============================================================================

BridgedClass _createStringInvocationBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_3.StringInvocation,
    name: 'StringInvocation',
    isAssignable: (v) => v is $tom_reflection_3.StringInvocation,
    constructors: {
    },
    getters: {
      'memberName': (visitor, target) => D4.validateTarget<$tom_reflection_3.StringInvocation>(target, 'StringInvocation').memberName,
      'positionalArguments': (visitor, target) => D4.validateTarget<$tom_reflection_3.StringInvocation>(target, 'StringInvocation').positionalArguments,
      'namedArguments': (visitor, target) => D4.validateTarget<$tom_reflection_3.StringInvocation>(target, 'StringInvocation').namedArguments,
      'isMethod': (visitor, target) => D4.validateTarget<$tom_reflection_3.StringInvocation>(target, 'StringInvocation').isMethod,
      'isGetter': (visitor, target) => D4.validateTarget<$tom_reflection_3.StringInvocation>(target, 'StringInvocation').isGetter,
      'isSetter': (visitor, target) => D4.validateTarget<$tom_reflection_3.StringInvocation>(target, 'StringInvocation').isSetter,
      'isAccessor': (visitor, target) => D4.validateTarget<$tom_reflection_3.StringInvocation>(target, 'StringInvocation').isAccessor,
    },
    getterSignatures: {
      'memberName': 'String get memberName',
      'positionalArguments': 'List get positionalArguments',
      'namedArguments': 'Map<Symbol, dynamic> get namedArguments',
      'isMethod': 'bool get isMethod',
      'isGetter': 'bool get isGetter',
      'isSetter': 'bool get isSetter',
      'isAccessor': 'bool get isAccessor',
    },
  );
}

// =============================================================================
// ReflectCapability Bridge
// =============================================================================

BridgedClass _createReflectCapabilityBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_1.ReflectCapability,
    name: 'ReflectCapability',
    isAssignable: (v) => v is $tom_reflection_1.ReflectCapability,
    constructors: {
    },
  );
}

// =============================================================================
// ApiReflectCapability Bridge
// =============================================================================

BridgedClass _createApiReflectCapabilityBridge() {
  return BridgedClass(
    nativeType: ApiReflectCapability,
    name: 'ApiReflectCapability',
    isAssignable: (v) => v is ApiReflectCapability,
    constructors: {
    },
  );
}

// =============================================================================
// NamePatternCapability Bridge
// =============================================================================

BridgedClass _createNamePatternCapabilityBridge() {
  return BridgedClass(
    nativeType: NamePatternCapability,
    name: 'NamePatternCapability',
    isAssignable: (v) => v is NamePatternCapability,
    constructors: {
    },
    getters: {
      'namePattern': (visitor, target) => D4.validateTarget<NamePatternCapability>(target, 'NamePatternCapability').namePattern,
    },
    getterSignatures: {
      'namePattern': 'String get namePattern',
    },
  );
}

// =============================================================================
// MetadataQuantifiedCapability Bridge
// =============================================================================

BridgedClass _createMetadataQuantifiedCapabilityBridge() {
  return BridgedClass(
    nativeType: MetadataQuantifiedCapability,
    name: 'MetadataQuantifiedCapability',
    isAssignable: (v) => v is MetadataQuantifiedCapability,
    constructors: {
    },
    getters: {
      'metadataType': (visitor, target) => D4.validateTarget<MetadataQuantifiedCapability>(target, 'MetadataQuantifiedCapability').metadataType,
    },
    getterSignatures: {
      'metadataType': 'Type get metadataType',
    },
  );
}

// =============================================================================
// InstanceInvokeCapability Bridge
// =============================================================================

BridgedClass _createInstanceInvokeCapabilityBridge() {
  return BridgedClass(
    nativeType: InstanceInvokeCapability,
    name: 'InstanceInvokeCapability',
    isAssignable: (v) => v is InstanceInvokeCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'InstanceInvokeCapability');
        final namePattern = D4.getRequiredArg<String>(positional, 0, 'namePattern', 'InstanceInvokeCapability');
        return InstanceInvokeCapability(namePattern);
      },
    },
    getters: {
      'namePattern': (visitor, target) => D4.validateTarget<InstanceInvokeCapability>(target, 'InstanceInvokeCapability').namePattern,
    },
    constructorSignatures: {
      '': 'const InstanceInvokeCapability(String namePattern)',
    },
    getterSignatures: {
      'namePattern': 'String get namePattern',
    },
  );
}

// =============================================================================
// InstanceInvokeMetaCapability Bridge
// =============================================================================

BridgedClass _createInstanceInvokeMetaCapabilityBridge() {
  return BridgedClass(
    nativeType: InstanceInvokeMetaCapability,
    name: 'InstanceInvokeMetaCapability',
    isAssignable: (v) => v is InstanceInvokeMetaCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'InstanceInvokeMetaCapability');
        final metadataType = D4.getRequiredArg<Type>(positional, 0, 'metadataType', 'InstanceInvokeMetaCapability');
        return InstanceInvokeMetaCapability(metadataType);
      },
    },
    getters: {
      'metadataType': (visitor, target) => D4.validateTarget<InstanceInvokeMetaCapability>(target, 'InstanceInvokeMetaCapability').metadataType,
    },
    constructorSignatures: {
      '': 'const InstanceInvokeMetaCapability(Type metadataType)',
    },
    getterSignatures: {
      'metadataType': 'Type get metadataType',
    },
  );
}

// =============================================================================
// StaticInvokeCapability Bridge
// =============================================================================

BridgedClass _createStaticInvokeCapabilityBridge() {
  return BridgedClass(
    nativeType: StaticInvokeCapability,
    name: 'StaticInvokeCapability',
    isAssignable: (v) => v is StaticInvokeCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'StaticInvokeCapability');
        final namePattern = D4.getRequiredArg<String>(positional, 0, 'namePattern', 'StaticInvokeCapability');
        return StaticInvokeCapability(namePattern);
      },
    },
    getters: {
      'namePattern': (visitor, target) => D4.validateTarget<StaticInvokeCapability>(target, 'StaticInvokeCapability').namePattern,
    },
    constructorSignatures: {
      '': 'const StaticInvokeCapability(String namePattern)',
    },
    getterSignatures: {
      'namePattern': 'String get namePattern',
    },
  );
}

// =============================================================================
// StaticInvokeMetaCapability Bridge
// =============================================================================

BridgedClass _createStaticInvokeMetaCapabilityBridge() {
  return BridgedClass(
    nativeType: StaticInvokeMetaCapability,
    name: 'StaticInvokeMetaCapability',
    isAssignable: (v) => v is StaticInvokeMetaCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'StaticInvokeMetaCapability');
        final metadata = D4.getRequiredArg<Type>(positional, 0, 'metadata', 'StaticInvokeMetaCapability');
        return StaticInvokeMetaCapability(metadata);
      },
    },
    getters: {
      'metadataType': (visitor, target) => D4.validateTarget<StaticInvokeMetaCapability>(target, 'StaticInvokeMetaCapability').metadataType,
    },
    constructorSignatures: {
      '': 'const StaticInvokeMetaCapability(Type metadata)',
    },
    getterSignatures: {
      'metadataType': 'Type get metadataType',
    },
  );
}

// =============================================================================
// TopLevelInvokeCapability Bridge
// =============================================================================

BridgedClass _createTopLevelInvokeCapabilityBridge() {
  return BridgedClass(
    nativeType: TopLevelInvokeCapability,
    name: 'TopLevelInvokeCapability',
    isAssignable: (v) => v is TopLevelInvokeCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TopLevelInvokeCapability');
        final namePattern = D4.getRequiredArg<String>(positional, 0, 'namePattern', 'TopLevelInvokeCapability');
        return TopLevelInvokeCapability(namePattern);
      },
    },
    getters: {
      'namePattern': (visitor, target) => D4.validateTarget<TopLevelInvokeCapability>(target, 'TopLevelInvokeCapability').namePattern,
    },
    constructorSignatures: {
      '': 'const TopLevelInvokeCapability(String namePattern)',
    },
    getterSignatures: {
      'namePattern': 'String get namePattern',
    },
  );
}

// =============================================================================
// TopLevelInvokeMetaCapability Bridge
// =============================================================================

BridgedClass _createTopLevelInvokeMetaCapabilityBridge() {
  return BridgedClass(
    nativeType: TopLevelInvokeMetaCapability,
    name: 'TopLevelInvokeMetaCapability',
    isAssignable: (v) => v is TopLevelInvokeMetaCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TopLevelInvokeMetaCapability');
        final metadataType = D4.getRequiredArg<Type>(positional, 0, 'metadataType', 'TopLevelInvokeMetaCapability');
        return TopLevelInvokeMetaCapability(metadataType);
      },
    },
    getters: {
      'metadataType': (visitor, target) => D4.validateTarget<TopLevelInvokeMetaCapability>(target, 'TopLevelInvokeMetaCapability').metadataType,
    },
    constructorSignatures: {
      '': 'const TopLevelInvokeMetaCapability(Type metadataType)',
    },
    getterSignatures: {
      'metadataType': 'Type get metadataType',
    },
  );
}

// =============================================================================
// NewInstanceCapability Bridge
// =============================================================================

BridgedClass _createNewInstanceCapabilityBridge() {
  return BridgedClass(
    nativeType: NewInstanceCapability,
    name: 'NewInstanceCapability',
    isAssignable: (v) => v is NewInstanceCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'NewInstanceCapability');
        final namePattern = D4.getRequiredArg<String>(positional, 0, 'namePattern', 'NewInstanceCapability');
        return NewInstanceCapability(namePattern);
      },
    },
    getters: {
      'namePattern': (visitor, target) => D4.validateTarget<NewInstanceCapability>(target, 'NewInstanceCapability').namePattern,
    },
    constructorSignatures: {
      '': 'const NewInstanceCapability(String namePattern)',
    },
    getterSignatures: {
      'namePattern': 'String get namePattern',
    },
  );
}

// =============================================================================
// NewInstanceMetaCapability Bridge
// =============================================================================

BridgedClass _createNewInstanceMetaCapabilityBridge() {
  return BridgedClass(
    nativeType: NewInstanceMetaCapability,
    name: 'NewInstanceMetaCapability',
    isAssignable: (v) => v is NewInstanceMetaCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'NewInstanceMetaCapability');
        final metadataType = D4.getRequiredArg<Type>(positional, 0, 'metadataType', 'NewInstanceMetaCapability');
        return NewInstanceMetaCapability(metadataType);
      },
    },
    getters: {
      'metadataType': (visitor, target) => D4.validateTarget<NewInstanceMetaCapability>(target, 'NewInstanceMetaCapability').metadataType,
    },
    constructorSignatures: {
      '': 'const NewInstanceMetaCapability(Type metadataType)',
    },
    getterSignatures: {
      'metadataType': 'Type get metadataType',
    },
  );
}

// =============================================================================
// MetadataCapability Bridge
// =============================================================================

BridgedClass _createMetadataCapabilityBridge() {
  return BridgedClass(
    nativeType: MetadataCapability,
    name: 'MetadataCapability',
    isAssignable: (v) => v is MetadataCapability,
    constructors: {
      '': (visitor, positional, named) {
        return MetadataCapability();
      },
    },
    constructorSignatures: {
      '': 'const MetadataCapability()',
    },
  );
}

// =============================================================================
// TypeCapability Bridge
// =============================================================================

BridgedClass _createTypeCapabilityBridge() {
  return BridgedClass(
    nativeType: TypeCapability,
    name: 'TypeCapability',
    isAssignable: (v) => v is TypeCapability,
    constructors: {
      '': (visitor, positional, named) {
        return TypeCapability();
      },
    },
    constructorSignatures: {
      '': 'const TypeCapability()',
    },
  );
}

// =============================================================================
// TypeRelationsCapability Bridge
// =============================================================================

BridgedClass _createTypeRelationsCapabilityBridge() {
  return BridgedClass(
    nativeType: TypeRelationsCapability,
    name: 'TypeRelationsCapability',
    isAssignable: (v) => v is TypeRelationsCapability,
    constructors: {
      '': (visitor, positional, named) {
        return TypeRelationsCapability();
      },
    },
    constructorSignatures: {
      '': 'const TypeRelationsCapability()',
    },
  );
}

// =============================================================================
// LibraryCapability Bridge
// =============================================================================

BridgedClass _createLibraryCapabilityBridge() {
  return BridgedClass(
    nativeType: LibraryCapability,
    name: 'LibraryCapability',
    isAssignable: (v) => v is LibraryCapability,
    constructors: {
      '': (visitor, positional, named) {
        return LibraryCapability();
      },
    },
    constructorSignatures: {
      '': 'const LibraryCapability()',
    },
  );
}

// =============================================================================
// DeclarationsCapability Bridge
// =============================================================================

BridgedClass _createDeclarationsCapabilityBridge() {
  return BridgedClass(
    nativeType: DeclarationsCapability,
    name: 'DeclarationsCapability',
    isAssignable: (v) => v is DeclarationsCapability,
    constructors: {
      '': (visitor, positional, named) {
        return DeclarationsCapability();
      },
    },
    constructorSignatures: {
      '': 'const DeclarationsCapability()',
    },
  );
}

// =============================================================================
// UriCapability Bridge
// =============================================================================

BridgedClass _createUriCapabilityBridge() {
  return BridgedClass(
    nativeType: UriCapability,
    name: 'UriCapability',
    isAssignable: (v) => v is UriCapability,
    constructors: {
      '': (visitor, positional, named) {
        return UriCapability();
      },
    },
    constructorSignatures: {
      '': 'const UriCapability()',
    },
  );
}

// =============================================================================
// LibraryDependenciesCapability Bridge
// =============================================================================

BridgedClass _createLibraryDependenciesCapabilityBridge() {
  return BridgedClass(
    nativeType: LibraryDependenciesCapability,
    name: 'LibraryDependenciesCapability',
    isAssignable: (v) => v is LibraryDependenciesCapability,
    constructors: {
      '': (visitor, positional, named) {
        return LibraryDependenciesCapability();
      },
    },
    constructorSignatures: {
      '': 'const LibraryDependenciesCapability()',
    },
  );
}

// =============================================================================
// InvokingCapability Bridge
// =============================================================================

BridgedClass _createInvokingCapabilityBridge() {
  return BridgedClass(
    nativeType: InvokingCapability,
    name: 'InvokingCapability',
    isAssignable: (v) => v is InvokingCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'InvokingCapability');
        final namePattern = D4.getRequiredArg<String>(positional, 0, 'namePattern', 'InvokingCapability');
        return InvokingCapability(namePattern);
      },
    },
    getters: {
      'namePattern': (visitor, target) => D4.validateTarget<InvokingCapability>(target, 'InvokingCapability').namePattern,
    },
    constructorSignatures: {
      '': 'const InvokingCapability(String namePattern)',
    },
    getterSignatures: {
      'namePattern': 'String get namePattern',
    },
  );
}

// =============================================================================
// InvokingMetaCapability Bridge
// =============================================================================

BridgedClass _createInvokingMetaCapabilityBridge() {
  return BridgedClass(
    nativeType: InvokingMetaCapability,
    name: 'InvokingMetaCapability',
    isAssignable: (v) => v is InvokingMetaCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'InvokingMetaCapability');
        final metadataType = D4.getRequiredArg<Type>(positional, 0, 'metadataType', 'InvokingMetaCapability');
        return InvokingMetaCapability(metadataType);
      },
    },
    getters: {
      'metadataType': (visitor, target) => D4.validateTarget<InvokingMetaCapability>(target, 'InvokingMetaCapability').metadataType,
    },
    constructorSignatures: {
      '': 'const InvokingMetaCapability(Type metadataType)',
    },
    getterSignatures: {
      'metadataType': 'Type get metadataType',
    },
  );
}

// =============================================================================
// TypingCapability Bridge
// =============================================================================

BridgedClass _createTypingCapabilityBridge() {
  return BridgedClass(
    nativeType: TypingCapability,
    name: 'TypingCapability',
    isAssignable: (v) => v is TypingCapability,
    constructors: {
      '': (visitor, positional, named) {
        return TypingCapability();
      },
    },
    constructorSignatures: {
      '': 'const TypingCapability()',
    },
  );
}

// =============================================================================
// ReflecteeQuantifyCapability Bridge
// =============================================================================

BridgedClass _createReflecteeQuantifyCapabilityBridge() {
  return BridgedClass(
    nativeType: ReflecteeQuantifyCapability,
    name: 'ReflecteeQuantifyCapability',
    isAssignable: (v) => v is ReflecteeQuantifyCapability,
    constructors: {
    },
  );
}

// =============================================================================
// SuperclassQuantifyCapability Bridge
// =============================================================================

BridgedClass _createSuperclassQuantifyCapabilityBridge() {
  return BridgedClass(
    nativeType: SuperclassQuantifyCapability,
    name: 'SuperclassQuantifyCapability',
    isAssignable: (v) => v is SuperclassQuantifyCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'SuperclassQuantifyCapability');
        final upperBound = D4.getRequiredArg<Type>(positional, 0, 'upperBound', 'SuperclassQuantifyCapability');
        final excludeUpperBound = D4.getNamedArgWithDefault<bool>(named, 'excludeUpperBound', false);
        return SuperclassQuantifyCapability(upperBound, excludeUpperBound: excludeUpperBound);
      },
    },
    getters: {
      'upperBound': (visitor, target) => D4.validateTarget<SuperclassQuantifyCapability>(target, 'SuperclassQuantifyCapability').upperBound,
      'excludeUpperBound': (visitor, target) => D4.validateTarget<SuperclassQuantifyCapability>(target, 'SuperclassQuantifyCapability').excludeUpperBound,
    },
    constructorSignatures: {
      '': 'const SuperclassQuantifyCapability(Type upperBound, {bool excludeUpperBound = false})',
    },
    getterSignatures: {
      'upperBound': 'Type get upperBound',
      'excludeUpperBound': 'bool get excludeUpperBound',
    },
  );
}

// =============================================================================
// TypeAnnotationQuantifyCapability Bridge
// =============================================================================

BridgedClass _createTypeAnnotationQuantifyCapabilityBridge() {
  return BridgedClass(
    nativeType: TypeAnnotationQuantifyCapability,
    name: 'TypeAnnotationQuantifyCapability',
    isAssignable: (v) => v is TypeAnnotationQuantifyCapability,
    constructors: {
      '': (visitor, positional, named) {
        final transitive = D4.getNamedArgWithDefault<bool>(named, 'transitive', false);
        return TypeAnnotationQuantifyCapability(transitive: transitive);
      },
    },
    getters: {
      'transitive': (visitor, target) => D4.validateTarget<TypeAnnotationQuantifyCapability>(target, 'TypeAnnotationQuantifyCapability').transitive,
    },
    constructorSignatures: {
      '': 'const TypeAnnotationQuantifyCapability({bool transitive = false})',
    },
    getterSignatures: {
      'transitive': 'bool get transitive',
    },
  );
}

// =============================================================================
// ImportAttachedCapability Bridge
// =============================================================================

BridgedClass _createImportAttachedCapabilityBridge() {
  return BridgedClass(
    nativeType: ImportAttachedCapability,
    name: 'ImportAttachedCapability',
    isAssignable: (v) => v is ImportAttachedCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'ImportAttachedCapability');
        final reflector = D4.getRequiredArg<$tom_reflection_3.Reflection>(positional, 0, 'reflector', 'ImportAttachedCapability');
        return ImportAttachedCapability(reflector);
      },
    },
    getters: {
      'reflector': (visitor, target) => D4.validateTarget<ImportAttachedCapability>(target, 'ImportAttachedCapability').reflector,
    },
    constructorSignatures: {
      '': 'const ImportAttachedCapability(Reflection reflector)',
    },
    getterSignatures: {
      'reflector': 'Reflection get reflector',
    },
  );
}

// =============================================================================
// GlobalQuantifyCapability Bridge
// =============================================================================

BridgedClass _createGlobalQuantifyCapabilityBridge() {
  return BridgedClass(
    nativeType: GlobalQuantifyCapability,
    name: 'GlobalQuantifyCapability',
    isAssignable: (v) => v is GlobalQuantifyCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'GlobalQuantifyCapability');
        final classNamePattern = D4.getRequiredArg<String>(positional, 0, 'classNamePattern', 'GlobalQuantifyCapability');
        final reflector = D4.getRequiredArg<$tom_reflection_3.Reflection>(positional, 1, 'reflector', 'GlobalQuantifyCapability');
        return GlobalQuantifyCapability(classNamePattern, reflector);
      },
    },
    getters: {
      'reflector': (visitor, target) => D4.validateTarget<GlobalQuantifyCapability>(target, 'GlobalQuantifyCapability').reflector,
      'classNamePattern': (visitor, target) => D4.validateTarget<GlobalQuantifyCapability>(target, 'GlobalQuantifyCapability').classNamePattern,
    },
    constructorSignatures: {
      '': 'const GlobalQuantifyCapability(String classNamePattern, Reflection reflector)',
    },
    getterSignatures: {
      'reflector': 'Reflection get reflector',
      'classNamePattern': 'String get classNamePattern',
    },
  );
}

// =============================================================================
// GlobalQuantifyMetaCapability Bridge
// =============================================================================

BridgedClass _createGlobalQuantifyMetaCapabilityBridge() {
  return BridgedClass(
    nativeType: GlobalQuantifyMetaCapability,
    name: 'GlobalQuantifyMetaCapability',
    isAssignable: (v) => v is GlobalQuantifyMetaCapability,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'GlobalQuantifyMetaCapability');
        final metadataType = D4.getRequiredArg<Type>(positional, 0, 'metadataType', 'GlobalQuantifyMetaCapability');
        final reflector = D4.getRequiredArg<$tom_reflection_3.Reflection>(positional, 1, 'reflector', 'GlobalQuantifyMetaCapability');
        return GlobalQuantifyMetaCapability(metadataType, reflector);
      },
    },
    getters: {
      'reflector': (visitor, target) => D4.validateTarget<GlobalQuantifyMetaCapability>(target, 'GlobalQuantifyMetaCapability').reflector,
      'metadataType': (visitor, target) => D4.validateTarget<GlobalQuantifyMetaCapability>(target, 'GlobalQuantifyMetaCapability').metadataType,
    },
    constructorSignatures: {
      '': 'const GlobalQuantifyMetaCapability(Type metadataType, Reflection reflector)',
    },
    getterSignatures: {
      'reflector': 'Reflection get reflector',
      'metadataType': 'Type get metadataType',
    },
  );
}

// =============================================================================
// NoSuchCapabilityError Bridge
// =============================================================================

BridgedClass _createNoSuchCapabilityErrorBridge() {
  return BridgedClass(
    nativeType: NoSuchCapabilityError,
    name: 'NoSuchCapabilityError',
    isAssignable: (v) => v is NoSuchCapabilityError,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'NoSuchCapabilityError');
        final message = D4.getRequiredArg<String>(positional, 0, 'message', 'NoSuchCapabilityError');
        return NoSuchCapabilityError(message);
      },
    },
    getters: {
      'stackTrace': (visitor, target) => D4.validateTarget<NoSuchCapabilityError>(target, 'NoSuchCapabilityError').stackTrace,
    },
    constructorSignatures: {
      '': 'factory NoSuchCapabilityError(String message)',
    },
    getterSignatures: {
      'stackTrace': 'StackTrace? get stackTrace',
    },
  );
}

// =============================================================================
// ReflectionNoSuchMethodError Bridge
// =============================================================================

BridgedClass _createReflectionNoSuchMethodErrorBridge() {
  return BridgedClass(
    nativeType: ReflectionNoSuchMethodError,
    name: 'ReflectionNoSuchMethodError',
    isAssignable: (v) => v is ReflectionNoSuchMethodError,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 5, 'ReflectionNoSuchMethodError');
        final receiver = D4.getRequiredArg<Object?>(positional, 0, 'receiver', 'ReflectionNoSuchMethodError');
        final memberName = D4.getRequiredArg<String>(positional, 1, 'memberName', 'ReflectionNoSuchMethodError');
        if (positional.length <= 2) {
          throw ArgumentError('ReflectionNoSuchMethodError: Missing required argument "positionalArguments" at position 2');
        }
        final positionalArguments = D4.coerceList<dynamic>(positional[2], 'positionalArguments');
        if (positional.length <= 3) {
          throw ArgumentError('ReflectionNoSuchMethodError: Missing required argument "namedArguments" at position 3');
        }
        final namedArguments = D4.coerceMapOrNull<Symbol, dynamic>(positional[3], 'namedArguments');
        final kind = D4.getRequiredArg<$tom_reflection_1.StringInvocationKind>(positional, 4, 'kind', 'ReflectionNoSuchMethodError');
        return ReflectionNoSuchMethodError(receiver, memberName, positionalArguments, namedArguments, kind);
      },
    },
    getters: {
      'receiver': (visitor, target) => D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError').receiver,
      'memberName': (visitor, target) => D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError').memberName,
      'positionalArguments': (visitor, target) => D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError').positionalArguments,
      'namedArguments': (visitor, target) => D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError').namedArguments,
      'kind': (visitor, target) => D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError').kind,
      'invocation': (visitor, target) => D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError').invocation,
      'stackTrace': (visitor, target) => D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError').stackTrace,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ReflectionNoSuchMethodError>(target, 'ReflectionNoSuchMethodError');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'ReflectionNoSuchMethodError(Object? receiver, String memberName, List<dynamic> positionalArguments, Map<Symbol, dynamic>? namedArguments, StringInvocationKind kind)',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'receiver': 'Object? get receiver',
      'memberName': 'String get memberName',
      'positionalArguments': 'List get positionalArguments',
      'namedArguments': 'Map<Symbol, dynamic>? get namedArguments',
      'kind': 'StringInvocationKind get kind',
      'invocation': 'StringInvocation get invocation',
      'stackTrace': 'StackTrace? get stackTrace',
    },
  );
}

// =============================================================================
// Mirror Bridge
// =============================================================================

BridgedClass _createMirrorBridge() {
  return BridgedClass(
    nativeType: Mirror,
    name: 'Mirror',
    isAssignable: (v) => v is Mirror,
    constructors: {
    },
  );
}

// =============================================================================
// DeclarationMirror Bridge
// =============================================================================

BridgedClass _createDeclarationMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.DeclarationMirror,
    name: 'DeclarationMirror',
    isAssignable: (v) => v is $tom_reflection_2.DeclarationMirror,
    constructors: {
    },
    getters: {
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.DeclarationMirror>(target, 'DeclarationMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.DeclarationMirror>(target, 'DeclarationMirror').qualifiedName,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.DeclarationMirror>(target, 'DeclarationMirror').owner,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.DeclarationMirror>(target, 'DeclarationMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.DeclarationMirror>(target, 'DeclarationMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.DeclarationMirror>(target, 'DeclarationMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.DeclarationMirror>(target, 'DeclarationMirror').metadata,
    },
    getterSignatures: {
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'owner': 'DeclarationMirror? get owner',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// ObjectMirror Bridge
// =============================================================================

BridgedClass _createObjectMirrorBridge() {
  return BridgedClass(
    nativeType: ObjectMirror,
    name: 'ObjectMirror',
    isAssignable: (v) => v is ObjectMirror,
    constructors: {
    },
    methods: {
      'invoke': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ObjectMirror>(target, 'ObjectMirror');
        D4.requireMinArgs(positional, 2, 'invoke');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoke');
        final positionalArguments = D4.getRequiredArg<List>(positional, 1, 'positionalArguments', 'invoke');
        final namedArguments = positional.length > 2
            ? D4.coerceMapOrNull<Symbol, dynamic>(positional[2], 'namedArguments')
            : null;
        return t.invoke(memberName, positionalArguments, namedArguments);
      },
      'invokeGetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ObjectMirror>(target, 'ObjectMirror');
        D4.requireMinArgs(positional, 1, 'invokeGetter');
        final getterName = D4.getRequiredArg<String>(positional, 0, 'getterName', 'invokeGetter');
        return t.invokeGetter(getterName);
      },
      'invokeSetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ObjectMirror>(target, 'ObjectMirror');
        D4.requireMinArgs(positional, 2, 'invokeSetter');
        final setterName = D4.getRequiredArg<String>(positional, 0, 'setterName', 'invokeSetter');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'invokeSetter');
        return t.invokeSetter(setterName, value);
      },
    },
    methodSignatures: {
      'invoke': 'Object? invoke(String memberName, List positionalArguments, [Map<Symbol, dynamic>? namedArguments])',
      'invokeGetter': 'Object? invokeGetter(String getterName)',
      'invokeSetter': 'Object? invokeSetter(String setterName, Object? value)',
    },
  );
}

// =============================================================================
// InstanceMirror Bridge
// =============================================================================

BridgedClass _createInstanceMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.InstanceMirror,
    name: 'InstanceMirror',
    isAssignable: (v) => v is $tom_reflection_2.InstanceMirror,
    constructors: {
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror').type,
      'hasReflectee': (visitor, target) => D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror').hasReflectee,
      'reflectee': (visitor, target) => D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror').reflectee,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror').hashCode,
    },
    methods: {
      'delegate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror');
        D4.requireMinArgs(positional, 1, 'delegate');
        final invocation = D4.getRequiredArg<Invocation>(positional, 0, 'invocation', 'delegate');
        return t.delegate(invocation);
      },
      'invoke': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror');
        D4.requireMinArgs(positional, 2, 'invoke');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoke');
        if (positional.length <= 1) {
          throw ArgumentError('invoke: Missing required argument "positionalArguments" at position 1');
        }
        final positionalArguments = D4.coerceList<dynamic>(positional[1], 'positionalArguments');
        final namedArguments = positional.length > 2
            ? D4.coerceMapOrNull<Symbol, dynamic>(positional[2], 'namedArguments')
            : null;
        return t.invoke(memberName, positionalArguments, namedArguments);
      },
      'invokeGetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror');
        D4.requireMinArgs(positional, 1, 'invokeGetter');
        final getterName = D4.getRequiredArg<String>(positional, 0, 'getterName', 'invokeGetter');
        return t.invokeGetter(getterName);
      },
      'invokeSetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror');
        D4.requireMinArgs(positional, 2, 'invokeSetter');
        final setterName = D4.getRequiredArg<String>(positional, 0, 'setterName', 'invokeSetter');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'invokeSetter');
        return t.invokeSetter(setterName, value);
      },
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.InstanceMirror>(target, 'InstanceMirror');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    methodSignatures: {
      'delegate': 'Object? delegate(Invocation invocation)',
      'invoke': 'Object? invoke(String memberName, List<dynamic> positionalArguments, [Map<Symbol, dynamic>? namedArguments])',
      'invokeGetter': 'Object? invokeGetter(String getterName)',
      'invokeSetter': 'Object? invokeSetter(String setterName, Object? value)',
    },
    getterSignatures: {
      'type': 'ClassMirror get type',
      'hasReflectee': 'bool get hasReflectee',
      'reflectee': 'Object? get reflectee',
      'hashCode': 'int get hashCode',
    },
  );
}

// =============================================================================
// ClosureMirror Bridge
// =============================================================================

BridgedClass _createClosureMirrorBridge() {
  return BridgedClass(
    nativeType: ClosureMirror,
    name: 'ClosureMirror',
    isAssignable: (v) => v is ClosureMirror,
    constructors: {
    },
    getters: {
      'function': (visitor, target) => D4.validateTarget<ClosureMirror>(target, 'ClosureMirror').function,
      'type': (visitor, target) => D4.validateTarget<ClosureMirror>(target, 'ClosureMirror').type,
      'hasReflectee': (visitor, target) => D4.validateTarget<ClosureMirror>(target, 'ClosureMirror').hasReflectee,
      'reflectee': (visitor, target) => D4.validateTarget<ClosureMirror>(target, 'ClosureMirror').reflectee,
      'hashCode': (visitor, target) => D4.validateTarget<ClosureMirror>(target, 'ClosureMirror').hashCode,
    },
    methods: {
      'apply': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ClosureMirror>(target, 'ClosureMirror');
        D4.requireMinArgs(positional, 1, 'apply');
        final positionalArguments = D4.getRequiredArg<List>(positional, 0, 'positionalArguments', 'apply');
        final namedArguments = positional.length > 1
            ? D4.coerceMapOrNull<Symbol, dynamic>(positional[1], 'namedArguments')
            : null;
        return t.apply(positionalArguments, namedArguments);
      },
      'delegate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ClosureMirror>(target, 'ClosureMirror');
        D4.requireMinArgs(positional, 1, 'delegate');
        final invocation = D4.getRequiredArg<Invocation>(positional, 0, 'invocation', 'delegate');
        return t.delegate(invocation);
      },
      'invoke': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ClosureMirror>(target, 'ClosureMirror');
        D4.requireMinArgs(positional, 2, 'invoke');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoke');
        if (positional.length <= 1) {
          throw ArgumentError('invoke: Missing required argument "positionalArguments" at position 1');
        }
        final positionalArguments = D4.coerceList<dynamic>(positional[1], 'positionalArguments');
        final namedArguments = positional.length > 2
            ? D4.coerceMapOrNull<Symbol, dynamic>(positional[2], 'namedArguments')
            : null;
        return t.invoke(memberName, positionalArguments, namedArguments);
      },
      'invokeGetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ClosureMirror>(target, 'ClosureMirror');
        D4.requireMinArgs(positional, 1, 'invokeGetter');
        final getterName = D4.getRequiredArg<String>(positional, 0, 'getterName', 'invokeGetter');
        return t.invokeGetter(getterName);
      },
      'invokeSetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ClosureMirror>(target, 'ClosureMirror');
        D4.requireMinArgs(positional, 2, 'invokeSetter');
        final setterName = D4.getRequiredArg<String>(positional, 0, 'setterName', 'invokeSetter');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'invokeSetter');
        return t.invokeSetter(setterName, value);
      },
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ClosureMirror>(target, 'ClosureMirror');
        final other = D4.getRequiredArg<Object>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    methodSignatures: {
      'apply': 'Object? apply(List positionalArguments, [Map<Symbol, dynamic>? namedArguments])',
      'delegate': 'Object? delegate(Invocation invocation)',
      'invoke': 'Object? invoke(String memberName, List<dynamic> positionalArguments, [Map<Symbol, dynamic>? namedArguments])',
      'invokeGetter': 'Object? invokeGetter(String getterName)',
      'invokeSetter': 'Object? invokeSetter(String setterName, Object? value)',
    },
    getterSignatures: {
      'function': 'MethodMirror get function',
      'type': 'ClassMirror<dynamic> get type',
      'hasReflectee': 'bool get hasReflectee',
      'reflectee': 'Object? get reflectee',
      'hashCode': 'int get hashCode',
    },
  );
}

// =============================================================================
// LibraryMirror Bridge
// =============================================================================

BridgedClass _createLibraryMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.LibraryMirror,
    name: 'LibraryMirror',
    isAssignable: (v) => v is $tom_reflection_2.LibraryMirror,
    constructors: {
    },
    getters: {
      'uri': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').uri,
      'declarations': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').declarations,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').hashCode,
      'libraryDependencies': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').libraryDependencies,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').owner,
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').qualifiedName,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror').metadata,
    },
    methods: {
      'invoke': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror');
        D4.requireMinArgs(positional, 2, 'invoke');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoke');
        if (positional.length <= 1) {
          throw ArgumentError('invoke: Missing required argument "positionalArguments" at position 1');
        }
        final positionalArguments = D4.coerceList<dynamic>(positional[1], 'positionalArguments');
        final namedArguments = positional.length > 2
            ? D4.coerceMapOrNull<Symbol, dynamic>(positional[2], 'namedArguments')
            : null;
        return t.invoke(memberName, positionalArguments, namedArguments);
      },
      'invokeGetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror');
        D4.requireMinArgs(positional, 1, 'invokeGetter');
        final getterName = D4.getRequiredArg<String>(positional, 0, 'getterName', 'invokeGetter');
        return t.invokeGetter(getterName);
      },
      'invokeSetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror');
        D4.requireMinArgs(positional, 2, 'invokeSetter');
        final setterName = D4.getRequiredArg<String>(positional, 0, 'setterName', 'invokeSetter');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'invokeSetter');
        return t.invokeSetter(setterName, value);
      },
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.LibraryMirror>(target, 'LibraryMirror');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    methodSignatures: {
      'invoke': 'Object? invoke(String memberName, List<dynamic> positionalArguments, [Map<Symbol, dynamic>? namedArguments])',
      'invokeGetter': 'Object? invokeGetter(String getterName)',
      'invokeSetter': 'Object? invokeSetter(String setterName, Object? value)',
    },
    getterSignatures: {
      'uri': 'Uri get uri',
      'declarations': 'Map<String, DeclarationMirror> get declarations',
      'hashCode': 'int get hashCode',
      'libraryDependencies': 'List<LibraryDependencyMirror> get libraryDependencies',
      'owner': 'Null get owner',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// LibraryDependencyMirror Bridge
// =============================================================================

BridgedClass _createLibraryDependencyMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.LibraryDependencyMirror,
    name: 'LibraryDependencyMirror',
    isAssignable: (v) => v is $tom_reflection_2.LibraryDependencyMirror,
    constructors: {
    },
    getters: {
      'isImport': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').isImport,
      'isExport': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').isExport,
      'isDeferred': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').isDeferred,
      'sourceLibrary': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').sourceLibrary,
      'targetLibrary': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').targetLibrary,
      'prefix': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').prefix,
      'combinators': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').combinators,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.LibraryDependencyMirror>(target, 'LibraryDependencyMirror').metadata,
    },
    getterSignatures: {
      'isImport': 'bool get isImport',
      'isExport': 'bool get isExport',
      'isDeferred': 'bool get isDeferred',
      'sourceLibrary': 'LibraryMirror get sourceLibrary',
      'targetLibrary': 'LibraryMirror get targetLibrary',
      'prefix': 'String get prefix',
      'combinators': 'List<CombinatorMirror> get combinators',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object?> get metadata',
    },
  );
}

// =============================================================================
// CombinatorMirror Bridge
// =============================================================================

BridgedClass _createCombinatorMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.CombinatorMirror,
    name: 'CombinatorMirror',
    isAssignable: (v) => v is $tom_reflection_2.CombinatorMirror,
    constructors: {
    },
    getters: {
      'identifiers': (visitor, target) => D4.validateTarget<$tom_reflection_2.CombinatorMirror>(target, 'CombinatorMirror').identifiers,
      'isShow': (visitor, target) => D4.validateTarget<$tom_reflection_2.CombinatorMirror>(target, 'CombinatorMirror').isShow,
      'isHide': (visitor, target) => D4.validateTarget<$tom_reflection_2.CombinatorMirror>(target, 'CombinatorMirror').isHide,
    },
    getterSignatures: {
      'identifiers': 'List<String> get identifiers',
      'isShow': 'bool get isShow',
      'isHide': 'bool get isHide',
    },
  );
}

// =============================================================================
// TypeMirror Bridge
// =============================================================================

BridgedClass _createTypeMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.TypeMirror,
    name: 'TypeMirror',
    isAssignable: (v) => v is $tom_reflection_2.TypeMirror,
    constructors: {
    },
    getters: {
      'reflectedGenericType': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').reflectedGenericType,
      'hasReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').hasReflectedType,
      'reflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').reflectedType,
      'typeVariables': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').typeVariables,
      'typeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').typeArguments,
      'reflectedTypeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').reflectedTypeArguments,
      'isOriginalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').isOriginalDeclaration,
      'originalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').originalDeclaration,
      'isNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').isNullable,
      'isNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').isNonNullable,
      'isPotentiallyNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').isPotentiallyNullable,
      'isPotentiallyNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').isPotentiallyNonNullable,
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').qualifiedName,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').owner,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror').metadata,
    },
    methods: {
      'createList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createList();
      },
      'createSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createSet();
      },
      'createValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createValuedMap();
      },
      'createKeyedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createKeyedMap();
      },
      'createKeyedValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createKeyedValuedMap();
      },
      'isInstanceOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        D4.requireMinArgs(positional, 1, 'isInstanceOf');
        final object = D4.getRequiredArg<Object?>(positional, 0, 'object', 'isInstanceOf');
        return t.isInstanceOf(object);
      },
      'isSubtype': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.isSubtype();
      },
      'createNullableList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createNullableList();
      },
      'createNullableSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createNullableSet();
      },
      'createNullableValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        return t.createNullableValuedMap();
      },
      'isSubtypeOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        D4.requireMinArgs(positional, 1, 'isSubtypeOf');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror>(positional, 0, 'other', 'isSubtypeOf');
        return t.isSubtypeOf(other);
      },
      'isAssignableTo': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeMirror>(target, 'TypeMirror');
        D4.requireMinArgs(positional, 1, 'isAssignableTo');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror>(positional, 0, 'other', 'isAssignableTo');
        return t.isAssignableTo(other);
      },
    },
    methodSignatures: {
      'createList': 'List<T> createList()',
      'createSet': 'Set<T> createSet()',
      'createValuedMap': 'Map<K, T> createValuedMap()',
      'createKeyedMap': 'Map<T, V> createKeyedMap()',
      'createKeyedValuedMap': 'Map<T, T> createKeyedValuedMap()',
      'isInstanceOf': 'bool isInstanceOf(Object? object)',
      'isSubtype': 'bool isSubtype()',
      'createNullableList': 'List<T?> createNullableList()',
      'createNullableSet': 'Set<T?> createNullableSet()',
      'createNullableValuedMap': 'Map<K, T?> createNullableValuedMap()',
      'isSubtypeOf': 'bool isSubtypeOf(TypeMirror other)',
      'isAssignableTo': 'bool isAssignableTo(TypeMirror other)',
    },
    getterSignatures: {
      'reflectedGenericType': 'Type get reflectedGenericType',
      'hasReflectedType': 'bool get hasReflectedType',
      'reflectedType': 'Type get reflectedType',
      'typeVariables': 'List<TypeVariableMirror> get typeVariables',
      'typeArguments': 'List<TypeMirror> get typeArguments',
      'reflectedTypeArguments': 'List<Type> get reflectedTypeArguments',
      'isOriginalDeclaration': 'bool get isOriginalDeclaration',
      'originalDeclaration': 'TypeMirror get originalDeclaration',
      'isNullable': 'bool get isNullable',
      'isNonNullable': 'bool get isNonNullable',
      'isPotentiallyNullable': 'bool get isPotentiallyNullable',
      'isPotentiallyNonNullable': 'bool get isPotentiallyNonNullable',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'owner': 'DeclarationMirror? get owner',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// ClassMirror Bridge
// =============================================================================

BridgedClass _createClassMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.ClassMirror,
    name: 'ClassMirror',
    isAssignable: (v) => v is $tom_reflection_2.ClassMirror,
    constructors: {
    },
    getters: {
      'superclass': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').superclass,
      'superinterfaces': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').superinterfaces,
      'isAbstract': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isAbstract,
      'isEnum': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isEnum,
      'declarations': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').declarations,
      'instanceMembers': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').instanceMembers,
      'staticMembers': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').staticMembers,
      'mixin': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').mixin,
      'hasDynamicReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').hasDynamicReflectedType,
      'dynamicReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').dynamicReflectedType,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').hashCode,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').owner,
      'reflectedGenericType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').reflectedGenericType,
      'hasReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').hasReflectedType,
      'reflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').reflectedType,
      'typeVariables': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').typeVariables,
      'typeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').typeArguments,
      'reflectedTypeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').reflectedTypeArguments,
      'isOriginalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isOriginalDeclaration,
      'originalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').originalDeclaration,
      'isNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isNullable,
      'isNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isNonNullable,
      'isPotentiallyNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isPotentiallyNullable,
      'isPotentiallyNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isPotentiallyNonNullable,
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').qualifiedName,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror').metadata,
    },
    methods: {
      'createList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createList();
      },
      'createSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createSet();
      },
      'createValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createValuedMap();
      },
      'createKeyedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createKeyedMap();
      },
      'createKeyedValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createKeyedValuedMap();
      },
      'newInstance': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 2, 'newInstance');
        final constructorName = D4.getRequiredArg<String>(positional, 0, 'constructorName', 'newInstance');
        final positionalArguments = D4.getRequiredArg<List>(positional, 1, 'positionalArguments', 'newInstance');
        final namedArguments = positional.length > 2
            ? D4.coerceMap<Symbol, dynamic>(positional[2], 'namedArguments')
            : <Symbol, dynamic>{};
        return t.newInstance(constructorName, positionalArguments, namedArguments);
      },
      'isSubclassOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 1, 'isSubclassOf');
        final other = D4.getRequiredArg<$tom_reflection_2.ClassMirror>(positional, 0, 'other', 'isSubclassOf');
        return t.isSubclassOf(other);
      },
      'invoker': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 1, 'invoker');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoker');
        return t.invoker(memberName);
      },
      'isInstanceOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 1, 'isInstanceOf');
        final object = D4.getRequiredArg<Object?>(positional, 0, 'object', 'isInstanceOf');
        return t.isInstanceOf(object);
      },
      'isSubtype': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.isSubtype();
      },
      'createNullableList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createNullableList();
      },
      'createNullableSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createNullableSet();
      },
      'createNullableValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        return t.createNullableValuedMap();
      },
      'isSubtypeOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 1, 'isSubtypeOf');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isSubtypeOf');
        return t.isSubtypeOf(other);
      },
      'isAssignableTo': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 1, 'isAssignableTo');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isAssignableTo');
        return t.isAssignableTo(other);
      },
      'invoke': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 2, 'invoke');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoke');
        if (positional.length <= 1) {
          throw ArgumentError('invoke: Missing required argument "positionalArguments" at position 1');
        }
        final positionalArguments = D4.coerceList<dynamic>(positional[1], 'positionalArguments');
        final namedArguments = positional.length > 2
            ? D4.coerceMapOrNull<Symbol, dynamic>(positional[2], 'namedArguments')
            : null;
        return t.invoke(memberName, positionalArguments, namedArguments);
      },
      'invokeGetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 1, 'invokeGetter');
        final getterName = D4.getRequiredArg<String>(positional, 0, 'getterName', 'invokeGetter');
        return t.invokeGetter(getterName);
      },
      'invokeSetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        D4.requireMinArgs(positional, 2, 'invokeSetter');
        final setterName = D4.getRequiredArg<String>(positional, 0, 'setterName', 'invokeSetter');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'invokeSetter');
        return t.invokeSetter(setterName, value);
      },
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ClassMirror>(target, 'ClassMirror');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    methodSignatures: {
      'createList': 'List<T> createList()',
      'createSet': 'Set<T> createSet()',
      'createValuedMap': 'Map<K, T> createValuedMap()',
      'createKeyedMap': 'Map<T, V> createKeyedMap()',
      'createKeyedValuedMap': 'Map<T, T> createKeyedValuedMap()',
      'newInstance': 'Object newInstance(String constructorName, List positionalArguments, [Map<Symbol, dynamic> namedArguments])',
      'isSubclassOf': 'bool isSubclassOf(ClassMirror other)',
      'invoker': 'Function invoker(String memberName)',
      'isInstanceOf': 'bool isInstanceOf(Object? object)',
      'isSubtype': 'bool isSubtype()',
      'createNullableList': 'List<T?> createNullableList()',
      'createNullableSet': 'Set<T?> createNullableSet()',
      'createNullableValuedMap': 'Map<K, T?> createNullableValuedMap()',
      'isSubtypeOf': 'bool isSubtypeOf(TypeMirror<dynamic> other)',
      'isAssignableTo': 'bool isAssignableTo(TypeMirror<dynamic> other)',
      'invoke': 'Object? invoke(String memberName, List<dynamic> positionalArguments, [Map<Symbol, dynamic>? namedArguments])',
      'invokeGetter': 'Object? invokeGetter(String getterName)',
      'invokeSetter': 'Object? invokeSetter(String setterName, Object? value)',
    },
    getterSignatures: {
      'superclass': 'ClassMirror? get superclass',
      'superinterfaces': 'List<ClassMirror> get superinterfaces',
      'isAbstract': 'bool get isAbstract',
      'isEnum': 'bool get isEnum',
      'declarations': 'Map<String, DeclarationMirror> get declarations',
      'instanceMembers': 'Map<String, MethodMirror> get instanceMembers',
      'staticMembers': 'Map<String, MethodMirror> get staticMembers',
      'mixin': 'ClassMirror get mixin',
      'hasDynamicReflectedType': 'bool get hasDynamicReflectedType',
      'dynamicReflectedType': 'Type get dynamicReflectedType',
      'hashCode': 'int get hashCode',
      'owner': 'DeclarationMirror get owner',
      'reflectedGenericType': 'Type get reflectedGenericType',
      'hasReflectedType': 'bool get hasReflectedType',
      'reflectedType': 'Type get reflectedType',
      'typeVariables': 'List<TypeVariableMirror<dynamic>> get typeVariables',
      'typeArguments': 'List<TypeMirror<dynamic>> get typeArguments',
      'reflectedTypeArguments': 'List<Type> get reflectedTypeArguments',
      'isOriginalDeclaration': 'bool get isOriginalDeclaration',
      'originalDeclaration': 'TypeMirror<dynamic> get originalDeclaration',
      'isNullable': 'bool get isNullable',
      'isNonNullable': 'bool get isNonNullable',
      'isPotentiallyNullable': 'bool get isPotentiallyNullable',
      'isPotentiallyNonNullable': 'bool get isPotentiallyNonNullable',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// FunctionTypeMirror Bridge
// =============================================================================

BridgedClass _createFunctionTypeMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.FunctionTypeMirror,
    name: 'FunctionTypeMirror',
    isAssignable: (v) => v is $tom_reflection_2.FunctionTypeMirror,
    constructors: {
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').returnType,
      'parameters': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').parameters,
      'callMethod': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').callMethod,
      'superclass': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').superclass,
      'superinterfaces': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').superinterfaces,
      'isAbstract': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isAbstract,
      'isEnum': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isEnum,
      'declarations': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').declarations,
      'instanceMembers': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').instanceMembers,
      'staticMembers': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').staticMembers,
      'mixin': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').mixin,
      'hasDynamicReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').hasDynamicReflectedType,
      'dynamicReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').dynamicReflectedType,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').hashCode,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').owner,
      'reflectedGenericType': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').reflectedGenericType,
      'hasReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').hasReflectedType,
      'reflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').reflectedType,
      'typeVariables': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').typeVariables,
      'typeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').typeArguments,
      'reflectedTypeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').reflectedTypeArguments,
      'isOriginalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isOriginalDeclaration,
      'originalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').originalDeclaration,
      'isNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isNullable,
      'isNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isNonNullable,
      'isPotentiallyNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isPotentiallyNullable,
      'isPotentiallyNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isPotentiallyNonNullable,
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').qualifiedName,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror').metadata,
    },
    methods: {
      'createList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createList();
      },
      'createSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createSet();
      },
      'createValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createValuedMap();
      },
      'createKeyedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createKeyedMap();
      },
      'createKeyedValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createKeyedValuedMap();
      },
      'newInstance': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 2, 'newInstance');
        final constructorName = D4.getRequiredArg<String>(positional, 0, 'constructorName', 'newInstance');
        if (positional.length <= 1) {
          throw ArgumentError('newInstance: Missing required argument "positionalArguments" at position 1');
        }
        final positionalArguments = D4.coerceList<dynamic>(positional[1], 'positionalArguments');
        final namedArguments = positional.length > 2
            ? D4.coerceMap<Symbol, dynamic>(positional[2], 'namedArguments')
            : <Symbol, dynamic>{};
        return t.newInstance(constructorName, positionalArguments, namedArguments);
      },
      'isSubclassOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 1, 'isSubclassOf');
        final other = D4.getRequiredArg<$tom_reflection_2.ClassMirror<dynamic>>(positional, 0, 'other', 'isSubclassOf');
        return t.isSubclassOf(other);
      },
      'invoker': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 1, 'invoker');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoker');
        return t.invoker(memberName);
      },
      'isInstanceOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 1, 'isInstanceOf');
        final object = D4.getRequiredArg<Object?>(positional, 0, 'object', 'isInstanceOf');
        return t.isInstanceOf(object);
      },
      'isSubtype': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.isSubtype();
      },
      'createNullableList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createNullableList();
      },
      'createNullableSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createNullableSet();
      },
      'createNullableValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        return t.createNullableValuedMap();
      },
      'isSubtypeOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 1, 'isSubtypeOf');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isSubtypeOf');
        return t.isSubtypeOf(other);
      },
      'isAssignableTo': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 1, 'isAssignableTo');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isAssignableTo');
        return t.isAssignableTo(other);
      },
      'invoke': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 2, 'invoke');
        final memberName = D4.getRequiredArg<String>(positional, 0, 'memberName', 'invoke');
        if (positional.length <= 1) {
          throw ArgumentError('invoke: Missing required argument "positionalArguments" at position 1');
        }
        final positionalArguments = D4.coerceList<dynamic>(positional[1], 'positionalArguments');
        final namedArguments = positional.length > 2
            ? D4.coerceMapOrNull<Symbol, dynamic>(positional[2], 'namedArguments')
            : null;
        return t.invoke(memberName, positionalArguments, namedArguments);
      },
      'invokeGetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 1, 'invokeGetter');
        final getterName = D4.getRequiredArg<String>(positional, 0, 'getterName', 'invokeGetter');
        return t.invokeGetter(getterName);
      },
      'invokeSetter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        D4.requireMinArgs(positional, 2, 'invokeSetter');
        final setterName = D4.getRequiredArg<String>(positional, 0, 'setterName', 'invokeSetter');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'invokeSetter');
        return t.invokeSetter(setterName, value);
      },
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.FunctionTypeMirror>(target, 'FunctionTypeMirror');
        final other = D4.getRequiredArg<Object>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    methodSignatures: {
      'createList': 'List<T> createList()',
      'createSet': 'Set<T> createSet()',
      'createValuedMap': 'Map<K, T> createValuedMap()',
      'createKeyedMap': 'Map<T, V> createKeyedMap()',
      'createKeyedValuedMap': 'Map<T, T> createKeyedValuedMap()',
      'newInstance': 'Object newInstance(String constructorName, List<dynamic> positionalArguments, [Map<Symbol, dynamic> namedArguments])',
      'isSubclassOf': 'bool isSubclassOf(ClassMirror<dynamic> other)',
      'invoker': 'Function invoker(String memberName)',
      'isInstanceOf': 'bool isInstanceOf(Object? object)',
      'isSubtype': 'bool isSubtype()',
      'createNullableList': 'List<T?> createNullableList()',
      'createNullableSet': 'Set<T?> createNullableSet()',
      'createNullableValuedMap': 'Map<K, T?> createNullableValuedMap()',
      'isSubtypeOf': 'bool isSubtypeOf(TypeMirror<dynamic> other)',
      'isAssignableTo': 'bool isAssignableTo(TypeMirror<dynamic> other)',
      'invoke': 'Object? invoke(String memberName, List<dynamic> positionalArguments, [Map<Symbol, dynamic>? namedArguments])',
      'invokeGetter': 'Object? invokeGetter(String getterName)',
      'invokeSetter': 'Object? invokeSetter(String setterName, Object? value)',
    },
    getterSignatures: {
      'returnType': 'TypeMirror get returnType',
      'parameters': 'List<ParameterMirror> get parameters',
      'callMethod': 'MethodMirror get callMethod',
      'superclass': 'ClassMirror<dynamic> get superclass',
      'superinterfaces': 'List<ClassMirror<dynamic>> get superinterfaces',
      'isAbstract': 'bool get isAbstract',
      'isEnum': 'bool get isEnum',
      'declarations': 'Map<String, DeclarationMirror> get declarations',
      'instanceMembers': 'Map<String, MethodMirror> get instanceMembers',
      'staticMembers': 'Map<String, MethodMirror> get staticMembers',
      'mixin': 'ClassMirror<dynamic> get mixin',
      'hasDynamicReflectedType': 'bool get hasDynamicReflectedType',
      'dynamicReflectedType': 'Type get dynamicReflectedType',
      'hashCode': 'int get hashCode',
      'owner': 'DeclarationMirror get owner',
      'reflectedGenericType': 'Type get reflectedGenericType',
      'hasReflectedType': 'bool get hasReflectedType',
      'reflectedType': 'Type get reflectedType',
      'typeVariables': 'List<TypeVariableMirror<dynamic>> get typeVariables',
      'typeArguments': 'List<TypeMirror<dynamic>> get typeArguments',
      'reflectedTypeArguments': 'List<Type> get reflectedTypeArguments',
      'isOriginalDeclaration': 'bool get isOriginalDeclaration',
      'originalDeclaration': 'TypeMirror<dynamic> get originalDeclaration',
      'isNullable': 'bool get isNullable',
      'isNonNullable': 'bool get isNonNullable',
      'isPotentiallyNullable': 'bool get isPotentiallyNullable',
      'isPotentiallyNonNullable': 'bool get isPotentiallyNonNullable',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// TypeVariableMirror Bridge
// =============================================================================

BridgedClass _createTypeVariableMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.TypeVariableMirror,
    name: 'TypeVariableMirror',
    isAssignable: (v) => v is $tom_reflection_2.TypeVariableMirror,
    constructors: {
    },
    getters: {
      'reflectedGenericType': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').reflectedGenericType,
      'hasReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').hasReflectedType,
      'reflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').reflectedType,
      'typeVariables': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').typeVariables,
      'typeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').typeArguments,
      'reflectedTypeArguments': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').reflectedTypeArguments,
      'isOriginalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isOriginalDeclaration,
      'originalDeclaration': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').originalDeclaration,
      'isNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isNullable,
      'isNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isNonNullable,
      'isPotentiallyNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isPotentiallyNullable,
      'isPotentiallyNonNullable': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isPotentiallyNonNullable,
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').qualifiedName,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').owner,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').metadata,
      'upperBound': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').upperBound,
      'isStatic': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').isStatic,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror').hashCode,
    },
    methods: {
      'createList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createList();
      },
      'createSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createSet();
      },
      'createValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createValuedMap();
      },
      'createKeyedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createKeyedMap();
      },
      'createKeyedValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createKeyedValuedMap();
      },
      'isInstanceOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        D4.requireMinArgs(positional, 1, 'isInstanceOf');
        final object = D4.getRequiredArg<Object?>(positional, 0, 'object', 'isInstanceOf');
        return t.isInstanceOf(object);
      },
      'isSubtype': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.isSubtype();
      },
      'createNullableList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createNullableList();
      },
      'createNullableSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createNullableSet();
      },
      'createNullableValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        return t.createNullableValuedMap();
      },
      'isSubtypeOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        D4.requireMinArgs(positional, 1, 'isSubtypeOf');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isSubtypeOf');
        return t.isSubtypeOf(other);
      },
      'isAssignableTo': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        D4.requireMinArgs(positional, 1, 'isAssignableTo');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isAssignableTo');
        return t.isAssignableTo(other);
      },
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.TypeVariableMirror>(target, 'TypeVariableMirror');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    methodSignatures: {
      'createList': 'List<T> createList()',
      'createSet': 'Set<T> createSet()',
      'createValuedMap': 'Map<K, T> createValuedMap()',
      'createKeyedMap': 'Map<T, V> createKeyedMap()',
      'createKeyedValuedMap': 'Map<T, T> createKeyedValuedMap()',
      'isInstanceOf': 'bool isInstanceOf(Object? object)',
      'isSubtype': 'bool isSubtype()',
      'createNullableList': 'List<T?> createNullableList()',
      'createNullableSet': 'Set<T?> createNullableSet()',
      'createNullableValuedMap': 'Map<K, T?> createNullableValuedMap()',
      'isSubtypeOf': 'bool isSubtypeOf(TypeMirror<dynamic> other)',
      'isAssignableTo': 'bool isAssignableTo(TypeMirror<dynamic> other)',
    },
    getterSignatures: {
      'reflectedGenericType': 'Type get reflectedGenericType',
      'hasReflectedType': 'bool get hasReflectedType',
      'reflectedType': 'Type get reflectedType',
      'typeVariables': 'List<TypeVariableMirror<dynamic>> get typeVariables',
      'typeArguments': 'List<TypeMirror<dynamic>> get typeArguments',
      'reflectedTypeArguments': 'List<Type> get reflectedTypeArguments',
      'isOriginalDeclaration': 'bool get isOriginalDeclaration',
      'originalDeclaration': 'TypeMirror<dynamic> get originalDeclaration',
      'isNullable': 'bool get isNullable',
      'isNonNullable': 'bool get isNonNullable',
      'isPotentiallyNullable': 'bool get isPotentiallyNullable',
      'isPotentiallyNonNullable': 'bool get isPotentiallyNonNullable',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'owner': 'DeclarationMirror? get owner',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
      'upperBound': 'TypeMirror get upperBound',
      'isStatic': 'bool get isStatic',
      'hashCode': 'int get hashCode',
    },
  );
}

// =============================================================================
// TypedefMirror Bridge
// =============================================================================

BridgedClass _createTypedefMirrorBridge() {
  return BridgedClass(
    nativeType: TypedefMirror,
    name: 'TypedefMirror',
    isAssignable: (v) => v is TypedefMirror,
    constructors: {
    },
    getters: {
      'referent': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').referent,
      'reflectedGenericType': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').reflectedGenericType,
      'hasReflectedType': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').hasReflectedType,
      'reflectedType': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').reflectedType,
      'typeVariables': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').typeVariables,
      'typeArguments': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').typeArguments,
      'reflectedTypeArguments': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').reflectedTypeArguments,
      'isOriginalDeclaration': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').isOriginalDeclaration,
      'originalDeclaration': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').originalDeclaration,
      'isNullable': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').isNullable,
      'isNonNullable': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').isNonNullable,
      'isPotentiallyNullable': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').isPotentiallyNullable,
      'isPotentiallyNonNullable': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').isPotentiallyNonNullable,
      'simpleName': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').qualifiedName,
      'owner': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').owner,
      'isPrivate': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<TypedefMirror>(target, 'TypedefMirror').metadata,
    },
    methods: {
      'createList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createList();
      },
      'createSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createSet();
      },
      'createValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createValuedMap();
      },
      'createKeyedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createKeyedMap();
      },
      'createKeyedValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createKeyedValuedMap();
      },
      'isInstanceOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        D4.requireMinArgs(positional, 1, 'isInstanceOf');
        final object = D4.getRequiredArg<Object?>(positional, 0, 'object', 'isInstanceOf');
        return t.isInstanceOf(object);
      },
      'isSubtype': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.isSubtype();
      },
      'createNullableList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createNullableList();
      },
      'createNullableSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createNullableSet();
      },
      'createNullableValuedMap': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        return t.createNullableValuedMap();
      },
      'isSubtypeOf': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        D4.requireMinArgs(positional, 1, 'isSubtypeOf');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isSubtypeOf');
        return t.isSubtypeOf(other);
      },
      'isAssignableTo': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TypedefMirror>(target, 'TypedefMirror');
        D4.requireMinArgs(positional, 1, 'isAssignableTo');
        final other = D4.getRequiredArg<$tom_reflection_2.TypeMirror<dynamic>>(positional, 0, 'other', 'isAssignableTo');
        return t.isAssignableTo(other);
      },
    },
    methodSignatures: {
      'createList': 'List<T> createList()',
      'createSet': 'Set<T> createSet()',
      'createValuedMap': 'Map<K, T> createValuedMap()',
      'createKeyedMap': 'Map<T, V> createKeyedMap()',
      'createKeyedValuedMap': 'Map<T, T> createKeyedValuedMap()',
      'isInstanceOf': 'bool isInstanceOf(Object? object)',
      'isSubtype': 'bool isSubtype()',
      'createNullableList': 'List<T?> createNullableList()',
      'createNullableSet': 'Set<T?> createNullableSet()',
      'createNullableValuedMap': 'Map<K, T?> createNullableValuedMap()',
      'isSubtypeOf': 'bool isSubtypeOf(TypeMirror<dynamic> other)',
      'isAssignableTo': 'bool isAssignableTo(TypeMirror<dynamic> other)',
    },
    getterSignatures: {
      'referent': 'FunctionTypeMirror get referent',
      'reflectedGenericType': 'Type get reflectedGenericType',
      'hasReflectedType': 'bool get hasReflectedType',
      'reflectedType': 'Type get reflectedType',
      'typeVariables': 'List<TypeVariableMirror<dynamic>> get typeVariables',
      'typeArguments': 'List<TypeMirror<dynamic>> get typeArguments',
      'reflectedTypeArguments': 'List<Type> get reflectedTypeArguments',
      'isOriginalDeclaration': 'bool get isOriginalDeclaration',
      'originalDeclaration': 'TypeMirror<dynamic> get originalDeclaration',
      'isNullable': 'bool get isNullable',
      'isNonNullable': 'bool get isNonNullable',
      'isPotentiallyNullable': 'bool get isPotentiallyNullable',
      'isPotentiallyNonNullable': 'bool get isPotentiallyNonNullable',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'owner': 'DeclarationMirror? get owner',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// MethodMirror Bridge
// =============================================================================

BridgedClass _createMethodMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.MethodMirror,
    name: 'MethodMirror',
    isAssignable: (v) => v is $tom_reflection_2.MethodMirror,
    constructors: {
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').returnType,
      'hasReflectedReturnType': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').hasReflectedReturnType,
      'reflectedReturnType': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').reflectedReturnType,
      'hasDynamicReflectedReturnType': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').hasDynamicReflectedReturnType,
      'dynamicReflectedReturnType': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').dynamicReflectedReturnType,
      'source': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').source,
      'parameters': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').parameters,
      'isStatic': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isStatic,
      'isAbstract': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isAbstract,
      'isSynthetic': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isSynthetic,
      'isRegularMethod': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isRegularMethod,
      'isOperator': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isOperator,
      'isGetter': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isGetter,
      'isSetter': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isSetter,
      'isConstructor': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isConstructor,
      'constructorName': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').constructorName,
      'isConstConstructor': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isConstConstructor,
      'isGenerativeConstructor': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isGenerativeConstructor,
      'isRedirectingConstructor': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isRedirectingConstructor,
      'isFactoryConstructor': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isFactoryConstructor,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').hashCode,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').owner,
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').qualifiedName,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror').metadata,
    },
    methods: {
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.MethodMirror>(target, 'MethodMirror');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    getterSignatures: {
      'returnType': 'TypeMirror get returnType',
      'hasReflectedReturnType': 'bool get hasReflectedReturnType',
      'reflectedReturnType': 'Type get reflectedReturnType',
      'hasDynamicReflectedReturnType': 'bool get hasDynamicReflectedReturnType',
      'dynamicReflectedReturnType': 'Type get dynamicReflectedReturnType',
      'source': 'String? get source',
      'parameters': 'List<ParameterMirror> get parameters',
      'isStatic': 'bool get isStatic',
      'isAbstract': 'bool get isAbstract',
      'isSynthetic': 'bool get isSynthetic',
      'isRegularMethod': 'bool get isRegularMethod',
      'isOperator': 'bool get isOperator',
      'isGetter': 'bool get isGetter',
      'isSetter': 'bool get isSetter',
      'isConstructor': 'bool get isConstructor',
      'constructorName': 'String get constructorName',
      'isConstConstructor': 'bool get isConstConstructor',
      'isGenerativeConstructor': 'bool get isGenerativeConstructor',
      'isRedirectingConstructor': 'bool get isRedirectingConstructor',
      'isFactoryConstructor': 'bool get isFactoryConstructor',
      'hashCode': 'int get hashCode',
      'owner': 'DeclarationMirror get owner',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// VariableMirror Bridge
// =============================================================================

BridgedClass _createVariableMirrorBridge() {
  return BridgedClass(
    nativeType: VariableMirror,
    name: 'VariableMirror',
    isAssignable: (v) => v is VariableMirror,
    constructors: {
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').type,
      'hasReflectedType': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').hasReflectedType,
      'reflectedType': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').reflectedType,
      'hasDynamicReflectedType': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').hasDynamicReflectedType,
      'dynamicReflectedType': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').dynamicReflectedType,
      'isStatic': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').isStatic,
      'isFinal': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').isFinal,
      'isConst': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').isConst,
      'hashCode': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').hashCode,
      'owner': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').owner,
      'simpleName': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').qualifiedName,
      'isPrivate': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<VariableMirror>(target, 'VariableMirror').metadata,
    },
    methods: {
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<VariableMirror>(target, 'VariableMirror');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    getterSignatures: {
      'type': 'TypeMirror get type',
      'hasReflectedType': 'bool get hasReflectedType',
      'reflectedType': 'Type get reflectedType',
      'hasDynamicReflectedType': 'bool get hasDynamicReflectedType',
      'dynamicReflectedType': 'Type get dynamicReflectedType',
      'isStatic': 'bool get isStatic',
      'isFinal': 'bool get isFinal',
      'isConst': 'bool get isConst',
      'hashCode': 'int get hashCode',
      'owner': 'DeclarationMirror get owner',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// ParameterMirror Bridge
// =============================================================================

BridgedClass _createParameterMirrorBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.ParameterMirror,
    name: 'ParameterMirror',
    isAssignable: (v) => v is $tom_reflection_2.ParameterMirror,
    constructors: {
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').type,
      'isOptional': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').isOptional,
      'isNamed': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').isNamed,
      'hasDefaultValue': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').hasDefaultValue,
      'defaultValue': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').defaultValue,
      'hasReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').hasReflectedType,
      'reflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').reflectedType,
      'hasDynamicReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').hasDynamicReflectedType,
      'dynamicReflectedType': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').dynamicReflectedType,
      'isStatic': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').isStatic,
      'isFinal': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').isFinal,
      'isConst': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').isConst,
      'hashCode': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').hashCode,
      'owner': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').owner,
      'simpleName': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').simpleName,
      'qualifiedName': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').qualifiedName,
      'isPrivate': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').isPrivate,
      'isTopLevel': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').isTopLevel,
      'location': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').location,
      'metadata': (visitor, target) => D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror').metadata,
    },
    methods: {
      '==': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_reflection_2.ParameterMirror>(target, 'ParameterMirror');
        final other = D4.getRequiredArg<Object>(positional, 0, 'other', 'operator==');
        return t == other;
      },
    },
    getterSignatures: {
      'type': 'TypeMirror get type',
      'isOptional': 'bool get isOptional',
      'isNamed': 'bool get isNamed',
      'hasDefaultValue': 'bool get hasDefaultValue',
      'defaultValue': 'Object? get defaultValue',
      'hasReflectedType': 'bool get hasReflectedType',
      'reflectedType': 'Type get reflectedType',
      'hasDynamicReflectedType': 'bool get hasDynamicReflectedType',
      'dynamicReflectedType': 'Type get dynamicReflectedType',
      'isStatic': 'bool get isStatic',
      'isFinal': 'bool get isFinal',
      'isConst': 'bool get isConst',
      'hashCode': 'int get hashCode',
      'owner': 'DeclarationMirror get owner',
      'simpleName': 'String get simpleName',
      'qualifiedName': 'String get qualifiedName',
      'isPrivate': 'bool get isPrivate',
      'isTopLevel': 'bool get isTopLevel',
      'location': 'SourceLocation get location',
      'metadata': 'List<Object> get metadata',
    },
  );
}

// =============================================================================
// SourceLocation Bridge
// =============================================================================

BridgedClass _createSourceLocationBridge() {
  return BridgedClass(
    nativeType: $tom_reflection_2.SourceLocation,
    name: 'SourceLocation',
    isAssignable: (v) => v is $tom_reflection_2.SourceLocation,
    constructors: {
    },
    getters: {
      'line': (visitor, target) => D4.validateTarget<$tom_reflection_2.SourceLocation>(target, 'SourceLocation').line,
      'column': (visitor, target) => D4.validateTarget<$tom_reflection_2.SourceLocation>(target, 'SourceLocation').column,
      'sourceUri': (visitor, target) => D4.validateTarget<$tom_reflection_2.SourceLocation>(target, 'SourceLocation').sourceUri,
    },
    getterSignatures: {
      'line': 'int get line',
      'column': 'int get column',
      'sourceUri': 'Uri get sourceUri',
    },
  );
}

// =============================================================================
// Comment Bridge
// =============================================================================

BridgedClass _createCommentBridge() {
  return BridgedClass(
    nativeType: Comment,
    name: 'Comment',
    isAssignable: (v) => v is Comment,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'Comment');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'Comment');
        final trimmedText = D4.getRequiredArg<String>(positional, 1, 'trimmedText', 'Comment');
        final isDocComment = D4.getRequiredArg<bool>(positional, 2, 'isDocComment', 'Comment');
        return Comment(text, trimmedText, isDocComment);
      },
    },
    getters: {
      'text': (visitor, target) => D4.validateTarget<Comment>(target, 'Comment').text,
      'trimmedText': (visitor, target) => D4.validateTarget<Comment>(target, 'Comment').trimmedText,
      'isDocComment': (visitor, target) => D4.validateTarget<Comment>(target, 'Comment').isDocComment,
    },
    constructorSignatures: {
      '': 'const Comment(String text, String trimmedText, bool isDocComment)',
    },
    getterSignatures: {
      'text': 'String get text',
      'trimmedText': 'String get trimmedText',
      'isDocComment': 'bool get isDocComment',
    },
  );
}

// =============================================================================
// TypeValue Bridge
// =============================================================================

BridgedClass _createTypeValueBridge() {
  return BridgedClass(
    nativeType: TypeValue,
    name: 'TypeValue',
    isAssignable: (v) => v is TypeValue,
    constructors: {
      '': (visitor, positional, named) {
        return TypeValue();
      },
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<TypeValue>(target, 'TypeValue').type,
    },
    constructorSignatures: {
      '': 'const TypeValue()',
    },
    getterSignatures: {
      'type': 'Type get type',
    },
  );
}

