/// Marker interface for screen element providers.
///
/// A screen element provider declares all widgets for a screen as typed fields.
/// When used with `@tomReflect`, reflection discovers the field list
/// automatically — no manual element registration needed.
///
/// This is a marker interface rather than a base class because element
/// providers must be `@tomReflect`-annotated and the reflection annotation
/// works on any class. The marker restricts the generic type on
/// [TomAclBuilder] to classes explicitly intended as element providers.
///
/// ```dart
/// @tomReflect
/// class LoginScreenElements implements TomScreenElementsProvider {
///   TomText greeting = TomText(tomId: 'login_greeting');
///   TomButton loginButton = TomButton(id: 'login_button', ...);
/// }
/// ```
abstract interface class TomScreenElementsProvider {}
