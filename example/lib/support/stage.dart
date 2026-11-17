import 'package:flutter/material.dart';
import 'package:kiss_layout/kiss_layout.dart';

/// Centres a use case on the panel at a phone-like width, with room to
/// scroll when it is taller than the viewport.
class Stage extends StatelessWidget {
  const Stage({
    required this.child,
    this.maxWidth = defaultMaxWidth,
    super.key,
  });

  static const defaultMaxWidth = 420.0;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: Layout.of(context).edgeSpacing.outer.medium,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// A titled group of examples within a use case.
class Specimen extends StatelessWidget {
  const Specimen({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: layout.itemSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: layout.itemSpacing.small,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          child,
        ],
      ),
    );
  }
}
