import 'package:flutter/services.dart';
import 'package:kiss_physical/src/light/up_vector_filter.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// Asks the device which way round it is showing the interface.
///
/// This is the system's own answer, so it holds with rotation locked, in a
/// window of another shape, and at the very moment the interface turns.
class ScreenTurnReader {
  /// Creates a reader of the interface orientation.
  const ScreenTurnReader();

  /// The current turn, or null where the device cannot say.
  Future<ScreenTurn?> read() async {
    try {
      final orientation = await NativeDeviceOrientationCommunicator()
          .orientation(defaultOrientation: NativeDeviceOrientation.unknown);
      return _turns[orientation];
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static const _turns = {
    NativeDeviceOrientation.portraitUp: ScreenTurn.upright,
    NativeDeviceOrientation.portraitDown: ScreenTurn.upsideDown,
    NativeDeviceOrientation.landscapeLeft: ScreenTurn.topToLeft,
    NativeDeviceOrientation.landscapeRight: ScreenTurn.topToRight,
  };
}
