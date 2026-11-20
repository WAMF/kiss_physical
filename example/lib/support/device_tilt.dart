import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

/// Lets a use case leave "down" to the device it is running on.
abstract final class DeviceTilt {
  static const _label = 'Follow device tilt';

  /// Whether this device can feel which way up it is held.
  static bool get isFelt =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// A knob for whether water and flames follow the device as it is
  /// tilted, on by default where the device can feel it. While it is on
  /// the use case's own "down" controls are set aside.
  static bool knob(BuildContext context) {
    return context.knobs.boolean(label: _label, initialValue: isFelt);
  }
}
