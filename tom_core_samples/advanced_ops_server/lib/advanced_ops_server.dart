/// Back-office server for the advanced Tom Core full-stack sample.
///
/// No endpoints and no database of its own: four scheduled jobs and one
/// timer-driven publisher, all over the app server's existing `app_db` and the
/// auth server's `auth_db`, under a deliberately narrow deployment principal.
///
/// It exists because scheduling, audit, messaging and export each have a good
/// module example, and nothing showed them *combined*. Four seams that were
/// documented in prose are demonstrated here:
///
///  * a machine-initiated delete is audited exactly like a human one, because
///    it goes through the same repository (`jobs/retention_service.dart`);
///  * a job that produces mail names a template rather than a subject, and
///    hands the result to a queue rather than a transport — so the text is
///    translatable and composition and delivery retry on separate budgets
///    (`jobs/digest_service.dart`, `ops_texts.dart`);
///  * a rendered export lands in the same blob store the application's
///    attachments live in (`jobs/report_service.dart`);
///  * the one maintenance operation a backend admits it needs gets the
///    scheduled caller it was missing — `purgeOrphanedChunks` collects the
///    chunk rows a failed cleanup leaves, and a sweep nobody runs is a slow
///    leak with a documented name (`jobs/blob_sweep_service.dart`); and
///  * the audit anchor publisher is pointedly **not** a scheduled job, because
///    the chain is per writer and the scheduler's single-fire guarantee would
///    anchor one node's head and leave the rest unattested (`ops_anchoring.dart`).
///
/// And one that is not a seam but a grade: every job runs as
/// [opsServiceAccount] under [opsDeploymentPrincipal], so
/// `TomAccessControl`'s `min(user, server)` meet is observable — the account
/// holds `app.item.reassign`, the deployment does not, and the refusal is a
/// test rather than a comment (`ops_identity.dart`).
///
/// And one that is neither: because this is the one process holding both
/// servers' repositories, it is where the sample's personal data is registered
/// with `TomPrivacy`, so a user's erasure and subject-access export reach both
/// databases (`ops_privacy.dart`).
///
/// See `README_advanced_14_operations.md` for the narrative.
library;

export 'src/jobs/blob_sweep_service.dart';
export 'src/jobs/digest_service.dart';
export 'src/jobs/ops_jobs.dart';
export 'src/jobs/report_service.dart';
export 'src/jobs/retention_service.dart';
export 'src/ops_anchoring.dart';
export 'src/ops_identity.dart';
export 'src/ops_privacy.dart';
export 'src/ops_runtime.dart';
export 'src/ops_texts.dart';
