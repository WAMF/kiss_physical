import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Flat and raised',
  type: PhysicalPanel,
  path: 'Surfaces',
)
Widget buildPanels(BuildContext context) {
  final layout = Layout.of(context);
  return Stage(
    child: Column(
      spacing: layout.itemSpacing.large,
      children: [
        for (final isRaised in [false, true])
          PhysicalPanel(
            isRaised: isRaised,
            child: Padding(
              padding: layout.edgeSpacing.inner.large,
              child: Row(
                children: [Text(isRaised ? 'Raised panel' : 'Flat panel')],
              ),
            ),
          ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Shapes',
  type: PhysicalCard,
  path: 'Surfaces',
)
Widget buildCards(BuildContext context) {
  final layout = Layout.of(context);
  final colors = SemanticColors.of(context).data;
  final side = layout.heroSizes.medium.width;
  return Stage(
    child: Wrap(
      spacing: layout.itemSpacing.medium,
      runSpacing: layout.itemSpacing.medium,
      children: [
        PhysicalCard(
          width: side,
          height: side,
          content: const Center(child: Text('PhysicalCard')),
        ),
        SizedBox.square(
          dimension: side,
          child: PhysicalDisc(
            backgroundColor: colors.brand.primary.background,
            content: Center(
              child: Text(
                'PhysicalDisc',
                style: TextStyle(color: colors.brand.primary.foreground),
              ),
            ),
          ),
        ),
        PhysicalPill(
          height: layout.actionSizes.large.height,
          content: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(widthFactor: 1, child: Text('PhysicalPill')),
          ),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Over a photo',
  type: PhysicalGlass,
  path: 'Surfaces/Glass',
)
Widget buildGlass(BuildContext context) {
  final layout = Layout.of(context);
  final radius = BorderRadius.circular(layout.cornerRadii.large);
  return Stage(
    child: AspectRatio(
      aspectRatio: 1,
      child: PhysicalGlass(
        borderRadius: radius,
        child: ClipRRect(
          borderRadius: radius,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2B3A55),
                  Color(0xFFB8572A),
                  Color(0xFFF2C14E),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Panel',
  type: PhysicalPegboard,
  path: 'Surfaces/Backgrounds',
)
Widget buildPegboard(BuildContext context) {
  final colors = SemanticColors.of(context).data;
  return PhysicalPegboard(
    color: colors.primary.background,
    grid: PegboardGrid(
      pitch: context.knobs.double.slider(
        label: 'Pitch',
        initialValue: PegboardGrid.defaultPitch,
        min: 8,
        max: 40,
      ),
    ),
    child: const SizedBox.expand(),
  );
}

@widgetbook.UseCase(
  name: 'Beads and sockets',
  type: PhysicalDotGrid,
  path: 'Surfaces/Backgrounds',
)
Widget buildDotGrid(BuildContext context) {
  final colors = SemanticColors.of(context).data;
  const columns = 26;
  const rows = 7;
  const everyNth = 5;
  return Stage(
    child: PhysicalPanel(
      isRaised: true,
      child: Padding(
        padding: Layout.of(context).edgeSpacing.inner.large,
        child: AspectRatio(
          aspectRatio: columns / rows,
          child: PhysicalDotGrid(
            columns: columns,
            rows: rows,
            dots: [
              for (var cell = 0; cell < columns * rows; cell++)
                cell % everyNth == 0
                    ? PhysicalDot.bead(
                        Color.lerp(
                          colors.brand.primary.background,
                          colors.primary.foreground,
                          cell / (columns * rows),
                        )!,
                      )
                    : PhysicalDot.socket(colors.secondary.background),
            ],
          ),
        ),
      ),
    ),
  );
}
