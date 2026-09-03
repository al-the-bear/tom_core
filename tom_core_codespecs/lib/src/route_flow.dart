/// How a target screen replaces or covers the current one
/// (`codespecs_mapping.md` §5.11).
enum TomScreenPresentation {
  /// The target takes over the current screen.
  replace,

  /// The target is layered over the current screen, which stays mounted.
  popup,
}

/// The outcome of an action, which selects the navigation target
/// (`codespecs_mapping.md` §5.11).
///
/// Navigation is action-triggered and *conditional on the outcome*: one action
/// reaches different screens depending on how it ended, so the outcome set is
/// part of the flow vocabulary rather than a runtime detail.
enum TomFlowOutcome {
  /// The action completed.
  success,

  /// The action failed with a processing error.
  error,

  /// The action was rejected by validation.
  validationError,
}

/// One addressable screen in the navigation graph.
class TomRouteDefinition {
  /// Stable identifier of the route, unique within the registry.
  String routeId;

  /// The route's URL path, when it is deep-linkable.
  String? path;

  /// Human-readable title of the screen.
  String title;

  /// Names of the parameters the route accepts.
  List<String> parameters;

  /// Creates a route definition.
  TomRouteDefinition({
    this.routeId = '',
    this.path,
    this.title = '',
    List<String>? parameters,
  }) : parameters = parameters ?? <String>[];
}

/// Placement of a form onto a screen (`codespecs_mapping.md` §5.11).
///
/// A form is not itself a screen: the same form may take over a route or be
/// layered over one, so the placement is authored separately from the form.
class TomFormScreenAssignment {
  /// Id of the form being placed.
  String formId;

  /// Id of the route the form is placed on.
  String routeId;

  /// Whether the form takes over the screen or is layered over it.
  TomScreenPresentation presentation;

  /// Creates a form-to-screen assignment.
  TomFormScreenAssignment({
    this.formId = '',
    this.routeId = '',
    this.presentation = TomScreenPresentation.replace,
  });
}

/// One conditional edge of the screen flow: from a screen, via an action, for a
/// given outcome, to a target screen.
class TomScreenFlowEdge {
  /// Route the action is triggered from.
  String sourceRouteId;

  /// Id of the triggering action.
  String actionId;

  /// Outcome that selects this edge.
  TomFlowOutcome outcome;

  /// Route reached when the action ends with [outcome].
  String targetRouteId;

  /// How the target is presented.
  TomScreenPresentation presentation;

  /// Creates a screen-flow edge.
  TomScreenFlowEdge({
    this.sourceRouteId = '',
    this.actionId = '',
    this.outcome = TomFlowOutcome.success,
    this.targetRouteId = '',
    this.presentation = TomScreenPresentation.replace,
  });
}

/// The route registry and screen-flow model a CodeSpec's `@CsRoute` /
/// `@CsScreenFlow` (CE-NV) is built on.
///
/// **Why this is a gap (`codespecs_mapping.md` §5.11, verdict *gap*).** The
/// `tom_flutter_ui` substrate (`TomPageRoute` in `widgets/navigation/`) is a
/// bare `MaterialPageRoute` subclass: it knows how to *push* a screen but
/// carries no route id and belongs to no registry. The framework therefore
/// **assumes route uniqueness without anywhere to check it** — two screens can
/// claim the same name and nothing notices until runtime. CodeSpecs needs the
/// two things the substrate has no home for: (a) a **route-id registry** that
/// makes uniqueness and dangling references checkable at generation time, and
/// (b) a **screen-flow model** in which an action's target is conditional on
/// its [TomFlowOutcome] and a form's placement is authored as replace-or-popup.
/// So it lands here as a concrete `tom_core`-family class — never an abstract
/// `Cs*` base (the framework carries annotations only, `codespecs_mapping.md`
/// §1.1).
///
/// A CodeSpec `@CsRoute` graph *is a* [TomRouteRegistry]. CE-NV is a *client*
/// part (`codespecs_mapping.md` §4.2), so the registry lives in the client
/// project of the three-project output trio.
class TomRouteRegistry {
  final Map<String, TomRouteDefinition> _routes =
      <String, TomRouteDefinition>{};
  final Map<String, TomFormScreenAssignment> _assignments =
      <String, TomFormScreenAssignment>{};
  final List<TomScreenFlowEdge> _edges = <TomScreenFlowEdge>[];

  /// Creates an empty registry.
  TomRouteRegistry();

  /// Every registered route, in registration order.
  List<TomRouteDefinition> get routes => _routes.values.toList(growable: false);

  /// Every form-to-screen assignment, in registration order.
  List<TomFormScreenAssignment> get assignments =>
      _assignments.values.toList(growable: false);

  /// Every screen-flow edge, in registration order.
  List<TomScreenFlowEdge> get flowEdges => List.unmodifiable(_edges);

  /// Whether [routeId] names a registered route.
  bool hasRoute(String routeId) => _routes.containsKey(routeId);

  /// Registers [route].
  ///
  /// Throws [ArgumentError] when the id is already taken. Uniqueness is the
  /// registry's whole reason to exist (`codespecs_mapping.md` §5.11): the
  /// substrate assumes it, so something has to enforce it.
  void registerRoute(TomRouteDefinition route) {
    if (_routes.containsKey(route.routeId)) {
      throw ArgumentError.value(
        route.routeId,
        'route.routeId',
        'route id is already registered',
      );
    }
    _routes[route.routeId] = route;
  }

  /// Places a form onto a screen.
  ///
  /// Throws [ArgumentError] when the form already has an assignment — a form
  /// with two placements would render in an order-dependent position.
  void assignForm(TomFormScreenAssignment assignment) {
    if (_assignments.containsKey(assignment.formId)) {
      throw ArgumentError.value(
        assignment.formId,
        'assignment.formId',
        'form is already assigned to a screen',
      );
    }
    _assignments[assignment.formId] = assignment;
  }

  /// The placement of [formId], or `null` when the form is unplaced.
  TomFormScreenAssignment? assignmentFor(String formId) => _assignments[formId];

  /// Adds a conditional screen-flow edge.
  void addFlowEdge(TomScreenFlowEdge edge) => _edges.add(edge);

  /// The route [actionId] reaches from [sourceRouteId] for [outcome], or `null`
  /// when that outcome navigates nowhere (the screen simply stays).
  String? targetFor(
    String sourceRouteId,
    String actionId,
    TomFlowOutcome outcome,
  ) {
    for (final edge in _edges) {
      if (edge.sourceRouteId == sourceRouteId &&
          edge.actionId == actionId &&
          edge.outcome == outcome) {
        return edge.targetRouteId;
      }
    }
    return null;
  }

  /// Route ids referenced by edges or assignments that are not registered.
  ///
  /// This is the generation-time check the substrate cannot perform: a flow
  /// edge pointing at a screen nobody defined is a dead end that would
  /// otherwise only surface when a user walked into it.
  Set<String> danglingRouteReferences() {
    final dangling = <String>{};
    for (final edge in _edges) {
      if (!hasRoute(edge.sourceRouteId)) dangling.add(edge.sourceRouteId);
      if (!hasRoute(edge.targetRouteId)) dangling.add(edge.targetRouteId);
    }
    for (final assignment in _assignments.values) {
      if (!hasRoute(assignment.routeId)) dangling.add(assignment.routeId);
    }
    return dangling;
  }
}
