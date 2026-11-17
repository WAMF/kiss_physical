import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const maxDepth = 60.0;
  static const maxHeight = 60.0;
  static const startDepth = 28.0;
  static const rowCount = 24;
  static const rowHeight = 64.0;
  static const menuWidth = 220.0;
}

@widgetbook.UseCase(
  name: 'Background, content and foreground',
  type: PhysicalParallaxLayer,
  path: 'Depth',
)
Widget buildDepthLayers(BuildContext context) {
  final colors = SemanticColors.of(context).data;
  final depth = context.knobs.double.slider(
    label: 'Pegboard depth below content',
    initialValue: _Sample.startDepth,
    max: _Sample.maxDepth,
  );
  final height = context.knobs.double.slider(
    label: 'Menu height above content',
    initialValue: PhysicalParallaxLayer.defaultHeight,
    max: _Sample.maxHeight,
  );
  return WorldLight(
    child: PhysicalPegboard(
      color: colors.primary.background,
      scrollsWithContent: true,
      depth: depth,
      child: Stack(
        children: [
          const _ScrollingRows(),
          Align(
            alignment: Alignment.bottomCenter,
            child: PhysicalParallaxLayer(
              height: height,
              child: const _FloatingMenu(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Content at the level of the screen, scrolling over the pegboard.
class _ScrollingRows extends StatelessWidget {
  const _ScrollingRows();

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    return ListView.separated(
      padding: layout.edgeSpacing.outer.medium,
      itemCount: _Sample.rowCount,
      separatorBuilder: (context, index) =>
          SizedBox(height: layout.itemSpacing.medium),
      itemBuilder: (context, index) => SizedBox(
        height: _Sample.rowHeight,
        child: PhysicalPanel(
          child: Center(child: Text('Row ${index + 1}')),
        ),
      ),
    );
  }
}

/// A raised bar of controls that floats above the content.
class _FloatingMenu extends StatelessWidget {
  const _FloatingMenu();

  static const _icons = [Icons.home, Icons.search, Icons.person];

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final colors = SemanticColors.of(context).data;
    return Padding(
      padding: layout.edgeSpacing.outer.large,
      child: SizedBox(
        width: _Sample.menuWidth,
        height: layout.actionSizes.large.height,
        child: PhysicalSurface(
          color: colors.secondary.background,
          material: PhysicalMaterial.floatingPanel,
          borderRadius: PhysicalSurface.stadium,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final icon in _icons)
                Icon(icon, color: colors.secondary.foreground),
            ],
          ),
        ),
      ),
    );
  }
}
