import 'package:flutter/material.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical_example/main.directories.g.dart';
import 'package:kiss_physical_example/support/kit_addon.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

void main() {
  runApp(
    const Layout(
      child: WidgetbookApp(),
    ),
  );
}

@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      themeMode: ThemeMode.dark,
      initialRoute: _Start.showpieces,
      directories: directories,
      addons: [
        KitAddon(),
        ViewportAddon([
          Viewports.none,
          IosViewports.iPhone13,
          IosViewports.iPad,
        ]),
        TextScaleAddon(),
      ],
    );
  }
}

class _Start {
  static const showpieces = '/?path=materials/materialgallery/showpieces';
}
