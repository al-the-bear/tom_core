/// Opens a file path as a re-openable byte stream, where the platform has a
/// filesystem.
///
/// A picker on desktop or mobile hands back a *path*, and the whole point of
/// the streaming upload path is not to read that path into memory first. Web
/// has no path — a picker there returns bytes — so this is one of the few
/// places in `tom_flutter_ui` that needs a conditional import rather than a
/// runtime check: `dart:io` cannot even be *compiled* for the web.
///
/// [openFilePath] returns `null` when the platform has no filesystem, which is
/// the caller's signal to fall back to whatever bytes the picker supplied.
library;

export 'file_opener_stub.dart' if (dart.library.io) 'file_opener_io.dart';
