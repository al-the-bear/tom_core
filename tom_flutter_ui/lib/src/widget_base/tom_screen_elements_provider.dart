import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Interface for screen element providers.
///
/// A screen element provider declares all widgets for a screen as typed fields
/// and provides a [scope] for resource/authorization lookups.
///
/// When used with `@tomReflect`, reflection discovers the field list
/// automatically — no manual element registration needed.
///
/// This is an interface rather than a base class because element
/// providers must be `@tomReflect`-annotated and the reflection annotation
/// works on any class. The interface restricts the generic type on
/// [TomAclBuilder] to classes explicitly intended as element providers.
///
/// ```dart
/// @tomReflect
/// class LoginScreenElements implements TomScreenElementsProvider {
///   @override
///   final TomScope scope;
///
///   LoginScreenElements({required this.scope});
///
///   late final TomText greeting = TomText(tomId: 'login_greeting');
///   late final TomButton loginButton = TomButton(tomId: 'login_button', ...);
/// }
/// ```
abstract interface class TomScreenElementsProvider {
  /// The scope for resource and authorization lookups.
  ///
  /// This scope provides the base path for all widgets in this provider.
  /// When widgets resolve their resource paths, they use this scope's path
  /// as a prefix.
  ///
  /// Typically set during construction, e.g., `TomScope.named('loginScreen')`.
  TomScope get scope;
}
