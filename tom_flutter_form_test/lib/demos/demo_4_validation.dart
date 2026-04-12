import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../forms/company_forms.dart';
import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Demo 4: Validation — Fast vs Slow validators
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - Fast validators: required, email, minLength, maxLength, pattern
/// - Slow validators with pending spinner (SlowValidator)
/// - Validation debouncing (300ms fast, 600ms slow)
/// - Compose() for combining validators
/// - Cross-field validation (override validateForm())
/// - Validation state observation (ValidationPristine/Success/Error/Pending)
class Demo4Validation extends StatefulWidget {
  const Demo4Validation({super.key});

  @override
  State<Demo4Validation> createState() => _Demo4ValidationState();
}

class _Demo4ValidationState extends State<Demo4Validation> {
  final _profile = CompanyProfile();
  late final _form = CompanyBasicInfoForm();
  late final _inspector = TomFormInspector();
  
  @override
  void initState() {
    super.initState();
    _form.addListener(_inspector);
    _form.bind(_profile);
  }

  @override
  void dispose() {
    _form.removeListener(_inspector);
    _form.dispose();
    super.dispose();
  }

  Widget _buildValidationStatus(TomField<Object?> field) {
    return TomMultiObservableBuilder(
      observables: [field],
      builder: (context) {
        final state = field.validationState;
        IconData icon;
        Color color;
        String text;

        switch (state) {
          case ValidationPristine():
            icon = Icons.remove_circle_outline;
            color = Colors.grey;
            text = 'Pristine';
          case ValidationSuccess():
            icon = Icons.check_circle;
            color = Colors.green;
            text = 'Valid';
          case ValidationPending():
            icon = Icons.hourglass_empty;
            color = Colors.orange;
            text = 'Validating...';
          case ValidationError():
            icon = Icons.error;
            color = Colors.red;
            text = 'Error: ${state.errorKey}';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(color: color, fontSize: 12)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(
      id: 'validationDemo',
      elementProvider: _form,
      title: 'Validation Demo',
      borderStyle: const AclBorderStyle.solid(),
      padding: const EdgeInsets.all(16),
    )
        // Company Name - required + minLength
        .append((p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                p.name.widget,
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Validators: required, minLength(2) | ',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    _buildValidationStatus(p.name),
                  ],
                ),
              ],
            ))
        .newRow()
        // Tax ID - pattern + SlowValidator
        .append((p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                p.taxId.widget,
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Validators: required, pattern, SLOW (1s) | ',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    _buildValidationStatus(p.taxId),
                  ],
                ),
                const Text('Try: "X123" triggers SlowValidator error',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ))
        .newRow()
        // Website - pattern URL
        .append((p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                p.website.widget,
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Validators: pattern (URL) | ',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    _buildValidationStatus(p.website),
                  ],
                ),
              ],
            ))
        .newRow()
        // Description - maxLength
        .append((p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                p.description.widget,
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Validators: maxLength(500) | ',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    _buildValidationStatus(p.description),
                  ],
                ),
              ],
            ))
        .expandX()
        .build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo 4: Validation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validation Types:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('• Fast: required, email, minLength, maxLength, pattern'),
                    Text('• Slow: SlowValidator (shows pending spinner)'),
                    Text('• Debounce: Fast=300ms, Slow=600ms'),
                    SizedBox(height: 8),
                    Text(
                      'Tips:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('• Tax ID starting with "X" fails slow validation'),
                    Text('• Watch the pending state during slow validation'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Form
            TomFormStyleScope(
              style: TomFormStyle.material3,
              child: formLayout,
            ),
            const SizedBox(height: 16),
            // Event log
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Form Events (last 5):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            _inspector.clear();
                            setState(() {});
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const Divider(),
                    ..._inspector.events.reversed.take(5).map((e) => Text(
                          '${e.runtimeType}: ${e.source}',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        )),
                    if (_inspector.isEmpty)
                      const Text(
                        'No events yet',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
