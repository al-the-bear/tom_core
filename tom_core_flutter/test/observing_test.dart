import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/observing/observing_example.dart' as example;

/// A [TomObserver] that does nothing but count, so a test can hold one
/// deliberately and ask how many notifications reached it.
class _CountingObserver implements TomObserver<TomBool> {
  int calls = 0;

  @override
  void onNotify(TomBool observable) => calls++;
}

/// A [ValueListenableObserver] that counts the notifications it is handed.
///
/// `onNotify` is the inherited forwarding step, so counting calls to it answers
/// the one question the adaptor's public surface otherwise cannot: whether this
/// adaptor is still registered on its observable. A cleared listener and a
/// removed registration both produce silence; only the second stops `onNotify`
/// from being reached — which is why this is a subclass rather than a reach
/// into the listener slot, now that the slot is private.
class _CountingAdaptor extends ValueListenableObserver<TomBool> {
  _CountingAdaptor(super.observable);

  /// How many times the observable has notified this adaptor.
  int notifications = 0;

  @override
  void onNotify(TomBool observable) {
    notifications++;
    super.onNotify(observable);
  }
}

/// Tests for the observing module (`TomObservingWidget`,
/// `ValueListenableObserver`).
///
/// Both adapt the kernel observation model: a `TomObservable` is read with `~`
/// and mutated with `|`, and notifies its observers on change.
/// A widget that reports each time its element rebuilds.
///
/// Counting inside a builder closure would answer a different question — the
/// closure re-runs on every notification by design. What the hoist promises is
/// that the *element* reached through `child` is not rebuilt, and only a widget
/// can report that.
class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox.shrink();
  }
}

/// A [TomObservingWidget] whose `State` counts the notifications that reach it.
///
/// `onNotify`'s `mounted` guard makes a notification to a disposed `State`
/// harmless, which is what makes the ordinary "no exception after unmount"
/// assertion blind to whether `dispose` deregistered at all. Counting the calls
/// reaches past the guard: an observer that was removed is never called.
class _CountingObservingWidget extends TomObservingWidget<TomBool> {
  _CountingObservingWidget(TomBool observable, this.notifications)
    : super(
        subState: observable,
        builder: (state, _) =>
            Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
      );

  /// A single-element list so the count survives the widget being rebuilt.
  final List<int> notifications;

  @override
  State<StatefulWidget> createState() => _CountingObservingState();
}

class _CountingObservingState extends TomObservingWidgetState<TomBool> {
  @override
  void onNotify(TomObservable observable) {
    (widget as _CountingObservingWidget).notifications[0]++;
    super.onNotify(observable);
  }
}

/// A `TomBool` that counts how often anything asks for its string form.
///
/// The measurement the trace-message change is about: an eagerly interpolated
/// log line calls `toString()` on the observable whether or not the line is
/// written, and for the containers this framework observes that walks their
/// contents.
class _CountingToString extends TomBool {
  _CountingToString(super.value);

  /// How many times [toString] has been called.
  int toStringCalls = 0;

  @override
  String toString() {
    toStringCalls++;
    return super.toString();
  }
}

/// A log output that keeps what it is given, so a test can read the lines the
/// logger actually wrote rather than assert they exist unseen.
class _RecordingLogOutput extends TomLogOutput {
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      messages.add(convertToString(message));
    }
  }
}

/// A `TomBool` that counts the observer registrations made against it.
///
/// "Identical observables are left alone, so an ordinary parent rebuild costs
/// nothing" is a claim about cost rather than behaviour — deregistering and
/// re-registering on the same observable leaves the widget registered either
/// way. Counting the calls is the only way to see the difference.
class _CountingObservable extends TomBool {
  _CountingObservable(super.value);

  /// How many times an observer was registered on this observable.
  int addCalls = 0;

  /// How many times an observer was removed from it.
  int removeCalls = 0;

  @override
  void addObserver(TomObserver observer) {
    addCalls++;
    super.addObserver(observer);
  }

  @override
  void removeObserver(TomObserver observer) {
    removeCalls++;
    super.removeObserver(observer);
  }
}

void main() {
  group('TomObservingWidget', () {
    testWidgets('renders from the initial observable value', (tester) async {
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            builder: (state, _) =>
                Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('ON'), findsNothing);
    });

    testWidgets('rebuilds when the observable notifies', (tester) async {
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            builder: (state, _) =>
                Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);

      flag | true; // mutate the observable → triggers onNotify → setState
      await tester.pump();

      expect(find.text('ON'), findsOneWidget);
      expect(find.text('OFF'), findsNothing);
    });

    // Disposal: once the widget leaves the tree it must deregister, so a later
    // mutation does not call setState on a dead State ("setState() called after
    // dispose()"). `TomObservingWidgetState.dispose` is what this pins.
    //
    // The benefit is about *timing*, not lifetime: TomObservable holds its
    // observers weakly, so a surviving registration would not have kept the
    // State alive either way — it would just have gone on notifying a disposed
    // element until the collector happened to run. There is no public
    // observer-count getter on TomObservable, so a still-registered dead
    // observer surfaces only as the framework throw on the post-unmount
    // notification; asserting that nothing was thrown is the deregistration
    // check.
    testWidgets('a notification after teardown is a no-op', (tester) async {
      // `dispose` deregisters, so the ordinary path never reaches this. The
      // window it cannot close is the kernel's: `notifyObservers` iterates a
      // *snapshot* taken before the loop, so an observer removed by an earlier
      // observer's `onNotify` in the same round is still notified — and a
      // `setState` on a disposed `State` throws.
      //
      // That timing cannot be staged from a widget test: unmounting an element
      // synchronously from inside a notification loop is not something a test
      // can arrange. So the seam is driven directly, with the `State` retained
      // across the unmount, which is exactly the object the kernel's snapshot
      // hands a notification to.
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            builder: (state, _) =>
                Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
          ),
        ),
      );
      final state = tester.state<TomObservingWidgetState<TomBool>>(
        find.byType(TomObservingWidget<TomBool>),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(state.mounted, isFalse);

      expect(() => state.onNotify(flag), returnsNormally);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mutating the observable from a build throws, loudly', (
      tester,
    ) async {
      // Left to throw on purpose. The message names the widget that wrote to
      // the observable from inside its own `build`, which is where the mistake
      // is; deferring the rebuild to a post-frame callback would make it work
      // one frame late, every time, silently — a diagnosable failure traded for
      // an undiagnosable one.
      final flag = TomBool(false);

      // Collected through `FlutterError.onError` rather than
      // `tester.takeException()`: the failure produces more than one report,
      // and the tester folds several into one "Multiple exceptions" object
      // whose text no longer contains the message being asserted.
      final reported = <String>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) =>
          reported.add(details.exceptionAsString());
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              TomObservingWidget<TomBool>(
                subState: flag,
                builder: (state, _) => Text(
                  ~state ? 'ON' : 'OFF',
                  textDirection: TextDirection.ltr,
                ),
              ),
              Builder(
                builder: (context) {
                  // The offending line: a plain `|` assignment, carrying no
                  // hint that it schedules a rebuild of somebody else.
                  flag | true;
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );

      expect(
        reported.any((message) => message.contains('called during build')),
        isTrue,
        reason:
            'the throw is the signal, and it names the widget that mutated '
            'the observable from inside its own build — reported: $reported',
      );
    });

    testWidgets('a hoisted child is built once across notifications', (
      tester,
    ) async {
      // The escape hatch `ValueListenableBuilder` and `AnimatedBuilder` both
      // provide, and the reason it matters here: a form bound to a
      // high-frequency observable would otherwise repaint everything its
      // builder returns on every keystroke.
      //
      // `_BuildCounter` counts its own builds, so what is asserted is the
      // element actually being rebuilt rather than the closure being re-run.
      final flag = TomBool(false);
      var hoistedBuilds = 0;
      var builderRuns = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            child: _BuildCounter(onBuild: () => hoistedBuilds++),
            builder: (state, child) {
              builderRuns++;
              return Column(
                children: [
                  Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
                  child!,
                ],
              );
            },
          ),
        ),
      );

      expect(hoistedBuilds, 1);
      expect(builderRuns, 1);

      flag | true;
      await tester.pump();
      flag | false;
      await tester.pump();
      flag | true;
      await tester.pump();

      expect(builderRuns, 4, reason: 'the builder runs on every notification');
      expect(
        hoistedBuilds,
        1,
        reason: 'the hoisted subtree is the parent\'s, and is not rebuilt',
      );
      expect(find.text('ON'), findsOneWidget);
    });

    testWidgets('the builder is handed null when nothing was hoisted', (
      tester,
    ) async {
      // `child` is optional, so the builder's second parameter is nullable. A
      // builder that reaches for a child it was not given should fail at the
      // `!`, where the call site is named, rather than render something empty.
      final flag = TomBool(false);
      Widget? received = const SizedBox.shrink();

      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            builder: (state, child) {
              received = child;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(received, isNull);
    });

    testWidgets('deregisters on unmount — no setState after dispose', (
      tester,
    ) async {
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            builder: (state, _) =>
                Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);

      // Remove the observing widget from the tree → State.dispose() runs.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Mutating the (now unobserved) observable must not reach the disposed
      // State.
      flag | true;
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('and the deregistration is what stops it, not the guard', (
      tester,
    ) async {
      // The test above asserts the *symptom* — no exception — and `onNotify`'s
      // `mounted` guard now suppresses that symptom whether or not `dispose`
      // deregisters. So it no longer distinguishes a widget that unsubscribed
      // from one that merely declines to act, and something has to.
      //
      // `onNotify` is public, so a `State` subclass can count the calls that
      // reach it. A deregistered observer is never called at all, which is the
      // difference the symptom hides.
      final flag = TomBool(false);
      final notifications = <int>[0];

      await tester.pumpWidget(
        MaterialApp(home: _CountingObservingWidget(flag, notifications)),
      );

      flag | true;
      await tester.pump();
      expect(notifications[0], 1, reason: 'registered while mounted');

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      flag | false;
      await tester.pump();
      expect(
        notifications[0],
        1,
        reason:
            'dispose removed the registration, so the notification never '
            'reached the State at all',
      );
    });

    // Observable swap: a parent rebuild with a different subState must make the
    // widget observe and render from the NEW observable and ignore the OLD one.
    // `TomObservingWidgetState.didUpdateWidget` is what this pins — it compares
    // the two by identity and moves the registration across.
    //
    // Both halves are asserted because only one of them is visible in the
    // rendering. Adding the new registration without dropping the old one
    // renders correctly from the new observable and still looks right; the
    // stale registration shows up only as a rebuild that the old observable
    // should no longer be able to cause, which is what the build counter at the
    // end of the test measures.
    group('the key decides migrate or start over', () {
      // Keys are how a caller tells Flutter whether to reuse an element or
      // build a new one, and that choice is what selects between this widget's
      // two behaviours: reuse runs `didUpdateWidget`, which *migrates* the
      // registration, while a new element runs `initState` on a fresh `State`.
      //
      // A list row rebinding to an unrelated model usually wants the second,
      // and without a `Key` parameter there was no way to ask for it.

      /// Pumps the widget under [key] over [observable], and returns a setter
      /// that rebuilds the parent with new values.
      Future<void Function(Key?, TomBool)> pumpKeyed(
        WidgetTester tester, {
        required Key? key,
        required TomBool observable,
        required List<int> builds,
      }) async {
        var currentKey = key;
        var current = observable;
        late void Function(void Function()) rebuildParent;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuildParent = setState;
                return TomObservingWidget<TomBool>(
                  key: currentKey,
                  subState: current,
                  builder: (state, _) {
                    builds[0]++;
                    return Text(
                      ~state ? 'ON' : 'OFF',
                      textDirection: TextDirection.ltr,
                    );
                  },
                );
              },
            ),
          ),
        );

        return (nextKey, nextObservable) => rebuildParent(() {
          currentKey = nextKey;
          current = nextObservable;
        });
      }

      TomObservingWidgetState<TomBool> stateOf(WidgetTester tester) =>
          tester.state<TomObservingWidgetState<TomBool>>(
            find.byType(TomObservingWidget<TomBool>),
          );

      testWidgets('an identical subState is left alone across a rebuild', (
        tester,
      ) async {
        // "Identical observables are left alone, so an ordinary parent rebuild
        // costs nothing." That is a claim about *cost*, and it is invisible in
        // behaviour: deregistering and re-registering on the same observable
        // leaves the widget registered either way, so nothing renders
        // differently and no notification is missed.
        //
        // What can be observed is the calls themselves, so the observable
        // counts them.
        final source = _CountingObservable(false);
        var rebuilds = 0;
        late void Function(void Function()) rebuildParent;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuildParent = setState;
                rebuilds++;
                return TomObservingWidget<_CountingObservable>(
                  subState: source,
                  builder: (state, _) => Text(
                    ~state ? 'ON' : 'OFF',
                    textDirection: TextDirection.ltr,
                  ),
                );
              },
            ),
          ),
        );

        expect(source.addCalls, 1, reason: 'initState registered once');
        expect(source.removeCalls, 0);

        rebuildParent(() {});
        await tester.pump();
        rebuildParent(() {});
        await tester.pump();

        expect(rebuilds, 3, reason: 'the parent really did rebuild');
        expect(
          source.addCalls,
          1,
          reason: 'didUpdateWidget compares by identity and does nothing',
        );
        expect(source.removeCalls, 0);
      });

      testWidgets('a different subState moves the registration exactly once', (
        tester,
      ) async {
        // The other arm, counted rather than inferred: one removal from the old
        // observable and one registration on the new, not a re-registration on
        // both.
        final first = _CountingObservable(false);
        final second = _CountingObservable(false);
        var current = first;
        late void Function(void Function()) rebuildParent;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuildParent = setState;
                return TomObservingWidget<_CountingObservable>(
                  subState: current,
                  builder: (state, _) => Text(
                    ~state ? 'ON' : 'OFF',
                    textDirection: TextDirection.ltr,
                  ),
                );
              },
            ),
          ),
        );

        rebuildParent(() => current = second);
        await tester.pump();

        expect(first.addCalls, 1);
        expect(first.removeCalls, 1, reason: 'the old one was dropped');
        expect(second.addCalls, 1, reason: 'the new one was taken up');
        expect(second.removeCalls, 0);
      });

      testWidgets('the same key keeps the State and migrates it', (
        tester,
      ) async {
        final first = TomBool(false);
        final second = TomBool(false);
        final builds = [0];
        final rebuild = await pumpKeyed(
          tester,
          key: const ValueKey('row'),
          observable: first,
          builds: builds,
        );
        final before = stateOf(tester);

        rebuild(const ValueKey('row'), second);
        await tester.pump();

        expect(
          identical(stateOf(tester), before),
          isTrue,
          reason: 'the element was reused, so didUpdateWidget migrated',
        );

        // And the migration actually moved: the new one drives it, the old one
        // does not.
        second | true;
        await tester.pump();
        expect(find.text('ON'), findsOneWidget);

        final buildsBefore = builds[0];
        first | true;
        await tester.pump();
        expect(builds[0], buildsBefore);
      });

      testWidgets('a different key builds a fresh State and registration', (
        tester,
      ) async {
        final first = TomBool(false);
        final second = TomBool(false);
        final builds = [0];
        final rebuild = await pumpKeyed(
          tester,
          key: const ValueKey('row-a'),
          observable: first,
          builds: builds,
        );
        final before = stateOf(tester);

        rebuild(const ValueKey('row-b'), second);
        await tester.pump();

        final after = stateOf(tester);
        expect(
          identical(after, before),
          isFalse,
          reason: 'a new key means a new element, so initState ran again',
        );
        expect(before.mounted, isFalse, reason: 'the old State was disposed');

        // The fresh registration observes the new observable...
        second | true;
        await tester.pump();
        expect(find.text('ON'), findsOneWidget);

        // ...and the disposed one left nothing behind on the old observable.
        final buildsBefore = builds[0];
        first | true;
        await tester.pump();
        expect(builds[0], buildsBefore);
      });

      testWidgets('a new key starts over even on the same observable', (
        tester,
      ) async {
        // The case a list row actually hits: the model is unchanged, but the
        // caller wants a clean `State`. Without the key there is no way to
        // distinguish this from "nothing changed".
        final shared = TomBool(false);
        final builds = [0];
        final rebuild = await pumpKeyed(
          tester,
          key: const ValueKey('row-a'),
          observable: shared,
          builds: builds,
        );
        final before = stateOf(tester);

        rebuild(const ValueKey('row-b'), shared);
        await tester.pump();

        expect(identical(stateOf(tester), before), isFalse);
        expect(before.mounted, isFalse);

        // One registration, not two: the disposed State deregistered, so a
        // single mutation produces a single rebuild.
        final buildsBefore = builds[0];
        shared | true;
        await tester.pump();
        expect(builds[0], buildsBefore + 1);
        expect(find.text('ON'), findsOneWidget);
      });
    });

    testWidgets('swaps to a new subState — observes/renders new, ignores old', (
      tester,
    ) async {
      final first = TomBool(false);
      final second = TomBool(false);
      var current = first;
      late void Function(void Function()) rebuildParent;
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return TomObservingWidget<TomBool>(
                subState: current,
                builder: (state, _) {
                  builds++;
                  return Text(
                    ~state ? 'ON' : 'OFF',
                    textDirection: TextDirection.ltr,
                  );
                },
              );
            },
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);

      // Swap the parent to observe `second` (still false).
      rebuildParent(() => current = second);
      await tester.pump();

      // It now renders from `second`.
      second | true;
      await tester.pump();
      expect(find.text('ON'), findsOneWidget);

      // The OLD observable must be ignored: mutating it triggers no rebuild.
      final buildsBefore = builds;
      first | true;
      await tester.pump();
      expect(builds, buildsBefore);
      expect(find.text('ON'), findsOneWidget);
    });
  });

  group('ValueListenableObserver', () {
    test('value returns the observed observable', () {
      final source = TomBool(true);
      final adaptor = ValueListenableObserver<TomBool>(source);
      expect(identical(adaptor.value, source), isTrue);
    });

    test('invokes the registered listener once per notification', () {
      final source = TomBool(false);
      final adaptor = ValueListenableObserver<TomBool>(source);

      var calls = 0;
      adaptor.addListener(() => calls++);

      source | true;
      expect(calls, 1);

      source | false;
      expect(calls, 2);
    });

    test('stops notifying after removeListener', () {
      final source = TomBool(false);
      final adaptor = ValueListenableObserver<TomBool>(source);

      var calls = 0;
      void listener() => calls++;
      adaptor.addListener(listener);
      source | true;
      expect(calls, 1);

      adaptor.removeListener(listener);
      source | false;
      expect(calls, 1); // unchanged
    });

    // The `Listenable` contract, which this type declares and therefore has to
    // keep. A `Listenable` is *structurally* substitutable wherever Flutter
    // asks for one, so an implementation that replaced on add would leave the
    // first consumer silently not rebuilding, with no error anywhere.
    group('the Listenable contract', () {
      test('addListener appends rather than replacing', () {
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);

        var first = 0;
        var second = 0;
        adaptor.addListener(() => first++);
        adaptor.addListener(() => second++);

        source | true;

        expect(first, 1);
        expect(second, 1);
      });

      test('removeListener removes only the listener it is given', () {
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);

        var kept = 0;
        var dropped = 0;
        void keptListener() => kept++;
        void droppedListener() => dropped++;
        adaptor.addListener(keptListener);
        adaptor.addListener(droppedListener);

        adaptor.removeListener(droppedListener);
        source | true;

        expect(kept, 1);
        expect(dropped, 0);
      });

      test('removing a listener that was never registered does nothing', () {
        // The old behaviour silenced the adaptor for any argument at all. A
        // consumer removing its own listener would then have stopped every
        // other consumer, which is the multicast failure in miniature.
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);

        var calls = 0;
        adaptor.addListener(() => calls++);

        adaptor.removeListener(() {});
        source | true;

        expect(calls, 1);
      });

      test('registrations are counted, not de-duplicated', () {
        // Flutter's own semantics: the same callback added twice fires twice,
        // and one removal undoes one registration. A `Set` would collapse both
        // halves of that silently.
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);

        var calls = 0;
        void listener() => calls++;
        adaptor.addListener(listener);
        adaptor.addListener(listener);

        source | true;
        expect(calls, 2);

        adaptor.removeListener(listener);
        source | false;
        expect(calls, 3, reason: 'one removal undoes one registration');
      });

      test('a listener may remove itself while being notified', () {
        // Dispatch walks a snapshot, so a listener removed mid-notification
        // does not shift the ones after it. Without that this throws a
        // concurrent-modification error, or skips a listener.
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);

        var selfRemoving = 0;
        var following = 0;
        late final VoidCallback listener;
        listener = () {
          selfRemoving++;
          adaptor.removeListener(listener);
        };
        adaptor.addListener(listener);
        adaptor.addListener(() => following++);

        source | true;
        expect(selfRemoving, 1);
        expect(following, 1, reason: 'the listener after it still runs');

        source | false;
        expect(selfRemoving, 1, reason: 'it removed itself');
        expect(following, 2);
      });

      test('a listener added while notifying waits for the next one', () {
        // The snapshot's other edge. Calling a listener registered *during*
        // this dispatch would run it for a change it was not there for.
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);

        var late = 0;
        adaptor.addListener(() => adaptor.addListener(() => late++));

        source | true;
        expect(late, 0);

        source | false;
        expect(late, greaterThan(0));
      });

      test('onNotify does nothing at all when no listener is registered', () {
        // The `_listeners.isEmpty` early return. It is invisible through
        // rendering — an adaptor with no listener produces no visible effect
        // either way — so the trace line is what tells the two apart: the guard
        // returns *before* it, so a notification to a listener-less adaptor
        // writes nothing.
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);
        addTearDown(adaptor.dispose);

        final recorder = _RecordingLogOutput();
        final previousOutput = tomLog.logOutput;
        final previousLevel = tomLog.logLevel;
        tomLog.logOutput = recorder;
        tomLog.setLogLevel(TomLogLevel.all);
        try {
          source | true;
          final withoutListener = recorder.messages
              .where((m) => m.contains('ValueListenableObserver: notified'))
              .length;
          expect(withoutListener, 0, reason: 'nothing to notify, so no line');

          adaptor.addListener(() {});
          source | false;
          final withListener = recorder.messages
              .where((m) => m.contains('ValueListenableObserver: notified'))
              .length;
          expect(withListener, 1, reason: 'and the guard is the only reason');
        } finally {
          tomLog.setLogLevel(previousLevel);
          tomLog.logOutput = previousOutput;
        }
      });

      test('removeListener is tolerated after dispose', () {
        // A widget tearing down cannot always control whether the listenable
        // it registered on was disposed first, and refusing the call would
        // turn a correct teardown into a crash.
        final adaptor = ValueListenableObserver<TomBool>(TomBool(false));
        void listener() {}
        adaptor.addListener(listener);
        adaptor.dispose();

        expect(() => adaptor.removeListener(listener), returnsNormally);
      });
    });

    group('dispose ends the subscription', () {
      test('a disposed adaptor stops forwarding', () {
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);

        var calls = 0;
        adaptor.addListener(() => calls++);
        source | true;
        expect(calls, 1);

        adaptor.dispose();

        source | false;
        expect(calls, 1, reason: 'the listener is dropped by dispose');
      });

      test('and is off the observer list, not merely silent', () {
        // The case that tells `dispose` from `removeListener`, and the one a
        // test has to go out of its way to write: clearing the listener makes
        // an adaptor silent too, so "no listener fired" cannot distinguish
        // them. What distinguishes them is whether `onNotify` is *reached* at
        // all, which a subclass can count — and counting it needs no access to
        // the adaptor's internals.
        final source = TomBool(false);
        final silenced = _CountingAdaptor(source);
        final disposed = _CountingAdaptor(source);

        silenced.removeListener(() {});
        disposed.dispose();

        source | true;

        expect(
          silenced.notifications,
          1,
          reason:
              'removeListener clears the listener and leaves the kernel '
              'registration in place, so onNotify still runs',
        );
        expect(
          disposed.notifications,
          0,
          reason: 'dispose deregisters, so onNotify is never reached',
        );
      });

      test('a disposed adaptor refuses a new listener in debug', () {
        // Left as a silent no-op this is the shape that wastes an afternoon:
        // the builder is wired, the value changes, and nothing happens. The
        // assert costs nothing in release and fails where the mistake is.
        final adaptor = ValueListenableObserver<TomBool>(TomBool(false));
        adaptor.dispose();

        expect(
          () => adaptor.addListener(() {}),
          throwsA(isA<AssertionError>()),
        );
      });

      test('and releases the listener closure', () {
        // Retention, not notification: a builder's closure captures the element
        // it rebuilds, so an adaptor that kept it would pin a disposed subtree.
        // The slot is private, so the closure itself is the witness — it is the
        // only strong reference the test keeps, and after `dispose` the adaptor
        // must not be holding it. Asserted through a re-registered subclass
        // that can see whether the inherited forwarding still has anything to
        // forward to.
        final source = TomBool(false);
        final adaptor = _CountingAdaptor(source);

        var listenerCalls = 0;
        adaptor.addListener(() => listenerCalls++);
        source | true;
        expect(listenerCalls, 1);
        expect(adaptor.notifications, 1);

        adaptor.dispose();
        // Drive `onNotify` directly, bypassing the deregistration, so the only
        // question left is whether the listener slot still holds the closure.
        adaptor.onNotify(source);

        expect(adaptor.notifications, 2, reason: 'onNotify did run');
        expect(
          listenerCalls,
          1,
          reason: 'dispose dropped the closure, so there was nothing to call',
        );
      });

      test('the adaptor cannot be retargeted or reached past', () {
        // Both are compile-time facts, so both are read off the source: "you
        // cannot assign it" is the one assertion a test cannot make by
        // assigning it.
        //
        // `observable` is final because the constructor registers against
        // *this* observable and nothing moves that registration. A settable
        // field would leave an adaptor reporting one observable through `value`
        // while firing from another — a builder rebuilding on one's changes
        // while rendering the other's. `_voidCallback` is private because
        // assigning it would bypass `addListener`, which is where the
        // single-slot replacement is traced and where use after `dispose` is
        // caught.
        final source = File(
          'lib/src/tomclient/observing/value_listenable_observer.dart',
        ).readAsStringSync();

        expect(source, contains('final T observable;'));
        expect(source, contains('final List<VoidCallback> _listeners = [];'));
        expect(
          source,
          isNot(contains('void Function()? voidCallback;')),
          reason: 'the listener list is implementation state, not surface',
        );
      });

      test('dispose is idempotent', () {
        // What a `State` that disposes and then nulls its field ends up doing.
        // A teardown that punishes a second call makes every call site
        // defensive instead of simple.
        final source = TomBool(false);
        final adaptor = ValueListenableObserver<TomBool>(source);
        adaptor.addListener(() {});

        adaptor.dispose();
        expect(adaptor.dispose, returnsNormally);
      });

      test('disposing one adaptor leaves another on the same observable', () {
        // Two adaptors is the documented answer to "two parts of a screen need
        // this observable", so one screen going away must not silence the
        // other.
        final source = TomBool(false);
        final going = ValueListenableObserver<TomBool>(source);
        final staying = ValueListenableObserver<TomBool>(source);

        var stayingCalls = 0;
        going.addListener(() {});
        staying.addListener(() => stayingCalls++);

        going.dispose();
        source | true;

        expect(stayingCalls, 1);
      });
    });
  });

  testWidgets('ValueListenableObserver drives a ValueListenableBuilder', (
    tester,
  ) async {
    final source = TomBool(false);
    final adaptor = ValueListenableObserver<TomBool>(source);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<TomBool>(
          valueListenable: adaptor,
          builder: (context, value, _) =>
              Text(~value ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('OFF'), findsOneWidget);

    source | true;
    await tester.pump();
    expect(find.text('ON'), findsOneWidget);
  });

  testWidgets('two builders over one adaptor both rebuild', (tester) async {
    // The case the type exists to make safe, and the one a single-listener
    // implementation broke without an error anywhere: a `Listenable` is
    // structurally substitutable, so nothing at either call site would have
    // shown that the first builder had silently stopped.
    final source = TomBool(false);
    final adaptor = ValueListenableObserver<TomBool>(source);
    addTearDown(adaptor.dispose);

    Widget label(String prefix) => ValueListenableBuilder<TomBool>(
      valueListenable: adaptor,
      builder: (context, value, _) => Text(
        '$prefix:${~value ? 'ON' : 'OFF'}',
        textDirection: TextDirection.ltr,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Column(children: [label('a'), label('b')])),
    );
    expect(find.text('a:OFF'), findsOneWidget);
    expect(find.text('b:OFF'), findsOneWidget);

    source | true;
    await tester.pump();

    expect(find.text('a:ON'), findsOneWidget);
    expect(find.text('b:ON'), findsOneWidget);
  });

  group('a notification costs nothing while trace logging is off', () {
    // `tomLog.trace` takes an `Object`, and every `TomLogOutput` calls a
    // `Function` message through `convertToString` *inside* its level check. So
    // a closure defers the whole message build — `observable.toString()`
    // included — until the line is actually written.
    //
    // The cost this removes is not hypothetical for the containers this
    // framework observes: a `TomList`'s or `TomClass`'s `toString()` walks its
    // contents, and it would run on every mutation for the lifetime of the
    // widget, in the one module whose purpose is being attached to state that
    // changes often.

    test('the observable is never stringified by the adaptor', () {
      final source = _CountingToString(false);
      final adaptor = ValueListenableObserver<_CountingToString>(source);
      addTearDown(adaptor.dispose);
      adaptor.addListener(() {});

      source | true;
      source | false;

      expect(
        source.toStringCalls,
        0,
        reason: 'the trace message is a closure, and trace output is off',
      );
    });

    testWidgets('nor by the widget', (tester) async {
      final source = _CountingToString(false);

      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<_CountingToString>(
            subState: source,
            builder: (state, _) =>
                Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
          ),
        ),
      );

      source | true;
      await tester.pump();
      source | false;
      await tester.pump();

      expect(source.toStringCalls, 0);
    });

    test('and the message is still produced when trace is on', () {
      // The other half: deferring must not mean dropping. Without this, the
      // assertions above pass just as well on a module that logs nothing.
      final source = _CountingToString(false);
      final adaptor = ValueListenableObserver<_CountingToString>(source);
      addTearDown(adaptor.dispose);
      adaptor.addListener(() {});

      final recorder = _RecordingLogOutput();
      final previousOutput = tomLog.logOutput;
      final previousLevel = tomLog.logLevel;
      tomLog.logOutput = recorder;
      tomLog.setLogLevel(TomLogLevel.all);
      try {
        source | true;
      } finally {
        tomLog.setLogLevel(previousLevel);
        tomLog.logOutput = previousOutput;
      }

      expect(
        recorder.messages.any(
          (message) => message.contains('ValueListenableObserver: notified'),
        ),
        isTrue,
        reason: 'the closure is called when the level admits the line',
      );
      expect(
        source.toStringCalls,
        greaterThan(0),
        reason: 'and the observable is stringified only then',
      );
    });
  });

  group('observer lifetime', () {
    // The documented corollary of the weak-observer contract, and the half of
    // it that is easy to get backwards: collection is not a substitute for
    // removal. Nothing here depends on the garbage collector — the observer is
    // held by a local for the whole test — which is the point. What ends the
    // notifications is `removeObserver`, and that is deterministic.
    test('an observer that is still held keeps firing until it is removed', () {
      final flag = TomBool(false);
      final observer = _CountingObserver();
      flag.addObserver(observer);

      flag | true;
      expect(observer.calls, 1);

      flag | false;
      expect(observer.calls, 2);

      flag.removeObserver(observer);

      flag | true;
      expect(observer.calls, 2, reason: 'removal is what stops notifications');
    });

    testWidgets('the widget holds its observable, not the other way round', (
      tester,
    ) async {
      // The strong reference runs widget → observable, through the plain
      // `final T subState` field. Reading it back off the mounted widget is
      // the observable part of "the widget keeps the observable alive": the
      // element has a live, strong handle on the very instance the caller
      // passed, so nothing can collect it while the widget is in the tree.
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            builder: (state, _) =>
                Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
          ),
        ),
      );

      final mounted = tester.widget<TomObservingWidget<TomBool>>(
        find.byType(TomObservingWidget<TomBool>),
      );
      expect(identical(mounted.subState, flag), isTrue);
    });
  });

  group('the weak-reference contract is documented consistently', () {
    // Closing the lifecycle section with "a long-lived observable that outlives
    // the widget is therefore not retained" would invert the contract in both
    // directions it could be read: the observable holds observers *weakly* (so
    // deregistration is not what releases the `State`), and the widget holds
    // the observable *strongly* (so deregistration does nothing about that
    // reference either). A claim of that shape does not stay in one file — it
    // gets copied into the widget's dartdoc and the API summary — which is why
    // the guard checks every file that discusses the lifecycle rather than one.

    /// Every file in this module that tells a reader what `dispose` does.
    const lifecycleFiles = <String>[
      'doc/observing.md',
      'doc/api/api_summary_observing.md',
      'lib/src/tomclient/observing/tom_observing_widget.dart',
    ];

    final deregisters = RegExp(
      r'deregister|removeObserver',
      caseSensitive: false,
    );

    test('every documented file exists and describes the deregistration', () {
      // Without this the two tests below are satisfiable by deleting the
      // prose they check: a file that says nothing about `dispose` states
      // nothing wrong about it either.
      for (final path in lifecycleFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        final text = file.readAsStringSync();
        expect(
          text,
          contains('dispose'),
          reason: '$path never mentions dispose',
        );
        expect(
          deregisters.hasMatch(text),
          isTrue,
          reason: '$path no longer says that dispose deregisters',
        );
      }
    });

    test('each one says which side holds which', () {
      // Saying "dispose deregisters" without saying which way the references
      // point is how the inversion got in: a reader supplies the missing
      // direction themselves, and supplies it wrongly.
      final offenders = <String>[
        for (final path in lifecycleFiles)
          ...() {
            final text = File(path).readAsStringSync().toLowerCase();
            return <String>[
              if (!text.contains('weak'))
                '$path describes the deregistration without saying the '
                    'observers are held weakly',
              if (!text.contains('strong'))
                '$path describes the deregistration without saying the widget '
                    'holds subState strongly',
            ];
          }(),
      ];
      expect(offenders, isEmpty);
    });

    test('the retired claim has not come back', () {
      final retired = RegExp(
        r'not retained|neither leaks',
        caseSensitive: false,
      );
      final offenders = <String>[
        for (final path in lifecycleFiles)
          if (retired.hasMatch(File(path).readAsStringSync()))
            '$path claims again that deregistration prevents retention',
      ];
      expect(offenders, isEmpty);
    });
  });

  group('the documents describe a multicast listenable', () {
    // The deviation these files used to describe is gone: `addListener`
    // appends and `removeListener` removes the callback it is given. A
    // document still warning about a single slot would send a reader to the
    // one-adaptor-per-listener workaround for a problem that no longer exists —
    // and, worse, would leave the next reader unsure which of the two
    // descriptions the code follows.

    /// Every file in this module that describes the listener surface.
    const surfaceFiles = <String>[
      'doc/observing.md',
      'doc/api/api_summary_observing.md',
      'lib/src/tomclient/observing/value_listenable_observer.dart',
      'lib/src/tomclient/observing/readme.md',
    ];

    test('every file that describes the surface still describes it', () {
      // Without this the test below is satisfiable by deleting the prose: a
      // file that says nothing about listeners claims nothing wrong about them.
      for (final path in surfaceFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        expect(
          file.readAsStringSync(),
          contains('addListener'),
          reason: '$path no longer describes the listener surface',
        );
      }
    });

    test('none of them still claims a single-listener limitation', () {
      final offenders = <String>[
        for (final path in surfaceFiles)
          ...() {
            final lower = File(path).readAsStringSync().toLowerCase();
            return <String>[
              if (lower.contains('single-listener'))
                '$path still calls the adaptor single-listener',
              if (lower.contains('ignores its argument'))
                '$path still says removeListener ignores its argument',
              if (RegExp(r'addlistener\*{0,2} \*{0,2}replac').hasMatch(lower))
                '$path still says addListener replaces',
            ];
          }(),
      ];
      expect(offenders, isEmpty);
    });

    test('the API summary row says removeListener takes its argument', () {
      // The row is checked on its own because the file-wide check above passes
      // as soon as the prose elsewhere is right. The table is what a reader
      // scanning for the signature actually reads.
      final summary = File(
        'doc/api/api_summary_observing.md',
      ).readAsStringSync();
      final row = RegExp(
        r'^\| `removeListener` \|.*$',
        multiLine: true,
      ).firstMatch(summary);
      expect(row, isNotNull, reason: 'no removeListener row in the table');

      final text = row!.group(0)!.toLowerCase();
      expect(text, isNot(contains('ignor')));
      expect(
        text,
        contains('one'),
        reason: 'the row must say it removes one registration of that listener',
      );
    });
  });

  group('the shipped example runs', () {
    test('observing_example.run() completes its assertions', () {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      example.run();
    });
  });
}
