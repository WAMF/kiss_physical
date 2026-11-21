// Records the screenshots shown on the package's pub.dev page.
//
// Run from the package root:
//   flutter test tool/screenshots --update-goldens
//
// It writes PNG files at three times the size of the shot. Convert each to
// a JPEG 1920 pixels wide before committing it, to keep the package small:
//   sips -Z 1920 -s format jpeg -s formatOptions 85 shot.png --out shot.jpg
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/kiss_physical.dart';

class _Shot {
  static const size = Size(960, 540);
  static const background = Color(0xFF1A1D1C);
  static const panel = Color(0xFF3B393E);
  static const accent = Color(0xFFD71921);
  static const paper = Color(0xFFFFFFFF);
  static const padding = EdgeInsets.all(36);
  static const gap = 24.0;
  static const radius = BorderRadius.all(Radius.circular(28));
  static const light = Offset(-0.3, -0.5);
  static const settle = Duration(seconds: 4);
  static const frame = Duration(milliseconds: 50);
}

/// The fonts a real app draws with, which tests leave out.
abstract final class _Fonts {
  static const text = 'Roboto';
  static const icons = 'MaterialIcons';
  static const _folder = 'bin/cache/artifacts/material_fonts';
  static const _files = {
    text: 'Roboto-Medium.ttf',
    icons: 'MaterialIcons-Regular.otf',
  };

  static Future<void> load() async {
    final flutter = Platform.environment['FLUTTER_ROOT'];
    for (final MapEntry(key: family, value: file) in _files.entries) {
      final bytes = File('$flutter/$_folder/$file').readAsBytesSync();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  }
}

/// What one panel of controls is made of, and the colour of each part.
enum _Made {
  ofPlastic(
    panel: PhysicalTexture.none,
    panelColor: _Shot.panel,
    fittings: PhysicalTexture.none,
    fittingsColor: _Shot.accent,
    labelColor: _Shot.paper,
    track: PhysicalTexture.none,
    trackColor: _Shot.background,
  ),
  ofOakAndBrass(
    panel: PhysicalTexture.oak,
    panelColor: Color(0xFF7A5230),
    fittings: PhysicalTexture.brass,
    fittingsColor: Color(0xFFC9A24B),
    labelColor: Color(0xFF2B1D0E),
    track: PhysicalTexture.walnut,
    trackColor: Color(0xFF3A2414),
  ),
  ofMarbleAndSteel(
    panel: PhysicalTexture.carrara,
    panelColor: Color(0xFFE9E7E2),
    fittings: PhysicalTexture.stainlessSteel,
    fittingsColor: Color(0xFFAEB4BC),
    labelColor: Color(0xFF1A1D1C),
    track: PhysicalTexture.granite,
    trackColor: Color(0xFF6E7075),
  );

  const _Made({
    required this.panel,
    required this.panelColor,
    required this.fittings,
    required this.fittingsColor,
    required this.labelColor,
    required this.track,
    required this.trackColor,
  });

  /// What the panel is made of.
  final PhysicalTexture panel;
  final Color panelColor;

  /// What the buttons, the bead and the bar are made of.
  final PhysicalTexture fittings;
  final Color fittingsColor;
  final Color labelColor;

  /// What the recessed tracks are made of.
  final PhysicalTexture track;
  final Color trackColor;
}

/// A slider, a progress bar and two buttons on a panel, all [made] of the
/// same few substances.
class _Controls extends StatelessWidget {
  const _Controls(this.made);

  static const _slid = 0.6;
  static const _filled = 0.4;
  static const _buttonDiameter = 48.0;

  final _Made made;

  @override
  Widget build(BuildContext context) {
    final bar = PhysicalMaterial.gloss.withTexture(made.fittings);
    final track = PhysicalMaterial.well.withTexture(made.track);
    return PhysicalPanel(
      color: made.panelColor,
      texture: made.panel,
      isRaised: true,
      child: Padding(
        padding: const EdgeInsets.all(_Shot.gap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: _Shot.gap,
          children: [
            PhysicalSlider(
              value: _slid,
              onChanged: (_) {},
              barColor: made.fittingsColor,
              trackColor: made.trackColor,
              thumbColor: made.fittingsColor,
              barMaterial: bar,
              trackMaterial: track,
              thumbMaterial: PhysicalMaterial.bead.withTexture(made.fittings),
            ),
            PhysicalProgressBar(
              fraction: _filled,
              barColor: made.fittingsColor,
              trackColor: made.trackColor,
              barMaterial: bar,
              trackMaterial: track,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PhysicalPillButton(
                  color: made.fittingsColor,
                  foregroundColor: made.labelColor,
                  material: bar,
                  onPressed: () {},
                  child: const Text('Save'),
                ),
                PhysicalIconButton(
                  diameter: _buttonDiameter,
                  color: made.fittingsColor,
                  material: PhysicalMaterial.bead.withTexture(made.fittings),
                  tooltip: 'Add',
                  onPressed: () {},
                  icon: Icon(Icons.add, color: made.labelColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

PhysicalMaterial _of(PhysicalTexture texture) {
  return PhysicalMaterial.satin.withTexture(texture);
}

Widget _slab(PhysicalMaterial material, {Color color = _Shot.panel}) {
  return PhysicalSurface(
    color: color,
    material: material,
    borderRadius: _Shot.radius,
    child: const SizedBox.expand(),
  );
}

/// [bodies] side by side in rows of [columns], filling the shot.
class _Grid extends StatelessWidget {
  const _Grid({required this.bodies, required this.columns});

  final List<Widget> bodies;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: _Shot.gap,
      crossAxisSpacing: _Shot.gap,
      childAspectRatio: _aspectFor(bodies.length ~/ columns),
      physics: const NeverScrollableScrollPhysics(),
      children: bodies,
    );
  }

  double _aspectFor(int rows) {
    final width = _Shot.size.width - _Shot.padding.horizontal;
    final height = _Shot.size.height - _Shot.padding.vertical;
    final cellWidth = (width - (columns - 1) * _Shot.gap) / columns;
    final cellHeight = (height - (rows - 1) * _Shot.gap) / rows;
    return cellWidth / cellHeight;
  }
}

Future<void> _record(
  WidgetTester tester,
  String name,
  Widget content, {
  bool isAnimated = false,
}) async {
  await tester.runAsync(PhysicalShader.precacheAll);
  await tester.runAsync(_Fonts.load);
  await tester.binding.setSurfaceSize(_Shot.size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: _Fonts.text),
      ),
      home: PhysicalLight.fixed(
        direction: _Shot.light,
        child: PhysicalPegboard(
          color: _Shot.background,
          child: Padding(padding: _Shot.padding, child: content),
        ),
      ),
    ),
  );
  await tester.pump();
  if (isAnimated) {
    final frames = _Shot.settle.inMilliseconds ~/ _Shot.frame.inMilliseconds;
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(_Shot.frame);
    }
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../screenshots/$name.png'),
  );
}

void main() {
  testWidgets('showpieces', (tester) async {
    await _record(
      tester,
      'showpieces',
      _Grid(
        columns: 3,
        bodies: [
          _slab(
            _of(
              PhysicalTexture.slate.imperfect(0.7),
            ).withEffect(const PhysicalEffect.rain(intensity: 0.9)),
          ),
          _slab(
            _of(
              PhysicalTexture.oak.aged(0.7).imperfect(0.6),
            ).withEffect(const PhysicalEffect.flame(scorch: 0.6, embers: 0.7)),
          ),
          _slab(
            _of(
              PhysicalTexture.copper.aged(1).dented(0.4),
            ).withDecals(const PhysicalDecals(dew: 0.7)),
          ),
          _slab(
            _of(
              PhysicalTexture.travertine.aged(0.5).dented(0.9),
            ).withDecals(const PhysicalDecals(dew: 0.3)),
          ),
          _slab(
            PhysicalMaterial.gloss.withEffect(
              const PhysicalEffect.neon(color: _Shot.accent, tube: 0.5),
            ),
          ),
          _slab(
            PhysicalMaterial.gloss.withVessel(
              const PhysicalVessel.glass(color: _Shot.accent),
            ),
          ),
        ],
      ),
      isAnimated: true,
    );
  });

  testWidgets('textures', (tester) async {
    await _record(
      tester,
      'textures',
      _Grid(
        columns: 4,
        bodies: [
          _slab(_of(PhysicalTexture.walnut)),
          _slab(_of(PhysicalTexture.oak)),
          _slab(_of(PhysicalTexture.zebrano)),
          _slab(_of(PhysicalTexture.carrara)),
          _slab(_of(PhysicalTexture.neroMarquina)),
          _slab(_of(PhysicalTexture.granite)),
          _slab(_of(PhysicalTexture.brass)),
          _slab(_of(PhysicalTexture.stainlessSteel)),
        ],
      ),
    );
  });

  testWidgets('controls', (tester) async {
    await _record(
      tester,
      'controls',
      const Center(
        child: Row(
          spacing: _Shot.gap,
          children: [
            Expanded(child: _Controls(_Made.ofPlastic)),
            Expanded(child: _Controls(_Made.ofOakAndBrass)),
            Expanded(child: _Controls(_Made.ofMarbleAndSteel)),
          ],
        ),
      ),
    );
  });
}
