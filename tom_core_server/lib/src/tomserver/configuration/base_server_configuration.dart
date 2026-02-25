import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

// TODO: add settings for JWT creation
class TomServerConfigResourceProvider {

  static TomServerConfigResourceProvider? _configProvider;

  static Map<String, dynamic> Function()? loader;

  static void setServerConfigProvider(
    TomServerConfigResourceProvider provider,
  ) {
    _configProvider = provider;
  }

  static TomServerConfigResourceProvider getServerConfig() {
    _configProvider ??= TomServerConfigResourceProvider();
    return _configProvider!;
  }

  Map<String, dynamic> resources = {};

  TomServerConfigResourceProvider() {
    if (loader != null) {
      resources = loader!();
    }
  }

  TomServerConfigResourceProvider.load(Map<String, dynamic> Function() loader) {
    resources = loader();
  }

  TomServerConfigResourceProvider.from(this.resources);

  bool exists(String s) {
    try {
      getObjectFromTree(resources, s);
      return true;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null;
  }

  Object get(String s) {
    try {
      dynamic value = getObjectFromTree(resources, s);
      return value;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null ? resources[s]! : s;
  }
}

String tomAppId = "";

@tomReflector
abstract class TomBaseServerConfiguration {
  String appId = "";

  List<String> args = [];

  String serverHeader = "";

  bool autoCompress = true;

  String poweredByHeader = "tom";

  bool noSsl = false;

  bool listenToAnyIP = false;

  int port = 8080;

  String certificateChain = '''
-----BEGIN CERTIFICATE-----
MIIFgzCCA2ugAwIBAgIUIQjzx85IYfitPxv3DWFnvTsKKYYwDQYJKoZIhvcNAQEL
BQAwXzELMAkGA1UEBhMCR0IxEDAOBgNVBAgMB0VuZ2xhbmQxETAPBgNVBAcMCEJy
aWdodG9uMRcwFQYDVQQKDA5IYWxsbWFya2Rlc2lnbjESMBAGA1UEAwwJbG9jYWxo
b3N0MB4XDTI0MDMxOTE0MzMzN1oXDTM0MDMxNzE0MzMzN1owXzELMAkGA1UEBhMC
R0IxEDAOBgNVBAgMB0VuZ2xhbmQxETAPBgNVBAcMCEJyaWdodG9uMRcwFQYDVQQK
DA5IYWxsbWFya2Rlc2lnbjESMBAGA1UEAwwJbG9jYWxob3N0MIICIjANBgkqhkiG
9w0BAQEFAAOCAg8AMIICCgKCAgEAxTZNpBvalsYr0XS9jnwg24k8vJmrjX+VODih
jKEoneghj/TYGpRZXFNF5s0J/Dg58gCrSEV6CAmjr5PS08FhBHQyfpb2uvgO5Dr7
nOx2+vQxZjyWKRZS2IRk8heoOsr3aGNrAqZ4747GcCaH36ki18LFZNUZbSBTMtzH
KCYutrKwl5B782R26V4XVooSLaXDmsSqi5HiSnW5gZHOyn3z0cQqtnSejH25qDNo
VKLD0wvxFs37CjDJS2eEsN/n8KrHvu7eGyYi/7Q3Ai7lm2jbhaZ1UKgk0hULOCq4
2mrQw/cvIUiCum4hSB5FuCzsm2wFpIgSgREcyPChTVUHTZg1dOFKaYcqjQTbP30w
yCylUsGv4AK94sF1NzK7v3HUDiioT1nbTJZaiLHuCu8Hk6nPYw2l36SSWRVY1S6g
sFX3Gv/+kDp7YxkFx9WXsvGlNI9CAiXFaRcJdkKX6xLESd7PiGcuj0x3gctdMxtP
jSdGPYYeOHRK+pi5ktpjaPzWIZNxPQM7nuWcramI5Mi5b0EOlAayQFkMxc5QMg5r
qSj/dTL97nhxuVhlaGcQYLD1kwGMEulkrpqwkeGWcPzWPHOMbG5PqHXGnLBIP2vy
cL0txmNF/6uEnyQUeV1bSxjBcHEObyCmSxWAhLDP8TZKEWRu2/LV37B2XiVjcXa5
8UAaB78CAwEAAaM3MDUwFAYDVR0RBA0wC4IJbG9jYWxob3N0MB0GA1UdDgQWBBQz
dxlPiTQZGKk/FuAtxXa+O6+0vDANBgkqhkiG9w0BAQsFAAOCAgEAGs5LqQcokOqc
gafFphrtQqLlHJWmu4k+gzSwO1K1viRpnwnwIRnnrsRYeGOHk43QGLc2E6Ze8/b9
snvGDIUJ5vP3C5G+7G4tj4/kdUEDy7dkQs/hznwkZsgUdfjigq2ykEevC6TB5cwH
vL0ZNYF3745xuMmsG4/WzkCpJ5Wb9WbyIYPAUW3vKdA+7pR6atC/EWGlCXMeiwCY
s9QHncYW71zwJDVoUygkCPe/hATJeZTd/sDGDF5j96b6e3FOkeTN+5Zi/sLDC0f8
/B19NZfWvnO9X6GS57+izspbkSejHVf9rjitpAykeha91MQje7rsP52Ymc+RMxGI
gVF8x3gX1oUINLnmq8jHhq03/b/tcQx1vqxw37uyn0QGEkef0OfD9Tgo6K02HUkn
F/8+7Hqq8e2ZoFWhws4LVGIp0UnScKn8+fCu1holc4112pBo0Fy8s+uZXZcAdiFv
WaW2zEEkYzCHc1XKiIjMBWO9YbTzQeWz7RCiiO6FoKo5CKur4iHxVm4gewCebBeC
n7809H7FuopWpa5JhGCTyRQRSCv9IXvtJd6oH/dZyq5yhypyjtAzDfpRcD6Ut3Wp
Fge3ejxMrwsq13az1+esJSH161qunB6Zsrs1/bx4zwQfJc0a90CAjqQESjLv+dUC
A1KMqQJg19+OXA5eF2Fs7N1UwFLrVsI=
-----END CERTIFICATE-----
  ''';
  String privateKey = '''
-----BEGIN PRIVATE KEY-----
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
utj3flRQDLaDAl91lySpAjUp9aM8
-----END PRIVATE KEY-----
    ''';

  String? jwtRsaPubKey;

  String? jwtRsaPrivKey;

  // currently not in use...
  String? jwtSharedSecretKey = "config-secret-passphrase";

  String host = Platform.isWindows ? "t" : "0";

  int isolateCount = 10;

  Middleware? authenticationMiddleware;

  Response? Function(Request, Object, StackTrace)? errorHandler;

  Response? Function(Request, Object, StackTrace)? authenticationErrorHandler;

  Handler? preExecutionHandler;

  Handler? postExecutionHandler;

  Middleware loggingMiddleware = tomLoggingMiddleware();
  /*
  logRequests( logger:
      (String s, bool error) => error ? tomLog.error(s) : tomLog.info(s)
  );
   */

  bool isolateLogging = true;

  String logLevelExceptions = "";

  String logLevel = "";

  String databaseMigrationsDirectory = "./database_migrations";

  static Map<String, Object?> getDefaultValues(List<String> args) {
    Map<String, Object?> values =
        TomServerConfigResourceProvider.getServerConfig().resources;
    mergeMapsOneSided(values, TomArgs.convertToObjectMap(Platform.environment));
    mergeMapsOneSided(values, TomEnvFile.read());
    mergeMapsOneSided(values, TomArgs.parseArgsToMap(args));
    return values;
  }

  void setValues(Map<String, Object?> values);

  TomBaseServerConfiguration(List<String> args) {
    setValues(getDefaultValues(args));
  }
}
