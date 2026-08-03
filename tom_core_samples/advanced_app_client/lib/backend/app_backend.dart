/// The backend contract the end-user app talks to, independent of transport
/// (step 26).
///
/// Every screen (steps 27–31) is written against this seam, not a concrete
/// backend, so the same widgets drive either the seeded [InMemoryAppBackend]
/// (the offline teaching default — and what the widget tests bind, never
/// touching a socket) or the [LiveAppBackend], which delegates to
/// `advanced_client_core` over HTTP. Keeping the seam here is what makes the
/// widget tests deterministic.
///
/// The seam speaks the shared **wire contracts** ([LoginRequest]/[LoginResult]/
/// [ShareRequest]) and the reflected **domain entities** ([Workspace]/[Project]/
/// [TodoList]/[TodoItem]/[TodoComment]) — exactly the currency the live client
/// core exchanges — plus one authorization convenience, [resourceRoles], which
/// exposes the principal's `resourceKey → roleName` grants so the app can install
/// the framework's [TomResourceRoleAdapter] and resolve field states through the
/// registry.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Raised when a backend call fails — rejected credentials, an unknown resource,
/// or a denied write.
///
/// A single typed failure the screens catch and surface: the in-memory backend
/// throws it directly, and [LiveAppBackend] wraps the client core's transport
/// exceptions (`AuthClientException`/`AppApiException`/`TomAuthExpiredException`)
/// in it. It carries a human [message] to show the user and, when the underlying
/// failure had one, the server's stable error [key] so a caller can branch
/// without parsing the message.
class AppBackendException implements Exception {
  /// What went wrong, fit to show the user.
  final String message;

  /// The server's stable error key when one was available (e.g.
  /// `auth.login.failed`, `app.access.forbidden`), else null.
  final String? key;

  /// Whether a refused [AppBackend.submitSecondFactor] may simply be tried
  /// again with a new code.
  ///
  /// Carries `AuthClientException.canRetrySecondFactor` across the seam. It is
  /// the *only* signal that distinguishes "wrong code, try again" from "the
  /// challenge is spent, start over", and the two demand different screens — so
  /// it travels as a field rather than being re-derived from [key], which would
  /// scatter the mapping across every caller.
  final bool canRetrySecondFactor;

  /// Creates the exception with a human [message] and an optional stable [key].
  const AppBackendException(
    this.message, {
    this.key,
    this.canRetrySecondFactor = false,
  });

  @override
  String toString() =>
      'AppBackendException: $message${key == null ? '' : ' ($key)'}';
}

/// The end-user todo backend the app reads and edits against.
///
/// Reads are filtered to what the logged-in principal owns or is shared into;
/// writes are re-checked field-by-field against the principal's four-state
/// grade. The live implementation enforces this server-side; the in-memory fake
/// mirrors the same model so the client behaves identically either way.
abstract class AppBackend {
  /// Authenticates [request], stores the session, and returns the resolved
  /// principal + token pair. Throws [AppBackendException] when rejected.
  ///
  /// A [LoginResult] with `requires2FA` set is **not** a session: the stored
  /// token is an interim challenge carrier that authorizes nothing, and the
  /// caller must complete the login with [submitSecondFactor] before any other
  /// method will succeed.
  Future<LoginResult> login(LoginRequest request);

  /// Completes a two-pass login by submitting the one-time [code], returning
  /// exactly the pair a 2FA-free [login] would have produced.
  ///
  /// Throws [AppBackendException] when the code is refused; its
  /// [AppBackendException.canRetrySecondFactor] says whether the challenge
  /// survived (submit another code) or is spent (start over from the password
  /// screen). On a retryable refusal the re-issued challenge has *already* been
  /// stored, so [pendingChallenge] reports the decremented attempt count.
  Future<LoginResult> submitSecondFactor(String code);

  /// The challenge a [login] left pending, or null when none is outstanding.
  ///
  /// Its `type`, `attemptsRemaining`, `expiresAt` and `clientData['digits']`
  /// are what the code screen renders from — the field width included, so a
  /// mechanism with a different digit count needs no client change.
  Tom2FAChallenge? get pendingChallenge;

  /// The second factor a [login] offered to set up, or null when none is owed.
  ///
  /// The other half of the two-pass login: a principal who owes a factor but
  /// holds none is offered enrolment instead of a challenge, and this is the
  /// offer — the mechanisms available, whether declining is permitted, and (once
  /// [beginEnrolment] has picked one) the mechanism's own `clientData`. Like
  /// [pendingChallenge] it is *not* a session.
  Tom2FAPendingEnrolment? get pendingEnrolment;

  /// Begins enrolment in the mechanism [type], returning the interim result
  /// whose [pendingEnrolment] now carries that mechanism's set-up payload (for
  /// TOTP the secret and the `otpauth://` URI).
  ///
  /// Only a mechanism the offer named is accepted — the authority for what may
  /// be enrolled is the server's list, never the key the client sends back.
  Future<LoginResult> beginEnrolment(String type);

  /// Confirms the half-built factor with the [code] the user read off their
  /// authenticator, completing the login exactly as [submitSecondFactor] does.
  ///
  /// Throws [AppBackendException] when the code is refused;
  /// [AppBackendException.canRetrySecondFactor] distinguishes "wrong code, try
  /// again" from "the offer is burned, start over".
  Future<LoginResult> confirmEnrolment(String code);

  /// Declines the offer and completes the login without a factor.
  ///
  /// Reachable only when the offer was [Tom2FAPendingEnrolment.skippable] — the
  /// server decides that, and a client that asks anyway is refused.
  Future<LoginResult> skipEnrolment();

  /// Ends the session and discards the stored token pair — including a
  /// half-finished two-factor login.
  Future<void> logout();

  /// Fetches the public login resource bundle (screen texts) the app installs
  /// before the sign-in screen builds. Reachable unauthenticated.
  Future<ResourceBundleDto> loginResources();

  /// Fetches the authenticated full resource bundle (every screen's texts) the
  /// app installs right after sign-in, so the board, item form, and sharing
  /// chrome render server-delivered strings. Requires a session.
  Future<ResourceBundleDto> resources();

  /// Workspaces the current principal owns or is shared into.
  Future<List<Workspace>> listWorkspaces();

  /// Visible projects in [workspaceId].
  Future<List<Project>> listProjects(String workspaceId);

  /// Lists in the visible project [projectId].
  Future<List<TodoList>> listLists(String projectId);

  /// Items in the visible list [listId]; the principal's per-resource role
  /// (from [resourceRoles]) drives each item's field grades.
  Future<List<TodoItem>> listItems(String listId);

  /// The attachment descriptors of the visible items in [listId], one entry per
  /// item that actually has a file.
  ///
  /// This is the board's paperclip source: one call per list, and it moves no
  /// bytes — each entry is exactly what a `HEAD` on the item's file slot
  /// returns, so the card can show presence, media type and size before anyone
  /// asks for the content. An item whose slot is empty is simply absent.
  Future<List<FileDescriptorDto>> listAttachments(String listId);

  /// The byte half of the backend: uploads, downloads, `HEAD`s and deletes
  /// against the server's file endpoint.
  ///
  /// Deliberately *not* routed through [saveItem]. An attachment is a stream,
  /// and a payload worth storing is a payload not worth holding in memory as a
  /// field of an entity; the server also keeps the file column out of the
  /// writable bindings so a client cannot mint a storage key by editing an
  /// item. So the item's metadata travels on [saveItem] and its bytes travel
  /// here, addressed by [AppFileSlots.itemAttachment].
  ///
  /// Both implementations expose the *same* [TomFileTransferClient] surface, so
  /// the screens' file field runs its real code path either way — offline
  /// against a memory store, live against the authenticated HTTP client that
  /// shares the JSON half's bearer and refresher.
  TomFileTransferClient get files;

  /// Creates ([TodoItem.id] empty) or updates an item, returning the persisted
  /// entity (with its assigned id). A write to a field the principal's grade is
  /// not `full` on is rejected server-side with an [AppBackendException].
  Future<TodoItem> saveItem(TodoItem item);

  /// Removes the item with [id] (owner/editor only).
  Future<void> deleteItem(String id);

  /// Adds [comment] to the item [itemId] (commenter and above), returning the
  /// persisted comment.
  Future<TodoComment> addComment(String itemId, TodoComment comment);

  /// The comment thread on the item [itemId], oldest first.
  ///
  /// Gated by the *item's* readability, not by [ProjectRole.commenter]: a
  /// viewer sees the history they may not add to. The order is the server's and
  /// is preserved end-to-end — the detail screen renders the list as given.
  Future<List<TodoComment>> listComments(String itemId);

  /// The subtask checklist of the item [itemId], in `position` order.
  Future<List<Subtask>> listSubtasks(String itemId);

  /// Adds [subtask] to the item [itemId] (editor and above), returning the
  /// persisted subtask with its assigned id.
  ///
  /// One role stronger than [addComment] on purpose: a comment is *about* an
  /// item, a subtask is *part of* it, so adding one edits what the item claims
  /// to require.
  ///
  /// `id`, `itemId` and `position` are server-owned: the step always appends,
  /// one past the highest already stored, so a caller's `position` is ignored.
  /// Only `title` and `done` are read off the payload.
  Future<Subtask> addSubtask(String itemId, Subtask subtask);

  /// Updates [subtask] (editor and above on its parent item) — the screen uses
  /// it to toggle `done`. The parent link is server-owned and cannot be moved.
  Future<Subtask> updateSubtask(Subtask subtask);

  /// The current principal's per-resource role grants, as a
  /// `resourceKey → roleName` map (`<type>:<id>` keys — e.g. `item:1` →
  /// `'editor'`). The app installs it as a [TomResourceRoleAdapter] at login, so
  /// the item screen resolves each field's state through the framework registry.
  /// A resource the principal has no role on is simply absent (the adapter
  /// resolves it closed-safe to [TomAuthState.none]). The live backend fetches
  /// this from the app server's authenticated `/resource-roles` endpoint (the
  /// token is an opaque bearer client-side); the seeded in-memory backend
  /// computes it from its own rows. Keys carry each backend's own id space —
  /// `app_db` surrogate ids on the live wire, the demo's business ids in memory
  /// — matching the ids that backend's entities expose.
  Future<Map<String, String>> resourceRoles();

  /// Shares the named resource with another user at a [ProjectRole].
  Future<void> share(ShareRequest request);
}
