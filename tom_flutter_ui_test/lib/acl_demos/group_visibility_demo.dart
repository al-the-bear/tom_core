part of 'acl_demos.dart';

class GroupVisibilityDemo extends StatefulWidget {
  const GroupVisibilityDemo({super.key});

  @override
  State<GroupVisibilityDemo> createState() => _GroupVisibilityDemoState();
}

class _GroupVisibilityDemoState extends State<GroupVisibilityDemo> {
  final _addressCtrl = AclBinaryVisibilityController();
  final _notesCtrl = AclBinaryVisibilityController();
  final _textController = TextEditingController();
  final _textNotifier = ValueNotifier<String>('');
  late final AclCallbackVisibilityController<String> _inputCtrl;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => _textNotifier.value = _textController.text);
    _inputCtrl = AclCallbackVisibilityController<String>(
      valueListenable: _textNotifier,
      modeBuilder: (text) => text.length >= 3
          ? AclGroupVisibilityMode.visible
          : AclGroupVisibilityMode.hidden,
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _inputCtrl.dispose();
    _textNotifier.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Binary visibility toggle (Switch → hide/show):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Show address'),
            ValueListenableBuilder(
              valueListenable: _addressCtrl.modeNotifier,
              builder: (_, mode, _) => Switch(
                value: mode == AclGroupVisibilityMode.visible,
                onChanged: (on) => _addressCtrl.mode = on
                    ? AclGroupVisibilityMode.visible
                    : AclGroupVisibilityMode.hidden,
              ),
            ),
            const SizedBox(width: 16),
            const Text('Disable notes'),
            ValueListenableBuilder(
              valueListenable: _notesCtrl.modeNotifier,
              builder: (_, mode, _) => Switch(
                value: mode == AclGroupVisibilityMode.disabled,
                onChanged: (on) => _notesCtrl.mode = on
                    ? AclGroupVisibilityMode.disabled
                    : AclGroupVisibilityMode.visible,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 200,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.blueGrey,
              rounded: true,
              borderRadius: 8,
            ),
          )
              .setGroupVisibilityController('address', _addressCtrl)
              .setGroupVisibilityController('notes', _notesCtrl)
              // Row 1: always visible
              .append(const SizedBox(width: 80, child: Text('Name:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Always visible',
                  ),
                ),
              )
              .expandX()
              // Row 2: address group
              .newRow(dist: 8)
              .startGroup('address')
              .append(const SizedBox(width: 80, child: Text('Address:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Toggleable via switch',
                  ),
                ),
              )
              .expandX()
              .endGroup()
              // Row 3: notes group
              .newRow(dist: 8)
              .startGroup('notes')
              .append(const SizedBox(width: 80, child: Text('Notes:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Can be disabled',
                  ),
                ),
              )
              .expandX()
              .endGroup()
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Input-value-driven visibility (type 3+ chars to reveal):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: 'Type 3+ characters to show details',
            ),
          ),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 140,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.deepPurple,
              rounded: true,
              borderRadius: 8,
            ),
          )
              .setGroupVisibilityController('details', _inputCtrl)
              .append(const Text('Summary is always shown'))
              .expandX()
              .newRow(dist: 8)
              .startGroup('details')
              .append(
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Detail section appears when input ≥ 3 chars'),
                ),
              )
              .expandX()
              .endGroup()
              .build(),
        ),
        const SizedBox(height: 16),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
final ctrl = AclBinaryVisibilityController();
// Toggle: ctrl.mode = AclGroupVisibilityMode.hidden;

AclBuilder()
    .setGroupVisibilityController('address', ctrl)
    .append(alwaysVisibleWidget)
    .newRow(dist: 8)
    .startGroup('address')
    .append(addressWidget).expandX()
    .endGroup()
    .build()

// Callback-based:
final inputCtrl = AclCallbackVisibilityController<String>(
  source: textEditingController,
  modeBuilder: (text) => text.length >= 3
      ? AclGroupVisibilityMode.visible
      : AclGroupVisibilityMode.hidden,
);
'''),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive Variants Demo
// ─────────────────────────────────────────────────────────────────────────────
