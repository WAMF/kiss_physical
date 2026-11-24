import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiss_physical/src/material/disabled_look.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/motion/physical_feel.dart';
import 'package:kiss_physical/src/motion/physical_haptics.dart';
import 'package:kiss_physical/src/motion/physical_motion.dart';
import 'package:kiss_physical/src/motion/spring_controller.dart';
import 'package:kiss_physical/src/surface/focus_ring.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Segments {
  /// The gap between the thumb and the wall of its track.
  static const inset = 3.0;
  static const fewest = 2;
  static const labelChange = Duration(milliseconds: 150);
}

/// A row of choices in a recessed track, with one raised thumb that slides
/// under the chosen one.
///
/// Tapping a choice sends the thumb there on a spring; the thumb can also
/// be dragged or thrown along the track and settles on the choice it is
/// heading for. With keyboard focus the arrow keys move it. With no
/// [onChanged] the control is frosted over and inert.
class PhysicalSegmentedControl<T extends Object> extends StatefulWidget {
  /// Creates a control offering [segments], with [selected] chosen.
  const PhysicalSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.trackColor,
    required this.thumbColor,
    this.foregroundColor,
    this.selectedForegroundColor,
    this.height = defaultHeight,
    this.trackMaterial = PhysicalMaterial.well,
    this.thumbMaterial = PhysicalMaterial.gloss,
    this.semanticLabel,
    this.focusNode,
    super.key,
  }) : assert(
          segments.length >= _Segments.fewest,
          'there must be at least two choices',
        );

  /// The height of the track unless another is given.
  static const defaultHeight = 40.0;

  /// The choices in the order they are shown, each with what labels it.
  final Map<T, Widget> segments;

  /// The chosen one of [segments].
  final T selected;

  /// Called with the choice the thumb is moved to. The control is frosted
  /// over and inert when null.
  final ValueChanged<T>? onChanged;

  /// The colour of the recessed track.
  final Color trackColor;

  /// The colour of the thumb.
  final Color thumbColor;

  /// The colour of the labels on the track, or null for the theme's.
  final Color? foregroundColor;

  /// The colour of the label over the thumb, or null for
  /// [foregroundColor].
  final Color? selectedForegroundColor;

  /// The height of the track in logical pixels.
  final double height;

  /// How the recessed track is shaped and catches the light. A texture on
  /// it is tinted to [trackColor].
  final PhysicalMaterial trackMaterial;

  /// How the thumb is shaped and catches the light, and what it feels like
  /// to move. A texture on it is tinted to [thumbColor].
  final PhysicalMaterial thumbMaterial;

  /// What the control is called by screen readers.
  final String? semanticLabel;

  /// Controls the keyboard focus of the control, or null for one of its
  /// own.
  final FocusNode? focusNode;

  @override
  State<PhysicalSegmentedControl<T>> createState() =>
      _PhysicalSegmentedControlState<T>();
}

class _PhysicalSegmentedControlState<T extends Object>
    extends State<PhysicalSegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  late final _position = SpringController(
    vsync: this,
    value: _selectedIndex.toDouble(),
  );
  final _showsFocus = ValueNotifier<bool>(false);

  /// Where the finger has carried the thumb during the drag in progress.
  var _dragged = 0.0;

  List<T> get _choices => widget.segments.keys.toList();

  int get _selectedIndex {
    final index = _choices.indexOf(widget.selected);
    return index < 0 ? 0 : index;
  }

  int get _last => widget.segments.length - 1;

  PhysicalFeel get _feel => PhysicalFeel.of(widget.thumbMaterial);

  @override
  void didUpdateWidget(PhysicalSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _settle();
  }

  @override
  void dispose() {
    _position.dispose();
    _showsFocus.dispose();
    super.dispose();
  }

  void _settle({double? velocity}) {
    _position.springTo(
      _selectedIndex.toDouble(),
      spring: _feel.release,
      velocity: velocity,
    );
  }

  void _choose(int index) {
    final held = index.clamp(0, _last);
    if (held == _selectedIndex) return;
    PhysicalHaptics.play(context, PhysicalHaptic.tick);
    widget.onChanged?.call(_choices[held]);
  }

  void _startDrag() => _dragged = _position.value;

  void _drag(double segmentsAlong) {
    _dragged += segmentsAlong;
    _position.value = _dragged;
  }

  /// Where the thumb shows for a [position] counted in choices: past
  /// either end it gives a little and is held by the track.
  double _shownAt(double position) {
    return PhysicalMotion.heldWithin(
      position,
      lowest: 0,
      highest: _last.toDouble(),
    );
  }

  void _endDrag(double segmentsASecond) {
    final rest = PhysicalMotion.stopFor(
      _position.value,
      segmentsASecond,
      [for (var index = 0; index <= _last; index++) index.toDouble()],
    );
    _settle(velocity: segmentsASecond);
    _choose(rest.round());
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onChanged != null;
    final towardsEnd = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return FocusableActionDetector(
      enabled: isEnabled,
      focusNode: widget.focusNode,
      onShowFocusHighlight: (shows) => _showsFocus.value = shows,
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            _MoveIntent(towardsEnd),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            _MoveIntent(-towardsEnd),
      },
      actions: {
        _MoveIntent: CallbackAction<_MoveIntent>(
          onInvoke: (intent) => _choose(_selectedIndex + intent.direction),
        ),
      },
      child: Semantics(
        container: true,
        label: widget.semanticLabel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = (constraints.maxWidth - _Segments.inset * 2) /
                widget.segments.length;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: isEnabled ? (_) => _startDrag() : null,
              onHorizontalDragUpdate: isEnabled
                  ? (details) => _drag(
                        details.primaryDelta! * towardsEnd / segmentWidth,
                      )
                  : null,
              onHorizontalDragEnd: isEnabled
                  ? (details) => _endDrag(
                        details.primaryVelocity! * towardsEnd / segmentWidth,
                      )
                  : null,
              child: PhysicalFocusRing(
                isShown: _showsFocus,
                borderRadius: PhysicalSurface.stadium,
                child: _Track(
                  height: widget.height,
                  color: widget.trackColor,
                  material: widget.trackMaterial,
                  isEnabled: isEnabled,
                  thumb: AnimatedBuilder(
                    animation: _position,
                    builder: (context, thumb) => Align(
                      alignment: AlignmentDirectional(
                        _shownAt(_position.value) / _last * 2 - 1,
                        0,
                      ),
                      child: thumb,
                    ),
                    child: _Thumb(
                      share: 1 / widget.segments.length,
                      color: widget.thumbColor,
                      material: widget.thumbMaterial,
                      isEnabled: isEnabled,
                    ),
                  ),
                  labels: [
                    for (final (index, label) in widget.segments.values.indexed)
                      _Label(
                        isSelected: index == _selectedIndex,
                        isEnabled: isEnabled,
                        onTap: isEnabled ? () => _choose(index) : null,
                        color: widget.foregroundColor,
                        selectedColor: widget.selectedForegroundColor,
                        child: label,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Moves the thumb one choice: towards the end when [direction] is
/// positive, towards the start when it is negative.
class _MoveIntent extends Intent {
  const _MoveIntent(this.direction);

  final int direction;
}

/// The recessed track, with the [thumb] lying in it under the [labels].
class _Track extends StatelessWidget {
  const _Track({
    required this.height,
    required this.color,
    required this.material,
    required this.isEnabled,
    required this.thumb,
    required this.labels,
  });

  final double height;
  final Color color;
  final PhysicalMaterial material;
  final bool isEnabled;
  final Widget thumb;
  final List<Widget> labels;

  @override
  Widget build(BuildContext context) {
    final shown = isEnabled ? color : DisabledLook.frosted(color);
    final made = material.tintedTo(shown);
    return SizedBox(
      height: height,
      child: PhysicalSurface(
        color: shown,
        material: isEnabled ? made : DisabledLook.flattened(made),
        borderRadius: PhysicalSurface.stadium,
        child: Padding(
          padding: const EdgeInsets.all(_Segments.inset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumb,
              Row(
                children: [
                  for (final label in labels) Expanded(child: label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The raised thumb, as wide as its [share] of the track.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.share,
    required this.color,
    required this.material,
    required this.isEnabled,
  });

  final double share;
  final Color color;
  final PhysicalMaterial material;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final shown = isEnabled ? color : DisabledLook.frosted(color);
    final made = material.tintedTo(shown);
    return FractionallySizedBox(
      widthFactor: share,
      heightFactor: 1,
      child: PhysicalSurface(
        color: shown,
        material: isEnabled ? made : DisabledLook.flattened(made),
        borderRadius: PhysicalSurface.stadium,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// One choice on the track, which can be tapped to choose it.
class _Label extends StatelessWidget {
  const _Label({
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
    required this.color,
    required this.selectedColor,
    required this.child,
  });

  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;
  final Color? color;
  final Color? selectedColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resting = color ?? theme.colorScheme.onSurface;
    final chosen = isSelected ? selectedColor ?? resting : resting;
    final shown = isEnabled
        ? chosen
        : chosen.withValues(alpha: DisabledLook.foregroundAlpha);
    final style = (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(color: shown);
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            style: style,
            duration: _Segments.labelChange,
            child: IconTheme.merge(
              data: IconThemeData(color: shown),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
