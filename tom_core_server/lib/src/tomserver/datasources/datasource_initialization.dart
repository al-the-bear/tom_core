import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../transactions/transaction_manager.dart';
import 'sql_dialects.dart';
import 'queries.dart';

/// Thrown when a data source cannot be discovered, instantiated, or
/// initialised (duplicate or missing driver, bad configuration, etc.).
class TomDatasourceInitException extends TomException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomException].
  TomDatasourceInitException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

/// Annotation marking a [TomDataSource] implementation as the driver for a
/// named data-source [type] (e.g. `"mariadb"`). Drivers are discovered by
/// scanning [tomReflector] for this annotation.
@tomReflector
class TomDatasourceDriver {
  /// The data-source type this driver serves.
  final String type;

  /// Binds the annotated class to [type].
  const TomDatasourceDriver(this.type);
}

/// A reusable, server-side compiled statement that can be [execute]d (with
/// optional named [params]) any number of times and then [deallocate]d.
abstract class TomPreparedStatement<T extends Object> {
  /// Runs the statement and returns the mapped result rows.
  Future<List<T>> execute([Map<String, Object?>? params]);

  /// Releases the statement's server-side resources.
  Future<void> deallocate();

  /// The database-assigned auto-increment / identity key produced by the most
  /// recent [execute] that inserted a row, or `null` when the last execute
  /// produced no generated key.
  ///
  /// Read from the insert's *own* result, this is the authoritative source for
  /// a freshly inserted row's surrogate key — unlike a follow-up
  /// `SELECT LAST_INSERT_ID()`, which is session-scoped and returns `0` if it
  /// happens to run on a different connection than the insert.
  int? get lastGeneratedId => null;
}

/// A connection to one data source — the abstract contract a driver implements.
///
/// A data source exposes its [sqlDialect], lifecycle ([initialize] / [close] /
/// [isOperational]), and execution surface ([prepareStatement], [executeCommand]
/// for writes returning an affected-row count, [executeQuery] for reads). It is
/// a [TomTransactionParticipant], so it can enlist in a transaction.
///
/// Concrete drivers register via [TomDatasourceDriver]; obtain one for a type
/// with [createDatasourceOf], which lazily scans reflection metadata on first
/// use.
abstract class TomDataSource implements TomTransactionParticipant {
  /// The SQL dialect this data source generates against.
  TomStandardSqlDialect get sqlDialect;

  /// Opens the connection and applies [settings] (host, credentials, …).
  Future<void> initialize(Map<String, dynamic> settings);

  /// Closes the connection and frees its resources.
  Future<void> close();

  /// Whether the connection is currently usable (default `true`).
  bool isOperational() {
    return true;
  }

  /// Compiles [query] (optionally mapping rows to [resultType]) into a reusable
  /// [TomPreparedStatement].
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]);

  /// Executes a write [command] (optionally with [params]) and returns the
  /// number of affected rows.
  Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params]);

  /// Executes a read [command] (optionally with [params]), mapping rows to
  /// [resultType].
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]);

  static final Map<String, ClassMirror> _datasourceTypes = {};

  static void _initializeDatasourceTypes() {
    for (var candidate in tomReflector.annotatedClasses) {
      if (candidate.metadata.any((o) => o is TomDatasourceDriver)) {
        TomDatasourceDriver driver =
            candidate.metadata.firstWhere((o) => o is TomDatasourceDriver)
                as TomDatasourceDriver;
        if (_datasourceTypes[driver.type] != null) {
          throw TomDatasourceInitException(
            "tom_datasource.duplicate_driver",
            "Found more than one datasource driver for ${driver.type} first is ${_datasourceTypes[driver.type]}, additional found $candidate",
            autoLog: true,
          );
        } else {
          Object? datasource;
          try {
            datasource = candidate.newInstance("", []);
          } catch (error) {
            throw TomDatasourceInitException(
              "tom_datasource.driver_instantiation_failed",
              "Datasource driver scan: Failed to instantiate datasource",
              autoLog: true,
            );
          }
          if (datasource is TomDataSource) {
            _datasourceTypes[driver.type] = candidate;
          } else {
            throw TomDatasourceInitException(
              "tom_datasource.invalid_driver_not_implementing_datasource",
              "Datasouce driver scan: Datasource class is not implementing TomDataSource",
              autoLog: true,
            );
          }
        }
      }
    }
  }

  /// Returns a fresh data source for [type], discovering drivers on first call.
  ///
  /// Throws a [TomDatasourceInitException] if no driver is registered for
  /// [type], or if the registered driver fails to instantiate.
  static TomDataSource? createDatasourceOf(String type) {
    if (_datasourceTypes.isEmpty) {
      _initializeDatasourceTypes();
    }
    ClassMirror? datasourceClass = _datasourceTypes[type];
    if (datasourceClass != null) {
      Object? datasource;
      try {
        datasource = datasourceClass.newInstance("", []);
      } catch (error) {
        throw TomDatasourceInitException(
          "tom_datasource_create.driver_instantiation_failed",
          "Failed to instantiated datasource driver $datasourceClass for datasource type $type: $error",
          autoLog: true,
        );
      }
      if (datasource is TomDataSource) {
        return datasource;
      } else {
        throw TomDatasourceInitException(
          "tom_datasource_create.invalid_driver_not_implementing_datasource",
          "Datasouce driver scan: Datasource class is not implementing TomDataSource",
          autoLog: true,
        );
      }
    } else {
      throw TomDatasourceInitException(
        "tom_datasource_create.no_driver_found",
        "There was no datasource driver for datasource type $type",
        autoLog: true,
      );
    }
  }
}

/// The process-wide registry of named, configured data sources.
///
/// Each named entry pairs a [name] with its [settings] and, once
/// [initialize]d, the live [datasource]. [initializeDatasourceInfo] builds the
/// registry from a configuration map; [getDataSourceInfo] looks one up by name;
/// [closeAll] shuts them all down. A `delegateTo` setting aliases one name onto
/// another already-registered data source instead of opening a new connection.
class TomDataSourceInfo {
  /// All registered data sources, keyed by name.
  static Map<String, TomDataSourceInfo> datasources = {};

  /// Returns the registered info for [dsName], or `null` if none.
  static TomDataSourceInfo? getDataSourceInfo(String dsName) {
    return datasources[dsName];
  }

  /// Builds and initialises a registry entry for every map-valued entry in
  /// [datasourceConfiguration]. Returns `1` on success.
  static Future<int> initializeDatasourceInfo(
    Map<String, dynamic> datasourceConfiguration,
  ) async {
    for (var entry in datasourceConfiguration.entries) {
      if (entry.value is Map) {
        // Read keys defensively. Config decoded from YAML/env arrives as a
        // `YamlMap` (`Map<dynamic, dynamic>`) or `Map<String, dynamic>` /
        // `Map<String, Object?>` — none of which is a `Map<String, Object>` for
        // the runtime `is` check (`dynamic`/`Object?` ⊄ `Object`), so the old
        // reified guard silently skipped every real config entry.
        // Normalise to `Map<String, dynamic>` with String keys before
        // registering.
        final raw = entry.value as Map;
        final settings = <String, dynamic>{
          for (final e in raw.entries) '${e.key}': e.value,
        };
        var dsi = TomDataSourceInfo(entry.key, settings);
        await dsi.initialize();
      }
    }
    return 1;
  }

  /// Closes every initialised data source in the registry.
  static Future<void> closeAll() async {
    for (TomDataSourceInfo dsi in datasources.values) {
      if (dsi._datasource != null) {
        await dsi._datasource!.close();
      }
    }
  }

  /// The registry key / logical name of this data source.
  String name;

  /// The driver type, resolved from [settings] during [initialize].
  late String type;

  /// The raw configuration for this data source.
  Map<String, dynamic> settings;
  late TomDataSource? _datasource;

  /// Whether the underlying data source exists and reports operational.
  bool get isOperational => _datasource != null && _datasource!.isOperational();

  /// The live data source, or throws if it has not been initialised.
  TomDataSource get datasource {
    if (_datasource != null) {
      return _datasource!;
    }
    throw TomDatasourceInitException(
      "tom_datasource_info.get_datasource.datasource_is_null",
      "TomDatasourceInfo datasource is null.",
      autoLog: true,
    );
  }

  /// Creates an (uninitialised) registry entry from [name] and [settings].
  TomDataSourceInfo(this.name, this.settings);

  /// Registers this entry and opens its data source.
  ///
  /// With a `delegateTo` setting, aliases [name] onto the referenced
  /// already-registered data source. Otherwise resolves the `type`, creates the
  /// driver via [TomDataSource.createDatasourceOf], and initialises it with
  /// [settings]. Throws a [TomDatasourceInitException] on any failure (missing
  /// delegate, absent/empty `type`, or no driver for the type).
  Future<void> initialize() async {
    String? delegate = settings["delegateTo"];
    if (delegate != null) {
      if (datasources[delegate] != null) {
        datasources[name] = datasources[delegate]!;
        return;
      } else {
        throw TomDatasourceInitException(
          "tom_datasource_info.initialize.delegate_not_found",
          "Datasource initialization faild: Datasource referred to as delegate $delegate not found.",
          autoLog: true,
        );
      }
    }
    datasources[name] = this;
    type = settings["type"] ?? "";
    if (type.isNotEmpty) {
      var datasourceCandidate = TomDataSource.createDatasourceOf(type);
      if (datasourceCandidate != null) {
        await datasourceCandidate.initialize(settings);
        _datasource = datasourceCandidate;
      } else {
        throw TomDatasourceInitException(
          "tom_datasource_info.initialize.no_datasource_obtained_for_type",
          "Failed to obtain datasource object for datasource type $type",
          autoLog: true,
        );
      }
    } else {
      throw TomDatasourceInitException(
        "tom_datasource_info.initialize.no_type_specified",
        "Datasource definition doesn't contain 'type' attribute or it's empty",
        autoLog: true,
      );
    }
  }

  @override
  String toString() => "TomDataSourceInfo $name $type $_datasource";
}
