import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

import 'golden_support.dart';

class _Lettering {
  static const family = 'Roboto';
  static const fonts = 'bin/cache/artifacts/material_fonts';
  static const weights = ['Roboto-Regular.ttf', 'Roboto-Black.ttf'];
  static const sheet = Size(560, 560);
  static const heading = TextStyle(
    fontFamily: family,
    fontSize: 64,
    fontWeight: FontWeight.w900,
    height: 1.1,
  );
  static const gold = Color(0xFFD9A441);
  static const steel = Color(0xFFB8BEC6);
  static const chrome = PhysicalMaterial(
    roughness: 0.22,
    specularTint: 0.9,
    elevation: 2,
  );
  static const engraved = PhysicalMaterial(
    roughness: 0.6,
    relief: -1,
    elevation: 0,
  );

  /// Loads the real typeface a test would otherwise draw as blocks.
  static Future<void> load() async {
    final root = Platform.environment['FLUTTER_ROOT']!;
    final loader = FontLoader(family);
    for (final weight in weights) {
      final bytes = File('$root/$fonts/$weight').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

Future<void> _expectLettering(
  WidgetTester tester,
  String name,
  List<Widget> lines,
) async {
  await tester.runAsync(_Lettering.load);
  await tester.runAsync(PhysicalShader.precacheAll);
  await tester.binding.setSurfaceSize(_Lettering.sheet);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PhysicalLight(
        direction: const AlwaysStoppedAnimation(Sheet.light),
        child: ColoredBox(
          color: Sheet.background,
          child: Padding(
            padding: const EdgeInsets.all(Sheet.gap * 2),
            child: DefaultTextStyle(
              style: _Lettering.heading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('images/$name.png'),
  );
}

PhysicalText _made(String words, PhysicalMaterial material) {
  return PhysicalText(words, color: Sheet.body, material: material);
}

void main() {
  useTolerantGoldens('test/golden/text_golden_test.dart');

  testWidgets(
    'lettering',
    (tester) async {
      await _expectLettering(tester, 'lettering', [
        const PhysicalText('Satin 123', color: Sheet.accent),
        const PhysicalText(
          'Gloss 456',
          color: Sheet.accent,
          material: PhysicalMaterial.gloss,
        ),
        const PhysicalText(
          'Gold 789',
          color: _Lettering.gold,
          material: _Lettering.chrome,
        ),
        const PhysicalText(
          'Steel',
          color: _Lettering.steel,
          material: _Lettering.chrome,
        ),
        const PhysicalText(
          'Engraved',
          color: Sheet.body,
          material: _Lettering.engraved,
        ),
        PhysicalText(
          'Regular weight at twenty-four',
          color: Sheet.accent,
          style: _Lettering.heading.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
        ),
      ]);
    },
    skip: !rendersLikeTheGoldens,
  );

  testWidgets(
    'textured lettering',
    (tester) async {
      const satin = PhysicalMaterial.satin;
      await _expectLettering(tester, 'textured_lettering', [
        _made('Oak 123', satin.withTexture(PhysicalTexture.oak)),
        _made('Brass 456', satin.withTexture(PhysicalTexture.brass)),
        _made('Copper', satin.withTexture(PhysicalTexture.copper)),
        _made('Carrara', satin.withTexture(PhysicalTexture.carrara)),
        _made('Granite', satin.withTexture(PhysicalTexture.granite)),
        _made(
          'Worn brass',
          satin.withTexture(PhysicalTexture.brass.imperfect(0.8)),
        ),
        _made(
          'Dewy',
          satin
              .withTexture(PhysicalTexture.plastic)
              .withDecals(const PhysicalDecals(dew: 0.6)),
        ),
      ]);
    },
    skip: !rendersLikeTheGoldens,
  );
}
