import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomAuthorizationCacheException extends TomException {
  TomAuthorizationCacheException(
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

/// this class with cache the authorization tokens received during calls to
/// getSettingsAndAssociateWithAuthorization so the information is available for subsequent calls
/// the information is stored in the main isolate to make it accessible from all requests
///
///

class TomAuthorizationCacheEntry {
  late DateTime deletionTime;
  TomPrincipal authorizedPrincipal;

  TomAuthorizationCacheEntry(
    this.authorizedPrincipal, [
    DateTime? deletionTime,
  ]) {
    this.deletionTime = deletionTime ?? DateTime.now().add(Duration(days: 1));
  }
}

class TomAuthorizationCache {
  static final TomAuthorizationCache _current = TomAuthorizationCache();

  TomAuthorizationCache() {
    Zone.current.createPeriodicTimer(Duration(hours: 1), (Timer t) {
      var now = DateTime.now();
      List<String> entriesToDelete = [];
      for (var entry in _cache.entries) {
        if (entry.value.deletionTime.isBefore(now)) {
          entriesToDelete.add(entry.key);
        }
      }
      if (entriesToDelete.isNotEmpty) {
        tomLog.debug(
          "TomAuthorizationCache timer is deleting keys $entriesToDelete",
        );
        for (var key in entriesToDelete) {
          _cache.remove(key);
        }
      }
    });
  }

  final Map<String, TomAuthorizationCacheEntry> _cache = {};

  static Future<TomPrincipal?> getPrincipal(
    TomClientJwtToken authenticationToken,
  ) async {
    if (TomWorker.isMainIsolate) {
      TomAuthorizationCacheEntry? entry =
          _current._cache[authenticationToken.tokenString];
      if (entry != null) {
        if (entry.deletionTime.isAfter(DateTime.now())) {
          tomLog.trace(
            "Found authorization principal for ${limited(authenticationToken.tokenString, 100)}",
          );
          return entry.authorizedPrincipal;
        } else {
          // TODO: introduce specific exception here, this might be important for reauthorizing the user
          throw TomAuthorizationCacheException(
            "tomclient.authorization_cache.expired_principal",
            "AuthorizedPrincipal expired for user $authenticationToken",
          );
        }
      }
    } else {
      Object? cachedResult = await TomWorker.executeInCreator(
        TomAuthorizationCacheRetrieveMessage(authenticationToken),
      );
      if (cachedResult != null && cachedResult is TomPrincipal) {
        return cachedResult;
      }
    }
    return null;
  }

  static Future<int> storePrincipal(
    TomClientJwtToken authenticationToken,
    TomPrincipal authorizedPrincipal,
  ) async {
    if (TomWorker.isMainIsolate) {
      DateTime expiry = DateTime.parse(
        authenticationToken.token.payload["validUntil"],
      );
      tomLog.trace(
        "Storing principal ${limited(authenticationToken.tokenString, 100)} with expiry $expiry",
      );
      _current._cache[authenticationToken.tokenString] =
          TomAuthorizationCacheEntry(authorizedPrincipal, expiry);
    } else {
      await TomWorker.executeInCreator(
        TomAuthorizationCacheStoreMessage(
          authenticationToken,
          authorizedPrincipal,
        ),
      );
    }
    return 0;
  }
}

class TomAuthorizationCacheStoreMessage {
  TomClientJwtToken authenticationToken;
  TomPrincipal authorizedPrincipal;
  TomAuthorizationCacheStoreMessage(
    this.authenticationToken,
    this.authorizedPrincipal,
  );
}

class TomAuthorizationCacheRetrieveMessage {
  TomClientJwtToken authenticationToken;
  TomAuthorizationCacheRetrieveMessage(this.authenticationToken);
}

class TomAuthorizationCacheExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is TomAuthorizationCacheStoreMessage) {
      tomLog.trace(
        "Storing authorizedPrincipal ${limited(command.authenticationToken.tokenString, 100)} in main Isolate",
      );
      // ignore: discarded_futures
      TomAuthorizationCache.storePrincipal(
        command.authenticationToken,
        command.authorizedPrincipal,
      );
      return true;
    }
    if (command is TomAuthorizationCacheRetrieveMessage) {
      tomLog.trace(
        "Retrieving authorizedPrincipal ${limited(command.authenticationToken.tokenString, 100)}",
      );
      return TomAuthorizationCache.getPrincipal(command.authenticationToken);
    }
    return TomExecutor.noResult;
  }
}
