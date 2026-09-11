/// The JSON protection tier: the reflective serializer withholds a field
/// annotated `@TomProtectedField` whose grade shows no content.
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'json_protection_test.reflection.dart';

@tomReflector
class ProtectedEmployee {
  String? name;

  @TomProtectedField('employee.salary')
  int? salary;
}

TomPrincipal _principal({
  List<String> resourceKeys = const [],
  Map<String, String> resourceRoles = const {},
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(id: 7, username: 'ada'),
  aci: TomAccessControlInformation(
    resourceKeys: resourceKeys,
    resourceRoles: resourceRoles,
  ),
);

final _employee = ProtectedEmployee()
  ..name = 'Ada'
  ..salary = 85000;

Map<String, Object?> _renderAs(TomPrincipal? principal) => runZoned(
  () => tomReflectionInfo.getValues(_employee),
  zoneValues: {TomPrincipal: principal},
);

void main() {
  setUpAll(initializeReflection);
  setUp(() {
    TomResourceKeyProtection.restoreDefaults();
    TomResourceKeyProtection.globalSettingProtectionDefault = true;
    TomResourceRoleRegistry.reset();
    TomAuthorization.reset();
  });
  tearDown(() {
    TomResourceKeyProtection.restoreDefaults();
    TomResourceRoleRegistry.reset();
    TomAuthorization.reset();
  });

  test('a field the principal holds is serialized', () {
    final json = _renderAs(_principal(resourceKeys: ['employee.*']));
    expect(json, {'name': 'Ada', 'salary': 85000});
  });

  test('a field the principal does not hold is left out, not nulled', () {
    final json = _renderAs(_principal());
    expect(json, {'name': 'Ada'});
    expect(json.containsKey('salary'), isFalse);
  });

  test('a read-only grade shows content, so the field is serialized', () {
    TomResourceRoleRegistry.register('viewer', TomAuthState.read);
    final json = _renderAs(
      _principal(resourceRoles: {'employee.salary': 'viewer'}),
    );
    expect(json['salary'], 85000);
  });

  test('a disabled grade shows no content, so the field is left out', () {
    TomResourceRoleRegistry.register('locked', TomAuthState.disabled);
    final json = _renderAs(
      _principal(resourceRoles: {'employee.salary': 'locked'}),
    );
    expect(json.containsKey('salary'), isFalse);
  });

  test('no principal on the zone gets nothing protected', () {
    expect(_renderAs(null), {'name': 'Ada'});
  });

  test('with the tier switched off every field is serialized', () {
    TomResourceKeyProtection.globalSettingUseAutomaticJsonProtection = false;
    expect(_renderAs(_principal()), {'name': 'Ada', 'salary': 85000});
  });

  test('with resource keys not enforced every field is serialized', () {
    TomResourceKeyProtection.globalSettingProtectionDefault = false;
    expect(_renderAs(null), {'name': 'Ada', 'salary': 85000});
  });

  test('an installed authorization adapter grades the field too', () {
    // The automatic grade is the adapter's met with the principal's, so a
    // client that grades through an adapter — and enforces no resource keys —
    // is still protected.
    TomResourceKeyProtection.globalSettingProtectionDefault = false;
    TomAuthorization.adapter = _FixedAdapter({
      'employee.salary': TomAuthState.none,
    });
    expect(_renderAs(null), {'name': 'Ada'});
  });

  test('the containers of convertToJsonString get the same treatment', () {
    final text = runZoned(
      () => tomReflectionInfo.convertToJsonString([_employee]),
      zoneValues: {TomPrincipal: _principal()},
    );
    expect(jsonDecode(text), [
      {'name': 'Ada'},
    ]);
  });
}

class _FixedAdapter implements TomAuthorizationAdapter {
  _FixedAdapter(this.states);

  final Map<String, TomAuthState> states;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      states[resourceKeyPath] ?? TomAuthState.full;
}
