import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/disabled_look.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/surface/focus_ring.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

class _Field {
  static const padding = EdgeInsets.symmetric(horizontal: 16);
  static const textPadding = EdgeInsets.symmetric(vertical: 14);
  static const gap = SizedBox(width: 8);

  /// How strongly the hint shows against the well.
  static const hintAlpha = 0.6;
}

/// A well pressed into its parent to type into: a Material [TextField]
/// with all its editing, laid in a recessed [PhysicalSurface].
///
/// A ring shows round the well while it has focus, and tapping anywhere in
/// the well places the cursor. When not [enabled] it is frosted over.
class PhysicalTextField extends StatefulWidget {
  /// Creates a well to type into.
  const PhysicalTextField({
    this.controller,
    this.focusNode,
    this.color,
    this.material = PhysicalMaterial.well,
    this.borderRadius,
    this.hintText,
    this.leading,
    this.trailing,
    this.style,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// Holds the text being edited, or null for one the field keeps itself.
  final TextEditingController? controller;

  /// Controls the keyboard focus of the field, or null for one of its own.
  final FocusNode? focusNode;

  /// The colour of the well. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? color;

  /// How the well is shaped and catches the light. A texture on it is
  /// tinted to the colour of the well.
  final PhysicalMaterial material;

  /// The corner radii of the well, or null for the large corner radius of
  /// the nearest `Layout`.
  final BorderRadius? borderRadius;

  /// What is shown, faintly, while nothing has been typed.
  final String? hintText;

  /// What sits in the well before the text, such as a search icon.
  final Widget? leading;

  /// What sits in the well after the text, such as a button to clear it.
  final Widget? trailing;

  /// The style of the text, or null for the theme's.
  final TextStyle? style;

  /// The kind of keyboard to show.
  final TextInputType? keyboardType;

  /// The action button the keyboard shows.
  final TextInputAction? textInputAction;

  /// Which letters the keyboard capitalises.
  final TextCapitalization textCapitalization;

  /// What may be typed, checked as it is typed.
  final List<TextInputFormatter>? inputFormatters;

  /// Whether what is typed is hidden, as a password is.
  final bool obscureText;

  /// Whether the field takes keyboard focus when it first appears.
  final bool autofocus;

  /// Whether the field can be typed into. It is frosted over when not.
  final bool enabled;

  /// The most lines the well grows to show, or null for no limit.
  final int? maxLines;

  /// The fewest lines the well is tall enough for.
  final int? minLines;

  /// Called with the text as it is typed.
  final ValueChanged<String>? onChanged;

  /// Called with the text when the keyboard's action button is pressed.
  final ValueChanged<String>? onSubmitted;

  @override
  State<PhysicalTextField> createState() => _PhysicalTextFieldState();
}

class _PhysicalTextFieldState extends State<PhysicalTextField> {
  FocusNode? _ownFocus;
  final _hasFocus = ValueNotifier<bool>(false);

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  void _onFocusChanged() => _hasFocus.value = _focus.hasFocus;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PhysicalTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocusChanged);
    _focus.addListener(_onFocusChanged);
    _onFocusChanged();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _ownFocus?.dispose();
    _hasFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resting = widget.color ?? PhysicalDefaults.surfaceColor(context);
    final shown = widget.enabled ? resting : DisabledLook.frosted(resting);
    final made = widget.material.tintedTo(shown);
    final radius = widget.borderRadius ??
        BorderRadius.circular(PhysicalDefaults.cornerRadius(context));
    final leading = widget.leading;
    final trailing = widget.trailing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focus.requestFocus : null,
      child: PhysicalFocusRing(
        isShown: _hasFocus,
        borderRadius: radius,
        child: PhysicalSurface(
          color: shown,
          material: widget.enabled ? made : DisabledLook.flattened(made),
          borderRadius: radius,
          child: Padding(
            padding: _Field.padding,
            child: Row(
              children: [
                if (leading != null) ...[leading, _Field.gap],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    style: widget.style,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textCapitalization: widget.textCapitalization,
                    inputFormatters: widget.inputFormatters,
                    obscureText: widget.obscureText,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    maxLines: widget.maxLines,
                    minLines: widget.minLines,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: _Field.hintAlpha),
                      ),
                      border: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: _Field.textPadding,
                    ),
                  ),
                ),
                if (trailing != null) ...[_Field.gap, trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
