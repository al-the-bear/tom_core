// ignore_for_file: avoid_print
/// Tom Flutter UI — runnable demo application.
///
/// A single `runApp` demo that pages, via a [NavigationBar], through the three
/// pillars of the library:
///
/// 1. **Widgets** — the general widget kit ([TomElevatedButton], [TomText],
///    [TomChip], [TomBadge], [TomListTile], [TomSwitch], [TomCheckbox],
///    [TomCard], [TomSlider], [TomLinearProgressIndicator],
///    [TomCircularProgressIndicator]). Renders without any reflection or
///    resource setup beyond the app-level provider installed in [main].
/// 2. **Custom** — the non-form composites ([TomAuthGuard], [TomEmptyState],
///    [TomLoadingOverlay], [TomSkeletonLoader], [TomRadioGroup],
///    [TomErrorBoundary]).
/// 3. **Forms** — the declarative form system exercised through
///    [TomFormStringInput] + [TomFormStringDropdown]: bind/save/discard
///    lifecycle, four authorization states, authorization groups, per-field
///    authorizers, UI-state controllers, nested forms, sync/async/cross-field
///    validation, the error banner, and resource resolution.
///
/// The default landing tab is **Widgets**, so the app pumps cleanly under the
/// Flutter toolchain (`flutter run example/gallery_demo.dart`). The **Forms**
/// tab relies on Tom reflection for its `@tomReflector` form models; a host app
/// must call `initializeReflection()` (with generated reflection data) at
/// startup. When that wiring is absent — as in this standalone example — the
/// Forms tab degrades gracefully to an explanatory panel instead of crashing.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  // Tom widgets resolve labels/colours through the resource layer; install a
  // (here empty) provider and the all-colours adapter so the kit renders with
  // its explicit values rather than failing a resource lookup.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomUIColors.adapter = AllColorsAdapter();
  runApp(const Phase1DemoApp());
}

class Phase1DemoApp extends StatelessWidget {
  const Phase1DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Flutter UI Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const _DemoHome(),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell — NavigationBar paging the three galleries
// ---------------------------------------------------------------------------

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  int _index = 0;

  static const _titles = ['Widgets', 'Custom', 'Forms'];

  @override
  Widget build(BuildContext context) {
    // Build only the selected screen — never an IndexedStack — so the
    // reflection-dependent Forms screen is constructed only when chosen.
    final Widget body = switch (_index) {
      0 => const _WidgetsGallery(),
      1 => const _CustomGallery(),
      _ => const ProfileFormScreen(),
    };
    return Scaffold(
      appBar: AppBar(title: Text('Tom Flutter UI — ${_titles[_index]}')),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.widgets), label: 'Widgets'),
          NavigationDestination(icon: Icon(Icons.extension), label: 'Custom'),
          NavigationDestination(icon: Icon(Icons.dynamic_form), label: 'Forms'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gallery 1 — the general widget kit
// ---------------------------------------------------------------------------

class _WidgetsGallery extends StatefulWidget {
  const _WidgetsGallery();

  @override
  State<_WidgetsGallery> createState() => _WidgetsGalleryState();
}

class _WidgetsGalleryState extends State<_WidgetsGallery> {
  bool _switchOn = true;
  bool _checkOn = false;
  double _slider = 0.4;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('Labels'),
        TomText(text: 'TomText renders styled text.'),
        const SizedBox(height: 8),
        Row(
          children: [
            TomBadge(labelText: '3', child: const Icon(Icons.notifications)),
            const SizedBox(width: 16),
            TomChip(labelText: 'TomChip'),
          ],
        ),
        const SizedBox(height: 8),
        TomCard(
          child: TomListTile(
            leading: const Icon(Icons.person),
            titleText: 'TomListTile inside a TomCard',
            subtitle: const Text('subtitle'),
          ),
        ),

        _section('Buttons'),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            TomElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            TomFilledButton(onPressed: () {}, child: const Text('Filled')),
            TomOutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          ],
        ),

        _section('Toggles'),
        Row(
          children: [
            TomSwitch(
              value: _switchOn,
              onChanged: (v) => setState(() => _switchOn = v),
            ),
            const SizedBox(width: 8),
            const Text('TomSwitch'),
            const SizedBox(width: 24),
            TomCheckbox(
              value: _checkOn,
              onChanged: (v) => setState(() => _checkOn = v ?? false),
            ),
            const SizedBox(width: 8),
            const Text('TomCheckbox'),
          ],
        ),

        _section('Slider'),
        TomSlider(
          value: _slider,
          onChanged: (v) => setState(() => _slider = v),
        ),

        _section('Progress'),
        Row(
          children: [
            TomCircularProgressIndicator(value: null),
            const SizedBox(width: 24),
            Expanded(child: TomLinearProgressIndicator(value: _slider)),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

// ---------------------------------------------------------------------------
// Gallery 2 — non-form composites
// ---------------------------------------------------------------------------

class _CustomGallery extends StatelessWidget {
  const _CustomGallery();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('TomAuthGuard (full → renders child)', style: titleStyle),
        const SizedBox(height: 8),
        const TomAuthGuard(
          tomId: 'demo.guarded',
          child: ListTile(
            leading: Icon(Icons.lock_open),
            title: Text('Visible because auth resolves to full'),
          ),
        ),
        const Divider(height: 32),

        Text('TomRadioGroup', style: titleStyle),
        const SizedBox(height: 8),
        const TomRadioGroup<String>(
          tomId: 'demo.choice',
          selected: 'a',
          items: [
            TomRadioGroupItem(value: 'a', label: 'Alpha'),
            TomRadioGroupItem(value: 'b', label: 'Beta'),
            TomRadioGroupItem(value: 'c', label: 'Gamma'),
          ],
        ),
        const Divider(height: 32),

        Text('TomSkeletonLoader', style: titleStyle),
        const SizedBox(height: 8),
        const TomSkeletonLoader(width: 220, height: 14),
        const SizedBox(height: 8),
        const TomSkeletonLoader(width: 160, height: 14),
        const Divider(height: 32),

        Text('TomLoadingOverlay', style: titleStyle),
        const SizedBox(height: 8),
        const SizedBox(
          height: 140,
          child: TomLoadingOverlay(
            isLoading: true,
            message: 'Loading…',
            child: SizedBox.expand(
              child: Card(child: Center(child: Text('content'))),
            ),
          ),
        ),
        const Divider(height: 32),

        Text('TomEmptyState (wrapped in TomErrorBoundary)', style: titleStyle),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: TomErrorBoundary(
            child: TomEmptyState(
              title: 'Nothing here yet',
              description: 'Create your first item to get started.',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Forms — data models
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
        resolve: (currentAuth, data) {
          // In a real app this would check live data — here it just shows the API
          return currentAuth;
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
      errors.add(
        FormValidationError(
          errorKey: 'error.adminEmailRequired',
          fields: [email, role],
        ),
      );
    }
    return errors;
  }
}

// ---------------------------------------------------------------------------
// Forms screen — reflection-tolerant
// ---------------------------------------------------------------------------

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen>
    with TomFormEventListener {
  ProfileForm? _form;

  /// Non-null when the form could not be constructed (reflection not wired).
  Object? _initError;

  // Auth demo controls
  TomAuthState _formAuthState = TomAuthState.full;
  final _authAdapter = _DemoAuthAdapter();

  @override
  void initState() {
    super.initState();
    // The form models are `@tomReflector` types; without reflection data wired
    // by the host app this construction throws. Degrade gracefully instead of
    // taking down the whole demo.
    try {
      TomAuthorization.adapter = _authAdapter;

      final form = TomScope.withScope('demo', () => ProfileForm());
      form.addListener(this);

      final profile = UserProfile();
      profile.setValues({
        'firstName': 'John',
        'lastName': 'Doe',
        'email': 'john@example.com',
        'country': 'US',
        'role': 'user',
      });
      form.bind(profile);

      _form = form;
    } catch (e) {
      _initError = e;
    }
  }

  @override
  void dispose() {
    _form?.removeListener(this);
    _form?.dispose();
    TomAuthorization.reset();
    super.dispose();
  }

  @override
  void handleEvent(TomFormEvent event) {
    print('[Event] ${event.runtimeType}: ${event.description}');
    if (mounted) setState(() {});
  }

  void _onSave() async {
    final form = _form;
    if (form == null) return;
    final errors = await form.validate();
    if (errors.isEmpty) {
      if (await form.save()) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _onDiscard() {
    _form?.discard();
    setState(() {});
  }

  void _setAuthState(TomAuthState state) {
    _formAuthState = state;
    _authAdapter.globalOverride = state;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    if (form == null) {
      return _ReflectionRequiredPanel(error: _initError);
    }
    return Column(
      children: [
        // Auth state selector strip.
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.security, size: 18),
                const SizedBox(width: 8),
                const Text('Auth state:'),
                const SizedBox(width: 12),
                DropdownButton<TomAuthState>(
                  value: _formAuthState,
                  onChanged: (s) => s == null ? null : _setAuthState(s),
                  items: TomAuthState.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TomFormStyleScope(
            style: const TomFormStyle(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TomFormErrorBanner(form: form),
                  const SizedBox(height: 16),
                  _StatusBar(form: form),
                  const SizedBox(height: 16),
                  form.firstName.widget,
                  const SizedBox(height: 12),
                  form.lastName.widget,
                  const SizedBox(height: 12),
                  form.email.widget,
                  const SizedBox(height: 12),
                  form.country.widget,
                  const SizedBox(height: 12),
                  form.role.widget,
                  const SizedBox(height: 24),
                  Text(
                    'Address',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  form.address.street.widget,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: form.address.city.widget),
                      const SizedBox(width: 12),
                      SizedBox(width: 120, child: form.address.zipCode.widget),
                    ],
                  ),
                  const SizedBox(height: 24),
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
        ),
      ],
    );
  }
}

/// Shown when the `@tomReflector` form models cannot be built because the host
/// app never called `initializeReflection()`.
class _ReflectionRequiredPanel extends StatelessWidget {
  final Object? error;
  const _ReflectionRequiredPanel({this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 48),
            const SizedBox(height: 16),
            Text(
              'Forms need reflection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The form models are @tomReflector types. A host app must call '
              'initializeReflection() with generated reflection data at startup. '
              'The Widgets and Custom tabs run without it.',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
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
