/// The server half of feature flags: the flags of the configuration, and the
/// endpoint that hands a client the ones it may read.
///
/// The flags live under the `featureFlags` configuration key and are installed
/// by [TomFeatureFlagsServer.configure] (called by `TomServer.start`) as a
/// [TomRuleFlagProvider] in [TomFeatureFlags.provider], so server code reads
/// them with [TomFeatureFlags] for the request at hand. `GET /feature-flags`
/// ([tomFeatureFlagsApi]) answers the flags marked `exposed`, evaluated for
/// the caller; a deployment that installed another provider (an OpenFeature
/// or vendor bridge) serves whatever that provider's `evaluateAll` answers.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import 'tom_config.dart';

/// The `GET /feature-flags` endpoint, and the configuration of the flags.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: tomFeatureFlagsApiId)
class TomFeatureFlagsServer {
  /// Const constructor: the endpoint keeps no state of its own.
  const TomFeatureFlagsServer();

  /// The configuration key holding the flags.
  static const String configurationKey = 'featureFlags';

  /// Installs the flags of [config] (a map from flag key to definition, see
  /// [TomRuleFlagProvider.fromConfiguration]) as [TomFeatureFlags.provider].
  ///
  /// Throws `configuration.feature_flags.invalid`, naming the fault, for a
  /// value of the wrong shape; nothing is installed.
  static void configure(Object? config) {
    try {
      TomFeatureFlags.provider = TomRuleFlagProvider.fromConfiguration(config);
    } on FormatException catch (error) {
      throw TomConfigurationException(
        'configuration.feature_flags.invalid',
        'The feature flags cannot be read: ${error.message}',
        parameters: {'reason': error.message},
      );
    }
  }

  /// Every client-visible flag, evaluated for the caller.
  @TomApiEndpointImplementation(
    apiId: tomFeatureFlagsApiId,
    endpointId: tomFeatureFlagsEvaluateEndpointId,
  )
  Future<Map<String, Object?>> evaluateFlags() async => {
    'flags': await TomFeatureFlags.provider.evaluateAll(
      TomFlagContext.current(),
    ),
  };
}
