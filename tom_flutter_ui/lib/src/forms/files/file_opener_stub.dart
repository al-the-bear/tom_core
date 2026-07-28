/// The no-filesystem half of [file_opener.dart] — used on the web.
library;

/// Always `null`: the web has no file paths to open.
Stream<List<int>> Function()? openFilePath(String path) => null;

/// Always `null`: the web has no file paths to measure.
int? fileLengthAt(String path) => null;
