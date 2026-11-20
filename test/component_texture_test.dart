import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Fixture {
  static const texture = PhysicalTexture.oak;
  static const color = Color(0xFF3B393E);
}

Future<void> _pump(WidgetTester tester, Widget control) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: control))),
  );
}

Iterable<PhysicalTexture> _texturesIn(WidgetTester tester) {
  return tester
      .widgetList<PhysicalSurface>(find.byType(PhysicalSurface))
      .map((surface) => surface.material.texture);
}

void main() {
  testWidgets('a panel is made of the texture it is given', (tester) async {
    await _pump(
      tester,
      const PhysicalPanel(texture: _Fixture.texture, child: SizedBox.square()),
    );

    expect(_texturesIn(tester), everyElement(_Fixture.texture));
  });

  testWidgets('a slider keeps its bar plain so the value shows',
      (tester) async {
    await _pump(
      tester,
      PhysicalSlider(
        value: 0.5,
        onChanged: (_) {},
        barColor: _Fixture.color,
        trackColor: _Fixture.color,
        thumbColor: _Fixture.color,
        texture: _Fixture.texture,
      ),
    );

    expect(_texturesIn(tester), [
      _Fixture.texture,
      PhysicalTexture.none,
      _Fixture.texture,
    ]);
  });

  testWidgets('a progress bar keeps its bar plain so its fill shows', (
    tester,
  ) async {
    await _pump(
      tester,
      const PhysicalProgressBar(
        fraction: 0.5,
        barColor: _Fixture.color,
        trackColor: _Fixture.color,
        texture: _Fixture.texture,
      ),
    );

    expect(_texturesIn(tester), [_Fixture.texture, PhysicalTexture.none]);
  });

  testWidgets('controls are plain unless told otherwise', (tester) async {
    await _pump(
      tester,
      const PhysicalProgressBar(
        fraction: 0.5,
        barColor: _Fixture.color,
        trackColor: _Fixture.color,
      ),
    );

    expect(_texturesIn(tester), everyElement(PhysicalTexture.none));
  });
}
