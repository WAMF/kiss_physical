import 'package:flutter/material.dart';
import 'package:kiss_layout/kiss_layout.dart';
import 'package:widgetbook/widgetbook.dart';

/// A heading in a use case's list of knobs, over the knobs added after it.
///
/// It holds no value: it only divides a long list into named sections.
class KnobSection extends Knob<Object?> {
  KnobSection._(String title) : super(label: title, initialValue: null);

  /// Starts a section called [title] in the knobs of the use case being
  /// built in [context].
  static void start(BuildContext context, String title) {
    context.knobs.onKnobAdded(KnobSection._(title));
  }

  @override
  List<Field> get fields => const [];

  @override
  Object? valueFromQueryGroup(Map<String, String> group) => null;

  @override
  Widget buildFields(BuildContext context) => _SectionHeading(title: label);
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: layout.itemSpacing.large,
        bottom: layout.itemSpacing.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: layout.itemSpacing.small,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: _Heading.letterSpacing,
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

class _Heading {
  static const letterSpacing = 1.2;
}
