import 'package:tom_core_codespecs/tom_core_codespecs.dart';
import 'dart:async';

import 'package:test/test.dart';

void main() {
  group('csm2r7: CE-CL TomClientApplication', () {
    test('constructs with defaults and no shared mutable list', () {
      final a = TomClientApplication();
      final b = TomClientApplication();
      a.platforms.add('web');
      a.screenIds.add('dashboard');
      expect(a.platforms, ['web']);
      expect(a.screenIds, ['dashboard']);
      expect(b.platforms, isEmpty, reason: 'each instance owns its own list');
      expect(b.screenIds, isEmpty, reason: 'each instance owns its own list');
    });

    test('carries the spec-authorable client descriptor fields', () {
      final app = TomClientApplication(
        clientId: 'admin_console',
        displayName: 'Admin Console',
        platforms: ['web', 'macos'],
        entryRoute: 'dashboard',
        screenIds: ['dashboard', 'userList'],
        serverBaseUrl: 'https://api.example.com',
      );
      expect(app.clientId, 'admin_console');
      expect(app.platforms, ['web', 'macos']);
      expect(app.entryRoute, 'dashboard');
      expect(app.screenIds, ['dashboard', 'userList']);
      expect(app.serverBaseUrl, 'https://api.example.com');
    });

    test('a client with no screens is representable', () {
      // CLIAPP's `clientKind` admits a command-line client and another server
      // calling in; neither ships a screen, so the empty set is the answer,
      // not a missing one.
      final cli = TomClientApplication(clientId: 'importer');
      expect(cli.screenIds, isEmpty);
      expect(cli.entryRoute, isEmpty);
    });
  });

  group('csra2: CE-LO TomLayoutModel', () {
    test('the container-kind set is the closed codespecs_mapping.md §5.22 '
        'nine', () {
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

    test('the override-delta grammar is the closed '
        'codespecs_mapping.md §5.22 five', () {
      expect(TomLayoutDeltaOp.values, [
        TomLayoutDeltaOp.reparent,
        TomLayoutDeltaOp.setContainerProp,
        TomLayoutDeltaOp.setSlotHint,
        TomLayoutDeltaOp.insertContainer,
        TomLayoutDeltaOp.removeContainer,
      ]);
    });

    // `codespecs_mapping.md` §5.2: a slot references its element by stable id
    // and never embeds the definition — the semantics↔layout split.
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

    // `codespecs_mapping.md` §5.2/§5.22: the load-bearing invariant of the
    // two-layer design — a delta whose target id no longer exists is surfaced
    // as a reconcile warning, NEVER silently dropped, so manual layout survives
    // model changes.
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
      expect(
        model.overrides,
        hasLength(2),
        reason: 'the delta is reported, never removed',
      );
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

    // The kind check. Existence alone is the weaker half of the reconcile: an
    // id that vanished is conspicuous, while an id a regeneration re-used for a
    // different KIND of node still resolves, so the delta goes on applying and
    // quietly means something else. The sealed `TomLayoutNode` base exists so
    // the two can be told apart; these cases are what tells them apart.
    group('a delta addressed at the wrong kind of node', () {
      TomLayoutModel modelWith(List<TomLayoutOverrideDelta> deltas) =>
          TomLayoutModel(
            layoutId: 'payment_form',
            base: TomLayoutContainerNode(
              nodeId: 'root',
              kind: TomLayoutContainerKind.column,
              children: [
                TomLayoutSlotNode(nodeId: 'amount', referencedId: 'amount'),
              ],
            ),
            overrides: deltas,
          );

      test('setSlotHint on a container is reported', () {
        final warnings = modelWith([
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.setSlotHint,
            targetNodeId: 'root',
          ),
        ]).reconcileWarnings();

        expect(warnings, hasLength(1));
        expect(warnings.single, contains('setSlotHint'));
        expect(warnings.single, contains('container "root"'));
        expect(warnings.single, contains('not a slot'));
      });

      test('setContainerProp on a slot is reported', () {
        final warnings = modelWith([
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.setContainerProp,
            targetNodeId: 'amount',
          ),
        ]).reconcileWarnings();

        expect(warnings, hasLength(1));
        expect(warnings.single, contains('slot "amount"'));
        expect(warnings.single, contains('not a container'));
      });

      test('removeContainer on a slot is reported', () {
        final warnings = modelWith([
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.removeContainer,
            targetNodeId: 'amount',
          ),
        ]).reconcileWarnings();

        expect(warnings, hasLength(1));
        expect(warnings.single, contains('not a container'));
      });

      test('a slot named as a new parent is reported', () {
        // Only a container owns children, so a slot can never be a parent —
        // for either of the two operations that name one.
        for (final op in [
          TomLayoutDeltaOp.reparent,
          TomLayoutDeltaOp.insertContainer,
        ]) {
          final warnings = modelWith([
            TomLayoutOverrideDelta(
              op: op,
              targetNodeId: op == TomLayoutDeltaOp.reparent ? 'root' : 'fresh',
              newParentNodeId: 'amount',
            ),
          ]).reconcileWarnings();

          expect(warnings, hasLength(1), reason: op.name);
          expect(warnings.single, contains('slot "amount"'));
          expect(warnings.single, contains('cannot own children'));
        }
      });

      test('reparent accepts a target of either kind', () {
        // The control for the three cases above: `reparent` is the one
        // operation with no kind constraint on its target, so a rule that
        // simply demanded containers everywhere would fail here.
        expect(
          modelWith([
            TomLayoutOverrideDelta(
              op: TomLayoutDeltaOp.reparent,
              targetNodeId: 'amount',
              newParentNodeId: 'root',
            ),
          ]).reconcileWarnings(),
          isEmpty,
          reason: 'a slot may be moved',
        );
        expect(
          modelWith([
            TomLayoutOverrideDelta(
              op: TomLayoutDeltaOp.reparent,
              targetNodeId: 'root',
              newParentNodeId: 'root',
            ),
          ]).reconcileWarnings(),
          isEmpty,
          reason: 'a container may be moved',
        );
      });

      test('a well-formed delta of each kind stays silent', () {
        // The other control. Without it, a check that warned unconditionally
        // would pass every case above.
        expect(
          modelWith([
            TomLayoutOverrideDelta(
              op: TomLayoutDeltaOp.setSlotHint,
              targetNodeId: 'amount',
              properties: {'flex': 2},
            ),
            TomLayoutOverrideDelta(
              op: TomLayoutDeltaOp.setContainerProp,
              targetNodeId: 'root',
              properties: {'spacing': 8},
            ),
            TomLayoutOverrideDelta(
              op: TomLayoutDeltaOp.removeContainer,
              targetNodeId: 'root',
            ),
            TomLayoutOverrideDelta(
              op: TomLayoutDeltaOp.insertContainer,
              targetNodeId: 'fresh',
              newParentNodeId: 'root',
            ),
          ]).reconcileWarnings(),
          isEmpty,
        );
      });
    });

    test('an insert whose id the base already holds is reported', () {
      // The same drift from the other side. A node id is unique across the
      // tree, so an insert that was free to create its id when it was authored
      // and is not any more would otherwise duplicate one.
      final warnings = TomLayoutModel(
        layoutId: 'l',
        base: TomLayoutContainerNode(
          nodeId: 'root',
          children: [TomLayoutSlotNode(nodeId: 'new_row')],
        ),
        overrides: [
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.insertContainer,
            targetNodeId: 'new_row',
            newParentNodeId: 'root',
          ),
        ],
      ).reconcileWarnings();

      expect(warnings, hasLength(1));
      expect(warnings.single, contains('already contains'));
    });

    test(
      'an operation that requires a new parent and names none is reported',
      () {
        for (final op in [
          TomLayoutDeltaOp.reparent,
          TomLayoutDeltaOp.insertContainer,
        ]) {
          final warnings = TomLayoutModel(
            layoutId: 'l',
            base: TomLayoutContainerNode(nodeId: 'root'),
            // A free target id for the insert, so the only thing wrong with
            // the delta is the missing parent: `insertContainer` at an id the
            // base already holds is a second, separate fault.
            overrides: [
              TomLayoutOverrideDelta(
                op: op,
                targetNodeId: op == TomLayoutDeltaOp.reparent
                    ? 'root'
                    : 'fresh',
              ),
            ],
          ).reconcileWarnings();

          expect(warnings, hasLength(1), reason: op.name);
          expect(warnings.single, contains('names no new parent'));
        }
      },
    );

    test('an empty model reports every delta as unresolved', () {
      final model = TomLayoutModel(
        layoutId: 'l',
        overrides: [
          TomLayoutOverrideDelta(
            op: TomLayoutDeltaOp.removeContainer,
            targetNodeId: 'gone',
          ),
        ],
      );
      expect(model.nodeIds, isEmpty);
      expect(model.reconcileWarnings(), hasLength(1));
    });
  });

  group('csra2: CE-TX TomMessageKeyRegistry', () {
    test('the role and category sets are the closed '
        'codespecs_mapping.md §5.21 sets', () {
      expect(TomMessageRole.values, [
        TomMessageRole.error,
        TomMessageRole.notification,
        TomMessageRole.email,
        TomMessageRole.report,
        TomMessageRole.generic,
      ]);
      expect(TomMessageCategory.values, [
        TomMessageCategory.uiCopy,
        TomMessageCategory.errorCopy,
      ]);
    });

    test(
      'a missing per-locale entry falls back to base copy, never the key',
      () {
        final registry = TomMessageKeyRegistry(baseLocale: 'en')
          ..register(
            TomMessageKey(
              key: 'app.order.placed',
              baseCopy: 'Order placed',
              role: TomMessageRole.notification,
              category: TomMessageCategory.uiCopy,
              localeCopy: {'de': 'Bestellung aufgegeben'},
            ),
          );
        expect(
          registry.resolve('app.order.placed', 'de'),
          'Bestellung aufgegeben',
        );
        expect(registry.resolve('app.order.placed', 'fr'), 'Order placed');
        expect(registry.resolve('app.order.placed', 'en'), 'Order placed');
      },
    );

    // `codespecs_mapping.md` §5.21: the MSGKR is the closed key vocabulary, so
    // an unresolved key is a generation-time spec error — never a silent
    // raw-key render.
    test('an unregistered key is a spec error, not a raw-key render', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en');
      expect(registry.hasKey('app.missing'), isFalse);
      expect(() => registry.resolve('app.missing', 'en'), throwsArgumentError);
    });

    test('registering the same key twice is rejected', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en')
        ..register(
          TomMessageKey(
            key: 'app.a',
            baseCopy: 'A',
            role: TomMessageRole.generic,
            category: TomMessageCategory.uiCopy,
          ),
        );
      expect(
        () => registry.register(
          TomMessageKey(
            key: 'app.a',
            baseCopy: 'A again',
            role: TomMessageRole.generic,
            category: TomMessageCategory.uiCopy,
          ),
        ),
        throwsArgumentError,
      );
    });

    // `codespecs_mapping.md` §5.21: the error-copy namespace IS the CE-ER code
    // namespace — each code has exactly one MSGKR entry.
    test('error copy is keyed by its CE-ER error code', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en')
        ..register(
          TomMessageKey(
            key: 'app.error.amount.tooLarge',
            baseCopy: 'Amount may not exceed {max}.',
            role: TomMessageRole.error,
            category: TomMessageCategory.errorCopy,
            errorCode: 'amount.tooLarge',
            parameters: ['max'],
          ),
        );
      expect(
        registry.forErrorCode('amount.tooLarge')?.key,
        'app.error.amount.tooLarge',
      );
      expect(registry.forErrorCode('nope'), isNull);
      expect(registry.keys.single.parameters, ['max']);
    });

    test('an error-copy entry without an error code is rejected', () {
      final registry = TomMessageKeyRegistry(baseLocale: 'en');
      expect(
        () => registry.register(
          TomMessageKey(
            key: 'app.error.loose',
            baseCopy: 'Something failed',
            role: TomMessageRole.error,
            category: TomMessageCategory.errorCopy,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('csra2: CE-NV TomRouteRegistry', () {
    test('the presentation and outcome sets are the closed '
        'codespecs_mapping.md §5.11 sets', () {
      expect(TomScreenPresentation.values, [
        TomScreenPresentation.replace,
        TomScreenPresentation.popup,
      ]);
      expect(TomFlowOutcome.values, [
        TomFlowOutcome.success,
        TomFlowOutcome.error,
        TomFlowOutcome.validationError,
      ]);
    });

    // The documented gap: the substrate "assumes route uniqueness" with no
    // formal registry (`codespecs_mapping.md` §5.11). The registry is what
    // makes it checkable.
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
        ..assignForm(
          TomFormScreenAssignment(
            formId: 'payment_form',
            routeId: 'payment',
            presentation: TomScreenPresentation.popup,
          ),
        );
      expect(
        registry.assignmentFor('payment_form')?.presentation,
        TomScreenPresentation.popup,
      );
      expect(registry.assignmentFor('nope'), isNull);
    });

    // `codespecs_mapping.md` §5.11: navigation is action-triggered and its
    // target is CONDITIONAL on the action outcome.
    test('an action reaches different targets per outcome', () {
      final registry = TomRouteRegistry()
        ..registerRoute(TomRouteDefinition(routeId: 'payment'))
        ..registerRoute(TomRouteDefinition(routeId: 'confirmation'))
        ..registerRoute(TomRouteDefinition(routeId: 'error_display'))
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
          'payment',
          'submit_payment',
          TomFlowOutcome.validationError,
        ),
        isNull,
      );
    });

    test('edges and assignments naming an unregistered route are reported', () {
      final registry = TomRouteRegistry()
        ..registerRoute(TomRouteDefinition(routeId: 'payment'))
        ..addFlowEdge(
          TomScreenFlowEdge(
            sourceRouteId: 'payment',
            actionId: 'submit',
            outcome: TomFlowOutcome.success,
            targetRouteId: 'ghost',
          ),
        )
        ..assignForm(
          TomFormScreenAssignment(
            formId: 'f',
            routeId: 'phantom',
            presentation: TomScreenPresentation.replace,
          ),
        );
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
        readEntities: [_Invoice],
        writtenEntities: [_Payment],
      );
      expect(job.jobId, 'nightly_settlement');
      expect(job.serviceUnitId, 'billing');
      expect(job.environments, ['staging', 'prod']);
      expect(job.readEntities, [_Invoice]);
      expect(job.writtenEntities, [_Payment]);
    });

    // codespecs_mapping.md §5.29 scope part 3 / `codespecs_mapping.md` §4.4.1: a CE-DB target is a
    // `Type` literal, so a renamed entity is a COMPILE error rather than a
    // string that silently stops resolving. What is really being asserted is
    // the static type — a `List<Type>` cannot hold `'Payment'` at all, which is
    // the entire point of typing the member.
    test('entity targets are Type literals, never strings', () {
      final job = TomJobDeclaration(
        jobId: 'j',
        readEntities: [_Invoice],
        writtenEntities: [_Payment, _Invoice],
      );
      expect(job.readEntities, isA<List<Type>>());
      expect(job.writtenEntities, isA<List<Type>>());
      expect(job.writtenEntities, contains(_Payment));
    });

    // SCJOB-WORK.readEntities and .writtenEntities are authored as two separate
    // SOM fields, and impact analysis needs the difference — a schema change
    // breaks a writer differently from a reader. Collapsing them into one union
    // would drop authored information at the CodeSpecs boundary.
    test('read and written targets stay separate', () {
      final job = TomJobDeclaration(
        jobId: 'j',
        readEntities: [_Invoice],
        writtenEntities: [_Payment],
      );
      expect(job.readEntities, isNot(contains(_Payment)));
      expect(job.writtenEntities, isNot(contains(_Invoice)));
      expect(job.targetEntities, containsAll(<Type>[_Invoice, _Payment]));
    });

    // An entity both read and written is one target, not two — the union is
    // what a "which jobs touch this entity?" query wants.
    test('targetEntities is the deduplicated union', () {
      final job = TomJobDeclaration(
        jobId: 'j',
        readEntities: [_Invoice, _Payment],
        writtenEntities: [_Payment],
      );
      expect(job.targetEntities, hasLength(2));
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
      expect(
        TomJobDeclaration(jobId: 'j', environments: ['dev']).runsIn('prod'),
        isFalse,
      );
    });

    test('a disabled job runs nowhere', () {
      final job = TomJobDeclaration(jobId: 'j', enabled: false);
      expect(job.runsIn('prod'), isFalse);
    });

    test('defaults own their lists (no shared mutable list)', () {
      final a = TomJobDeclaration(jobId: 'a');
      final b = TomJobDeclaration(jobId: 'b');
      a.environments.add('dev');
      a.readEntities.add(_Invoice);
      a.writtenEntities.add(_Payment);
      expect(b.environments, isEmpty);
      expect(b.readEntities, isEmpty);
      expect(b.writtenEntities, isEmpty);
    });
  });

  group('csra7: CE-NT channel declarations', () {
    // An unrestricted channel is the common case, so "no urgency list" must
    // mean "carries everything" rather than "carries nothing".
    test('an empty urgency list carries every urgency', () {
      final channel = TomNotificationChannelDeclaration(channelId: 'email');
      for (final urgency in TomNotificationUrgency.values) {
        expect(channel.carries(urgency), isTrue);
      }
    });

    test('a restricted channel carries only its declared urgencies', () {
      final sms = TomNotificationChannelDeclaration(
        channelId: 'sms',
        urgencyLevels: {
          TomNotificationUrgency.high,
          TomNotificationUrgency.critical,
        },
      );
      expect(sms.carries(TomNotificationUrgency.critical), isTrue);
      expect(sms.carries(TomNotificationUrgency.high), isTrue);
      expect(sms.carries(TomNotificationUrgency.low), isFalse);
      expect(sms.carries(TomNotificationUrgency.medium), isFalse);
    });

    test('defaults own their urgency set (no shared mutable set)', () {
      final a = TomNotificationChannelDeclaration(channelId: 'a');
      final b = TomNotificationChannelDeclaration(channelId: 'b');
      a.urgencyLevels.add(TomNotificationUrgency.low);
      expect(b.urgencyLevels, isEmpty);
    });

    test('urgency is ordered least to most urgent', () {
      expect(TomNotificationUrgency.values, [
        TomNotificationUrgency.low,
        TomNotificationUrgency.medium,
        TomNotificationUrgency.high,
        TomNotificationUrgency.critical,
      ]);
      expect(
        TomNotificationUrgency.critical.index >
            TomNotificationUrgency.low.index,
        isTrue,
      );
    });

    test('the category set is the closed four', () {
      expect(TomNotificationCategory.values, [
        TomNotificationCategory.transactional,
        TomNotificationCategory.marketing,
        TomNotificationCategory.system,
        TomNotificationCategory.security,
      ]);
    });
  });

  group('csra7: CE-NT essentiality', () {
    // The compliance surface: "essential" is decided on the TYPE, in one
    // place, so no caller can define it differently.
    test('a mandatory channel makes a type essential', () {
      expect(
        TomNotificationType(
          typeId: 't',
          mandatoryChannelIds: ['email'],
        ).isEssential,
        isTrue,
      );
    });

    test('a non-configurable type is essential', () {
      expect(
        TomNotificationType(typeId: 't', userConfigurable: false).isEssential,
        isTrue,
      );
    });

    test('an ordinary configurable type is not essential', () {
      expect(TomNotificationType(typeId: 't').isEssential, isFalse);
    });
  });

  group('csra7: CE-NT channelsFor preference resolution', () {
    TomNotificationType shipped({
      List<String>? defaults,
      List<String>? mandatory,
      bool configurable = true,
    }) => TomNotificationType(
      typeId: 'order.shipped',
      defaultChannelIds: defaults ?? ['email', 'push'],
      mandatoryChannelIds: mandatory ?? const [],
      userConfigurable: configurable,
    );

    test('no preferences yields the declared defaults', () {
      expect(shipped().channelsFor(null), ['email', 'push']);
    });

    // Rule 1: mandatory first, because every later rule is a narrowing.
    test('mandatory channels come first and are never duplicated', () {
      final type = shipped(defaults: ['email', 'push'], mandatory: ['push']);
      expect(type.channelsFor(null), ['push', 'email']);
    });

    // Rule 2: !userConfigurable ignores preferences outright — stronger than
    // listing every channel as mandatory.
    test('a non-configurable type ignores preferences entirely', () {
      final type = shipped(configurable: false);
      final prefs = TomNotificationPreferences(
        globalOptOut: true,
        mutedTypeIds: {'order.shipped'},
        channelsByTypeId: {
          'order.shipped': ['sms'],
        },
      );
      expect(type.channelsFor(prefs), ['email', 'push']);
    });

    // Rule 3: silencing is all-or-nothing per TYPE, not a per-channel
    // narrowing — only a non-essential type can be silenced, and it has no
    // mandatory channels by definition, so it is left with nothing.
    test('a muted non-essential type is left with no channels', () {
      final prefs = TomNotificationPreferences(mutedTypeIds: {'order.shipped'});
      expect(shipped().channelsFor(prefs), isEmpty);
    });

    test('an essential type is not silenced, and keeps its full set', () {
      final type = shipped(mandatory: ['email']);
      final muted = TomNotificationPreferences(mutedTypeIds: {'order.shipped'});
      expect(type.channelsFor(muted), ['email', 'push']);
      expect(type.channelsFor(TomNotificationPreferences(globalOptOut: true)), [
        'email',
        'push',
      ]);
    });

    test('a global opt-out silences non-essential types only', () {
      final prefs = TomNotificationPreferences(globalOptOut: true);
      expect(shipped().channelsFor(prefs), isEmpty);
      expect(shipped(mandatory: ['email']).channelsFor(prefs), isNotEmpty);
    });

    // Rule 4: a recorded selection REPLACES the defaults; no selection keeps
    // them — which is why an empty list must not be conflated with absence.
    test('a recorded selection replaces the defaults', () {
      final prefs = TomNotificationPreferences(
        channelsByTypeId: {
          'order.shipped': ['sms'],
        },
      );
      expect(shipped().channelsFor(prefs), ['sms']);
    });

    test('an empty selection is a choice, not an absence', () {
      final prefs = TomNotificationPreferences(
        channelsByTypeId: {'order.shipped': <String>[]},
      );
      expect(shipped().channelsFor(prefs), isEmpty);
      expect(
        shipped().channelsFor(TomNotificationPreferences()),
        ['email', 'push'],
        reason: 'no entry at all falls back to the declared defaults',
      );
    });

    test('a selection cannot drop a mandatory channel', () {
      final type = shipped(mandatory: ['email']);
      final prefs = TomNotificationPreferences(
        channelsByTypeId: {
          'order.shipped': ['sms'],
        },
      );
      expect(type.channelsFor(prefs), ['email', 'sms']);
    });
  });

  group('csra7: CE-NT catalogue', () {
    TomNotificationCatalog catalog() => TomNotificationCatalog(
      channels: [
        TomNotificationChannelDeclaration(
          channelId: 'push',
          fallbackChannelId: 'email',
        ),
        TomNotificationChannelDeclaration(channelId: 'email'),
        TomNotificationChannelDeclaration(
          channelId: 'sms',
          urgencyLevels: {TomNotificationUrgency.critical},
        ),
      ],
      types: [
        TomNotificationType(
          typeId: 'order.shipped',
          defaultChannelIds: ['email', 'sms'],
        ),
      ],
    );

    test('a fallback chain includes its own start, nearest first', () {
      expect(catalog().fallbackChainFrom('push'), ['push', 'email']);
    });

    test('a declaration cycle terminates instead of hanging', () {
      final looping = TomNotificationCatalog(
        channels: [
          TomNotificationChannelDeclaration(
            channelId: 'a',
            fallbackChannelId: 'b',
          ),
          TomNotificationChannelDeclaration(
            channelId: 'b',
            fallbackChannelId: 'a',
          ),
        ],
      );
      expect(looping.fallbackChainFrom('a'), ['a', 'b']);
    });

    // A dangling fallback is a spec defect for the validator to report — not a
    // crash at delivery time.
    test(
      'an unknown channel id yields an empty chain rather than throwing',
      () {
        expect(catalog().fallbackChainFrom('carrier-pigeon'), isEmpty);
      },
    );

    // The whole CE-NT resolution in one call: type constraints, then user
    // preference, then the channel's own urgency ceiling.
    test('delivery filters out channels that cannot carry the urgency', () {
      expect(
        catalog().deliveryChannelsFor('order.shipped', null),
        ['email'],
        reason: 'sms only carries critical; the type is medium',
      );
    });

    test('a critical type reaches the restricted channel', () {
      final urgent = TomNotificationCatalog(
        channels: [
          TomNotificationChannelDeclaration(
            channelId: 'sms',
            urgencyLevels: {TomNotificationUrgency.critical},
          ),
        ],
        types: [
          TomNotificationType(
            typeId: 'security.breach',
            urgency: TomNotificationUrgency.critical,
            defaultChannelIds: ['sms'],
          ),
        ],
      );
      expect(urgent.deliveryChannelsFor('security.breach', null), ['sms']);
    });

    test('an undeclared channel id is dropped from delivery', () {
      final dangling = TomNotificationCatalog(
        channels: [TomNotificationChannelDeclaration(channelId: 'email')],
        types: [
          TomNotificationType(
            typeId: 't',
            defaultChannelIds: ['email', 'telegram'],
          ),
        ],
      );
      expect(dangling.deliveryChannelsFor('t', null), ['email']);
    });

    test('an unknown type id yields no delivery channels', () {
      expect(catalog().deliveryChannelsFor('nope', null), isEmpty);
    });
  });

  group('csra8: CE-RP dimensions and measures', () {
    test('a dimension carries its projected key and grouped column', () {
      final d = TomReportDimension(
        key: 'region',
        columnName: 'customer_region',
        valueKind: TomReportValueKind.string,
      );
      expect(d.key, 'region');
      expect(d.columnName, 'customer_region');
    });

    test('a bare row count may omit its column', () {
      final m = TomReportMeasure(
        key: 'orders',
        function: TomReportMeasureFunction.count,
      );
      expect(m.columnName, isNull);
      expect(m.toString(), contains('count(*)'));
    });

    // A SUM with no operand cannot be compiled; the generator has no way to
    // repair it, so it is rejected where it is authored.
    test('every other aggregate must name a column', () {
      expect(
        () => TomReportMeasure(
          key: 'total',
          function: TomReportMeasureFunction.sum,
        ),
        throwsArgumentError,
      );
    });

    test(
      'distinct is a modifier on the measure, not a function of its own',
      () {
        final m = TomReportMeasure(
          key: 'customers',
          function: TomReportMeasureFunction.count,
          columnName: 'customer_id',
          distinct: true,
        );
        expect(m.distinct, isTrue);
        expect(m.function, TomReportMeasureFunction.count);
      },
    );
  });

  group('csra8: CE-RP parameters', () {
    test('an enumeration parameter must name its domain enum', () {
      expect(
        () => TomReportParameter(
          name: 'status',
          valueKind: TomReportValueKind.enumeration,
        ),
        throwsArgumentError,
      );
      expect(
        TomReportParameter(
          name: 'status',
          valueKind: TomReportValueKind.enumeration,
          enumId: 'order_status',
        ).enumId,
        'order_status',
      );
    });

    test('an entityRef parameter must name its entity', () {
      expect(
        () => TomReportParameter(
          name: 'customer',
          valueKind: TomReportValueKind.entityRef,
        ),
        throwsArgumentError,
      );
      expect(
        TomReportParameter(
          name: 'customer',
          valueKind: TomReportValueKind.entityRef,
          entityId: 'Customer',
        ).entityId,
        'Customer',
      );
    });

    test('a plain parameter needs neither', () {
      final p = TomReportParameter(
        name: 'from',
        valueKind: TomReportValueKind.date,
        required: true,
      );
      expect(p.required, isTrue);
      expect(p.enumId, isNull);
    });
  });

  group('csra8: CE-RP definition consistency', () {
    TomReportDefinition build({
      List<TomReportDimension>? dimensions,
      List<TomReportMeasure>? measures,
      List<TomReportColumn>? columns,
      List<TomReportChart> charts = const [],
    }) => TomReportDefinition(
      reportId: 'sales_by_region',
      sourceEntity: _Order,
      dimensions:
          dimensions ??
          [
            TomReportDimension(
              key: 'region',
              columnName: 'customer_region',
              valueKind: TomReportValueKind.string,
            ),
          ],
      measures:
          measures ??
          [
            TomReportMeasure(
              key: 'revenue',
              function: TomReportMeasureFunction.sum,
              columnName: 'total',
              valueKind: TomReportValueKind.currency,
            ),
          ],
      columns:
          columns ??
          [
            TomReportColumn(
              name: 'region',
              sourceKey: 'region',
              valueKind: TomReportValueKind.string,
            ),
            TomReportColumn(
              name: 'revenue',
              sourceKey: 'revenue',
              valueKind: TomReportValueKind.currency,
            ),
          ],
      charts: charts,
    );

    test('a consistent grouped projection is accepted', () {
      final report = build();
      expect(report.isAggregated, isTrue);
      expect(report.deliveryChannels, [TomReportDeliveryChannel.apiResponse]);
    });

    // The load-bearing invariant: a column displays a dimension or a measure,
    // it never introduces data of its own.
    test('a column displaying an undeclared key is rejected', () {
      expect(
        () => build(
          columns: [
            TomReportColumn(
              name: 'margin',
              sourceKey: 'margin',
              valueKind: TomReportValueKind.decimal,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a key used by both a dimension and a measure is rejected', () {
      expect(
        () => build(
          measures: [
            TomReportMeasure(
              key: 'region',
              function: TomReportMeasureFunction.count,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a chart plotting an unprojected column is rejected', () {
      expect(
        () => build(
          charts: [
            TomReportChart(
              chartId: 'trend',
              kind: TomReportChartKind.line,
              categoryColumn: 'quarter',
              valueColumns: ['revenue'],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a chart over projected columns is accepted and lists its refs', () {
      final chart = TomReportChart(
        chartId: 'by_region',
        kind: TomReportChartKind.bar,
        categoryColumn: 'region',
        valueColumns: ['revenue'],
      );
      expect(build(charts: [chart]).charts, [chart]);
      expect(chart.referencedColumns, ['region', 'revenue']);
    });

    test('a chart must plot at least one value column', () {
      expect(
        () => TomReportChart(
          chartId: 'empty',
          kind: TomReportChartKind.pie,
          categoryColumn: 'region',
          valueColumns: const [],
        ),
        throwsArgumentError,
      );
    });

    test('duplicate column names are rejected', () {
      expect(
        () => build(
          columns: [
            TomReportColumn(
              name: 'region',
              sourceKey: 'region',
              valueKind: TomReportValueKind.string,
            ),
            TomReportColumn(
              name: 'region',
              sourceKey: 'revenue',
              valueKind: TomReportValueKind.currency,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    // The constructor dartdoc names six rejected defects and offers
    // that list as what a generator may rely on being caught. Only three of
    // them had a test, and `_rejectDuplicates` is applied to five namespaces
    // of which only column name was exercised — so a namespace could have been
    // dropped from the call list without failing anything. The cases below
    // close that: one per remaining defect, so removing a check breaks a test
    // that names it.

    test('an empty reportId is rejected', () {
      expect(
        () => TomReportDefinition(
          reportId: '',
          sourceEntity: _Order,
          columns: [
            TomReportColumn(
              name: 'region',
              sourceKey: 'region',
              valueKind: TomReportValueKind.string,
            ),
          ],
          dimensions: [
            TomReportDimension(
              key: 'region',
              columnName: 'customer_region',
              valueKind: TomReportValueKind.string,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('duplicate dimension keys are rejected', () {
      expect(
        () => build(
          dimensions: [
            TomReportDimension(
              key: 'region',
              columnName: 'customer_region',
              valueKind: TomReportValueKind.string,
            ),
            TomReportDimension(
              key: 'region',
              columnName: 'billing_region',
              valueKind: TomReportValueKind.string,
            ),
          ],
        ),
        throwsDuplicate('dimension key'),
      );
    });

    test('duplicate measure keys are rejected', () {
      expect(
        () => build(
          measures: [
            TomReportMeasure(
              key: 'revenue',
              function: TomReportMeasureFunction.sum,
              columnName: 'total',
              valueKind: TomReportValueKind.currency,
            ),
            TomReportMeasure(
              key: 'revenue',
              function: TomReportMeasureFunction.avg,
              columnName: 'total',
              valueKind: TomReportValueKind.currency,
            ),
          ],
        ),
        throwsDuplicate('measure key'),
      );
    });

    test('duplicate parameter names are rejected', () {
      expect(
        () => TomReportDefinition(
          reportId: 'sales_by_region',
          sourceEntity: _Order,
          dimensions: [
            TomReportDimension(
              key: 'region',
              columnName: 'customer_region',
              valueKind: TomReportValueKind.string,
            ),
          ],
          columns: [
            TomReportColumn(
              name: 'region',
              sourceKey: 'region',
              valueKind: TomReportValueKind.string,
            ),
          ],
          parameters: [
            TomReportParameter(
              name: 'from',
              valueKind: TomReportValueKind.date,
            ),
            TomReportParameter(
              name: 'from',
              valueKind: TomReportValueKind.date,
            ),
          ],
        ),
        throwsDuplicate('parameter name'),
      );
    });

    test('duplicate chart ids are rejected', () {
      expect(
        () => build(
          charts: [
            TomReportChart(
              chartId: 'by_region',
              kind: TomReportChartKind.bar,
              categoryColumn: 'region',
              valueColumns: const ['revenue'],
            ),
            TomReportChart(
              chartId: 'by_region',
              kind: TomReportChartKind.line,
              categoryColumn: 'region',
              valueColumns: const ['revenue'],
            ),
          ],
        ),
        throwsDuplicate('chart id'),
      );
    });

    // An empty dimension list aggregates over the whole filtered set — the
    // same meaning an empty groupBy has in the query substrate.
    test('a report with no dimensions is a valid single-row aggregate', () {
      final report = TomReportDefinition(
        reportId: 'totals',
        sourceEntity: _Order,
        measures: [
          TomReportMeasure(
            key: 'orders',
            function: TomReportMeasureFunction.count,
          ),
        ],
        columns: [
          TomReportColumn(
            name: 'orders',
            sourceKey: 'orders',
            valueKind: TomReportValueKind.integer,
          ),
        ],
      );
      expect(report.dimensions, isEmpty);
      expect(report.isAggregated, isTrue);
    });

    test('a report with no measures is a plain listing', () {
      final report = TomReportDefinition(
        reportId: 'order_list',
        sourceEntity: _Order,
        dimensions: [
          TomReportDimension(
            key: 'number',
            columnName: 'order_number',
            valueKind: TomReportValueKind.string,
          ),
        ],
        columns: [
          TomReportColumn(
            name: 'number',
            sourceKey: 'number',
            valueKind: TomReportValueKind.string,
          ),
        ],
      );
      expect(report.isAggregated, isFalse);
    });

    test('a report must project at least one column', () {
      expect(
        () => TomReportDefinition(
          reportId: 'nothing',
          sourceEntity: _Order,
          columns: const [],
        ),
        throwsArgumentError,
      );
    });

    test(
      'requiredParameters selects only the parameters that need a value',
      () {
        final report = TomReportDefinition(
          reportId: 'r',
          sourceEntity: _Order,
          dimensions: [
            TomReportDimension(
              key: 'k',
              columnName: 'c',
              valueKind: TomReportValueKind.string,
            ),
          ],
          columns: [
            TomReportColumn(
              name: 'k',
              sourceKey: 'k',
              valueKind: TomReportValueKind.string,
            ),
          ],
          parameters: [
            TomReportParameter(
              name: 'from',
              valueKind: TomReportValueKind.date,
              required: true,
            ),
            TomReportParameter(
              name: 'detail',
              valueKind: TomReportValueKind.boolean,
            ),
          ],
        );
        expect(report.requiredParameters.map((p) => p.name), ['from']);
      },
    );
  });

  group('csrc3: CE-RP cross-part targets', () {
    TomReportDefinition build({
      String? scheduleExpression,
      String? drillThroughRouteId,
    }) => TomReportDefinition(
      reportId: 'sales_by_region',
      sourceEntity: _Order,
      scheduleExpression: scheduleExpression,
      dimensions: [
        TomReportDimension(
          key: 'region',
          columnName: 'customer_region',
          valueKind: TomReportValueKind.string,
        ),
      ],
      columns: [
        TomReportColumn(
          name: 'region',
          sourceKey: 'region',
          valueKind: TomReportValueKind.string,
          drillThroughRouteId: drillThroughRouteId,
        ),
      ],
    );

    // `codespecs_mapping.md` §5.23: an entity is already a Dart type, so it is
    // cited as a `Type` literal and gets no `Cs*Ref` const. A renamed entity is
    // then a compile error, which a string could never be.
    test('the source entity is a Type literal, not an id string', () {
      expect(build().sourceEntity, _Order);
      expect(build().sourceEntity, isA<Type>());
    });

    // `codespecs_mapping.md` §5.29: a scheduled report is declared once, on the
    // definition, and the CE-JB job is realised from that schedule. So what is
    // carried is the recurrence expression the specification authored, verbatim
    // — never a job id, which would be the second source that rule forbids.
    test('the schedule is a recurrence expression carried verbatim', () {
      expect(
        build(scheduleExpression: '0 6 1 * *').scheduleExpression,
        '0 6 1 * *',
      );
    });

    test('an unscheduled report simply has no schedule', () {
      expect(build().scheduleExpression, isNull);
    });

    // The one CE-RP target that stays an open id string: the locus rule bars
    // a server-owned definition from citing a client-owned route, so the
    // compile-time edge is unavailable and check 18 replaces it.
    test('the drill-through target stays an open route id string', () {
      final column = build(drillThroughRouteId: 'orderDetail').columns.single;
      expect(column.drillThroughRouteId, 'orderDetail');
      expect(column.drillThroughRouteId, isA<String>());
    });
  });

  group('csra8: CE-RP result envelope', () {
    TomReportResultSection section() => TomReportResultSection(
      columns: [
        TomReportColumn(
          name: 'region',
          sourceKey: 'region',
          valueKind: TomReportValueKind.string,
        ),
      ],
      openRows: () => Stream.fromIterable([
        ['north'],
        ['south'],
      ]),
    );

    test('rows stay streamable rather than materialised', () async {
      expect(await section().rows.toList(), [
        ['north'],
        ['south'],
      ]);
    });

    // The property the factory exists for, pinned against a source that can
    // only be listened to once. `Stream.fromIterable` tolerates re-listening,
    // so a test written the easy way passes whatever the type does — which is
    // why the defect this replaced was invisible to the suite for as long as
    // it existed.
    group('a section is read once per delivery', () {
      TomReportColumn column() => TomReportColumn(
        name: 'n',
        sourceKey: 'n',
        valueKind: TomReportValueKind.integer,
      );

      /// One pass over a genuinely single-subscription source.
      ///
      /// A `StreamController` is what a large result actually is: a query or a
      /// file read, listenable once. Opening it *inside* the closure is the
      /// obligation the constructor states, and it is what makes each read a
      /// fresh pass.
      Stream<List<Object?>> openRows() {
        final controller = StreamController<List<Object?>>();
        controller.add([1]);
        controller.close();
        return controller.stream;
      }

      test('two deliveries each read the rows in full', () async {
        final section = TomReportResultSection(
          columns: [column()],
          openRows: openRows,
        );

        expect(await section.rows.toList(), [
          [1],
        ]);
        expect(
          await section.rows.toList(),
          [
            [1],
          ],
          reason:
              'the second delivery must get its own pass, not a second '
              'listen on the first one',
        );
      });

      test('the source really is single-subscription', () {
        // The control. Without it the case above would also pass against a
        // broadcast or re-listenable source, which is the fixture mistake that
        // hid the original defect.
        final stream = openRows();
        expect(stream.isBroadcast, isFalse);
        stream.listen(null);
        expect(() => stream.listen(null), throwsStateError);
      });

      test('each read calls the factory again', () async {
        var opened = 0;
        final section = TomReportResultSection(
          columns: [column()],
          openRows: () {
            opened++;
            return openRows();
          },
        );

        expect(opened, 0, reason: 'construction opens nothing');
        await section.rows.drain<void>();
        await section.rows.drain<void>();
        expect(opened, 2);
      });

      test(
        'a factory that hands out one stream still fails, as documented',
        () async {
          // The obligation the type cannot enforce, stated as a test so the
          // failure mode is on record rather than only in a doc comment: a
          // closure over one controller returns the same spent stream.
          final controller = StreamController<List<Object?>>();
          controller.add([1]);
          // Not awaited: `close()` on a controller nobody has listened to yet
          // does not complete until someone does.
          unawaited(controller.close());
          final section = TomReportResultSection(
            columns: [column()],
            openRows: () => controller.stream,
          );

          await section.rows.drain<void>();
          expect(
            () => section.rows.listen(null),
            throwsStateError,
            reason: 'open the source inside the closure, not outside it',
          );
        },
      );
    });

    test('a section must declare at least one column', () {
      expect(
        () => TomReportResultSection(
          columns: const [],
          openRows: Stream<List<Object?>>.empty,
        ),
        throwsArgumentError,
      );
    });

    test('a section may not name a column twice', () {
      final column = TomReportColumn(
        name: 'region',
        sourceKey: 'region',
        valueKind: TomReportValueKind.string,
      );
      expect(
        () => TomReportResultSection(
          columns: [column, column],
          openRows: Stream<List<Object?>>.empty,
        ),
        throwsArgumentError,
      );
    });

    test('the single-section factory produces a one-section result', () {
      final result = TomReportResult.single(
        reportId: 'sales_by_region',
        title: 'Sales by region',
        section: section(),
        metadata: {'asOf': '2026-07-28'},
      );
      expect(result.sections, hasLength(1));
      expect(result.metadata['asOf'], '2026-07-28');
    });

    test(
      'metadata is unmodifiable so a renderer cannot rewrite provenance',
      () {
        final result = TomReportResult.single(
          reportId: 'r',
          title: 't',
          section: section(),
          metadata: {'ranBy': 'alexis'},
        );
        expect(
          () => result.metadata['ranBy'] = 'someone else',
          throwsUnsupportedError,
        );
      },
    );

    test('a result with no sections is rejected', () {
      expect(
        () => TomReportResult(reportId: 'r', title: 't', sections: const []),
        throwsArgumentError,
      );
    });

    // Charts travel on the envelope so a client can draw them; an exporter
    // that cannot express one omits it rather than failing.
    test('the envelope carries the declared charts', () {
      final chart = TomReportChart(
        chartId: 'by_region',
        kind: TomReportChartKind.bar,
        categoryColumn: 'region',
        valueColumns: ['revenue'],
      );
      final result = TomReportResult.single(
        reportId: 'r',
        title: 't',
        section: section(),
        charts: [chart],
      );
      expect(result.charts, [chart]);
    });
  });
}

/// Matches the [ArgumentError] `_rejectDuplicates` raises for [what].
///
/// A bare `throwsArgumentError` is too weak for the duplicate cases: a
/// repeated dimension key also shortens the combined key set, so
/// `TomReportDefinition`'s key-claimed-by-both check throws on the same input.
/// The test would then still pass with `_rejectDuplicates` deleted. Pinning
/// the message ties each test to the check it names.
Matcher throwsDuplicate(String what) => throwsA(
  isA<ArgumentError>().having(
    (e) => e.message,
    'message',
    contains('Duplicate $what'),
  ),
);

/// Stand-in CE-DB entity types for the CE-JB and CE-RP target tests.
///
/// A `TomJobDeclaration` cites its entity targets, and a `TomReportDefinition`
/// its source entity, as `Type` literals (`codespecs_mapping.md` §5.23,
/// §5.29 scope part 3), so the tests need real Dart types to cite. They are
/// empty on purpose: what is under test is that the reference is a type at
/// all, not anything the type carries.
class _Invoice {}

class _Payment {}

class _Order {}
