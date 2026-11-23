import 'dart:async';
import 'dart:ui';

/// Repeats an action for as long as something is held, slowly at first and
/// then faster, the way a held key or a stepper does.
class HoldRepeater {
  /// Creates a repeater that calls [onRepeat] while it is running.
  HoldRepeater({
    required this.onRepeat,
    this.delay = defaultDelay,
    this.slowest = defaultSlowest,
    this.fastest = defaultFastest,
    this.quickening = defaultQuickening,
  }) : assert(
          quickening > 0 && quickening <= 1,
          'quickening must be in (0, 1]',
        );

  /// Called for each repeat.
  final VoidCallback onRepeat;

  /// How long the hold lasts before the first repeat.
  final Duration delay;

  /// The wait between the first repeats.
  final Duration slowest;

  /// The shortest the wait between repeats becomes.
  final Duration fastest;

  /// What the wait is multiplied by after each repeat, so 1 keeps a steady
  /// pace and less speeds up.
  final double quickening;

  /// The wait before the first repeat when none is given.
  static const defaultDelay = Duration(milliseconds: 400);

  /// The wait between the first repeats when none is given.
  static const defaultSlowest = Duration(milliseconds: 160);

  /// The shortest wait between repeats when none is given.
  static const defaultFastest = Duration(milliseconds: 40);

  /// How fast the repeats quicken when no rate is given.
  static const defaultQuickening = 0.85;

  Timer? _timer;
  var _repeats = 0;

  /// How many times the action has repeated since the hold began.
  int get repeats => _repeats;

  /// Whether a hold is under way.
  bool get isRunning => _timer != null;

  /// Begins a hold. The count of repeats starts again from nothing.
  void start() {
    stop();
    _repeats = 0;
    _timer = Timer(delay, () => _repeat(slowest));
  }

  /// Ends the hold. The count of repeats is kept until the next hold.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _repeat(Duration wait) {
    _repeats++;
    _timer = Timer(wait, () => _repeat(_quicker(wait)));
    onRepeat();
  }

  Duration _quicker(Duration wait) {
    final quicker = wait * quickening;
    return quicker < fastest ? fastest : quicker;
  }
}
