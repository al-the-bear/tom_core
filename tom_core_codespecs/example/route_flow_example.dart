// CE-NV — the route-id registry and screen-flow model.
//
// Two things a `TomPageRoute` assumes and cannot check: that a route id a flow
// names was actually registered, and that an action's outcome has somewhere to
// go. Both are answerable here because the whole graph is in one place.
//
// The flow is keyed on (source route, action, OUTCOME), which is what lets one
// action lead three different ways — and what makes "no edge" a legitimate
// answer meaning the screen stays put.
//
// Run with:
//   dart run --enable-asserts example/route_flow_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

void main() {
  requireAsserts();
  print('== CE-NV: routes and screen flow ==');

  final routes = TomRouteRegistry()
    ..registerRoute(TomRouteDefinition(routeId: 'payment', title: 'Payment'))
    ..registerRoute(TomRouteDefinition(routeId: 'confirmation'))
    ..registerRoute(TomRouteDefinition(routeId: 'error_display'))
    ..assignForm(
      TomFormScreenAssignment(
        formId: 'payment_form',
        routeId: 'payment',
        presentation: TomScreenPresentation.popup,
      ),
    )
    ..addFlowEdge(
      TomScreenFlowEdge(
        sourceRouteId: 'payment',
        actionId: 'submit_payment',
        outcome: TomFlowOutcome.success,
        targetRouteId: 'confirmation',
      ),
    )
    ..addFlowEdge(
      TomScreenFlowEdge(
        sourceRouteId: 'payment',
        actionId: 'submit_payment',
        outcome: TomFlowOutcome.error,
        targetRouteId: 'error_display',
        presentation: TomScreenPresentation.popup,
      ),
    );

  // One action, three outcomes, and only two of them move.
  final onSuccess = routes.targetFor(
    'payment',
    'submit_payment',
    TomFlowOutcome.success,
  );
  final onError = routes.targetFor(
    'payment',
    'submit_payment',
    TomFlowOutcome.error,
  );
  final onValidation = routes.targetFor(
    'payment',
    'submit_payment',
    TomFlowOutcome.validationError,
  );

  print('  success          -> $onSuccess');
  print('  error            -> $onError');
  print('  validationError  -> $onValidation  (the screen stays put)');
  assert(onSuccess == 'confirmation');
  assert(onError == 'error_display');
  assert(onValidation == null);

  // The form knows which screen shows it, and how.
  final assignment = routes.assignmentFor('payment_form');
  assert(assignment?.routeId == 'payment');
  assert(assignment?.presentation == TomScreenPresentation.popup);
  print(
    '  payment_form shows on "${assignment?.routeId}" as '
    '${assignment?.presentation.name}',
  );

  // The reference check is what the individual registrations cannot do: run it
  // once the whole graph is in, and anything it returns is a dead end.
  assert(routes.danglingRouteReferences().isEmpty);
  print('  dangling references: none');

  routes.addFlowEdge(
    TomScreenFlowEdge(
      sourceRouteId: 'payment',
      actionId: 'cancel',
      outcome: TomFlowOutcome.success,
      targetRouteId: 'receipt_archive',
    ),
  );
  final dangling = routes.danglingRouteReferences();
  print('  after one unregistered target: ${dangling.join(", ")}');
  assert(dangling.contains('receipt_archive'));

  // Registering a route twice is refused: an id means one screen.
  var refused = false;
  try {
    routes.registerRoute(TomRouteDefinition(routeId: 'payment'));
  } on ArgumentError {
    refused = true;
  }
  assert(refused);
  print('  a duplicate route id is refused');
}
