import 'package:flutter/material.dart';
import 'package:kiss_physical/src/components/physical_defaults.dart';
import 'package:kiss_physical/src/material/physical_material.dart';
import 'package:kiss_physical/src/material/physical_texture.dart';
import 'package:kiss_physical/src/surface/physical_surface.dart';

/// A physical panel that lies flush with what is behind it, or floats above
/// it and casts a shadow.
class PhysicalPanel extends StatelessWidget {
  /// Creates a panel behind [child], rounded on every corner.
  const PhysicalPanel({
    required this.child,
    this.color,
    this.borderRadius,
    this.isRaised = false,
    this.texture = PhysicalTexture.none,
    super.key,
  }) : _isDocked = false;

  /// Creates a panel docked to the bottom edge behind [child]: rounded on
  /// its top corners, clipped to them, and padded for the bottom safe area.
  const PhysicalPanel.bottom({
    required this.child,
    this.color,
    this.isRaised = false,
    this.texture = PhysicalTexture.none,
    super.key,
  })  : borderRadius = null,
        _isDocked = true;

  /// What the panel holds.
  final Widget child;

  /// The colour of the panel. Defaults to the secondary background of the
  /// nearest `SemanticColors`, or the surface colour of the theme.
  final Color? color;

  /// The corner radii of the panel. Defaults to the large corner radius of
  /// the nearest `Layout`, or of the standard layout.
  final BorderRadius? borderRadius;

  /// Whether the panel floats above its parent and casts a shadow.
  final bool isRaised;

  /// What the panel is made of, plain unless a texture is given.
  final PhysicalTexture texture;

  final bool _isDocked;

  BorderRadius _radiusIn(BuildContext context) {
    final radius = Radius.circular(PhysicalDefaults.cornerRadius(context));
    return _isDocked
        ? BorderRadius.vertical(top: radius)
        : borderRadius ?? BorderRadius.all(radius);
  }

  @override
  Widget build(BuildContext context) {
    return PhysicalSurface(
      color: color ?? PhysicalDefaults.surfaceColor(context),
      material:
          (isRaised ? PhysicalMaterial.floatingPanel : PhysicalMaterial.panel)
              .withTexture(texture),
      borderRadius: _radiusIn(context),
      clipBehavior: _isDocked ? Clip.hardEdge : Clip.none,
      child: _isDocked
          ? SafeArea(top: false, left: false, right: false, child: child)
          : child,
    );
  }
}
