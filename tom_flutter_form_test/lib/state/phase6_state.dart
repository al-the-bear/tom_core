/// Phase 6 backing state — Demos Q + R.
///
/// Demo Q (`TomAuthGuard` + `TomEmptyState` + `TomLoadingOverlay`) and
/// Demo R (`TomAuthTreeView` + `TomChoiceGroup` + `TomInfiniteScroll`)
/// each carry small UI-state holders so the demos can stay
/// `StatelessWidget`-friendly where convenient. The real per-tab state
/// lives in the [DemoQController] / [DemoRController] classes below.
library;

import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// ---------------------------------------------------------------------------
// Demo Q — auth-guarded panel + empty list + loading overlay.
// ---------------------------------------------------------------------------

/// Per-demo auth adapter: a flat path → state map driven by the right-
/// hand controls. Re-used by Demo R.
class DemoPhase6AuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules = {};

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      rules[resourceKeyPath] ?? TomAuthState.full;

  void set(String path, TomAuthState state) {
    if (state == TomAuthState.full) {
      rules.remove(path);
    } else {
      rules[path] = state;
    }
  }
}

/// Light-weight controller for Demo Q. Owns:
///
///   * `auth`: state of the guarded `demoQ.profile` resource.
///   * `isSaving`: drives [TomLoadingOverlay] while the demo's
///     `ValidationForm.save()` awaits its async `SlowValidator`.
class DemoQController extends ChangeNotifier {
  TomAuthState _auth = TomAuthState.full;
  bool _isSaving = false;

  TomAuthState get auth => _auth;
  bool get isSaving => _isSaving;

  void setAuth(TomAuthState state, DemoPhase6AuthAdapter adapter) {
    _auth = state;
    adapter.set('demoQ.profile', state);
    notifyListeners();
  }

  void beginSave() {
    if (_isSaving) return;
    _isSaving = true;
    notifyListeners();
  }

  void endSave() {
    if (!_isSaving) return;
    _isSaving = false;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Demo R — auth tree + radio group + infinite scroll.
// ---------------------------------------------------------------------------

/// Selection / fetch controller for Demo R. Holds:
///
///   * `radioValue`: current `TomChoiceGroup<String>` selection.
///   * `failNext`: when true, the next page fetch throws — exercises
///     the error-state slot on `TomInfiniteScroll` (outer error slot).
///   * `throwOnTile`: when true, the per-tile builder throws for a
///     specific row index — exercises the *inner* `TomErrorBoundary`
///     that wraps every row (the spec's "boundary around the tile
///     builder" clause).
///   * `auth`: state of the `demoR.densityRadio` resource (drives the
///     group-level auth on the radio).
class DemoRController extends ChangeNotifier {
  /// Row index at which `throwOnTile=true` causes the tile builder to
  /// throw. Chosen so the row is within the first page so the synthetic
  /// error is visible without scrolling.
  static const int throwRowIndex = 3;

  String _radioValue = 'comfortable';
  bool _failNext = false;
  bool _throwOnTile = false;
  TomAuthState _radioAuth = TomAuthState.full;

  String get radioValue => _radioValue;
  bool get failNext => _failNext;
  bool get throwOnTile => _throwOnTile;
  TomAuthState get radioAuth => _radioAuth;

  void selectRadio(String value) {
    if (_radioValue == value) return;
    _radioValue = value;
    notifyListeners();
  }

  void toggleFailNext() {
    _failNext = !_failNext;
    notifyListeners();
  }

  void clearFailNext() {
    if (!_failNext) return;
    _failNext = false;
    notifyListeners();
  }

  void toggleThrowOnTile() {
    _throwOnTile = !_throwOnTile;
    notifyListeners();
  }

  void setRadioAuth(TomAuthState state, DemoPhase6AuthAdapter adapter) {
    _radioAuth = state;
    adapter.set('demoR.densityRadio', state);
    notifyListeners();
  }
}

/// Synthetic 10 000-row data source for Demo R's `TomInfiniteScroll`.
/// Returns a slice of pre-formatted strings with a tiny delay so the
/// initial-load skeleton + bottom-of-list "loading more" indicator both
/// have a chance to render.
class DemoRPageSource {
  static const int totalRows = 10000;

  Future<List<String>> fetchPage(
    int page,
    int pageSize, {
    bool failNext = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (failNext) {
      throw StateError('Synthetic page-fetch failure (page=$page).');
    }
    final start = page * pageSize;
    if (start >= totalRows) return const [];
    final end = (start + pageSize > totalRows) ? totalRows : (start + pageSize);
    return [
      for (var i = start; i < end; i++) 'Row #${i.toString().padLeft(5, '0')}',
    ];
  }
}
