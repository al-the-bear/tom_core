import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Tests for per-principal-per-resource role authorization (C-5).
///
/// The done-bar: *Alice's role differs per resource in a test; the resolved
/// state drives both server enforcement and client presentation.* These tests
/// exercise the kernel half — the `roleName → TomAuthState` registry, the
/// resource-role adapter, the no-fallback rule, and both consumption paths
/// (presentation getters and a server-enforcement gate).
void main() {
  group('TomResourceRoleRegistry', () {
    setUp(TomResourceRoleRegistry.reset);
    tearDown(TomResourceRoleRegistry.reset);

    test('maps a registered role to its resource-level state', () {
      TomResourceRoleRegistry.register('owner', TomAuthState.full);
      expect(TomResourceRoleRegistry.stateFor('owner'), TomAuthState.full);
    });

    test('registerAll declares several mappings at once', () {
      TomResourceRoleRegistry.registerAll({
        'owner': TomAuthState.full,
        'viewer': TomAuthState.read,
      });
      expect(TomResourceRoleRegistry.stateFor('owner'), TomAuthState.full);
      expect(TomResourceRoleRegistry.stateFor('viewer'), TomAuthState.read);
    });

    test('an unknown role has no state (null, a denial signal)', () {
      expect(TomResourceRoleRegistry.stateFor('ghost'), isNull);
    });

    test('mapping exposes an unmodifiable snapshot', () {
      TomResourceRoleRegistry.register('owner', TomAuthState.full);
      final snapshot = TomResourceRoleRegistry.mapping;
      expect(snapshot, {'owner': TomAuthState.full});
      expect(() => snapshot['editor'] = TomAuthState.full, throwsUnsupportedError);
    });
  });

  group('TomResourceRoleAdapter — C-5 done-bar', () {
    setUp(() {
      TomResourceRoleRegistry.reset();
      TomResourceRoleRegistry.registerAll({
        'owner': TomAuthState.full,
        'editor': TomAuthState.full,
        'commenter': TomAuthState.read,
        'viewer': TomAuthState.read,
      });
    });
    tearDown(() {
      TomResourceRoleRegistry.reset();
      TomAuthorization.reset();
    });

    test('Alice\'s role differs per resource → different resolved states', () {
      // Alice is owner of X and viewer of Y — one principal, two roles.
      final alice = TomAccessControlInformation(
        resourceRoles: {'project.X': 'owner', 'project.Y': 'viewer'},
      );
      final adapter = TomResourceRoleAdapter(alice.resourceRoles);

      expect(adapter.resolveAuth('project.X'), TomAuthState.full);
      expect(adapter.resolveAuth('project.Y'), TomAuthState.read);
    });

    test('no fallback: a resource with no role resolves to none', () {
      final adapter = TomResourceRoleAdapter(const {'project.X': 'owner'});
      // project.Z is not in the map — the principal has no role there.
      expect(adapter.resolveAuth('project.Z'), TomAuthState.none);
    });

    test('an unknown role grants nothing (none, not a default full)', () {
      final adapter = TomResourceRoleAdapter(const {'project.X': 'sovereign'});
      expect(adapter.resolveAuth('project.X'), TomAuthState.none);
    });

    test('resolved state drives client presentation', () {
      final adapter = TomResourceRoleAdapter(const {
        'project.X': 'owner', // full   → visible + interactive
        'project.Y': 'viewer', // read  → visible, not interactive
      });

      final x = adapter.resolveAuth('project.X');
      expect(x.isVisible, isTrue);
      expect(x.isInteractive, isTrue);

      final y = adapter.resolveAuth('project.Y');
      expect(y.isVisible, isTrue);
      expect(y.isInteractive, isFalse);
      expect(y.showsContent, isTrue);

      // A resource with no grant is hidden from the user entirely.
      final z = adapter.resolveAuth('project.Z');
      expect(z.isVisible, isFalse);
    });

    test('resolved state drives server enforcement (a write gate)', () {
      final adapter = TomResourceRoleAdapter(const {
        'project.X': 'owner', // may write
        'project.Y': 'viewer', // read-only
      });

      // A minimal server-side gate: an operation is allowed only when the
      // principal's resolved state on the resource is interactive.
      bool mayEdit(String resourceKey) =>
          adapter.stateOf(resourceKey).isInteractive;

      expect(mayEdit('project.X'), isTrue);
      expect(mayEdit('project.Y'), isFalse);
      expect(mayEdit('project.Z'), isFalse); // no role → denied
    });

    test('installs on the TomAuthorization singleton for UI-wide resolution',
        () {
      final alice = TomAccessControlInformation(
        resourceRoles: {'project.X': 'owner', 'project.Y': 'viewer'},
      );
      TomAuthorization.adapter = TomResourceRoleAdapter(alice.resourceRoles);

      expect(TomAuthorization.resolveAuth('project.X'), TomAuthState.full);
      expect(TomAuthorization.resolveAuth('project.Y'), TomAuthState.read);
      expect(TomAuthorization.resolveAuth('project.Z'), TomAuthState.none);
    });
  });
}
