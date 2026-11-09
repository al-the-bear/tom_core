/// The audit application: sign in as an auditor, ask the audit trail a
/// question across its writers, save questions, and have them delivered.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'backend.dart';

/// The application.
class AuditApp extends StatefulWidget {
  /// What the application talks to.
  final AuditBackend backend;

  /// Creates the application over [backend].
  const AuditApp({super.key, required this.backend});

  @override
  State<AuditApp> createState() => _AuditAppState();
}

class _AuditAppState extends State<AuditApp> {
  String? _user;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Audit Reports',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: _user == null
        ? SignInScreen(
            backend: widget.backend,
            onSignedIn: (name) => setState(() => _user = name),
          )
        : HomeScreen(
            backend: widget.backend,
            user: _user!,
            onSignedOut: () async {
              await widget.backend.signOut();
              setState(() => _user = null);
            },
          ),
  );
}

/// The sign-in form.
class SignInScreen extends StatefulWidget {
  /// Where the credentials are checked.
  final AuditBackend backend;

  /// Called with the user's display name once signed in.
  final ValueChanged<String> onSignedIn;

  /// Creates the screen.
  const SignInScreen({
    super.key,
    required this.backend,
    required this.onSignedIn,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.onSignedIn(
        await widget.backend.signIn(_username.text.trim(), _password.text),
      );
    } on AuditSignInException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Audit Reports',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('username'),
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'User name'),
                ),
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _signIn(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('signInError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('signIn'),
                  onPressed: _busy ? null : _signIn,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The signed-in application: asking, and the saved questions.
class HomeScreen extends StatelessWidget {
  /// What the application talks to.
  final AuditBackend backend;

  /// The signed-in user's name.
  final String user;

  /// Signs out.
  final VoidCallback onSignedOut;

  /// Creates the screen.
  const HomeScreen({
    super.key,
    required this.backend,
    required this.user,
    required this.onSignedOut,
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Audit Reports'),
        actions: [
          Center(child: Text(user)),
          IconButton(
            key: const Key('signOut'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: onSignedOut,
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.search), text: 'Ask'),
            Tab(icon: Icon(Icons.bookmarks), text: 'Saved questions'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          AskScreen(backend: backend),
          QuestionsScreen(backend: backend),
        ],
      ),
    ),
  );
}

/// The windows the ask form offers, in hours (`null`: all time).
const Map<String, int?> askWindows = {
  'Last 24 hours': 24,
  'Last 7 days': 24 * 7,
  'Last 30 days': 24 * 30,
  'All time': null,
};

/// Asking the trail a question.
class AskScreen extends StatefulWidget {
  /// What the application talks to.
  final AuditBackend backend;

  /// Creates the screen.
  const AskScreen({super.key, required this.backend});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen>
    with AutomaticKeepAliveClientMixin {
  final _actor = TextEditingController();
  final _target = TextEditingController();
  String? _action;
  String? _outcome;
  String _window = 'Last 7 days';
  List<String> _writers = const [];
  Set<String> _chosenWriters = {};
  TomAuditReportResultDto? _result;
  String? _error;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.backend.writers().then((writers) {
      if (mounted) {
        setState(() {
          _writers = writers;
          _chosenWriters = writers.toSet();
        });
      }
    });
  }

  Map<String, Object?> get _filter => {
    if (_actor.text.trim().isNotEmpty) 'actor': _actor.text.trim(),
    if (_target.text.trim().isNotEmpty) 'target': _target.text.trim(),
    'action': ?_action,
    'outcome': ?_outcome,
    'lastHours': ?askWindows[_window],
    if (_writers.isNotEmpty && _chosenWriters.length != _writers.length)
      'writers': _chosenWriters.toList()..sort(),
  };

  Future<void> _ask() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.backend.query(_filter);
      setState(() => _result = result);
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final question = await showDialog<TomAuditQuestionDto>(
      context: context,
      builder: (context) => SaveQuestionDialog(filter: _filter),
    );
    if (question == null) return;
    try {
      await widget.backend.save(question);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved "${question.name}".')));
      }
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  key: const Key('actor'),
                  controller: _actor,
                  decoration: const InputDecoration(labelText: 'Actor'),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  key: const Key('target'),
                  controller: _target,
                  decoration: const InputDecoration(labelText: 'Target'),
                ),
              ),
              _choice('Action', _action, const [
                'create',
                'update',
                'delete',
                'read',
                'execute',
              ], (v) => setState(() => _action = v)),
              _choice('Outcome', _outcome, const [
                'succeeded',
                'failed',
                'denied',
              ], (v) => setState(() => _outcome = v)),
              DropdownButton<String>(
                key: const Key('window'),
                value: _window,
                items: [
                  for (final label in askWindows.keys)
                    DropdownMenuItem(value: label, child: Text(label)),
                ],
                onChanged: (v) => setState(() => _window = v!),
              ),
              for (final writer in _writers)
                FilterChip(
                  label: Text(writer),
                  selected: _chosenWriters.contains(writer),
                  onSelected: (on) => setState(
                    () => on
                        ? _chosenWriters.add(writer)
                        : _chosenWriters.remove(writer),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                key: const Key('ask'),
                onPressed: _busy ? null : _ask,
                icon: const Icon(Icons.search),
                label: const Text('Ask'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('saveQuestion'),
                onPressed: _save,
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Save as question'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _result == null
                ? const Center(child: Text('Ask a question to see records.'))
                : AuditResultView(result: _result!),
          ),
        ],
      ),
    );
  }

  Widget _choice(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) => DropdownButton<String?>(
    key: Key(label.toLowerCase()),
    value: value,
    hint: Text(label),
    items: [
      DropdownMenuItem<String?>(
        value: null,
        child: Text('Any ${label.toLowerCase()}'),
      ),
      for (final option in options)
        DropdownMenuItem<String?>(value: option, child: Text(option)),
    ],
    onChanged: onChanged,
  );
}

/// The records of an answer, newest first.
class AuditResultView extends StatelessWidget {
  /// The answer.
  final TomAuditReportResultDto result;

  /// Creates the view.
  const AuditResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final summary =
        '${result.entries.length} record(s) from '
        '${result.writers.join(', ')}'
        '${result.hasMore ? ' — more matched; narrow the question' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(summary, key: const Key('resultSummary')),
        const Divider(),
        Expanded(
          child: ListView.separated(
            itemCount: result.entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final entry = result.entries[i];
              final record = entry.record;
              final actor = (record['actor'] as Map?)?['username'] ?? '?';
              final outcome = '${record['outcome']}';
              return ListTile(
                dense: true,
                leading: Icon(switch (outcome) {
                  'succeeded' => Icons.check_circle_outline,
                  'denied' => Icons.block,
                  _ => Icons.error_outline,
                }),
                title: Text(
                  '$actor ${record['action']} ${record['target']}'
                  '${record['targetKey'] == null ? '' : ' ${record['targetKey']}'}',
                ),
                subtitle: Text(
                  '${record['timestamp']} · ${entry.writer} #${entry.index}'
                  '${record['detail'] == null ? '' : ' · ${record['detail']}'}',
                ),
                trailing: Text(outcome),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Names a question and, optionally, its delivery.
class SaveQuestionDialog extends StatefulWidget {
  /// The filter the question asks.
  final Map<String, Object?> filter;

  /// Creates the dialog.
  const SaveQuestionDialog({super.key, required this.filter});

  @override
  State<SaveQuestionDialog> createState() => _SaveQuestionDialogState();
}

/// The schedules the dialog offers (cron, UTC).
const Map<String, String> questionSchedules = {
  'Not scheduled': '',
  'Every day at 06:00 UTC': '0 6 * * *',
  'Mondays at 06:00 UTC': '0 6 * * 1',
  'First of the month at 06:00 UTC': '0 6 1 * *',
};

class _SaveQuestionDialogState extends State<SaveQuestionDialog> {
  final _name = TextEditingController();
  final _recipients = TextEditingController();
  String _schedule = 'Not scheduled';
  String _format = 'csv';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save as question'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('questionName'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            key: const Key('questionRecipients'),
            controller: _recipients,
            decoration: const InputDecoration(
              labelText: 'Deliver to (email addresses, comma-separated)',
            ),
          ),
          DropdownButton<String>(
            key: const Key('questionSchedule'),
            isExpanded: true,
            value: _schedule,
            items: [
              for (final label in questionSchedules.keys)
                DropdownMenuItem(value: label, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _schedule = v!),
          ),
          DropdownButton<String>(
            key: const Key('questionFormat'),
            isExpanded: true,
            value: _format,
            items: [
              for (final format in const ['csv', 'xlsx', 'pdf'])
                DropdownMenuItem(
                  value: format,
                  child: Text(format.toUpperCase()),
                ),
            ],
            onChanged: (v) => setState(() => _format = v!),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirmSave'),
        onPressed: () {
          if (_name.text.trim().isEmpty) return;
          final filter = {...widget.filter};
          Navigator.of(context).pop(
            TomAuditQuestionDto(
              name: _name.text.trim(),
              filter: filter.cast<String, dynamic>(),
              schedule: questionSchedules[_schedule]!,
              recipients: [
                for (final address in _recipients.text.split(','))
                  if (address.trim().isNotEmpty) address.trim(),
              ],
              format: _format,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

/// The saved questions: answer one, deliver one now, delete one.
class QuestionsScreen extends StatefulWidget {
  /// What the application talks to.
  final AuditBackend backend;

  /// Creates the screen.
  const QuestionsScreen({super.key, required this.backend});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List<TomAuditQuestionDto>? _questions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final questions = await widget.backend.questions();
      if (mounted) setState(() => _questions = questions);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _answer(TomAuditQuestionDto question) async {
    final result = await widget.backend.answer(question.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question.name),
        content: SizedBox(
          width: 640,
          height: 420,
          child: AuditResultView(result: result),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (questions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: questions.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No saved questions yet. Ask one and save it.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : ListView(
              children: [
                for (final question in questions)
                  ListTile(
                    key: Key('question-${question.id}'),
                    title: Text(question.name),
                    subtitle: Text(
                      [
                        if (question.schedule.isNotEmpty)
                          'schedule ${question.schedule}',
                        if (question.recipients.isNotEmpty)
                          'to ${question.recipients.join(', ')} '
                              'as ${question.format.toUpperCase()}',
                        if (question.nextDeliveryAt.isNotEmpty)
                          'next delivery ${question.nextDeliveryAt}',
                        if (question.lastDeliveredAt.isNotEmpty)
                          'last delivered ${question.lastDeliveredAt}',
                      ].join(' · '),
                    ),
                    onTap: () => _answer(question),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          key: Key('deliver-${question.id}'),
                          tooltip: 'Deliver now',
                          icon: const Icon(Icons.send),
                          onPressed: question.recipients.isEmpty
                              ? null
                              : () => _act(
                                  () => widget.backend.deliver(question.id),
                                  '"${question.name}" will be delivered '
                                  'at the next pass.',
                                ),
                        ),
                        IconButton(
                          key: Key('delete-${question.id}'),
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _act(
                            () => widget.backend.delete(question.id),
                            'Deleted "${question.name}".',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
