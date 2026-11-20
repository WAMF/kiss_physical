# kiss_physical example

The least an app needs: compile the shaders, hang a light over everything,
and build from physical bodies. This is
[`lib/minimal.dart`](lib/minimal.dart); run it with
`flutter run -t lib/minimal.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:kiss_physical/kiss_physical.dart';

/// The least an app needs: compile the shaders, hang a light over
/// everything, and build from physical bodies.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PhysicalShader.precache();
  runApp(const WorldLight(child: MinimalApp()));
}

class _Look {
  static const background = Color(0xFF1A1D1C);
  static const accent = Color(0xFFD71921);
  static const cardPadding = EdgeInsets.all(24);
  static const cardWidth = 280.0;
  static const gap = 16.0;
}

/// A card holding a label and a button, on a pegboard that shifts beneath
/// them as the device is tilted.
class MinimalApp extends StatelessWidget {
  const MinimalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: PhysicalPegboard(
          color: _Look.background,
          depth: PhysicalParallaxLayer.defaultHeight,
          child: Center(child: _Greeting()),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return PhysicalCard(
      width: _Look.cardWidth,
      child: Padding(
        padding: _Look.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: _Look.gap,
          children: [
            const Text('Tilt the device to move the light.'),
            PhysicalPillButton(
              color: _Look.accent,
              foregroundColor: Colors.white,
              onPressed: () {},
              child: const Text('Press me'),
            ),
          ],
        ),
      ),
    );
  }
}
```

For every component, a gallery of the materials and controls for the light,
run the storybook in this folder (`flutter run`) or open it at
<https://wamf.github.io/kiss_physical/>.
