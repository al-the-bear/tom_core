/// The reflector and the field annotations: what a class needs to be
/// reflected, and nothing of the converter that reads the mirrors.
///
/// Kept apart from `reflection_info.dart` so that a library which only
/// annotates its classes (`@tomReflector`) does not import the JSON converter
/// and what that reaches (zoned dates, access controls, the observable
/// value types). This file is also the library generated `*.reflection.dart`
/// files name for the reflector and the two field annotations, so those
/// declarations stay here.
library;

import 'package:tom_reflection/tom_reflection.dart';

/// A reflector configured with capabilities required for JSON serialization
/// and deserialization of annotated classes.
///
/// This reflector provides the following capabilities:
/// - **invokingCapability**: Call methods and constructors via reflection
/// - **typingCapability**: Access type information at runtime
/// - **typeRelationsCapability**: Navigate class hierarchies
/// - **reflectedTypeCapability**: Get actual Dart Type objects
/// - **typeAnnotationDeepQuantifyCapability**: Access nested type annotations
/// - **typeAnnotationQuantifyCapability**: Access type annotations
/// - **metadataCapability**: Access annotations and metadata
/// - **superclassQuantifyCapability**: Access superclass information
///
/// Usage:
/// ```dart
/// @tomReflector
/// class MyClass {
///   String name = '';
///   int age = 0;
/// }
/// ```
///
/// Classes must be annotated with `@tomReflector` to be discoverable
/// by the reflection system at runtime.
class TomReflector extends Reflection {
  /// Creates a new [TomReflector] with all required capabilities.
  const TomReflector()
    : super.fromList(const [
        invokingCapability,
        typingCapability,
        typeRelationsCapability,
        reflectedTypeCapability,
        typeAnnotationDeepQuantifyCapability,
        typeAnnotationQuantifyCapability,
        metadataCapability,
        superclassQuantifyCapability,
      ]);
}

/// Marks a reflected field as one that a bound map must supply a value for.
///
/// The annotation states the requirement next to the field it constrains; it
/// does not enforce it. [TomReflectionInfo.missingRequiredFields] reads it and
/// reports, and the caller decides what an unsupplied setting means — which is
/// the same division [TomReflectionInfo.unknownFields] makes, and for the same
/// reason: the converter knows the class, not where the map came from or how
/// bad it is for that particular setting to be absent.
///
/// ```dart
/// @tomReflector
/// class BillingConfiguration extends TomBaseServerConfiguration {
///   @TomRequiredField()
///   String dbUrl = '';
/// }
/// ```
///
/// Binding cannot report this by itself. A setting no source supplied leaves
/// the field at its initialiser, which is indistinguishable from a setting that
/// was never required — so the failure surfaces much later, as a connection to
/// `localhost:0` or an empty application id.
///
/// **A field with a fallback is not required.** The requirement is that a
/// *source* named the setting, so a field whose constructor applies a default
/// when nothing was configured must not carry this: it would refuse the very
/// launch the default exists to serve.
class TomRequiredField {
  /// Marks the annotated field as required.
  const TomRequiredField();
}

/// Marks a field a bound map *should* supply a value for, where its absence is
/// worth saying but not worth refusing.
///
/// The softer twin of [TomRequiredField], read by
/// [TomReflectionInfo.missingRecommendedFields]. A server configuration warns
/// at startup for each one no source named; a field that cannot work without a
/// value is required instead, and one with a sensible default is neither.
///
/// ```dart
/// @tomReflector
/// class BillingConfiguration extends TomBaseServerConfiguration {
///   @TomRequiredField()
///   String dbUrl = '';
///
///   @TomRecommendedField()
///   String supportEmail = '';
/// }
/// ```
class TomRecommendedField {
  /// Marks the annotated field as recommended.
  const TomRecommendedField();
}

/// Global reflector instance for annotating classes.
///
/// Use this annotation on classes that need reflection support:
/// ```dart
/// @tomReflector
/// class MyClass {
///   String name = '';
///   int age = 0;
/// }
/// ```
///
/// After running `dart run build_runner build`, the class will be available
/// for reflection operations.
const TomReflector tomReflector = TomReflector();
