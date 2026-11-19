import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Sample {
  static const themeSurface = Color(0xFF102030);
  static const semanticSurface = Color(0xFF405060);
  static const layoutRadius = 37.0;
  static const clear = Color(0x00000000);
  static const ink = Color(0xFF000000);
}

const _plain = BaseColors(
  background: _Sample.ink,
  foreground: _Sample.ink,
  outline: _Sample.clear,
  shadow: _Sample.clear,
);

const _semanticColors = SemanticColorsData(
  primary: _plain,
  secondary: BaseColors(
    background: _Sample.semanticSurface,
    foreground: _Sample.ink,
    outline: _Sample.clear,
    shadow: _Sample.clear,
  ),
  brand: BrandColors(primary: _plain, secondary: _plain),
  state: StateColors(
    success: _plain,
    error: _plain,
    warning: _plain,
    disabled: _plain,
  ),
);

Widget _plainApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: const ColorScheme.dark(surface: _Sample.themeSurface),
    ),
    home: Center(child: child),
  );
}

Widget _kissApp(Widget child) {
  return Layout(
    data: const LayoutData(
      cornerRadii: LayoutCornerRadii(large: _Sample.layoutRadius),
    ),
    child: SemanticColors(data: _semanticColors, child: _plainApp(child)),
  );
}

PhysicalSurface _surfaceOf(WidgetTester tester) {
  return tester.widget<PhysicalSurface>(find.byType(PhysicalSurface));
}

void main() {
  const content = SizedBox.square(dimension: 40);
  final components = <String, Widget>{
    'PhysicalCard': const PhysicalCard(content: content),
    'PhysicalDisc': const PhysicalDisc(content: content),
    'PhysicalPill': const PhysicalPill(content: content),
    'PhysicalPanel': const PhysicalPanel(child: content),
    'PhysicalIconButton':
        PhysicalIconButton(icon: content, diameter: 40, onTap: () {}),
  };

  group('without Layout or SemanticColors', () {
    for (final MapEntry(key: name, value: component) in components.entries) {
      testWidgets('$name takes the surface colour of the theme', (
        tester,
      ) async {
        await tester.pumpWidget(_plainApp(component));

        expect(tester.takeException(), isNull);
        expect(_surfaceOf(tester).color, _Sample.themeSurface);
      });
    }

    testWidgets('PhysicalBottomPanel builds', (tester) async {
      await tester.pumpWidget(
        _plainApp(
          const PhysicalBottomPanel(
            backgroundColor: _Sample.themeSurface,
            child: content,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a card takes the large radius of the standard layout', (
      tester,
    ) async {
      await tester.pumpWidget(_plainApp(const PhysicalCard(content: content)));

      expect(
        _surfaceOf(tester).borderRadius,
        BorderRadius.circular(LayoutData.standard.cornerRadii.large),
      );
    });
  });

  group('under Layout and SemanticColors', () {
    for (final MapEntry(key: name, value: component) in components.entries) {
      testWidgets('$name takes the secondary background', (tester) async {
        await tester.pumpWidget(_kissApp(component));

        expect(_surfaceOf(tester).color, _Sample.semanticSurface);
      });
    }

    testWidgets('a card and a panel take the large radius of the layout', (
      tester,
    ) async {
      for (final component in [
        const PhysicalCard(content: content),
        const PhysicalPanel(child: content),
      ]) {
        await tester.pumpWidget(_kissApp(component));

        expect(
          _surfaceOf(tester).borderRadius,
          BorderRadius.circular(_Sample.layoutRadius),
        );
      }
    });

    testWidgets('a colour given to a component wins', (tester) async {
      await tester.pumpWidget(
        _kissApp(
          const PhysicalCard(
            backgroundColor: _Sample.themeSurface,
            content: content,
          ),
        ),
      );

      expect(_surfaceOf(tester).color, _Sample.themeSurface);
    });
  });
}
