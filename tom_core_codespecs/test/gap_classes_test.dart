import 'package:tom_core_codespecs/tom_core_codespecs.dart';
import 'package:test/test.dart';

void main() {
  group('csm2r7: CE-CL TomClientApplication', () {
    test('constructs with defaults and no shared mutable list', () {
      final a = TomClientApplication();
      final b = TomClientApplication();
      a.platforms.add('web');
      expect(a.platforms, ['web']);
      expect(b.platforms, isEmpty, reason: 'each instance owns its own list');
    });

    test('carries the spec-authorable client descriptor fields', () {
      final app = TomClientApplication(
        clientId: 'admin_console',
        displayName: 'Admin Console',
        platforms: ['web', 'macos'],
        entryRoute: 'dashboard',
        serverBaseUrl: 'https://api.example.com',
      );
      expect(app.clientId, 'admin_console');
      expect(app.platforms, ['web', 'macos']);
      expect(app.entryRoute, 'dashboard');
      expect(app.serverBaseUrl, 'https://api.example.com');
    });
  });

  group('csm2r7: CE-CC TomClientConfiguration', () {
    test('per-machine config holder defaults own their maps', () {
      final a = TomClientConfiguration();
      final b = TomClientConfiguration();
      a.featureToggles['beta'] = true;
      a.deviceOptions['dpi'] = 144;
      expect(b.featureToggles, isEmpty);
      expect(b.deviceOptions, isEmpty);
    });

    test('holds the deployment/per-installation fields', () {
      final cfg = TomClientConfiguration(
        apiBaseUrl: 'https://api.example.com',
        environment: 'prod',
        updateChannel: 'stable',
      );
      expect(cfg.apiBaseUrl, 'https://api.example.com');
      expect(cfg.environment, 'prod');
      expect(cfg.updateChannel, 'stable');
    });
  });

  group('csra3: CE-UP TomUserSettings is single-moded', () {
    test('carries value and default independently', () {
      final s = TomUserSettings(
        settingId: 'theme',
        value: 'dark',
        defaultValue: 'light',
      );
      expect(s.value, 'dark');
      expect(s.defaultValue, 'light');
    });

    test('effectiveValue applies the §5.16 persisted-value → default order', () {
      expect(
        TomUserSettings(settingId: 'theme', defaultValue: 'light')
            .effectiveValue,
        'light',
        reason: 'an unset setting resolves to its declared default',
      );
      expect(
        TomUserSettings(settingId: 'theme', value: 'dark', defaultValue: 'light')
            .effectiveValue,
        'dark',
        reason: "the user's persisted choice wins over the default",
      );
    });
  });

  group('csra3: CE-UP server-side per-user persistence', () {
    test('the store is keyed by user — two users never share values', () async {
      final store = TomMemoryUserSettingsStore();
      await store.write('alice', {'theme': 'dark'});
      await store.write('bob', {'theme': 'light'});
      expect(await store.read('alice'), {'theme': 'dark'});
      expect(await store.read('bob'), {'theme': 'light'});
    });

    test('an unknown user reads empty rather than failing', () async {
      expect(await TomMemoryUserSettingsStore().read('nobody'), isEmpty);
    });

    test('a write replaces that user\'s map, and empty clears it', () async {
      final store = TomMemoryUserSettingsStore();
      await store.write('alice', {'theme': 'dark', 'lang': 'de'});
      await store.write('alice', {'lang': 'en'});
      expect(await store.read('alice'), {'lang': 'en'},
          reason: 'write replaces, it does not merge');
      await store.write('alice', {});
      expect(await store.read('alice'), isEmpty);
    });

    test('read returns a copy — mutating it cannot corrupt the store',
        () async {
      final store = TomMemoryUserSettingsStore();
      await store.write('alice', {'theme': 'dark'});
      (await store.read('alice'))['theme'] = 'tampered';
      expect(await store.read('alice'), {'theme': 'dark'});
    });
  });

  group('csm210-4-1: CE-EN TomDomainEnum', () {
    test('defaults own their values list (no shared mutable list)', () {
      final a = TomDomainEnum();
      final b = TomDomainEnum();
      a.values.add(TomDomainEnumValue(valueId: 'pending'));
      expect(a.values.map((v) => v.valueId), ['pending']);
      expect(b.values, isEmpty, reason: 'each instance owns its own list');
    });

    test('names a domain closed value set with stable tokens vs labels', () {
      final e = TomDomainEnum(
        enumId: 'order_status',
        displayName: 'Order status',
        values: [
          TomDomainEnumValue(valueId: 'pending', label: 'Pending payment'),
          TomDomainEnumValue(valueId: 'paid', label: 'Paid'),
          TomDomainEnumValue(
              valueId: 'shipped', label: 'Shipped', description: 'Left the warehouse'),
        ],
        defaultValueId: 'pending',
      );
      expect(e.enumId, 'order_status');
      expect(e.values.map((v) => v.valueId), ['pending', 'paid', 'shipped']);
      expect(e.values[2].description, 'Left the warehouse');
      expect(e.defaultValueId, 'pending');
    });

    test('hasValue reports membership by valueId', () {
      final e = TomDomainEnum(values: [
        TomDomainEnumValue(valueId: 'pending'),
        TomDomainEnumValue(valueId: 'paid'),
      ]);
      expect(e.hasValue('paid'), isTrue);
      expect(e.hasValue('shipped'), isFalse);
    });

    test('defaultValueId is null when the enum has no default', () {
      final e = TomDomainEnum(values: [TomDomainEnumValue(valueId: 'a')]);
      expect(e.defaultValueId, isNull);
    });
  });

  group('csra2: CE-LO TomLayoutModel', () {
    test('the container-kind set is the closed §5.22 nine', () {
      expect(TomLayoutContainerKind.values, [
        TomLayoutContainerKind.row,
        TomLayoutContainerKind.column,
        TomLayoutContainerKind.wrap,
        TomLayoutContainerKind.stack,
        TomLayoutContainerKind.flex,
        TomLayoutContainerKind.grid,
        TomLayoutContainerKind.padding,
        TomLayoutContainerKind.align,
        TomLayoutContainerKind.sizedBox,
      ]);
    });

    test('the override-delta grammar is the closed §5.22 five', () {
      expect(TomLayoutDeltaOp.values, [
        TomLayoutDeltaOp.reparent,
        TomLayoutDeltaOp.setContainerProp,
        TomLayoutDeltaOp.setSlotHint,
        TomLayoutDeltaOp.insertContainer,
        TomLayoutDeltaOp.removeContainer,
      ]);
    });

    // §5.2: a slot references its element by stable id and never embeds the
    // definition — the semantics↔layout split.
    test('a slot node references its element by id, never embedding it', () {
      final slot = TomLayoutSlotNode(nodeId: 'amount', referencedId: 'amount');
      expect(slot.referencedId, 'amount');
      expect(slot.nodeId, 'amount');
    });

    test('nodeIds are unique across the whole base tree', () {
      final model = TomLayoutModel(
        layoutId: 'payment_form',
        base: TomLayoutContainerNode(
          nodeId: 'root',
          kind: TomLayoutContainerKind.column,
          children: [
            TomLayoutSlotNode(nodeId: 'amount', referencedId: 'amount'),
            TomLayoutContainerNode(
              nodeId: 'row1',
              kind: TomLayoutContainerKind.row,
              children: [
                TomLayoutSlotNode(nodeId: 'iban', referencedId: 'iban'),
              ],
            ),
          ],
        ),
      );
      expect(model.nodeIds, {'root', 'amount', 'row1', 'iban'});
      expect(model.findNode('iban'), isA<TomLayoutSlotNode>());
      expect(model.findNode('nope'), isNull);
    });

    // §5.2/§5.22: the load-bearing invariant of the two-layer design — a delta
    // whose target id no longer exists is surfaced as a reconcile warning,
    // NEVER silently dropped, so manual layout survives model changes.
    test('a delta targeting a vanished node is reported, not dropped', () {
      final model = TomLayoutModel(
        layoutId: 'payment_form',
        base: TomLayoutContainerNode(
          nodeId: 'root',
          kind: TomLayoutContainerKind.column,
          children: [
            TomLayoutSlotNode(nodeId: 'amount', referencedId: 'amount'),
          ],
        ),
        overrides: [
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.setSlotHint,
            targetNodeId: 'amount',
            properties: {'flex': 2},
          ),
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.reparent,
            targetNodeId: 'removed_field',
            newParentNodeId: 'root',
          ),
        ],
      );
      final warnings = model.reconcileWarnings();
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('removed_field'));
      expect(model.overrides, hasLength(2),
          reason: 'the delta is reported, never removed');
    });

    test('an insert-container delta resolves against its parent id', () {
      final model = TomLayoutModel(
        layoutId: 'l',
        base: TomLayoutContainerNode(
          nodeId: 'root',
          kind: TomLayoutContainerKind.column,
        ),
        overrides: [
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.insertContainer,
            targetNodeId: 'new_row',
            newParentNodeId: 'root',
            position: 0,
          ),
        ],
      );
      expect(model.reconcileWarnings(), isEmpty);
    });

    test('an empty model reports every delta as unresolved', () {
      final model = TomLayoutModel(layoutId: 'l', overrides: [
        TomLayoutOverrideDelta(
          op: TomLayoutDeltaOp.removeContainer,
          targetNodeId: 'gone',
        ),
      ]);
      expect(model.nodeIds, isEmpty);
      expect(model.reconcileWarnings(), hasLength(1));
    });
  });

  group('csra2: CE-TX TomMessageKeyRegistry', () {
    test('the role and category sets are the closed §5.21 sets', () {
      expect(TomMessageRole.values, [
        TomMessageRole.error,
        TomMessageRole.notification,
        TomMessageRole.email,
        TomMessageRole.report,
        TomMessageRole.generic,
      ]);
      expect(TomMessageCategory.values,
          [TomMessageCategory.uiCopy, TomMessageCategory.errorCopy]);
    });

    test('a missing per-locale entry falls back to base copy, never the key', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en')
        ..register(TomMessageKey(
          key: 'app.order.placed',
          baseCopy: 'Order placed',
          role: TomMessageRole.notification,
          category: TomMessageCategory.uiCopy,
          localeCopy: {'de': 'Bestellung aufgegeben'},
        ));
      expect(registry.resolve('app.order.placed', 'de'), 'Bestellung aufgegeben');
      expect(registry.resolve('app.order.placed', 'fr'), 'Order placed');
      expect(registry.resolve('app.order.placed', 'en'), 'Order placed');
    });

    // §5.21: the MSGKR is the closed key vocabulary, so an unresolved key is a
    // generation-time spec error — never a silent raw-key render.
    test('an unregistered key is a spec error, not a raw-key render', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en');
      expect(registry.hasKey('app.missing'), isFalse);
      expect(() => registry.resolve('app.missing', 'en'), throwsArgumentError);
    });

    test('registering the same key twice is rejected', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en')
        ..register(TomMessageKey(
          key: 'app.a',
          baseCopy: 'A',
          role: TomMessageRole.generic,
          category: TomMessageCategory.uiCopy,
        ));
      expect(
        () => registry.register(TomMessageKey(
          key: 'app.a',
          baseCopy: 'A again',
          role: TomMessageRole.generic,
          category: TomMessageCategory.uiCopy,
        )),
        throwsArgumentError,
      );
    });

    // §5.21: the error-copy namespace IS the CE-ER code namespace — each code
    // has exactly one MSGKR entry.
    test('error copy is keyed by its CE-ER error code', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en')
        ..register(TomMessageKey(
          key: 'app.error.amount.tooLarge',
          baseCopy: 'Amount may not exceed {max}.',
          role: TomMessageRole.error,
          category: TomMessageCategory.errorCopy,
          errorCode: 'amount.tooLarge',
          parameters: ['max'],
        ));
      expect(registry.forErrorCode('amount.tooLarge')?.key,
          'app.error.amount.tooLarge');
      expect(registry.forErrorCode('nope'), isNull);
      expect(registry.keys.single.parameters, ['max']);
    });

    test('an error-copy entry without an error code is rejected', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en');
      expect(
        () => registry.register(TomMessageKey(
          key: 'app.error.loose',
          baseCopy: 'Something failed',
          role: TomMessageRole.error,
          category: TomMessageCategory.errorCopy,
        )),
        throwsArgumentError,
      );
    });
  });

  group('csra2: CE-NV TomRouteRegistry', () {
    test('the presentation and outcome sets are the closed §5.11 sets', () {
      expect(TomScreenPresentation.values,
          [TomScreenPresentation.replace, TomScreenPresentation.popup]);
      expect(TomFlowOutcome.values, [
        TomFlowOutcome.success,
        TomFlowOutcome.error,
        TomFlowOutcome.validationError,
      ]);
    });

    // The documented gap: the substrate "assumes route uniqueness" with no
    // formal registry (§5.11). The registry is what makes it checkable.
    test('route ids are unique — a duplicate is rejected', () {
      final registry = TomRouteRegistry()
        ..registerRoute(TomRouteDefinition(routeId: 'dashboard'));
      expect(registry.hasRoute('dashboard'), isTrue);
      expect(
        () => registry.registerRoute(TomRouteDefinition(routeId: 'dashboard')),
        throwsArgumentError,
      );
    });

    test('a form is assigned to a screen as replace or popup overlay', () {
      final registry = TomRouteRegistry()
        ..registerRoute(TomRouteDefinition(routeId: 'payment'))
        ..assignForm(TomFormScreenAssignment(
          formId: 'payment_form',
          routeId: 'payment',
          presentation: TomScreenPresentation.popup,
        ));
      expect(registry.assignmentFor('payment_form')?.presentation,
          TomScreenPresentation.popup);
      expect(registry.assignmentFor('nope'), isNull);
    });

    // §5.11: navigation is action-triggered and its target is CONDITIONAL on
    // the action outcome.
    test('an action reaches different targets per outcome', () {
      final registry = TomRouteRegistry()
        ..registerRoute(TomRouteDefinition(routeId: 'payment'))
        ..registerRoute(TomRouteDefinition(routeId: 'confirmation'))
        ..registerRoute(TomRouteDefinition(routeId: 'error_display'))
        ..addFlowEdge(TomScreenFlowEdge(
          sourceRouteId: 'payment',
          actionId: 'submit_payment',
          outcome: TomFlowOutcome.success,
          targetRouteId: 'confirmation',
        ))
        ..addFlowEdge(TomScreenFlowEdge(
          sourceRouteId: 'payment',
          actionId: 'submit_payment',
          outcome: TomFlowOutcome.error,
          targetRouteId: 'error_display',
          presentation: TomScreenPresentation.popup,
        ));
      expect(
        registry.targetFor('payment', 'submit_payment', TomFlowOutcome.success),
        'confirmation',
      );
      expect(
        registry.targetFor('payment', 'submit_payment', TomFlowOutcome.error),
        'error_display',
      );
      expect(
        registry.targetFor(
            'payment', 'submit_payment', TomFlowOutcome.validationError),
        isNull,
      );
    });

    test('edges and assignments naming an unregistered route are reported', () {
      final registry = TomRouteRegistry()
        ..registerRoute(TomRouteDefinition(routeId: 'payment'))
        ..addFlowEdge(TomScreenFlowEdge(
          sourceRouteId: 'payment',
          actionId: 'submit',
          outcome: TomFlowOutcome.success,
          targetRouteId: 'ghost',
        ))
        ..assignForm(TomFormScreenAssignment(
          formId: 'f',
          routeId: 'phantom',
          presentation: TomScreenPresentation.replace,
        ));
      final dangling = registry.danglingRouteReferences();
      expect(dangling, containsAll(<String>['ghost', 'phantom']));
      expect(dangling, hasLength(2));
    });
  });

  group('csra2: CE-JB TomJobDeclaration', () {
    test('carries only the fields the tom_core scheduler has no home for', () {
      final job = TomJobDeclaration(
        jobId: 'nightly_settlement',
        serviceUnitId: 'billing',
        environments: ['staging', 'prod'],
        targetRefs: ['Payment', 'SettlementReport'],
      );
      expect(job.jobId, 'nightly_settlement');
      expect(job.serviceUnitId, 'billing');
      expect(job.environments, ['staging', 'prod']);
      expect(job.targetRefs, ['Payment', 'SettlementReport']);
    });

    // Deployment gating is opt-out, not opt-in: a declared job runs unless the
    // spec says otherwise.
    test('a declared job is enabled by default', () {
      expect(TomJobDeclaration(jobId: 'j').enabled, isTrue);
    });

    // An empty environment list means "every environment" — the alternative
    // (empty = nowhere) would make the common case the verbose one.
    test('an empty environment list runs everywhere', () {
      final job = TomJobDeclaration(jobId: 'j');
      expect(job.environments, isEmpty);
      expect(job.runsIn('prod'), isTrue);
      expect(TomJobDeclaration(jobId: 'j', environments: ['dev']).runsIn('prod'),
          isFalse);
    });

    test('a disabled job runs nowhere', () {
      final job = TomJobDeclaration(jobId: 'j', enabled: false);
      expect(job.runsIn('prod'), isFalse);
    });

    test('defaults own their lists (no shared mutable list)', () {
      final a = TomJobDeclaration(jobId: 'a');
      final b = TomJobDeclaration(jobId: 'b');
      a.environments.add('dev');
      a.targetRefs.add('Payment');
      expect(b.environments, isEmpty);
      expect(b.targetRefs, isEmpty);
    });
  });
}
