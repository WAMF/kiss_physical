import 'package:flutter/material.dart';
import 'package:kiss_color/kiss_color.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:kiss_physical/kiss_physical.dart';
import 'package:kiss_physical_example/support/stage.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

class _Sample {
  static const meals = ['Porridge', 'Lentil soup', 'Roast vegetables'];
  static const months = ['September', 'October', 'November', 'December'];
  static const stageHeight = 420.0;
  static const pageHeight = 220.0;
  static const rowHeight = 64.0;
}

@widgetbook.UseCase(name: 'Throw away', type: PhysicalSheet, path: 'Gestures')
Widget buildSheet(BuildContext context) {
  final dismissible = context.knobs.boolean(
    label: 'Dismissible',
    initialValue: true,
  );
  return Stage(
    child: SizedBox(
      height: _Sample.stageHeight,
      child: _SheetDemo(isDismissible: dismissible),
    ),
  );
}

/// A sheet that can be thrown away and called back.
class _SheetDemo extends StatefulWidget {
  const _SheetDemo({required this.isDismissible});

  final bool isDismissible;

  @override
  State<_SheetDemo> createState() => _SheetDemoState();
}

class _SheetDemoState extends State<_SheetDemo> {
  var _isShown = true;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final colors = SemanticColors.of(context).data;
    return ClipRect(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: PhysicalPillButton(
              color: colors.brand.primary.background,
              onPressed:
                  _isShown ? null : () => setState(() => _isShown = true),
              foregroundColor: colors.brand.primary.foreground,
              child: const Text('Show the sheet'),
            ),
          ),
          if (_isShown)
            PhysicalSheet(
              isDismissible: widget.isDismissible,
              onDismissed: () => setState(() => _isShown = false),
              child: PhysicalPanel.bottom(
                isRaised: true,
                child: Padding(
                  padding: layout.edgeSpacing.inner.large,
                  child: const SizedBox(
                    height: _Sample.pageHeight,
                    child: Center(child: Text('Drag or throw me down')),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

@widgetbook.UseCase(
  name: 'Actions behind a row',
  type: PhysicalSwipeRow,
  path: 'Gestures',
)
Widget buildSwipeRow(BuildContext context) {
  final layout = Layout.of(context);
  return Stage(
    child: Column(
      spacing: layout.itemSpacing.small,
      children: [
        for (final meal in _Sample.meals) _MealRow(meal: meal),
      ],
    ),
  );
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});

  final String meal;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final colors = SemanticColors.of(context).data;
    return PhysicalSwipeRow(
      startActions: const [
        _RowAction(icon: Icons.star_outline, label: 'Favourite'),
      ],
      endActions: const [
        _RowAction(icon: Icons.copy_outlined, label: 'Copy'),
        _RowAction(icon: Icons.delete_outline, label: 'Delete'),
      ],
      child: PhysicalCard(
        height: _Sample.rowHeight,
        color: colors.secondary.background,
        child: Padding(
          padding: layout.edgeSpacing.inner.medium,
          child: Row(children: [Text(meal)]),
        ),
      ),
    );
  }
}

/// A round button behind a row, which closes the row when pressed.
class _RowAction extends StatelessWidget {
  const _RowAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final colors = SemanticColors.of(context).data;
    return PhysicalIconButton(
      color: colors.brand.primary.background,
      diameter: layout.actionSizes.small.height,
      tooltip: label,
      onPressed: () => PhysicalSwipeRow.close(context),
      icon: Icon(icon, color: colors.brand.primary.foreground),
    );
  }
}

@widgetbook.UseCase(name: 'Sprung pages', type: PhysicalPager, path: 'Gestures')
Widget buildPager(BuildContext context) {
  return const Stage(child: _PagerDemo());
}

class _PagerDemo extends StatefulWidget {
  const _PagerDemo();

  @override
  State<_PagerDemo> createState() => _PagerDemoState();
}

class _PagerDemoState extends State<_PagerDemo> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final colors = SemanticColors.of(context).data;
    return Column(
      spacing: layout.itemSpacing.medium,
      children: [
        SizedBox(
          height: _Sample.pageHeight,
          child: PhysicalPager(
            itemCount: _Sample.months.length,
            page: _page,
            onPageChanged: (page) => setState(() => _page = page),
            semanticLabel: 'Month',
            itemBuilder: (context, index) => Padding(
              padding: layout.edgeSpacing.inner.small,
              child: PhysicalCard(
                color: colors.secondary.background,
                child: Center(child: Text(_Sample.months[index])),
              ),
            ),
          ),
        ),
        Text('${_page + 1} of ${_Sample.months.length}'),
      ],
    );
  }
}
