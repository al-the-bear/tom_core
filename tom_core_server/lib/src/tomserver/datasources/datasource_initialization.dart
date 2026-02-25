import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../transactions/transaction_manager.dart';
import 'sql_dialects.dart';
import 'queries.dart';

class TomDatasourceInitException extends TomException {
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

@tomReflector
class TomDatasourceDriver {
  final String type;

  const TomDatasourceDriver(this.type);
}

abstract class TomPreparedStatement<T extends Object> {
  Future<List<T>> execute([Map<String, Object?>? params]);
  Future<void> deallocate();
}

abstract class TomDataSource implements TomTransactionParticipant {
  TomStandardSqlDialect get sqlDialect;

  Future<void> initialize(Map<String, dynamic> settings);

  Future<void> close();

  bool isOperational() {
    return true;
  }

  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]);

  Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params]);

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

class TomDataSourceInfo {
  static Map<String, TomDataSourceInfo> datasources = {};

  static TomDataSourceInfo? getDataSourceInfo(String dsName) {
    return datasources[dsName];
  }

  static Future<int> initializeDatasourceInfo(
    Map<String, dynamic> datasourceConfiguration,
  ) async {
    for (var entry in datasourceConfiguration.entries) {
      if (entry.value is Map<String, Object>) {
        var dsi = TomDataSourceInfo(entry.key, entry.value);
        await dsi.initialize();
      }
    }
    return 1;
  }

  static Future<void> closeAll() async {
    for (TomDataSourceInfo dsi in datasources.values) {
      if (dsi._datasource != null) {
        await dsi._datasource!.close();
      }
    }
  }

  String name;
  late String type;
  Map<String, dynamic> settings;
  late TomDataSource? _datasource;

  bool get isOperational => _datasource != null && _datasource!.isOperational();

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

  TomDataSourceInfo(this.name, this.settings);

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
