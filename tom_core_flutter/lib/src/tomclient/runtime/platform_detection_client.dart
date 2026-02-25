// Take client remote context from browser window if running in a browser
import 'platform_detection_neutral.dart'
    if (dart.library.io) 'platform_detection_flutter_io.dart'
    if (dart.library.js) 'platform_detection_web.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

TomPlatformUtils get clientPlatformUtils => TomFlutterPlatformUtils();