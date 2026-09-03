import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'company_state.dart' show Person;

// ---------------------------------------------------------------------------
// ProjectBrief — complex state tree used by Demos G and H
// ---------------------------------------------------------------------------

/// Heterogeneous state tree with strings, dropdown-backed strings, booleans,
/// observable lists, long-form text, and two nested [Person] subforms.
/// Exercised by Demo G (responsive layout + styling + theming) and Demo H
/// (the same form, plus per-field authorization). Rich enough that every
/// ACL breakpoint API can be targeted at a distinct row/field.
@tomReflector
class ProjectBrief extends TomClass {
  // --- Identity ------------------------------------------------------------
  late final code = TomString('');
  late final title = TomString('');
  late final summary = TomString('');

  // --- Classification (dropdown-backed) -----------------------------------
  late final category = TomString('engineering');
  late final priority = TomString('medium');
  late final status = TomString('draft');
  late final phase = TomString('plan');

  // --- Scope --------------------------------------------------------------
  late final budget = TomString('');
  late final hoursEstimate = TomString('');
  late final deadline = TomString('');
  late final location = TomString('');

  // --- Classic-field targets ---------------------------------------------
  // These back `TomFormStringInputClassic` / `TomFormEmailStringInputClassic`
  // in the ProjectBriefForm so the Classic ↔ new-spec coexistence is
  // covered inside the same complex form.
  late final internalRef = TomString('');
  late final contactEmail = TomString('');

  // --- Booleans (Phase 2 stand-ins) --------------------------------------
  late final isPublic = TomBool(false);
  late final needsReview = TomBool(true);
  late final notifySubscribers = TomBool(false);

  // --- Observable lists --------------------------------------------------
  late final tags = TomList<TomString>();
  late final watchers = TomList<TomString>();

  // --- Long-form ---------------------------------------------------------
  late final description = TomString('');
  late final riskNotes = TomString('');

  // --- Nested Person subforms -------------------------------------------
  late final lead = Person();
  late final reviewer = Person();
}

// ---------------------------------------------------------------------------
// Pre-populated singleton so Demos G/H show real data on first open.
// ---------------------------------------------------------------------------

ProjectBrief phase2ProjectBriefState = _buildProjectBrief();

ProjectBrief _buildProjectBrief() {
  final s = ProjectBrief();
  s.code | 'PROJ-0142';
  s.title | 'Responsive dashboard refresh';
  s.summary | 'Rebuild the ops dashboard to cover the new SLA metrics.';
  s.category | 'engineering';
  s.priority | 'high';
  s.status | 'active';
  s.phase | 'build';
  s.budget | '80000';
  s.hoursEstimate | '480';
  s.deadline | '2026-09-30';
  s.location | 'Remote — EMEA';
  s.internalRef | 'dash-2026-q3';
  s.contactEmail | 'dashboard@example.com';
  s.isPublic | false;
  s.needsReview | true;
  s.notifySubscribers | true;
  s.tags.add(TomString('dashboard'));
  s.tags.add(TomString('metrics'));
  s.tags.add(TomString('sla'));
  s.watchers.add(TomString('anna'));
  s.watchers.add(TomString('bruno'));
  s.description |
      'Introduce SLA-compliance trend charts and incident-to-'
          'resolution timelines; retire the legacy per-service cards.';
  s.riskNotes | 'Risk of dependency on the (still-draft) metrics API v2.';
  s.lead.firstName | 'Alex';
  s.lead.lastName | 'Rivera';
  s.lead.email | 'alex.rivera@example.com';
  s.lead.phone | '+1 555 0111';
  s.lead.title | 'Lead Engineer';
  s.reviewer.firstName | 'Morgan';
  s.reviewer.lastName | 'Chen';
  s.reviewer.email | 'morgan.chen@example.com';
  s.reviewer.phone | '+1 555 0133';
  s.reviewer.title | 'Principal Reviewer';
  return s;
}
