
import 'dart:async';
import 'package:tom_core_kernel/src/tombase/little_things/little_things.dart';

abstract class TomScope {
  String get id;
  TomScope? get parent;
  static TomScope defaultScope = TomScopeBase(scopeId: 'default', parentScope: null);
  static TomScope get current => getFromCurrentZone<TomScope>() ?? defaultScope;
  static T withScope<T>(String scope, T Function() body) {
    return runZoned(body, zoneValues: { TomScope: TomScopeBase(scopeId: scope, parentScope: current)  }); 
  }

  /// Builds the scope path for any TomScope instance.
  /// Returns a dot-separated string (e.g., "app.checkout.orderForm").
  static String buildScopePath(TomScope scope) {
    final List<String> parts = [];
    TomScope? current = scope;
    while (current != null) {
      // Skip the default scope in the path
      if (current.id != 'default') {
        parts.add(current.id);
      }
      current = current.parent;
    }
    return parts.reversed.join('.');
  }

  /// Returns the full scope path as a dot-separated string.
  /// Used as a prefix for resource lookups.
  String getScopePath() => buildScopePath(this);
}

class TomScopeBase with TomScopeMixin {
  TomScopeBase({ required String scopeId, TomScope? parentScope}) {
    initScope(scopeId: scopeId, parentScope: parentScope);
  }
}

mixin TomScopeMixin on Object implements TomScope {
  late final String _id;
  late final TomScope? _parent;
  void initScope({ required String scopeId, TomScope? parentScope}) {
    _id = scopeId;
    _parent = parentScope;
  }

  void set id(String newId) => _id = newId;
  void set parent(TomScope? newParent) => _parent = newParent;

  @override
  String get id => _id;
  @override
  TomScope? get parent => _parent;

  @override
  String getScopePath() => TomScope.buildScopePath(this);
}
