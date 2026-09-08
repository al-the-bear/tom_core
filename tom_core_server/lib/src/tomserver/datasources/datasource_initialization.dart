import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../little_things/server_exception.dart';
import '../transactions/transaction_manager.dart';
import 'sql_dialects.dart';
import 'queries.dart';

/// Thrown when a data source cannot be discovered, instantiated, or
/// initialised (duplicate or missing driver, bad configuration, etc.).
///
/// `clientThrow` is not a parameter: every condition this type reports is
/// infrastructure, and its messages name driver classes, datasource types and
/// raw driver errors. Masking is therefore an invariant of the type rather than
/// a default a raise site could forget to keep.
class TomDatasourceInitException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  TomDatasourceInitException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  }) : super(clientThrow: false);
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

  /// The number of rows the most recent [execute] changed — the count a
  /// `DELETE` or `UPDATE` reports, and `0` for a statement that changed
  /// nothing or has not run yet.
  ///
  /// Deliberately non-nullable and without a default, unlike [lastGeneratedId]:
  /// a driver that ran a write knows how many rows it touched, and callers
  /// return this number as *the* answer to "how many rows were deleted". A
  /// default would let a driver stay silent and have the silence read as a
  /// real count — which is exactly the defect this member exists to remove.
  ///
  /// It is per-execution state on the handle, so read it immediately after
  /// [execute] and before [deallocate].
  int get lastAffectedRows;
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
            "tom_datasource.initialize_datasource_types.duplicate_driver",
            "Found more than one datasource driver for ${driver.type} first is ${_datasourceTypes[driver.type]}, additional found $candidate",
            autoLog: true,
          );
        } else {
          Object? datasource;
          try {
            datasource = candidate.newInstance("", []);
          } catch (error) {
            throw TomDatasourceInitException(
              "tom_datasource.initialize_datasource_types.driver_instantiation_failed",
              "Datasource driver scan: Failed to instantiate datasource",
              autoLog: true,
            );
          }
          if (datasource is TomDataSource) {
            _datasourceTypes[driver.type] = candidate;
          } else {
            throw TomDatasourceInitException(
              "tom_datasource.initialize_datasource_types.invalid_driver_not_implementing_datasource",
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
          "tom_datasource.create_datasource_of.driver_instantiation_failed",
          "Failed to instantiated datasource driver $datasourceClass for datasource type $type: $error",
          autoLog: true,
        );
      }
      if (datasource is TomDataSource) {
        return datasource;
      } else {
        throw TomDatasourceInitException(
          "tom_datasource.create_datasource_of.invalid_driver_not_implementing_datasource",
          "Datasouce driver scan: Datasource class is not implementing TomDataSource",
          autoLog: true,
        );
      }
    } else {
      throw TomDatasourceInitException(
        "tom_datasource.create_datasource_of.no_driver_found",
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

  /// The [settings] keys this registry reads itself, and so does not pass on.
  ///
  /// `type` selects the driver and `delegateTo` aliases one name onto another;
  /// neither is a field of any driver. They are removed from the map before it
  /// reaches [TomDataSource.initialize] rather than being excused by an
  /// allowlist inside the unknown-key check, so that the boundary says the
  /// same thing twice over: a driver is handed only what is addressed to it,
  /// and every key it is handed has to bind.
  static const Set<String> registryKeys = {'type', 'delegateTo'};

  /// Registers this entry and opens its data source.
  ///
  /// With a `delegateTo` setting, aliases [name] onto the referenced
  /// already-registered data source. Otherwise resolves the `type`, creates the
  /// driver via [TomDataSource.createDatasourceOf], strips [registryKeys] from
  /// [settings], checks that every remaining key binds a field the driver
  /// declares, and initialises it with what is left. Throws a
  /// [TomDatasourceInitException] on any failure (missing delegate,
  /// absent/empty `type`, no driver for the type, or an unknown settings key).
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
        final driverSettings = <String, dynamic>{
          for (final e in settings.entries)
            if (!registryKeys.contains(e.key)) e.key: e.value,
        };
        _rejectUnknownSettings(datasourceCandidate, driverSettings);
        await datasourceCandidate.initialize(driverSettings);
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

  /// Throws when [driverSettings] carries a key [driver] declares no field for.
  ///
  /// A datasource block is a file the operator wrote, for a driver whose field
  /// set is fixed and shipped — so a key that binds nothing is a mistake, and
  /// the only question is whether it is reported or absorbed. Absorbed, it
  /// surfaces later as a connection error that names neither the schema nor the
  /// credentials the driver was never given, and never mentions the key that
  /// caused it, because nothing ever looked at it.
  ///
  /// That tolerance is right on the wire, where the sender may be newer than
  /// the receiver, and it is what the shared `tomReflectionInfo` provides. It
  /// is not right here, and the check is made *at the registry* rather than by
  /// giving the driver a strict converter, for two reasons. The name of the
  /// data source lives here and not in the driver, and it is the half of the
  /// message that tells an operator which block to open. And a check here
  /// covers every driver, including one the framework never saw — a driver
  /// that binds tolerantly cannot opt out of it.
  ///
  /// Every offending key is named, not just the first: a block with two typos
  /// in it should not take two restarts to fix.
  void _rejectUnknownSettings(
    TomDataSource driver,
    Map<String, dynamic> driverSettings,
  ) {
    final unknown = tomReflectionInfo.unknownFields(driver, driverSettings);
    if (unknown.isEmpty) return;
    throw TomDatasourceInitException(
      "tom_datasource_info.initialize.unknown_setting",
      "Datasource '$name' (type '$type') is configured with "
          "${unknown.length == 1 ? 'a setting' : 'settings'} "
          "${unknown.map((k) => "'$k'").join(', ')} that "
          "${unknown.length == 1 ? 'names' : 'name'} no field of "
          "${driver.runtimeType}. Check the spelling in the datasource "
          "configuration for '$name'.",
      parameters: {"datasource": name, "keys": unknown},
      autoLog: true,
    );
  }

  @override
  String toString() => "TomDataSourceInfo $name $type $_datasource";
}
