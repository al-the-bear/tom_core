/// What a running job body may ask of the run it executes: the checkpoint it
/// starts from, and a way to record a new one.
///
/// ## Checkpoints
///
/// A long body — an import of a million rows, a sweep over every tenant — that
/// dies halfway would otherwise start again from the first row when its run is
/// retried or recovered. A checkpoint is the body's own note of how far it got:
/// an opaque JSON map it saves whenever it chooses, stored with the run, and
/// handed back to the next attempt.
///
/// ```dart
/// class ImportOrders extends TomJobBase {
///   @override
///   Future<Object?> execute() async {
///     final context = TomJobRunContext.require();
///     var offset = context.checkpoint?['offset'] as int? ?? 0;
///     while (true) {
///       final batch = await source.read(offset, 500);
///       if (batch.isEmpty) return null;
///       await target.write(batch);
///       offset += batch.length;
///       await context.saveCheckpoint({'offset': offset});
///     }
///   }
/// }
/// ```
///
/// What the map means, and how a body continues from it, is the job's
/// business; the framework stores it and hands it back. A body that never
/// saves one restarts from the beginning, every time.
///
/// A recovered run is only offered again when its job sets
/// `requestsRecovery` — a checkpoint does not change that rule. Work done after
/// the last checkpoint and before the node died may have happened, so the body
/// still has to tolerate repeating that stretch; what the checkpoint saves is
/// repeating everything before it.
///
/// ## Where it works
///
/// The scheduler runs every body inside a context, whichever dispatcher runs
/// it. Across an isolate hop — the worker pool — the context reaches the
/// scheduler's isolate through a port, so [saveCheckpoint] completes only once
/// the scheduler has stored the checkpoint, and reports whether it could.
library;

import 'dart:async';
import 'dart:isolate';

import '../isolate_pooling/tom_worker.dart';
import 'schedule.dart';

/// The run a job body is executing, as the body sees it.
class TomJobRunContext {
  TomJobRunContext._(this.runId, this.jobName, this._checkpoint, this._saves);

  static const Symbol _zoneKey = #tomJobRunContext;

  /// The context of the run the calling code executes, or `null` outside a
  /// job body.
  static TomJobRunContext? get current =>
      Zone.current[_zoneKey] as TomJobRunContext?;

  /// The context of the run the calling code executes.
  ///
  /// Throws a `schedule.run_context.missing` [TomScheduleException] outside a
  /// job body — code that saves a checkpoint and is not running as a job is a
  /// mistake worth hearing about, not a save worth dropping.
  static TomJobRunContext require() {
    final context = current;
    if (context != null) return context;
    throw TomScheduleException(
      'schedule.run_context.missing',
      'There is no job run here: TomJobRunContext is only available inside '
          'a job body the scheduler executes.',
    );
  }

  /// The id of the run.
  final String runId;

  /// The job the run belongs to.
  final String jobName;

  Map<String, Object?>? _checkpoint;

  final SendPort _saves;

  /// The checkpoint the run holds: the one it was handed at the start of this
  /// attempt, or the last one this attempt saved; `null` when there is none.
  Map<String, Object?>? get checkpoint => _checkpoint;

  /// Stores [checkpoint] as the run's progress, replacing the previous one;
  /// `null` clears it.
  ///
  /// Completes once it is stored, with `true`; with `false` when it was not,
  /// because the run is no longer this attempt's — its lease was lost or its
  /// attempt timed out, and a peer or a later attempt continues from the
  /// checkpoint it was handed. A body that sees `false` should stop: whatever
  /// it does next is not the run's progress.
  ///
  /// Throws a `schedule.job.checkpoint` [TomScheduleException] when
  /// [checkpoint] is not JSON-encodable, and a
  /// `schedule.job.checkpoint_failed` one when the store could not write it.
  Future<bool> saveCheckpoint(Map<String, Object?>? checkpoint) async {
    final reply = ReceivePort();
    try {
      _saves.send((checkpoint, reply.sendPort));
      final answer = await reply.first;
      if (answer is bool) {
        if (answer) _checkpoint = checkpoint;
        return answer;
      }
      final (key, message) = answer as (String, String);
      throw TomScheduleException(
        key,
        message,
        parameters: {'job': jobName, 'run': runId},
      );
    } finally {
      reply.close();
    }
  }
}

/// Runs [inner] inside a [TomJobRunContext] for one attempt of a run.
///
/// Built by the scheduler around every body it dispatches; a command, so it
/// crosses an isolate hop with the body it wraps. [saves] is the scheduler's
/// port for checkpoints: each message is a `(checkpoint, replyPort)` record,
/// answered with `true`/`false` for stored/not stored, or with a
/// `(key, message)` record when storing failed.
class TomJobRunCommand extends TomCommand {
  /// Wraps [inner] for the run [runId] of [jobName], starting from
  /// [checkpoint].
  TomJobRunCommand({
    required this.inner,
    required this.runId,
    required this.jobName,
    required this.checkpoint,
    required this.saves,
  });

  /// The body.
  final TomCommand inner;

  /// The run.
  final String runId;

  /// The run's job.
  final String jobName;

  /// The checkpoint the attempt starts from.
  final Map<String, Object?>? checkpoint;

  /// Where checkpoints are sent to be stored.
  final SendPort saves;

  @override
  Future<Object?> execute() => runZoned(
    inner.execute,
    zoneValues: {
      TomJobRunContext._zoneKey: TomJobRunContext._(
        runId,
        jobName,
        checkpoint,
        saves,
      ),
    },
  );
}
