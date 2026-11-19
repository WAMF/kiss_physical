import 'package:flutter/material.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Gallery',
  type: PhysicalSurface,
  path: 'Surfaces',
)
Widget buildPhysicalSurfaceGallery(BuildContext context) {
  return PhysicalGallery(
    roughness: context.knobs.double.slider(
      label: 'Button roughness',
      initialValue: PhysicalMaterial.gloss.roughness,
      min: 0.1,
      max: 1,
    ),
  );
}

/// Showcases the physical materials. Drag or hover to steer the light the
/// way turning a handset under a ceiling light would.
class PhysicalGallery extends StatefulWidget {
  const PhysicalGallery({
    this.roughness = 0.28,
    super.key,
  });

  final double roughness;

  @override
  State<PhysicalGallery> createState() => _PhysicalGalleryState();
}

class _PhysicalGalleryState extends State<PhysicalGallery> {
  final _direction = ValueNotifier<Offset>(PhysicalLight.still.value);
  bool _isSelected = true;

  @override
  void initState() {
    super.initState();
    PhysicalShader.precache();
  }

  @override
  void dispose() {
    _direction.dispose();
    super.dispose();
  }

  void _steer(PointerEvent event, Size size) {
    final centred = Offset(
      event.localPosition.dx / size.width - 0.5,
      event.localPosition.dy / size.height - 0.5,
    );
    _direction.value = centred * _Palette.steerRange;
  }

  @override
  Widget build(BuildContext context) {
    final gloss = PhysicalMaterial.gloss.copyWith(roughness: widget.roughness);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerHover: (event) => _steer(event, size),
          onPointerMove: (event) => _steer(event, size),
          child: PhysicalLight(
            direction: _direction,
            child: ColoredBox(
              color: _Palette.background,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(
                    height: 130,
                    child: PhysicalSurface(
                      color: _Palette.panel,
                      borderRadius: BorderRadius.circular(20),
                      child: const _Label('OUTPUT', '143%'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 170,
                    child: Row(
                      spacing: 16,
                      children: [
                        Expanded(
                          child: PhysicalSurface(
                            color: _Palette.light,
                            borderRadius: BorderRadius.circular(20),
                            child: const _Label(
                              'Charge',
                              '87%',
                              color: _Palette.ink,
                            ),
                          ),
                        ),
                        const AspectRatio(
                          aspectRatio: 1,
                          child: PhysicalSurface(
                            color: _Palette.brand,
                            material: PhysicalMaterial.bead,
                            borderRadius: PhysicalSurface.stadium,
                            child: Center(child: _Label('Level', '6')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    spacing: 8,
                    children: [
                      PhysicalPressable(
                        onTap: () => setState(() => _isSelected = !_isSelected),
                        color: _isSelected ? _Palette.brand : _Palette.panel,
                        material: _isSelected ? gloss : PhysicalMaterial.socket,
                        child: const _PillText('Morning'),
                      ),
                      const PhysicalSurface(
                        color: _Palette.panel,
                        material: PhysicalMaterial.socket,
                        borderRadius: PhysicalSurface.stadium,
                        child: _PillText('Noon'),
                      ),
                      const PhysicalSurface(
                        color: _Palette.panel,
                        material: PhysicalMaterial.socket,
                        borderRadius: PhysicalSurface.stadium,
                        child: _PillText('Evening'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    spacing: 12,
                    children: [
                      ElevatedButton(
                        clipBehavior: Clip.none,
                        style: physicalButtonStyle(
                          color: _Palette.brand,
                          foregroundColor: Colors.white,
                          material: gloss,
                          minimumSize: const Size(115, 48),
                        ),
                        onPressed: () {},
                        child: const Text('Save'),
                      ),
                      ElevatedButton(
                        clipBehavior: Clip.none,
                        style: physicalButtonStyle(
                          color: _Palette.light,
                          foregroundColor: _Palette.ink,
                          material: gloss,
                          minimumSize: const Size(115, 48),
                        ),
                        onPressed: () {},
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        clipBehavior: Clip.none,
                        style: physicalButtonStyle(
                          color: _Palette.brand,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(115, 48),
                        ),
                        onPressed: null,
                        child: const Text('Disabled'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 72,
                          child: PhysicalSurface(
                            color: _Palette.panel,
                            borderRadius: PhysicalSurface.stadium,
                            material: PhysicalMaterial.satin
                                .copyWith(bevel: 10, elevation: 6),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(Icons.home, color: Colors.white),
                                Icon(Icons.photo, color: Colors.white60),
                                Icon(Icons.person, color: Colors.white60),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 72,
                        child: PhysicalPressable(
                          onTap: () {},
                          color: Colors.white,
                          material: PhysicalMaterial.bead,
                          child: const Icon(Icons.add, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 64,
                    child: PhysicalSurface(
                      color: _Palette.background,
                      material: PhysicalMaterial.well,
                      borderRadius: BorderRadius.circular(16),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: _PillText('What happened today?'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: 358 / 180,
                    child: PhysicalSurface(
                      color: Colors.white,
                      borderRadius: PhysicalSurface.stadium,
                      material: PhysicalMaterial.gloss.copyWith(bevel: 8),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: PhysicalGlass(
                          borderRadius: PhysicalSurface.stadium,
                          child: ClipRRect(
                            borderRadius: PhysicalSurface.stadium,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF7A4B2A),
                                    Color(0xFFE0A050),
                                    Color(0xFF4F7A3A),
                                  ],
                                ),
                              ),
                              child: SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.title, this.value, {this.color = Colors.white});

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 16)),
          Text(value, style: TextStyle(color: color, fontSize: 32)),
        ],
      ),
    );
  }
}

class _PillText extends StatelessWidget {
  const _PillText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _Palette {
  static const background = Color(0xFF1A1D1C);
  static const panel = Color(0xFF3B393E);
  static const brand = Color(0xFFD71921);
  static const light = Color(0xFFE9ECEF);
  static const ink = Color(0xFF2C3E50);
  static const steerRange = 2.0;
}
