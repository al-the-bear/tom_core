/// The filesystem half of [file_opener.dart] — used everywhere except the web.
library;

import 'dart:io';

/// A factory that re-reads [path] from disk each time it is called, or `null`
/// when nothing is stored there.
///
/// A *factory* rather than a stream because a retry needs to read the file a
/// second time; `File.openRead()` is cheap to call again and never holds the
/// contents in memory.
Stream<List<int>> Function()? openFilePath(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.openRead;
}

/// The size of the file at [path], or `null` when it cannot be read.
///
/// Knowing the size up front is what turns an upload's progress bar from a
/// spinner into a percentage, so it is worth one `stat`.
int? fileLengthAt(String path) {
  try {
    return File(path).lengthSync();
  } on FileSystemException {
    return null;
  }
}
