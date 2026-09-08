# Tom Flutter UI — Debug and Inspection System

**Date:** 2026-04-02
**Status:** Proposal
**Package:** tom_flutter_ui

---

## Table of Contents

1. [Overview](#1-overview)
2. [Activation Model](#2-activation-model)
3. [Debug Overlay Architecture](#3-debug-overlay-architecture)
4. [Data Collection Infrastructure](#4-data-collection-infrastructure)
5. [Debug Views](#5-debug-views)
6. [Keyboard Shortcuts](#6-keyboard-shortcuts)
7. [Export and Serialization](#7-export-and-serialization)
8. [Performance Considerations](#8-performance-considerations)
9. [Implementation Plan](#9-implementation-plan)

- [Appendix: Data Models](#appendix-data-models)

---

## 1. Overview

The Debug and Inspection System provides development-time tools for validating authorization, resources, groups, actions, and state at runtime. The system is designed to be:

- **Zero-cost in production** — completely tree-shaken when not active
- **Pull-based** — no runtime overhead until explicitly opened
- **Reflection-powered** — deep inspection without manual debug code
- **Overlay-based** — non-intrusive UI that works with any app layout

### Goals

1. **Validate authorization setup** — see exactly why a widget is visible/hidden/readonly
2. **Debug resource resolution** — trace fallback chains and identify missing resources
3. **Inspect ID structure** — verify canonical paths and detect duplicates
4. **Monitor actions** — see action registry, execution history, undo stack
5. **Browse state** — inspect observable state tree with reflection

### Non-Goals

- Production monitoring (use dedicated observability tools)
- Performance profiling (use Flutter DevTools)
- Layout debugging (use Flutter Inspector)

---

## 2. Activation Model

### 2.1 Debug Mode Detection

The system uses a multi-layer activation model:

```dart
/// Global flag controlling debug overlay availability.
/// Set automatically based on build mode and explicit opt-in.
class TomDebugConfig {
  static bool _enabled = false;
  static bool _explicitOverride = false;
  
  /// Whether debug tools are available in this build.
  static bool get enabled {
    if (_explicitOverride) return _enabled;
    // In debug builds, default to enabled
    // In profile/release builds, default to disabled
    return kDebugMode;
  }
  
  /// Explicitly enable or disable debug tools.
  /// Call this in main() to override default behavior.
  static void setEnabled(bool value) {
    _enabled = value;
    _explicitOverride = true;
  }
  
  /// Enable debug tools based on command-line argument.
  /// Usage: flutter run --dart-define=TOM_DEBUG=true
  static void initFromEnvironment() {
    const debugArg = String.fromEnvironment('TOM_DEBUG');
    if (debugArg.toLowerCase() == 'true') {
      setEnabled(true);
    } else if (debugArg.toLowerCase() == 'false') {
      setEnabled(false);
    }
  }
}
```

### 2.2 Command-Line Activation

```bash
# Enable in any build mode
flutter run --dart-define=TOM_DEBUG=true

# Also works with release builds for debugging auth issues
flutter run --release --dart-define=TOM_DEBUG=true
```

### 2.3 App Integration

```dart
void main() {
  // Initialize debug config from environment
  TomDebugConfig.initFromEnvironment();
  
  // Or explicitly enable/disable
  TomDebugConfig.setEnabled(kDebugMode);
  
  runApp(
    TomDebugOverlay(
      // Only wraps when enabled; transparent pass-through otherwise
      child: MyApp(),
    ),
  );
}
```

---

## 3. Debug Overlay Architecture

### 3.1 Overlay Structure

```dart
/// Root widget that provides debug overlay functionality.
/// Tree-shaken in release builds when TomDebugConfig.enabled is const false.
class TomDebugOverlay extends StatefulWidget {
  final Widget child;
  
  const TomDebugOverlay({super.key, required this.child});
  
  @override
  State<TomDebugOverlay> createState() => _TomDebugOverlayState();
}

class _TomDebugOverlayState extends State<TomDebugOverlay> {
  bool _isOverlayVisible = false;
  int _selectedTabIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    if (!TomDebugConfig.enabled) {
      return widget.child;
    }
    
    return Stack(
      children: [
        // App content with keyboard listener
        CallbackShortcuts(
          bindings: _buildShortcuts(),
          child: Focus(
            autofocus: true,
            child: widget.child,
          ),
        ),
        
        // Debug overlay (when visible)
        if (_isOverlayVisible)
          Positioned.fill(
            child: TomDebugPanel(
              selectedTab: _selectedTabIndex,
              onTabChanged: (index) => setState(() => _selectedTabIndex = index),
              onClose: () => setState(() => _isOverlayVisible = false),
            ),
          ),
        
        // Debug activation indicator (when available but closed)
        if (!_isOverlayVisible)
          Positioned(
            right: 8,
            bottom: 8,
            child: _DebugIndicator(onTap: _showOverlay),
          ),
      ],
    );
  }
  
  Map<ShortcutActivator, VoidCallback> _buildShortcuts() => {
    // Ctrl+Shift+D: Toggle debug overlay
    const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true):
        _toggleOverlay,
    // Escape: Close overlay
    const SingleActivator(LogicalKeyboardKey.escape): _hideOverlay,
  };
  
  void _toggleOverlay() => setState(() => _isOverlayVisible = !_isOverlayVisible);
  void _showOverlay() => setState(() => _isOverlayVisible = true);
  void _hideOverlay() => setState(() => _isOverlayVisible = false);
}
```

### 3.2 Debug Panel Layout

```dart
/// Main debug panel with tabbed interface.
class TomDebugPanel extends StatefulWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onClose;
  
  const TomDebugPanel({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onClose,
  });
  
  @override
  State<TomDebugPanel> createState() => _TomDebugPanelState();
}

class _TomDebugPanelState extends State<TomDebugPanel> {
  final _searchController = TextEditingController();
  String _filterText = '';
  
  static const _tabs = [
    _DebugTab(icon: Icons.security, label: 'Auth', view: DebugViewType.authorization),
    _DebugTab(icon: Icons.translate, label: 'Resources', view: DebugViewType.resources),
    _DebugTab(icon: Icons.account_tree, label: 'ID Tree', view: DebugViewType.idStructure),
    _DebugTab(icon: Icons.play_arrow, label: 'Actions', view: DebugViewType.actions),
    _DebugTab(icon: Icons.data_object, label: 'State', view: DebugViewType.state),
    _DebugTab(icon: Icons.route, label: 'Auth Trace', view: DebugViewType.authTrace),
    _DebugTab(icon: Icons.search, label: 'Res Trace', view: DebugViewType.resourceTrace),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            _buildFilterBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Colors.amber),
          const SizedBox(width: 8),
          const Text(
            'Tom Debug Inspector',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white70),
            tooltip: 'Export',
            onPressed: _exportCurrentView,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Close (Esc)',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    final view = _tabs[widget.selectedTab].view;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildDebugView(view),
    );
  }
  
  Widget _buildDebugView(DebugViewType type) {
    return switch (type) {
      DebugViewType.authorization => AuthorizationDebugView(filter: _filterText),
      DebugViewType.resources => ResourcesDebugView(filter: _filterText),
      DebugViewType.idStructure => IdStructureDebugView(filter: _filterText),
      DebugViewType.actions => ActionsDebugView(filter: _filterText),
      DebugViewType.state => StateInspectorDebugView(filter: _filterText),
      DebugViewType.authTrace => AuthTraceDebugView(filter: _filterText),
      DebugViewType.resourceTrace => ResourceTraceDebugView(filter: _filterText),
    };
  }
}
```

---

## 4. Data Collection Infrastructure

### 4.1 Widget Tree Walker

Collects debug information from the live widget tree:

```dart
/// Walks the Flutter element tree collecting Tom widget information.
class TomWidgetTreeCollector {
  /// Collects all TomNodeBase widgets from the tree.
  static List<TomWidgetInfo> collectWidgets(BuildContext context) {
    final widgets = <TomWidgetInfo>[];
    
    void visitor(Element element) {
      final widget = element.widget;
      if (widget is TomNodeBase) {
        widgets.add(TomWidgetInfo.fromWidget(widget, element));
      }
      element.visitChildren(visitor);
    }
    
    context.visitChildElements(visitor);
    return widgets;
  }
  
  /// Collects all TomPolicyNodeBase widgets with authorization state.
  static List<TomAuthInfo> collectAuthorizationState(BuildContext context) {
    final result = <TomAuthInfo>[];
    
    void visitor(Element element) {
      final widget = element.widget;
      if (widget is TomPolicyNodeBase) {
        final fullPath = widget.basePath;
        final authState = (fullPath != null)
            ? TomAuthorization.resolveAuth(fullPath)
            : TomAuthState.full;
        
        result.add(TomAuthInfo(
          widgetType: widget.runtimeType.toString(),
          tomId: widget.tomId,
          fullPath: fullPath,
          authState: authState,
          groupMembership: widget.tomGroup?.id,
        ));
      }
      element.visitChildren(visitor);
    }
    
    context.visitChildElements(visitor);
    return result;
  }
}

/// Information about a Tom widget for debug display.
class TomWidgetInfo {
  final String widgetType;
  final String? tomId;
  final String? fullIdPath;
  final String? groupName;
  final String debugLabel;
  final int depth;
  
  const TomWidgetInfo({
    required this.widgetType,
    this.tomId,
    this.fullIdPath,
    this.groupName,
    required this.debugLabel,
    required this.depth,
  });
  
  factory TomWidgetInfo.fromWidget(TomNodeBase widget, Element element) {
    return TomWidgetInfo(
      widgetType: widget.runtimeType.toString(),
      tomId: widget.tomId,
      fullIdPath: widget.basePath,
      groupName: widget.tomGroup?.id,
      debugLabel: widget.debugLabel,
      depth: _calculateDepth(element),
    );
  }
}
```

### 4.2 Reflection-Based Collection

Collects deep information using `tom_reflection`:

```dart
/// Collects state and metadata using reflection.
class TomReflectionCollector {
  /// Inspects a TomClass state tree and returns all member information.
  static List<TomMemberInfo> inspectState(TomClass state) {
    final mirror = tomReflect.reflect(state);
    final classMirror = mirror.type;
    final members = <TomMemberInfo>[];
    
    for (final entry in classMirror.declarations.entries) {
      final name = entry.key;
      final decl = entry.value;
      
      if (decl is! VariableMirror) continue;
      
      final value = mirror.invokeGetter(name);
      final annotations = decl.metadata
          .map((m) => m.reflectee)
          .toList();
      
      members.add(TomMemberInfo(
        name: name,
        type: decl.type.reflectedType.toString(),
        value: _formatValue(value),
        annotations: annotations.map((a) => a.toString()).toList(),
        isObservable: value is TomObservable,
      ));
    }
    
    return members;
  }
  
  /// Discovers all widget fields in a TomScreenElementsProvider.
  static List<TomElementField> discoverElements<T extends TomScreenElementsProvider>(
    T provider,
  ) {
    final mirror = tomReflect.reflect(provider);
    final classMirror = mirror.type;
    final elements = <TomElementField>[];
    
    for (final entry in classMirror.declarations.entries) {
      final name = entry.key;
      final decl = entry.value;
      
      if (decl is! VariableMirror) continue;
      
      final value = mirror.invokeGetter(name);
      if (value is Widget) {
        String? tomId;
        if (value is TomNodeBase) {
          tomId = value.tomId;
        }
        
        elements.add(TomElementField(
          fieldName: name,
          widgetType: value.runtimeType.toString(),
          tomId: tomId,
        ));
      }
    }
    
    return elements;
  }
  
  /// Discovers all actions in an ActionController.
  static List<TomActionInfo> discoverActions(TomActionController controller) {
    final mirror = tomReflect.reflect(controller);
    final classMirror = mirror.type;
    final actions = <TomActionInfo>[];
    
    for (final entry in classMirror.declarations.entries) {
      final name = entry.key;
      final value = mirror.invokeGetter(name);
      
      if (value is TomAction) {
        actions.add(TomActionInfo(
          fieldName: name,
          actionId: value.actionId,
          actionType: value.runtimeType.toString(),
          controllerId: controller.controllerId,
          canExecute: value.canExecute(),
          isUndoable: value.isUndoable,
          group: value.group,
        ));
      }
    }
    
    return actions;
  }
}
```

### 4.3 Global Registry Access

Accesses global singletons for auth and resource data:

```dart
/// Collector for global authorization data.
class TomAuthCollector {
  /// Resolves authorization for a path and returns full trace.
  static TomAuthTrace resolveWithTrace(String path) {
    final state = TomAuthorization.resolveAuth(path);
    final adapter = TomAuthorization.adapter;
    
    // Collect lookup hierarchy
    final hierarchy = <String, TomAuthState>{};
    final segments = path.split('.');
    for (int i = 1; i <= segments.length; i++) {
      final subpath = segments.take(i).join('.');
      hierarchy[subpath] = TomAuthorization.resolveAuth(subpath);
    }
    
    return TomAuthTrace(
      requestedPath: path,
      resolvedState: state,
      lookupHierarchy: hierarchy,
      adapterType: adapter.runtimeType.toString(),
    );
  }
}

/// Collector for global resource data.
class TomResourceCollector {
  /// Resolves a resource with full fallback trace.
  static TomResourceTrace resolveWithTrace(String basePath, String suffix) {
    final attempts = <TomResourceAttempt>[];
    
    // Use the fallback chain from TomUIResources
    final fallbackPaths = TomUIResources.fallbackPathsFor(basePath);
    
    for (final path in fallbackPaths) {
      final fullKey = '$path.$suffix';
      final value = TomUIResources.adapter?.resourceMap[fullKey];
      attempts.add(TomResourceAttempt(
        key: fullKey,
        hit: value != null,
        value: value?.toString(),
      ));
      if (value != null) break; // Found
    }
    
    return TomResourceTrace(
      basePath: basePath,
      suffix: suffix,
      attempts: attempts,
      resolvedValue: attempts.firstWhereOrNull((a) => a.hit)?.value,
    );
  }
  
  /// Collects all registered resource keys matching a pattern.
  static List<String> findResourceKeys(String pattern) {
    final regex = RegExp(pattern, caseSensitive: false);
    final adapter = TomUIResources.adapter;
    if (adapter == null) return [];
    
    return adapter.resourceMap.keys
        .where((key) => regex.hasMatch(key))
        .toList()
      ..sort();
  }
}
```

---

## 5. Debug Views

### 5.1 Authorization View

Displays authorization state for all Tom widgets:

```dart
class AuthorizationDebugView extends StatelessWidget {
  final String filter;
  
  const AuthorizationDebugView({super.key, required this.filter});
  
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final authInfos = TomWidgetTreeCollector.collectAuthorizationState(context);
        final filtered = _applyFilter(authInfos);
        
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final info = filtered[index];
            return _AuthInfoTile(info: info);
          },
        );
      },
    );
  }
}

class _AuthInfoTile extends StatelessWidget {
  final TomAuthInfo info;
  
  @override
  Widget build(BuildContext context) {
    final stateColor = switch (info.authState) {
      TomAuthState.none => Colors.red,
      TomAuthState.disabled => Colors.grey,
      TomAuthState.read => Colors.orange,
      TomAuthState.full => Colors.green,
    };
    
    return ListTile(
      leading: Icon(Icons.security, color: stateColor),
      title: Text(info.tomId ?? '(no ID)'),
      subtitle: Text(info.fullPath),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.groupMembership != null)
            Chip(label: Text('g-${info.groupMembership}')),
          const SizedBox(width: 8),
          _AuthStateChip(state: info.authState),
        ],
      ),
      onTap: () => _showAuthTrace(context, info.fullPath),
    );
  }
}
```

### 5.2 Resources View

Displays resource resolution status:

```dart
class ResourcesDebugView extends StatefulWidget {
  final String filter;
  
  const ResourcesDebugView({super.key, required this.filter});
  
  @override
  State<ResourcesDebugView> createState() => _ResourcesDebugViewState();
}

class _ResourcesDebugViewState extends State<ResourcesDebugView> {
  String _selectedSuffix = 'label';
  
  static const _commonSuffixes = ['label', 'title', 'hint', 'icon', 'tooltip'];
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Suffix selector
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SegmentedButton<String>(
            segments: _commonSuffixes
                .map((s) => ButtonSegment(value: s, label: Text(s)))
                .toList(),
            selected: {_selectedSuffix},
            onSelectionChanged: (sel) => setState(() => _selectedSuffix = sel.first),
          ),
        ),
        
        // Resource list
        Expanded(
          child: _ResourceList(suffix: _selectedSuffix, filter: widget.filter),
        ),
      ],
    );
  }
}

class _ResourceList extends StatelessWidget {
  final String suffix;
  final String filter;
  
  @override
  Widget build(BuildContext context) {
    final widgetInfos = TomWidgetTreeCollector.collectWidgets(context);
    
    return ListView.builder(
      itemCount: widgetInfos.length,
      itemBuilder: (context, index) {
        final widget = widgetInfos[index];
        if (widget.fullIdPath == null) return const SizedBox.shrink();
        
        final trace = TomResourceCollector.resolveWithTrace(
          widget.fullIdPath!,
          suffix,
        );
        
        return _ResourceTile(
          widgetInfo: widget,
          trace: trace,
          suffix: suffix,
        );
      },
    );
  }
}
```

### 5.3 ID Structure View

Displays the hierarchical ID tree:

```dart
class IdStructureDebugView extends StatelessWidget {
  final String filter;
  
  const IdStructureDebugView({super.key, required this.filter});
  
  @override
  Widget build(BuildContext context) {
    final widgets = TomWidgetTreeCollector.collectWidgets(context);
    final tree = _buildIdTree(widgets);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tree.duplicates.isNotEmpty)
            _DuplicateWarnings(duplicates: tree.duplicates),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _IdTreeWidget(node: tree.root, filter: filter),
          ),
        ],
      ),
    );
  }
  
  _IdTree _buildIdTree(List<TomWidgetInfo> widgets) {
    final root = _IdTreeNode(segment: 'root', prefix: '', children: []);
    final duplicates = <String>[];
    final seen = <String>{};
    
    for (final widget in widgets) {
      final path = widget.fullIdPath;
      if (path == null) continue;
      
      if (seen.contains(path)) {
        duplicates.add(path);
      }
      seen.add(path);
      
      _insertPath(root, path.split('.'));
    }
    
    return _IdTree(root: root, duplicates: duplicates);
  }
}
```

### 5.4 Actions View

Displays registered actions and execution history:

```dart
class ActionsDebugView extends StatelessWidget {
  final String filter;
  
  const ActionsDebugView({super.key, required this.filter});
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Registry'),
              Tab(text: 'History'),
              Tab(text: 'Undo Stack'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ActionRegistryTab(filter: filter),
                _ActionHistoryTab(filter: filter),
                _UndoStackTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRegistryTab extends StatelessWidget {
  final String filter;
  
  @override
  Widget build(BuildContext context) {
    // Collect all registered action controllers
    final controllers = TomActionRegistry.allControllers;
    
    return ListView.builder(
      itemCount: controllers.length,
      itemBuilder: (context, index) {
        final controller = controllers[index];
        final actions = TomReflectionCollector.discoverActions(controller);
        
        return ExpansionTile(
          title: Text('ac-${controller.controllerId}'),
          subtitle: Text('${actions.length} actions'),
          children: actions.map((a) => _ActionTile(action: a)).toList(),
        );
      },
    );
  }
}
```

### 5.5 State Inspector View

Reflection-powered state tree browser:

```dart
class StateInspectorDebugView extends StatefulWidget {
  final String filter;
  
  const StateInspectorDebugView({super.key, required this.filter});
  
  @override
  State<StateInspectorDebugView> createState() => _StateInspectorDebugViewState();
}

class _StateInspectorDebugViewState extends State<StateInspectorDebugView> {
  TomStateSnapshot? _snapshot1;
  TomStateSnapshot? _snapshot2;
  bool _showDiff = false;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Snapshot controls
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Snapshot'),
                onPressed: _takeSnapshot,
              ),
              const SizedBox(width: 8),
              if (_snapshot1 != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.compare),
                  label: const Text('Diff'),
                  onPressed: _showDiffDialog,
                ),
            ],
          ),
        ),
        
        // State tree browser
        Expanded(
          child: _showDiff && _snapshot1 != null && _snapshot2 != null
              ? _StateDiffView(before: _snapshot1!, after: _snapshot2!)
              : _StateTreeView(filter: widget.filter),
        ),
      ],
    );
  }
  
  void _takeSnapshot() {
    final appState = getAppState(); // Access global app state
    setState(() {
      _snapshot2 = _snapshot1;
      _snapshot1 = TomStateSnapshot.capture(appState);
    });
  }
}

class _StateTreeView extends StatelessWidget {
  final String filter;
  
  @override
  Widget build(BuildContext context) {
    final appState = getAppState();
    final members = TomReflectionCollector.inspectState(appState);
    
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return _MemberTile(member: member);
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final TomMemberInfo member;
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        member.isObservable ? Icons.visibility : Icons.data_object,
        color: member.isObservable ? Colors.green : Colors.grey,
      ),
      title: Text(member.name),
      subtitle: Text('${member.type}: ${member.value}'),
      trailing: member.annotations.isNotEmpty
          ? Tooltip(
              message: member.annotations.join('\n'),
              child: const Icon(Icons.info_outline),
            )
          : null,
    );
  }
}
```

### 5.6 Auth Trace View

Deep trace for a selected widget's authorization:

```dart
class AuthTraceDebugView extends StatefulWidget {
  final String filter;
  
  const AuthTraceDebugView({super.key, required this.filter});
  
  @override
  State<AuthTraceDebugView> createState() => _AuthTraceDebugViewState();
}

class _AuthTraceDebugViewState extends State<AuthTraceDebugView> {
  String? _selectedPath;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Path selector
        SizedBox(
          width: 300,
          child: _PathSelectorList(
            filter: widget.filter,
            selectedPath: _selectedPath,
            onPathSelected: (path) => setState(() => _selectedPath = path),
          ),
        ),
        const VerticalDivider(),
        // Trace view
        Expanded(
          child: _selectedPath != null
              ? _AuthTraceDetail(path: _selectedPath!)
              : const Center(child: Text('Select a path to trace')),
        ),
      ],
    );
  }
}

class _AuthTraceDetail extends StatelessWidget {
  final String path;
  
  @override
  Widget build(BuildContext context) {
    final trace = TomAuthCollector.resolveWithTrace(path);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Path: $path', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Adapter: ${trace.adapterType}'),
          const SizedBox(height: 16),
          const Text('Lookup Hierarchy:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...trace.lookupHierarchy.entries.map((e) => ListTile(
            dense: true,
            title: Text(e.key),
            trailing: _AuthStateChip(state: e.value),
          )),
          const SizedBox(height: 16),
          const Text('Resolved State:', style: TextStyle(fontWeight: FontWeight.bold)),
          _AuthStateCard(state: trace.resolvedState),
        ],
      ),
    );
  }
}
```

### 5.7 Resource Trace View

Deep trace for resource resolution:

```dart
class ResourceTraceDebugView extends StatefulWidget {
  final String filter;
  
  const ResourceTraceDebugView({super.key, required this.filter});
  
  @override
  State<ResourceTraceDebugView> createState() => _ResourceTraceDebugViewState();
}

class _ResourceTraceDebugViewState extends State<ResourceTraceDebugView> {
  String? _selectedBasePath;
  String _suffix = 'label';
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Path selector
        SizedBox(
          width: 300,
          child: Column(
            children: [
              // Suffix input
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Suffix',
                    hintText: 'e.g., label, title, hint',
                  ),
                  onChanged: (v) => setState(() => _suffix = v),
                ),
              ),
              Expanded(
                child: _PathSelectorList(
                  filter: widget.filter,
                  selectedPath: _selectedBasePath,
                  onPathSelected: (path) => setState(() => _selectedBasePath = path),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(),
        // Trace view
        Expanded(
          child: _selectedBasePath != null
              ? _ResourceTraceDetail(basePath: _selectedBasePath!, suffix: _suffix)
              : const Center(child: Text('Select a path to trace')),
        ),
      ],
    );
  }
}

class _ResourceTraceDetail extends StatelessWidget {
  final String basePath;
  final String suffix;
  
  @override
  Widget build(BuildContext context) {
    final trace = TomResourceCollector.resolveWithTrace(basePath, suffix);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Base Path: $basePath', style: Theme.of(context).textTheme.titleMedium),
          Text('Suffix: $suffix'),
          const SizedBox(height: 16),
          const Text('Fallback Chain:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...trace.attempts.map((a) => ListTile(
            dense: true,
            leading: Icon(
              a.hit ? Icons.check_circle : Icons.cancel,
              color: a.hit ? Colors.green : Colors.red,
            ),
            title: Text(a.key),
            trailing: a.hit ? Text(a.value ?? '') : null,
          )),
          const SizedBox(height: 16),
          Text(
            'Resolved: ${trace.resolvedValue ?? "(not found)"}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: trace.resolvedValue != null ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 6. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+D` | Toggle debug overlay |
| `Escape` | Close debug overlay |
| `Ctrl+1` through `Ctrl+7` | Switch to tab 1-7 |
| `Ctrl+F` | Focus search/filter field |
| `Ctrl+E` | Export current view |
| `Ctrl+C` | Copy selected item |

Platform-specific modifier keys:
- macOS: Use `Cmd` instead of `Ctrl`
- Linux/Windows: Use `Ctrl`

---

## 7. Export and Serialization

### 7.1 Export Formats

Each view supports multiple export formats:

```dart
enum ExportFormat {
  yaml,
  json,
  csv,
  markdown,
}

abstract class DebugExporter {
  String export(ExportFormat format);
}

class AuthorizationExporter implements DebugExporter {
  final List<TomAuthInfo> data;
  
  @override
  String export(ExportFormat format) {
    return switch (format) {
      ExportFormat.yaml => _toYaml(),
      ExportFormat.json => _toJson(),
      ExportFormat.csv => _toCsv(),
      ExportFormat.markdown => _toMarkdown(),
    };
  }
  
  String _toYaml() {
    final buffer = StringBuffer('# Authorization State Export\n\n');
    for (final info in data) {
      buffer.writeln('- path: ${info.fullPath}');
      buffer.writeln('  state: ${info.authState.name}');
      if (info.groupMembership != null) {
        buffer.writeln('  group: ${info.groupMembership}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
  
  String _toMarkdown() {
    final buffer = StringBuffer('# Authorization State Export\n\n');
    buffer.writeln('| Path | Auth State | Group |');
    buffer.writeln('|------|------------|-------|');
    for (final info in data) {
      buffer.writeln(
        '| `${info.fullPath}` | ${info.authState.name} | '
        '${info.groupMembership ?? '-'} |',
      );
    }
    return buffer.toString();
  }
}
```

### 7.2 Copy-Ready Resource Entries

Generate resource map entries for missing resources:

```dart
class ResourceEntryGenerator {
  /// Generates resource map entries for all missing resources.
  static String generateMissingEntries(List<TomResourceTrace> traces) {
    final buffer = StringBuffer('// Missing resource entries\n\n');
    
    for (final trace in traces.where((t) => t.resolvedValue == null)) {
      // Generate entry for the most specific key (first in fallback chain)
      final key = trace.attempts.first.key;
      buffer.writeln("'$key': 'TODO: Add ${trace.suffix} text',");
    }
    
    return buffer.toString();
  }
}
```

---

## 8. Performance Considerations

### 8.1 Tree-Shaking in Release Builds

The debug system is completely removed in release builds when unused:

```dart
// In release mode with TomDebugConfig.enabled = false,
// Dart's tree-shaking removes all debug code.

class TomDebugOverlay extends StatelessWidget {
  final Widget child;
  
  const TomDebugOverlay({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    // Constant-folded in release mode
    if (!TomDebugConfig.enabled) {
      return child;
    }
    // ... debug code tree-shaken away
  }
}
```

### 8.2 Pull-Based Collection

Data is only collected when views are visible:

```dart
class LazyDebugData<T> {
  T? _cached;
  DateTime? _cachedAt;
  final Duration _maxAge;
  final T Function() _collector;
  
  LazyDebugData({
    required T Function() collector,
    Duration maxAge = const Duration(seconds: 2),
  }) : _collector = collector,
       _maxAge = maxAge;
  
  T get value {
    final now = DateTime.now();
    if (_cached == null || 
        _cachedAt == null || 
        now.difference(_cachedAt!) > _maxAge) {
      _cached = _collector();
      _cachedAt = now;
    }
    return _cached!;
  }
  
  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }
}
```

### 8.3 Efficient Tree Walking

Minimize tree traversals with batched collection:

```dart
class BatchedTreeCollector {
  /// Single pass collects all debug information.
  static DebugSnapshot collectAll(BuildContext context) {
    final widgets = <TomWidgetInfo>[];
    final authInfos = <TomAuthInfo>[];
    final idPaths = <String>{};
    
    void visitor(Element element) {
      final widget = element.widget;
      
      if (widget is TomNodeBase) {
        final info = TomWidgetInfo.fromWidget(widget, element);
        widgets.add(info);
        
        if (info.fullIdPath != null) {
          idPaths.add(info.fullIdPath!);
        }
      }
      
      if (widget is TomPolicyNodeBase) {
        authInfos.add(TomAuthInfo.fromWidget(widget, element));
      }
      
      element.visitChildren(visitor);
    }
    
    context.visitChildElements(visitor);
    
    return DebugSnapshot(
      widgets: widgets,
      authInfos: authInfos,
      idPaths: idPaths,
      timestamp: DateTime.now(),
    );
  }
}
```

---

## 9. Implementation Plan

### Phase 1: Core Infrastructure (1 week)

- [ ] `TomDebugConfig` activation model
- [ ] `TomDebugOverlay` widget wrapper
- [ ] `TomDebugPanel` tabbed interface
- [ ] Keyboard shortcut handling
- [ ] `TomWidgetTreeCollector` basic implementation

### Phase 2: Authorization & Resources Views (1 week)

- [ ] `AuthorizationDebugView` implementation
- [ ] `TomAuthCollector` with trace support
- [ ] `ResourcesDebugView` implementation
- [ ] `TomResourceCollector` with fallback trace
- [ ] Export functionality for both views

### Phase 3: ID Structure & Actions Views (1 week)

- [ ] `IdStructureDebugView` with tree widget
- [ ] Duplicate detection and warnings
- [ ] `ActionsDebugView` with registry tab
- [ ] Action history tracking
- [ ] Undo stack visualization

### Phase 4: State Inspector & Traces (1 week)

- [ ] `StateInspectorDebugView` with reflection
- [ ] State snapshot and diff support
- [ ] `AuthTraceDebugView` deep trace
- [ ] `ResourceTraceDebugView` fallback trace
- [ ] Entry generator for missing resources

### Phase 5: Polish & Testing (1 week)

- [ ] Performance optimization
- [ ] Tree-shaking verification
- [ ] Comprehensive tests
- [ ] Documentation
- [ ] Demo app integration

---

## Appendix: Data Models

```dart
/// Authorization trace result.
class TomAuthTrace {
  final String requestedPath;
  final TomAuthState resolvedState;
  final Map<String, TomAuthState> lookupHierarchy;
  final String adapterType;
}

/// Resource trace result.
class TomResourceTrace {
  final String basePath;
  final String suffix;
  final List<TomResourceAttempt> attempts;
  final String? resolvedValue;
}

/// Single resource lookup attempt.
class TomResourceAttempt {
  final String key;
  final bool hit;
  final String? value;
}

/// State member information from reflection.
class TomMemberInfo {
  final String name;
  final String type;
  final String value;
  final List<String> annotations;
  final bool isObservable;
}

/// Action information from reflection.
class TomActionInfo {
  final String fieldName;
  final String actionId;
  final String actionType;
  final String controllerId;
  final bool canExecute;
  final bool isUndoable;
  final String? group;
}

/// Element field discovered via reflection.
class TomElementField {
  final String fieldName;
  final String widgetType;
  final String? tomId;
}

/// Snapshot of debug data at a point in time.
class DebugSnapshot {
  final List<TomWidgetInfo> widgets;
  final List<TomAuthInfo> authInfos;
  final Set<String> idPaths;
  final DateTime timestamp;
}
```
