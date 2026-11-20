import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const texture = PhysicalTexture.oak;
  static const color = Color(0xFF3B393E);
  static const barColor = Color(0xFFD71921);
  static const diameter = 48.0;
}

Future<void> _pump(WidgetTester tester, Widget control) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: control))),
  );
}

List<PhysicalTexture> _texturesIn(WidgetTester tester) {
  return [
    for (final surface
        in tester.widgetList<PhysicalSurface>(find.byType(PhysicalSurface)))
      surface.material.texture,
  ];
}

/// Matches a texture of the fixture's substance tinted to the fixture's
/// colour.
final Matcher _isTinted = isA<PhysicalTexture>()
    .having((made) => made.substance, 'substance', _Fixture.texture.substance)
    .having((made) => made.naturalColor, 'naturalColor', _Fixture.color);

void main() {
  test('a material tints what it is made of and leaves a plain one alone', () {
    final oak = PhysicalMaterial.satin.withTexture(_Fixture.texture);

    expect(oak.tintedTo(_Fixture.color).texture, _isTinted);
    expect(
      PhysicalMaterial.satin.tintedTo(_Fixture.color),
      PhysicalMaterial.satin,
    );
  });

  testWidgets('a panel is made of its texture in its own colour', (
    tester,
  ) async {
    await _pump(
      tester,
      const PhysicalPanel(
        color: _Fixture.color,
        texture: _Fixture.texture,
        child: SizedBox.square(),
      ),
    );

    expect(_texturesIn(tester), [_isTinted]);
  });

  testWidgets('a card keeps its colour whatever it is made of', (tester) async {
    await _pump(
      tester,
      PhysicalCard(
        color: _Fixture.color,
        material: PhysicalMaterial.satin.withTexture(_Fixture.texture),
        child: const SizedBox.square(),
      ),
    );

    expect(_texturesIn(tester), [_isTinted]);
  });

  testWidgets('buttons keep their colour whatever they are made of', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          PhysicalPillButton(
            color: _Fixture.color,
            foregroundColor: _Fixture.barColor,
            material: PhysicalMaterial.gloss.withTexture(_Fixture.texture),
            onPressed: () {},
            child: const SizedBox.square(),
          ),
          PhysicalIconButton(
            diameter: _Fixture.diameter,
            color: _Fixture.color,
            material: PhysicalMaterial.bead.withTexture(_Fixture.texture),
            onPressed: () {},
            icon: const SizedBox.square(),
          ),
        ],
      ),
    );

    expect(_texturesIn(tester), [_isTinted, _isTinted]);
  });

  testWidgets('each part of a slider takes a material of its own', (
    tester,
  ) async {
    await _pump(
      tester,
      PhysicalSlider(
        value: 0.5,
        onChanged: (_) {},
        barColor: _Fixture.barColor,
        trackColor: _Fixture.color,
        thumbColor: _Fixture.color,
        trackMaterial: PhysicalMaterial.well.withTexture(_Fixture.texture),
        thumbMaterial: PhysicalMaterial.bead.withTexture(_Fixture.texture),
      ),
    );

    expect(_texturesIn(tester), [_isTinted, PhysicalTexture.none, _isTinted]);
  });

  testWidgets('a slider is a progress bar with a bead on it', (tester) async {
    await _pump(
      tester,
      PhysicalSlider(
        value: 0.5,
        onChanged: (_) {},
        barColor: _Fixture.barColor,
        trackColor: _Fixture.color,
        thumbColor: _Fixture.color,
      ),
    );

    final bar = tester.widget<PhysicalProgressBar>(
      find.byType(PhysicalProgressBar),
    );
    expect(bar.fillDuration, Duration.zero);
    expect(bar.barColor, _Fixture.barColor);
  });

  testWidgets('a progress bar and its track take materials of their own', (
    tester,
  ) async {
    await _pump(
      tester,
      PhysicalProgressBar(
        fraction: 0.5,
        barColor: _Fixture.barColor,
        trackColor: _Fixture.color,
        trackMaterial: PhysicalMaterial.well.withTexture(_Fixture.texture),
      ),
    );

    expect(_texturesIn(tester), [_isTinted, PhysicalTexture.none]);
  });

  testWidgets('controls are plain unless told otherwise', (tester) async {
    await _pump(
      tester,
      const PhysicalProgressBar(
        fraction: 0.5,
        barColor: _Fixture.barColor,
        trackColor: _Fixture.color,
      ),
    );

    expect(_texturesIn(tester), everyElement(PhysicalTexture.none));
  });
}
