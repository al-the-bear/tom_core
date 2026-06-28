/// Shared, reflected domain model for the advanced Tom Core full-stack sample.
///
/// One source of truth for the whole stack: the app server persists these
/// entities, the clients edit them, and the authorization layer grades their
/// fields. Import this barrel and call `initializeReflection()` once at startup
/// before constructing any reflected entity.
///
/// The entity classes, resource-key/role constants, and the reflection seed are
/// added in steps 2–3 of the implementation plan; this barrel is the stable
/// public entry point they will be exported from.
library;
