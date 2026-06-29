/// The item-detail screen the board opens when a card is tapped (step 29
/// scaffold).
///
/// Step 29 ships this as a minimal navigation target so the board's "tap an
/// item → open its detail" path is real and testable. Step 30 rewrites the body
/// into the bound `TomForm<TodoItem>` whose per-field controls are driven by the
/// session's four-state grade matrix (`TomAuthorizer.fixed(state)`), plus
/// comments and subtasks; the [session] is already threaded through for that.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:flutter/material.dart';

import '../app/app_session.dart';

/// Shows a single [TodoItem]; the real bound editor lands in step 30.
class ItemDetailScreen extends StatelessWidget {
  /// Creates the detail screen for [item] over [session].
  const ItemDetailScreen({super.key, required this.session, required this.item});

  /// The signed-in session (carries the field-grade matrix step 30 binds).
  final AppSession session;

  /// The item whose detail is shown.
  final TodoItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('item-detail-screen'),
      appBar: AppBar(title: Text(item.title.get())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title.get(),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Status: ${item.statusValue.label}'),
            if (item.description.get().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(item.description.get()),
            ],
          ],
        ),
      ),
    );
  }
}
