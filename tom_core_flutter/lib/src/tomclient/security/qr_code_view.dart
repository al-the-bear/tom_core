/// A QR code rendered as painted modules rather than as an image asset.
///
/// The framework needs exactly one QR code — the `otpauth://` URI an
/// authenticator app scans during TOTP enrolment — and needs it to sit inside a
/// themed panel like any other widget. A rendering package would bring its own
/// colours, its own sizing conventions and its own dependency surface for that
/// one use; the pure-Dart `qr` encoder plus thirty lines of [CustomPainter]
/// brings none of it, and the result inherits the ambient [Theme] the way the
/// rest of the panel does.
library;

import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

/// Renders [data] as a scannable QR code, [size] logical pixels square.
///
/// Sized by the caller rather than by intrinsic content: a QR code has no
/// natural size, only a natural *aspect*, and the enrolment panel is the party
/// that knows how much room it can spare.
///
/// **Never throws on its payload.** A [data] that cannot be shown — empty, or
/// past the capacity of the largest code — renders as an empty square of the
/// requested [size] instead. See [data] for why that is the contract.
///
/// Stateful only to hold the encoded code. Encoding is by far the expensive
/// part of this widget — milliseconds, a double-digit percentage of a frame
/// budget for a typical enrolment URI — and it depends on [data] alone, so it
/// happens when [data] changes rather than on every build. A parent that
/// rebuilds for its own reasons, which the enrolment panel does on every busy
/// flag and every controller notification, costs nothing here.
class TomQrCodeView extends StatefulWidget {
  /// Creates a QR view over [data].
  const TomQrCodeView({
    super.key,
    required this.data,
    this.size = 200,
    this.padding = 8,
    this.foreground,
    this.background,
    this.semanticsLabel,
  });

  /// The payload to encode — for TOTP enrolment, the `otpauth://` URI.
  ///
  /// Two values render as an empty square rather than as a code: the empty
  /// string, and anything past the capacity of the largest code at the
  /// correction level used here (2331 bytes). Neither is an error, because
  /// neither is this widget's to prevent — for TOTP the payload arrives from
  /// the server, and it grows with the issuer and account label a deployment
  /// configures, which nothing on the way here bounds. Throwing would trade a
  /// panel the user can still complete by typing the secret for a crashed
  /// screen they cannot.
  final String data;

  /// The edge length of the rendered code, in logical pixels.
  final double size;

  /// The quiet zone around the modules, in logical pixels.
  ///
  /// A QR code without a margin is materially harder for a camera to lock onto,
  /// so this is a scanning requirement rather than a styling preference —
  /// hence a default rather than something every caller must remember.
  final double padding;

  /// The module colour. Defaults to black, which is what scanners expect;
  /// overridable because a dark-themed panel may need to invert the pair.
  final Color? foreground;

  /// The quiet-zone and light-module colour. Defaults to white.
  final Color? background;

  /// What a screen reader announces in place of the code.
  ///
  /// Already-resolved text, not a resource key: this widget is a generic
  /// renderer with no opinion about where strings come from, and the caller —
  /// which does have one — resolves it (G-RES-5). Null renders no semantics
  /// node, which is right when the caller has described the code in adjacent
  /// text instead.
  final String? semanticsLabel;

  @override
  State<TomQrCodeView> createState() => _TomQrCodeViewState();
}

class _TomQrCodeViewState extends State<TomQrCodeView> {
  /// The encoded payload, or null when there is nothing to paint.
  ///
  /// Null carries both reasons there can be nothing to paint — an empty
  /// payload and one too large to encode — because they render identically and
  /// nothing downstream needs to tell them apart.
  QrImage? _code;

  @override
  void initState() {
    super.initState();
    _code = _encode(widget.data);
  }

  @override
  void didUpdateWidget(TomQrCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The payload is the only input the encoder sees; size, padding and the
    // two colours are applied at paint time. So a theme change or a resize
    // must not pay for a re-encode, and this deliberately does not check them.
    if (widget.data != oldWidget.data) _code = _encode(widget.data);
  }

  /// Encodes [data], or returns null if it cannot be shown as a code.
  static QrImage? _encode(String data) {
    // An empty payload would encode to a valid-but-meaningless code; showing
    // nothing is the honest rendering of "there is nothing to scan yet".
    if (data.isEmpty) return null;

    try {
      return QrImage(
        QrCode.fromData(
          data: data,
          // Medium correction: the standard authenticator level. Higher levels
          // buy damage tolerance a screen-displayed code has no use for, at the
          // cost of a denser grid that scans worse on small displays.
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
      );
    } on InputTooLongException {
      // A QR code has a hard capacity ceiling and [data] arrives from outside —
      // for TOTP enrolment, straight off the wire — so a payload that will not
      // fit is input this widget has to have an answer for, not a bug upstream
      // of it. An enrolment URI grows with the issuer and account label a
      // deployment configures, and nothing on the way here bounds their length.
      //
      // Caught rather than pre-checked because the encoder exposes no capacity
      // predicate; the alternative is to reimplement its block arithmetic here
      // and re-derive it on every upgrade. Caught *narrowly* — this one type,
      // which means exactly "too long" — so a genuine encoder fault still
      // surfaces as a crash instead of being hidden behind a blank square.
      //
      // Degrades to the same rendering as an empty payload because the
      // enrolment panel shows the base32 secret beside the code: the user keeps
      // a complete path through enrolment, which is not true of a thrown build.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    // Reserved rather than collapsed, so that whether the payload happened to
    // encode does not also move the layout around the code.
    if (code == null) return SizedBox.square(dimension: widget.size);

    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _QrPainter(
          data: widget.data,
          image: code,
          padding: widget.padding,
          foreground: widget.foreground ?? const Color(0xFF000000),
          background: widget.background ?? const Color(0xFFFFFFFF),
        ),
        // The payload is not readable text, so announce the widget's *purpose*
        // instead — a screen-reader user needs the base32 fallback string the
        // enrolment panel shows beside this, not a transcription of the code.
        child: widget.semanticsLabel == null
            ? null
            : Semantics(
                image: true,
                label: widget.semanticsLabel,
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

/// Paints a [QrImage]'s modules into the available square.
class _QrPainter extends CustomPainter {
  _QrPainter({
    required this.data,
    required this.image,
    required this.padding,
    required this.foreground,
    required this.background,
  });

  /// The payload [image] was encoded from.
  ///
  /// Held only so [shouldRepaint] has something meaningful to compare. [QrImage]
  /// declares no `operator ==`, so comparing two of them is an identity test and
  /// would report every distinct instance as a change — which, for a guard whose
  /// whole purpose is to notice that nothing changed, is the same as having no
  /// guard at all. The payload is what determines the modules (the correction
  /// level is fixed), so comparing it compares the rendering.
  final String data;

  final QrImage image;
  final double padding;
  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.shortestSide;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, edge, edge),
      Paint()..color = background,
    );

    final usable = edge - padding * 2;
    if (usable <= 0) return;

    final count = image.moduleCount;
    final module = usable / count;
    final paint = Paint()..color = foreground;

    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            padding + col * module,
            padding + row * module,
            // Overdraw by a hair so neighbouring dark modules meet cleanly
            // instead of leaving hairline seams that confuse a scanner at low
            // resolutions.
            module + 0.5,
            module + 0.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.data != data ||
      old.padding != padding ||
      old.foreground != foreground ||
      old.background != background;
}
