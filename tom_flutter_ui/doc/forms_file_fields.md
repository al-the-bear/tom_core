# File Fields

The file components of the `forms/` module: choosing a file, moving its bytes
to and from a file store, and showing the user what is happening while that
runs.

A file field is the one field whose value does not live in the form. Every
other field holds what it shows; a file field holds a *reference* — a name, a
size, and once stored, the key the server generated. The bytes travel a
separate path, which is why this module is more than a widget.

## Table of Contents

- [The pieces](#the-pieces)
- [Wiring a picker, once](#wiring-a-picker-once)
- [The value: `FileRef`](#the-value-fileref)
- [Slots, not keys](#slots-not-keys)
- [Transfers: the controller](#transfers-the-controller)
- [The transfer UX](#the-transfer-ux)
- [Putting it together](#putting-it-together)
- [The wire contract](#the-wire-contract)
- [Testing without a server](#testing-without-a-server)

---

## The pieces

| Symbol | Where | Purpose |
| ------ | ----- | ------- |
| `FileRef` | `forms/files/file_ref.dart` | The field's value: name, size, media type, and one of *bytes* / *streamed source* / *storage key*. |
| `FilePicker` | `forms/files/file_ref.dart` | `Future<FileRef?> Function(BuildContext)` — a field's explicit picker. |
| `TomPickedFile` | `forms/files/tom_file_picker_registry.dart` | A structural description of what a platform picker returned. |
| `TomFilePickerRegistry` | same | Holds the application's one picker adaptor. |
| `TomFilePickers` | same | Ready-made `FilePicker` callbacks and the `TomPickedFile` → `FileRef` conversion. |
| `TomFileTransferController` | `forms/files/tom_file_transfer_controller.dart` | The upload/download state machine: phase, progress, cancel, retry. |
| `TomFileTransferIndicator` | `forms/files/tom_file_transfer_indicator.dart` | The progress / cancel / retry / error row. |
| `TomFormFileField` | `forms/fields/tom_form_file_field.dart` | The abstract field. |
| `TomFileTransferClient` | `tom_core_kernel` | The transport contract — `TomHttpFileTransferClient` and `TomMemoryFileTransferClient` implement it. |

The transport lives in **`tom_core_kernel`**, not here: the kernel owns
`http_connection`, and a widget package is the wrong place for an HTTP client.
`tom_flutter_ui` consumes the contract and adds the state and the chrome.

### The three presentations

All three differ in **paint only** — every constraint, picker, transfer and
download behaviour is inherited from `TomFormFileField` unchanged, so a form
can switch between them without rewiring anything.

| Presentation | Material | Cupertino | Shows |
| ------------ | -------- | --------- | ----- |
| link | `TomFormFileUpload` | `TomCupertinoFormFileUpload` | A "Choose file…" button and the file's name and size. |
| dropzone | `TomFormFileDropzone` | — | A tall drop-target surface that also opens the picker on tap. |
| thumbnail | `TomFormFileThumbnail` | `TomCupertinoFormFileThumbnail` | A square preview of the file's own content. |

`FormFieldFamily.fileUpload` and `FormFieldFamily.fileThumbnail` build the
right side of the first and third rows for the family in force.

**What the thumbnail can paint.** `tomFileIsRenderableImage` decides, from
three sources consulted in order of how much they actually know: the reported
media type, then the file's extension, then the field's `pickKind`. The order
is the point — `pickKind` states what the field *asked for*, not what the value
*is*, so it never overrules the other two. A file with no Flutter codec falls
back to the same file-kind icon the other presentations show, which is why a
non-image file stays authorable under this presentation.

**Where the bytes come from.** A just-picked file carries its own; a re-opened
form holds a stored reference that carries none, so the thumbnail reads them
once — straight through the `TomFileTransferClient`, not the controller. A
controller download publishes `running` and `succeeded`, and the status row
would then announce "Downloading…" and "Downloaded." for a preview nobody
asked for. A read that fails costs one request and leaves the icon in place.

## Wiring a picker, once

`tom_flutter_ui` deliberately does not depend on `file_picker` or
`image_picker`: they pull in platform channels, they conflict with each other,
and an application that has already chosen one should not have to ship two.

The split is between the *plumbing* and the *plugin*. `TomPickedFile` is
structural — it names no picker package — so an adaptor is a handful of field
copies, written once at start-up:

```dart
import 'package:file_picker/file_picker.dart' as fp;

TomFilePickerRegistry.register((request) async {
  final result = await fp.FilePicker.platform.pickFiles(
    allowedExtensions: request.allowedExtensions,
    type: request.allowedExtensions == null
        ? fp.FileType.any
        : fp.FileType.custom,
    withReadStream: true,
  );
  return result?.files
          .map((f) => TomPickedFile(
                name: f.name,
                sizeBytes: f.size,
                path: f.path,
                bytes: f.bytes,
                open: f.readStream == null ? null : () => f.readStream!,
              ))
          .toList() ??
      const [];
});
```

`image_picker` is the same shape — see the library documentation of
`tom_file_picker_registry.dart` for that variant.

From then on **every file field in the application works with no `picker`
argument**. A field that needs something else still passes its own `picker`
callback, which wins over the registry. A field with neither reports
`canPick == false` and disables its affordance, rather than offering a button
that throws.

The field's own constraints reach the adaptor through `TomFilePickRequest`
(`allowedExtensions`, `maxSizeBytes`, `kind`), so a picker can apply them in
its native dialog — a user who cannot select an `.exe` in the first place is
better served than one told afterwards that `.exe` is not allowed.

## The value: `FileRef`

```dart
class FileRef {
  final String name;
  final int sizeBytes;
  final String? mimeType;
  final Uint8List? bytes;        // small, already read
  final TomFileSource? source;   // re-openable stream (large files, retry)
  final String? storageKey;      // server-generated, once stored
}
```

Three content forms, and a reference may carry more than one:

- **bytes** — what a picker that read the file eagerly gives you.
- **source** — a `TomFileSource`, whose `open()` returns a *fresh*
  `Stream<List<int>>` every call. A Dart stream can be listened to once, and a
  retry needs the bytes again; a re-openable factory is what makes retry
  possible at all. `TomFilePickers.toFileRef` prefers this over `bytes`
  whenever the picker offers both, because keeping the bytes would defeat the
  streaming upload the source exists to enable.
- **storageKey** — set once the server has stored the file. `isStored` reports
  it; `FileRef.stored(metadata)` builds a reference for a file that exists only
  on the server, which is what a re-opened form has.

`toSource()` produces the `TomFileSource` an upload needs from whichever form
is present, and throws when there is nothing to send.

## Slots, not keys

A field addresses an application-owned **slot** — `invoices/4711/scan` — and
the server returns the key it generated. The client never names a key. A client
that could name its own key would turn the upload endpoint into an open write
surface, so the asymmetry is deliberate: slots are the application's
vocabulary, keys are the store's.

## Transfers: the controller

`TomFileTransferController` is a `ValueNotifier<TomFileTransferState>` over one
slot:

```dart
final controller = TomFileTransferController(
  client: transferClient,
  slot: 'invoices/4711/scan',
);

await controller.upload(pickedRef);
if (controller.value.phase == TomTransferPhase.failed) {
  await controller.retry();
}
```

| Member | Behaviour |
| ------ | --------- |
| `upload(FileRef)` | Streams the reference's source; returns the stored descriptor, or `null` when cancelled or failed. |
| `download()` | The whole file in memory — for previews and small documents. |
| `downloadTo(onChunk)` | The streaming form: nothing accumulates unless `onChunk` accumulates. |
| `describe()` | One `HEAD`; cheap enough to call when a form opens. Not a transfer, so the phase stays `idle`. |
| `remove()` | Deletes the stored file. |
| `cancel()` / `retry()` / `reset()` | Abort the transfer in flight; repeat the last attempt; drop the last result while keeping the descriptor. |

`TomFileTransferState` carries `phase` (`idle` / `running` / `succeeded` /
`cancelled` / `failed`), `kind`, `progress`, `error` and `metadata`.
`fraction` is `null` when progress cannot be known — which is exactly what a
progress indicator's `value` already means by "indeterminate", so no widget has
to translate. `errorKey` exposes the transfer layer's stable keys
(`file_transfer.not_found`, `.rejected`, `.cancelled`, …) so a UI can
distinguish failures without matching on message text.

Three of the four things this module has to offer — progress, cancel, retry —
are not expressible as a `Future`: progress arrives *during* it, cancel has to
reach into it, retry needs to know what the last attempt was. That is why there
is a controller and not just an awaited call.

A transfer often outlives the widget that started it (a user leaves the page
mid-upload), so the controller silently drops publications after `dispose()`.

## The transfer UX

`TomFileTransferIndicator` renders one controller: a progress bar with a
cancel button while running, an error line with retry after a failure, a
confirmation after success, and an optional download affordance. It renders
**nothing** while idle, so a field can include it unconditionally without
gaining a permanent empty row.

`tomTransferErrorMessage(state)` maps the transfer keys to user-facing wording
in one place, instead of every widget re-inventing it. The Cupertino file field
builds an equivalent row from Cupertino widgets — the behaviour is shared
through `TomFileFieldStateMixin`, only the chrome differs.

## Putting it together

```dart
final report = TomFormFileUpload(
  'invoice.scan',
  null,
  transferClient: transferClient,     // a TomFileTransferClient
  storageSlot: 'invoices/4711/scan',
  allowedExtensions: const ['pdf', 'png'],
  maxSizeBytes: 8 * 1024 * 1024,
  onDownload: (ref, bytes) => showPreview(ref.name, bytes),
);
```

What the field then does:

1. Opens the registered picker with this field's constraints.
2. Rejects a file the constraints exclude — a snackbar on Material, a dialog on
   Cupertino — before it ever becomes the value. The same constraints are also
   auto-prepended as `Validator<FileRef?>`s, so a programmatic `setValue` is
   caught by the normal validation pipeline.
3. Uploads it (unless `autoUpload: false`), showing progress and offering
   cancel and retry.
4. Replaces the value with one carrying the server's key — which is what makes
   the upload visible to the rest of the form, because a value with a key is a
   value the form can save.
5. On a later open, describes the slot and offers download without transferring
   anything.
6. On clear, deletes the stored file: leaving an orphan blob behind every time
   a user changes their mind is how a store fills up.

`onDownload` gets the bytes and nothing more — what a downloaded file *is* (a
preview, a share sheet, a save dialog) is the application's decision.

## The wire contract

`TomHttpFileTransferClient` speaks a small contract over `<baseUri>/<slot>`:

| Method | Meaning | Response |
| ------ | ------- | -------- |
| `POST` | Upload; the body is the file's bytes, streamed. | JSON descriptor (`key`, `mediaType`, `byteCount`, `fileName?`, `storedAt?`). |
| `GET` | Download; the body is the bytes, streamed. | `404` when the slot is empty. |
| `HEAD` | Describe. | `x-tom-file` JSON header, or `x-tom-file-key` + `content-length`. |
| `DELETE` | Remove. | `404` when there was nothing to remove. |

A server implementing it builds its response headers with
`tomFileDescriptorHeaders(metadata)` — shipped alongside the reader so the two
halves of the contract cannot drift. A bearer token is attached from
`TomBearerAuthentication` when one is present, and omitted entirely when nobody
is logged in.

## Testing without a server

`TomMemoryFileTransferClient` implements the same contract in memory, with a
configurable chunk size so a test can observe several progress events. Every
scenario in this module's tests and its example runs against it — see
[`example/forms/file_fields_example.dart`](../example/forms/file_fields_example.dart),
exercised by `flutter test`.

`TomFilePickers.fixed(ref)` is the matching picker for a test, a demo or a
widget preview: it always returns the same reference and never touches a
platform channel.
