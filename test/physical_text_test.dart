import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical/src/shader/shader_programs.dart';
import 'package:kiss_physical/src/text/glyph_map.dart';

class _Sample {
  static const words = 'Lit';
  static const color = Color(0xFFD71921);
  static const style = TextStyle(fontSize: 40);
  static const softness = 2.0;
  static const reach = 8.0;
  static const pixelRatio = 2.0;
}

void main() {
  Future<void> pumpText(WidgetTester tester, Widget text) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PhysicalLight(
          direction: PhysicalLight.still,
          child: Center(child: text),
        ),
      ),
    );
  }

  TextPainter layOut(String words) {
    return TextPainter(
      text: TextSpan(text: words, style: _Sample.style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  group('PhysicalText', () {
    testWidgets('takes the room ordinary text would', (tester) async {
      await pumpText(tester, const Text(_Sample.words, style: _Sample.style));
      final ordinary = tester.getSize(find.byType(Text));

      await pumpText(
        tester,
        const PhysicalText(
          _Sample.words,
          color: _Sample.color,
          style: _Sample.style,
        ),
      );

      expect(tester.getSize(find.byType(PhysicalText)), ordinary);
    });

    testWidgets('is read out as its words', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpText(
        tester,
        const PhysicalText(_Sample.words, color: _Sample.color),
      );

      expect(find.bySemanticsLabel(_Sample.words), findsOneWidget);
      handle.dispose();
    });

    testWidgets('wraps within the width it is given', (tester) async {
      await pumpText(
        tester,
        const SizedBox(
          width: 60,
          child: PhysicalText(
            'Lit lit lit lit',
            color: _Sample.color,
            style: _Sample.style,
          ),
        ),
      );

      final size = tester.getSize(find.byType(PhysicalText));
      expect(size.width, lessThanOrEqualTo(60));
      expect(size.height, greaterThan(_Sample.style.fontSize! * 2));
    });

    testWidgets('paints flat until its program arrives', (tester) async {
      ShaderProgram.isLoadingAllowed = false;
      ShaderPrograms.lettering(SurfaceProgram.plain).unload();
      addTearDown(() => ShaderProgram.isLoadingAllowed = true);

      await pumpText(
        tester,
        const PhysicalText(_Sample.words, color: _Sample.color),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('lights its letters once the program is ready', (tester) async {
      await tester.runAsync(
        ShaderPrograms.lettering(SurfaceProgram.plain).load,
      );

      await pumpText(
        tester,
        const PhysicalText(
          _Sample.words,
          color: _Sample.color,
          material: PhysicalMaterial.gloss,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('takes the program of its substance', (tester) async {
      await tester.runAsync(PhysicalShader.precacheAll);

      for (final texture in [
        PhysicalTexture.oak,
        PhysicalTexture.brass,
        PhysicalTexture.plastic,
        PhysicalTexture.granite,
        PhysicalTexture.carrara,
      ]) {
        await pumpText(
          tester,
          PhysicalText(
            _Sample.words,
            color: _Sample.color,
            material: PhysicalMaterial.satin.withTexture(texture),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: '$texture');
      }
    });

    testWidgets('draws dew on letters with no texture', (tester) async {
      await tester.runAsync(PhysicalShader.precacheAll);

      await pumpText(
        tester,
        PhysicalText(
          _Sample.words,
          color: _Sample.color,
          material: PhysicalMaterial.satin.withDecals(
            const PhysicalDecals(dew: 0.5),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('GlyphMap', () {
    test('reaches past the blur and the thrown shadow', () {
      expect(GlyphMap.reachOf(softness: 2, elevation: 0), 7);
      expect(
        GlyphMap.reachOf(softness: 2, elevation: 4),
        greaterThan(GlyphMap.reachOf(softness: 2, elevation: 0)),
      );
    });

    test('is the lettering and its reach on every side', () {
      final lettering = layOut(_Sample.words);
      addTearDown(lettering.dispose);

      expect(
        GlyphMap.sizeOf(lettering, _Sample.reach),
        lettering.size + const Offset(_Sample.reach, _Sample.reach) * 2,
      );
    });

    test('is drawn once for the same lettering and again when it changes', () {
      final lettering = layOut(_Sample.words);
      final map = GlyphMap();
      addTearDown(lettering.dispose);
      addTearDown(map.dispose);

      final first = map.imageOf(
        lettering,
        softness: _Sample.softness,
        reach: _Sample.reach,
        pixelRatio: _Sample.pixelRatio,
      );
      final again = map.imageOf(
        lettering,
        softness: _Sample.softness,
        reach: _Sample.reach,
        pixelRatio: _Sample.pixelRatio,
      );
      final sharper = map.imageOf(
        lettering,
        softness: _Sample.softness / 2,
        reach: _Sample.reach,
        pixelRatio: _Sample.pixelRatio,
      );

      expect(again, same(first));
      expect(sharper, isNot(same(first)));
      expect(
        sharper.width,
        (GlyphMap.sizeOf(lettering, _Sample.reach).width * _Sample.pixelRatio)
            .ceil(),
      );
    });
  });
}
