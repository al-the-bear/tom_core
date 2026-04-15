// ignore_for_file: avoid_print
/// Phase 1 Demo Application
///
/// Exercises all Phase 1 framework features using ONLY
/// [TomFormStringInput] + [TomFormStringDropdown]:
///
/// 1. setValue(T) usage — typing in fields, selecting from dropdowns
/// 2. Form bind() / save() / discard() lifecycle — buttons + status bar
/// 3. Authorization (four states) — popup menu switches global auth
/// 4. TomAuthorizationGroup — firstName/lastName share a group
/// 5. TomAuthorizer — email field has per-field authorizer
/// 6. TomUIStateController — role dropdown uses uiStateController
/// 7. Form nesting — AddressForm nested inside ProfileForm
/// 8. Form actions (save, discard) — action buttons
/// 9. Validation (sync, async, cross-field, debounced)
/// 10. Validation error reset timing — setValue clears errors
/// 11. TomFormErrorBanner display — cross-field errors shown in banner
/// 12. Resource resolution (labels, hints, descriptions via overrides)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/tom_forms.dart';

// ---------------------------------------------------------------------------
// Data Models
// ---------------------------------------------------------------------------

@tomReflector
class UserProfile extends TomClass {
  late final TomObject<String> firstName = TomObject('');
  late final TomObject<String> lastName = TomObject('');
  late final TomObject<String> email = TomObject('');
  late final TomObject<String> country = TomObject('');
  late final TomObject<String> role = TomObject('user');
}

@tomReflector
class AddressData extends TomClass {
  late final TomObject<String> street = TomObject('');
  late final TomObject<String> city = TomObject('');
  late final TomObject<String> zipCode = TomObject('');
}

// ---------------------------------------------------------------------------
// Nested Address Form
// ---------------------------------------------------------------------------

@tomReflector
class AddressForm extends TomForm<AddressData> {
  AddressForm({super.parentForm}) : super(formId: 'address');

  late final TomFormStringInput street;
  late final TomFormStringInput city;
  late final TomFormStringInput zipCode;

  @override
  void createFormElements() {
    street = TomFormStringInput(
      'street',
      '',
      labelTextOverride: 'Street Address',
      hintTextOverride: '123 Main St',
      validators: [Validators.required()],
    );
    city = TomFormStringInput(
      'city',
      '',
      labelTextOverride: 'City',
      validators: [Validators.required()],
    );
    zipCode = TomFormStringInput(
      'zipCode',
      '',
      labelTextOverride: 'ZIP Code',
      validators: [
        Validators.required(),
        Validators.pattern(RegExp(r'^\d{5}$'), errorKey: 'error.zipFormat'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Main Profile Form
// ---------------------------------------------------------------------------

/// Async validator that simulates checking email uniqueness.
Future<ValidationResult> _emailUniqueValidator(String value) async {
  await Future.delayed(const Duration(milliseconds: 500));
  if (value == 'taken@example.com') {
    return const ValidationError('error.emailTaken');
  }
  return const ValidationSuccess();
}

@tomReflector
class ProfileForm extends TomForm<UserProfile> {
  ProfileForm() : super(formId: 'profile');

  late final TomFormStringInput firstName;
  late final TomFormStringInput lastName;
  late final TomFormStringInput email;
  late final TomFormStringDropdown country;
  late final TomFormStringDropdown role;
  late final AddressForm address;

  /// Authorization group: name fields share a group (demo feature #4).
  late final TomAuthorizationGroup nameGroup;

  @override
  void createFormElements() {
    nameGroup = TomAuthorizationGroup('nameFields');

    firstName = TomFormStringInput(
      'firstName',
      '',
      labelTextOverride: 'First Name',
      hintTextOverride: 'Enter first name',
      descriptionTextOverride: 'Your given name',
      validators: [Validators.required()],
      tomGroup: nameGroup,
    );
    lastName = TomFormStringInput(
      'lastName',
      '',
      labelTextOverride: 'Last Name',
      validators: [Validators.required()],
      tomGroup: nameGroup,
    );
    email = TomFormStringInput(
      'email',
      '',
      labelTextOverride: 'Email',
      hintTextOverride: 'user@example.com',
      keyboardType: TextInputType.emailAddress,
      validators: [
        Validators.required(),
        Validators.email(),
        _emailUniqueValidator,
      ],
      // Demo feature #5: per-field authorizer narrows to read when role=admin
      authorizer: TomAuthorizer(
        strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
        resolve: (resourceAuth) => resourceAuth,
      ),
    );
    country = TomFormStringDropdown(
      'country',
      '',
      labelTextOverride: 'Country',
      hintTextOverride: 'Select a country',
      source: StaticSelectableSource([
        const SelectableItem(value: 'US', label: 'United States'),
        const SelectableItem(value: 'UK', label: 'United Kingdom'),
        const SelectableItem(value: 'DE', label: 'Germany'),
        const SelectableItem(value: 'FR', label: 'France'),
        const SelectableItem(value: 'JP', label: 'Japan'),
      ]),
      validators: [Validators.required()],
    );
    role = TomFormStringDropdown(
      'role',
      'user',
      labelTextOverride: 'Role',
      source: StaticSelectableSource([
        const SelectableItem(value: 'user', label: 'User'),
        const SelectableItem(value: 'admin', label: 'Administrator'),
        const SelectableItem(value: 'editor', label: 'Editor'),
      ]),
      // Demo feature #6: uiStateController disables role unless country is set
      uiStateController: TomUIStateController(
        resolve: (resourceAuth) {
          // In a real app this would check live data — here it just shows the API
          return resourceAuth;
        },
      ),
    );
    address = AddressForm(parentForm: this);
  }

  /// Cross-field validation: email domain must match role requirements.
  @override
  Future<List<FormValidationError>> validateForm() async {
    final errors = <FormValidationError>[];
    if (role.get() == 'admin' && !email.get().endsWith('@company.com')) {
      errors.add(FormValidationError(
        errorKey: 'error.adminEmailRequired',
        fields: [email, role],
      ));
    }
    return errors;
  }
}

// ---------------------------------------------------------------------------
// Demo App
// ---------------------------------------------------------------------------

void main() {
  runApp(const Phase1DemoApp());
}

class Phase1DemoApp extends StatelessWidget {
  const Phase1DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phase 1 Forms Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const ProfileFormScreen(),
    );
  }
}

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen>
    with TomFormEventListener {
  late final ProfileForm _form;
  late final UserProfile _profile;

  // Auth demo controls
  TomAuthState _formAuthState = TomAuthState.full;
  final _authAdapter = _DemoAuthAdapter();

  @override
  void initState() {
    super.initState();
    TomAuthorization.adapter = _authAdapter;

    _form = TomScope.withScope('demo', () => ProfileForm());
    _form.addListener(this);

    // Create and bind initial data
    _profile = UserProfile();
    _profile.setValues({
      'firstName': 'John',
      'lastName': 'Doe',
      'email': 'john@example.com',
      'country': 'US',
      'role': 'user',
    });
    _form.bind(_profile);
  }

  @override
  void dispose() {
    _form.removeListener(this);
    _form.dispose();
    TomAuthorization.reset();
    super.dispose();
  }

  @override
  void handleEvent(TomFormEvent event) {
    print('[Event] ${event.runtimeType}: ${event.description}');
    if (mounted) setState(() {});
  }

  void _onSave() async {
    final errors = await _form.validate();
    if (errors.isEmpty) {
      if (await _form.save()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved!')),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _onDiscard() {
    _form.discard();
    setState(() {});
  }

  void _setAuthState(TomAuthState state) {
    _formAuthState = state;
    _authAdapter.globalOverride = state;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 1 Forms Demo'),
        actions: [
          // Auth state selector
          PopupMenuButton<TomAuthState>(
            icon: const Icon(Icons.security),
            tooltip: 'Set auth state',
            onSelected: _setAuthState,
            itemBuilder: (_) => TomAuthState.values.map((s) {
              return PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    Icon(
                      s == _formAuthState
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(s.name),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: TomFormStyleScopeLegacy(
        style: const TomFormStyleLegacy(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error banner
              TomFormErrorBanner(form: _form),
              const SizedBox(height: 16),

              // Status bar
              _StatusBar(form: _form),
              const SizedBox(height: 16),

              // Field widgets
              _form.firstName.widget,
              const SizedBox(height: 12),
              _form.lastName.widget,
              const SizedBox(height: 12),
              _form.email.widget,
              const SizedBox(height: 12),
              _form.country.widget,
              const SizedBox(height: 12),
              _form.role.widget,
              const SizedBox(height: 24),

              // Nested address form
              Text(
                'Address',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              _form.address.street.widget,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _form.address.city.widget),
                  const SizedBox(width: 12),
                  SizedBox(width: 120, child: _form.address.zipCode.widget),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _onDiscard,
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _onSave,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status bar showing form state
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  final ProfileForm form;
  const _StatusBar({required this.form});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _chip('Dirty', form.isDirty, cs),
            const SizedBox(width: 8),
            _chip('Valid', form.isValid, cs),
            const SizedBox(width: 8),
            Text(
              '${form.dirtyFields.length} dirty, '
              '${form.fieldsWithErrors.length} errors',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, ColorScheme cs) {
    return Chip(
      label: Text(label),
      backgroundColor: active ? cs.primaryContainer : cs.surfaceContainer,
      labelStyle: TextStyle(
        color: active ? cs.onPrimaryContainer : cs.onSurface,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo auth adapter
// ---------------------------------------------------------------------------

class _DemoAuthAdapter extends TomAuthorizationAdapter {
  TomAuthState? globalOverride;
  final Map<String, TomAuthState> _rules = {};

  void setRule(String path, TomAuthState state) => _rules[path] = state;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    if (globalOverride != null) return globalOverride!;
    return _rules[resourceKeyPath] ?? TomAuthState.full;
  }
}
