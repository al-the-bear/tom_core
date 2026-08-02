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
class TomQrCodeView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // An empty payload would encode to a valid-but-meaningless code; showing
    // nothing is the honest rendering of "there is nothing to scan yet".
    if (data.isEmpty) return SizedBox.square(dimension: size);

    final code = QrCode.fromData(
      data: data,
      // Medium correction: the standard authenticator level. Higher levels buy
      // damage tolerance a screen-displayed code has no use for, at the cost of
      // a denser grid that scans worse on small displays.
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _QrPainter(
          image: QrImage(code),
          padding: padding,
          foreground: foreground ?? const Color(0xFF000000),
          background: background ?? const Color(0xFFFFFFFF),
        ),
        // The payload is not readable text, so announce the widget's *purpose*
        // instead — a screen-reader user needs the base32 fallback string the
        // enrolment panel shows beside this, not a transcription of the code.
        child: semanticsLabel == null
            ? null
            : Semantics(
                image: true,
                label: semanticsLabel,
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

/// Paints a [QrImage]'s modules into the available square.
class _QrPainter extends CustomPainter {
  _QrPainter({
    required this.image,
    required this.padding,
    required this.foreground,
    required this.background,
  });

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
      old.image != image ||
      old.padding != padding ||
      old.foreground != foreground ||
      old.background != background;
}
