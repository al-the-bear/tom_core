/// Demo 27: Forms
///
/// Demonstrates form patterns using [TomScreenElementsProviderBase] to
/// organize form fields into scoped providers. Shows validation, field
/// grouping, and nested form sections.
///
/// Key concepts:
/// - Form fields organized in scoped providers
/// - Validation with visual feedback
/// - Nested form sections via provider nesting
/// - TomForm widget wrapper for Flutter form integration
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Form Providers
// =============================================================================

/// Simple login form provider.
///
/// Scope path: demo27.login
class LoginFormProvider extends TomScreenElementsProviderBase {
  LoginFormProvider() : super('login');

  late final emailField = TomTextField(
    tomId: 'email',
    scope: this,
  );

  late final passwordField = TomTextField(
    tomId: 'password',
    scope: this,
    obscureText: true,
  );

  late final submitButton = TomElevatedButton(
    tomId: 'submit',
    scope: this,
    onPressed: () {},
  );

  late final forgotButton = TomTextButton(
    tomId: 'forgot',
    scope: this,
    onPressed: () {},
  );
}

/// Contact form with multiple sections.
///
/// Scope path: demo27.contact
class ContactFormProvider extends TomScreenElementsProviderBase {
  ContactFormProvider() : super('contact');

  late final header = TomText(
    tomId: 'header',
    scope: this,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  /// Nested: demo27.contact.personal
  late final personal = PersonalSectionProvider(this);

  /// Nested: demo27.contact.address
  late final address = AddressSectionProvider(this);

  late final saveButton = TomElevatedButton(
    tomId: 'save',
    scope: this,
    onPressed: () {},
  );

  late final resetButton = TomOutlinedButton(
    tomId: 'reset',
    scope: this,
    onPressed: () {},
  );
}

/// Personal info sub-section: demo27.contact.personal
class PersonalSectionProvider extends TomScreenElementsProviderBase {
  PersonalSectionProvider(TomScreenElementsProvider parent)
      : super('personal', parent);

  late final firstNameField = TomTextField(
    tomId: 'firstName',
    scope: this,
  );

  late final lastNameField = TomTextField(
    tomId: 'lastName',
    scope: this,
  );

  late final emailField = TomTextField(
    tomId: 'email',
    scope: this,
  );

  late final phoneField = TomTextField(
    tomId: 'phone',
    scope: this,
  );
}

/// Address sub-section: demo27.contact.address
class AddressSectionProvider extends TomScreenElementsProviderBase {
  AddressSectionProvider(TomScreenElementsProvider parent)
      : super('address', parent);

  late final streetField = TomTextField(
    tomId: 'street',
    scope: this,
  );

  late final cityField = TomTextField(
    tomId: 'city',
    scope: this,
  );

  late final zipField = TomTextField(
    tomId: 'zip',
    scope: this,
  );

  late final countryField = TomTextField(
    tomId: 'country',
    scope: this,
  );
}

/// Settings form provider with mixed input types.
///
/// Scope path: demo27.settings
class SettingsFormProvider extends TomScreenElementsProviderBase {
  SettingsFormProvider() : super('settings');

  late final nameField = TomTextField(
    tomId: 'displayName',
    scope: this,
  );

  late final bioField = TomTextField(
    tomId: 'bio',
    scope: this,
    maxLines: 3,
  );

  late final notificationsSwitch = TomSwitch(
    tomId: 'notifications',
    scope: this,
    value: true,
    onChanged: (_) {},
  );

  late final darkModeSwitch = TomSwitch(
    tomId: 'darkMode',
    scope: this,
    value: false,
    onChanged: (_) {},
  );

  late final saveButton = TomFilledButton(
    tomId: 'save',
    scope: this,
    onPressed: () {},
  );
}

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Forms demo.
class FormsDemo extends TomStatelessWidget {
  FormsDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _FormsDemoContent();
  }
}

class _FormsDemoContent extends TomStatefulWidget {
  _FormsDemoContent();

  @override
  State<_FormsDemoContent> createState() => _FormsDemoContentState();
}

class _FormsDemoContentState extends TomState<_FormsDemoContent> {
  late final _loginProvider = LoginFormProvider();
  late final _contactProvider = ContactFormProvider();
  late final _settingsProvider = SettingsFormProvider();

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Simple Login Form
            _SectionHeader(tomId: 'section.login'),
            TomSizedBox(height: 16),
            _buildLoginForm(context),
            TomSizedBox(height: 32),

            // Section 2: Multi-Section Contact Form
            _SectionHeader(tomId: 'section.contact'),
            TomSizedBox(height: 16),
            _buildContactForm(context),
            TomSizedBox(height: 32),

            // Section 3: Settings Form (mixed inputs)
            _SectionHeader(tomId: 'section.settings'),
            TomSizedBox(height: 16),
            _buildSettingsForm(context),
            TomSizedBox(height: 32),

            // Section 4: Form with ACL layout
            _SectionHeader(tomId: 'section.aclForm'),
            TomSizedBox(height: 16),
            _buildAclForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return _DemoCard(
      tomId: 'card.login',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loginProvider.emailField,
          TomSizedBox(height: 16),
          _loginProvider.passwordField,
          TomSizedBox(height: 24),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _loginProvider.forgotButton,
              _loginProvider.submitButton,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm(BuildContext context) {
    return _DemoCard(
      tomId: 'card.contact',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _contactProvider.header,
          TomSizedBox(height: 16),
          // Personal section via ACL
          TomAclBuilder<PersonalSectionProvider>(
            id: 'personalAcl',
            elementProvider: _contactProvider.personal,
            title: 'Personal Information',
          )
              .append((p) => p.firstNameField, dist: 16)
              .append((p) => p.lastNameField, dist: 16)
              .newRow()
              .append((p) => p.emailField, dist: 16)
              .append((p) => p.phoneField, dist: 16)
              .build(context),
          TomSizedBox(height: 16),
          // Address section via ACL
          TomAclBuilder<AddressSectionProvider>(
            id: 'addressAcl',
            elementProvider: _contactProvider.address,
            title: 'Address',
          )
              .append((p) => p.streetField, dist: 16)
              .newRow()
              .append((p) => p.cityField, dist: 16)
              .append((p) => p.zipField, dist: 16)
              .newRow()
              .append((p) => p.countryField, dist: 16 )
              .newRow(dist:16).setRowAlignment(RowAlignment.right)
              .append( (p) => _contactProvider.resetButton, dist: 16).setMSize(200,0).setXSize(300, 0)
              .append( (p) => _contactProvider.saveButton, dist: 16).setMSize(200,0).setXSize(300,0)
              .build(context),
          TomSizedBox(height: 24),

        ],
      ),
    );
  }

  Widget _buildSettingsForm(BuildContext context) {
    return _DemoCard(
      tomId: 'card.settings',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _settingsProvider.nameField,
          TomSizedBox(height: 16),
          _settingsProvider.bioField,
          TomSizedBox(height: 24),
          TomRow(
            children: [
              TomExpanded(
                child: TomText(
                  tomId: 'notificationsLabel',
                  scope: _settingsProvider,
                ),
              ),
              _settingsProvider.notificationsSwitch,
            ],
          ),
          TomSizedBox(height: 8),
          TomRow(
            children: [
              TomExpanded(
                child: TomText(
                  tomId: 'darkModeLabel',
                  scope: _settingsProvider,
                ),
              ),
              _settingsProvider.darkModeSwitch,
            ],
          ),
          TomSizedBox(height: 24),
          TomAlign(
            alignment: Alignment.centerRight,
            child: _settingsProvider.saveButton,
          ),
        ],
      ),
    );
  }

  Widget _buildAclForm(BuildContext context) {
    return _DemoCard(
      tomId: 'card.aclForm',
      child: TomAclBuilder<ContactFormProvider>(
        id: 'contactAcl',
        elementProvider: _contactProvider,
        title: 'Contact (ACL Layout)',
        padding: const EdgeInsets.all(8),
      )
          .append((p) => p.personal.firstNameField)
          .append((p) => p.personal.lastNameField, dist: 16)
          .newRow()
          .append((p) => p.personal.emailField)
          .newRow()
          .append((p) => p.address.streetField)
          .newRow()
          .append((p) => p.address.cityField)
          .append((p) => p.address.zipField, dist: 16)
          .append((p) => p.address.countryField, dist: 16)
          .newRow()
          .gapRow()
          .newRow()
          .gap()
          .append((p) => p.resetButton, dist: 16)
          .append((p) => p.saveButton, dist: 16)
          .build(context),
    );
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({required this.tomId});

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          tomId: '$tomId.title',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TomSizedBox(height: 8),
        TomContainer(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomIcon(tomId: tomId),
                TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    tomId: '$tomId.title',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 8),
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 16),
            TomDivider(),
            TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
