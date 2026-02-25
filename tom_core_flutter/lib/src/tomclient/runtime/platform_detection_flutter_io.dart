import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomFlutterPlatformUtils extends TomFallbackPlatformUtils {
  TomFlutterPlatformUtils() {
    getTomEnvVars().addAll(Platform.environment);
  }

  @override
  bool isDesktop() =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool isMobile() =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool isWeb() => kIsWeb;

  @override
  bool isFuchsia() => defaultTargetPlatform == TargetPlatform.fuchsia;
  @override
  bool isWindows() => defaultTargetPlatform == TargetPlatform.windows;
  @override
  bool isLinux() => defaultTargetPlatform == TargetPlatform.linux;
  @override
  bool isMacOs() => defaultTargetPlatform == TargetPlatform.macOS;
  @override
  bool isAndroid() => defaultTargetPlatform == TargetPlatform.android;
  @override
  bool isIos() => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void out(String s) => print(s);
  @override
  void outError(String s) => print(s);
  @override
  //const _maxCacheSize = 2 * 1024 * 1024;
  // TODO: move custom factories for different client platforms to tom_client
  @override
  Client httpClient() {
    // TODO: set up CupertinoClient correctly
    /*if (Platform.isIOS || Platform.isMacOS) {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..cache = URLCache.withCapacity(memoryCapacity: _maxCacheSize)
      ..httpAdditionalHeaders = {'User-Agent': 'Book Agent'};
    return CupertinoClient.fromSessionConfiguration(config);
  }

   */
    return IOClient(
      HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              // allow bad certificates on local machine
              return (host.compareTo("0.0.0.0") == 0 ||
                  host.compareTo("localhost") == 0 ||
                  host.compareTo("127.0.0.1") == 0);
            },
    );
  }

  @override
  String? getBrowserLocation() {
    return null;
  }

  @override
  String getIsolateName() => Isolate.current.debugName ?? "main";

  @override
  String toString() => "TomFlutterPlatformUtis: io";
}
