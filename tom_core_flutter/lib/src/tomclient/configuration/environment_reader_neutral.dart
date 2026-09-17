/// The stand-in for `readPlatformEnvironment` on targets with no process
/// environment — in practice, the web.
///
/// Always `null`, which is the honest answer rather than a failure: a browser
/// has no environment to read, so every setting simply resolves from the layer
/// below. A web build that wants the same capability supplies it explicitly
/// through `TomClientEnvironment.reader` — a `--dart-define`, a value fetched
/// at startup, a query parameter — which is the same "the app knows, the
/// framework does not" split the file store makes.
String? readPlatformEnvironment(String name) => null;
