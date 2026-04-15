import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style_scope.dart';

class _Probe extends StatelessWidget {
  final void Function(BuildContext) onBuild;
  const _Probe({required this.onBuild});

  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return const SizedBox.shrink();
  }
}

void main() {
  group('TomFormStyleScope', () {
    testWidgets('of() returns material3 when no scope', (tester) async {
      TomFormStyle? captured;
      await tester.pumpWidget(MaterialApp(
        home: _Probe(
          onBuild: (ctx) => captured = TomFormStyleScope.of(ctx),
        ),
      ));
      expect(captured, TomFormStyle.material3);
    });

    testWidgets('of() returns the scope style', (tester) async {
      final style = TomFormStyle.material3.copyWith(
        stringInputStyle: const TomStringInputStyle(),
      );
      TomFormStyle? captured;
      await tester.pumpWidget(MaterialApp(
        home: TomFormStyleScope(
          style: style,
          child: _Probe(
            onBuild: (ctx) => captured = TomFormStyleScope.of(ctx),
          ),
        ),
      ));
      expect(captured, same(style));
    });

    testWidgets('widthOf publishes LayoutBuilder maxWidth', (tester) async {
      double? captured;
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 333,
            height: 100,
            child: TomFormStyleScope(
              style: TomFormStyle.material3,
              child: _Probe(
                onBuild: (ctx) => captured = TomFormStyleScope.widthOf(ctx),
              ),
            ),
          ),
        ),
      ));
      expect(captured, 333);
    });

    testWidgets('widthOf falls back to MediaQuery when no scope',
        (tester) async {
      double? captured;
      await tester.pumpWidget(MaterialApp(
        home: _Probe(
          onBuild: (ctx) => captured = TomFormStyleScope.widthOf(ctx),
        ),
      ));
      // Default test window logical size is 800x600.
      expect(captured, isNotNull);
      expect(captured! > 0, isTrue);
    });

    testWidgets('nested scope overrides outer scope', (tester) async {
      final outer = TomFormStyle.material3;
      final inner = TomFormStyle.material3.copyWith(
        checkboxStyle: const TomCheckboxStyle(),
      );
      TomFormStyle? captured;
      await tester.pumpWidget(MaterialApp(
        home: TomFormStyleScope(
          style: outer,
          child: TomFormStyleScope(
            style: inner,
            child: _Probe(
              onBuild: (ctx) => captured = TomFormStyleScope.of(ctx),
            ),
          ),
        ),
      ));
      expect(captured, same(inner));
    });
  });
}
