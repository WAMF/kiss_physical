import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiss_physical/src/surface/resize_snapshot.dart';

class _Painted {
  _Painted(this.snapshot);

  final ResizeSnapshot snapshot;
  int directDraws = 0;

  void at(Size size, {Object look = 'plain'}) {
    final recorder = ui.PictureRecorder();
    snapshot.paint(
      Canvas(recorder),
      size: size,
      area: (Offset.zero & size).inflate(4),
      pixelRatio: 2,
      look: look,
      draw: (canvas) {
        directDraws++;
        canvas.drawRect(Offset.zero & size, Paint());
      },
    );
    recorder.endRecording().dispose();
  }
}

void main() {
  testWidgets('draws a surface at rest directly every time', (tester) async {
    final painted = _Painted(ResizeSnapshot());
    addTearDown(painted.snapshot.dispose);

    painted
      ..at(const Size(100, 100))
      ..at(const Size(100, 100))
      ..at(const Size(100, 100));

    expect(painted.directDraws, 3);
  });

  testWidgets('draws once, then stretches, while growing evenly',
      (tester) async {
    final painted = _Painted(ResizeSnapshot());
    addTearDown(painted.snapshot.dispose);

    painted
      ..at(const Size(100, 100))
      ..at(const Size(102, 102))
      ..at(const Size(106, 106))
      ..at(const Size(112, 112))
      ..at(const Size(120, 120));

    expect(painted.directDraws, 2);
    await tester.pump();
  });

  testWidgets('takes a new picture once stretched too far', (tester) async {
    final painted = _Painted(ResizeSnapshot());
    addTearDown(painted.snapshot.dispose);

    painted
      ..at(const Size(100, 100))
      ..at(const Size(110, 110))
      ..at(const Size(130, 130))
      ..at(const Size(140, 140))
      ..at(const Size(160, 160));

    expect(painted.directDraws, 3);
    await tester.pump();
  });

  testWidgets('always draws directly while changing shape', (tester) async {
    final painted = _Painted(ResizeSnapshot());
    addTearDown(painted.snapshot.dispose);

    painted
      ..at(const Size(100, 20))
      ..at(const Size(110, 20))
      ..at(const Size(120, 20))
      ..at(const Size(130, 20));

    expect(painted.directDraws, 4);
    await tester.pump();
  });

  testWidgets('never shows a picture of another look', (tester) async {
    final painted = _Painted(ResizeSnapshot());
    addTearDown(painted.snapshot.dispose);

    painted
      ..at(const Size(100, 100))
      ..at(const Size(102, 102))
      ..at(const Size(104, 104), look: 'pressed');

    expect(painted.directDraws, 3);
    await tester.pump();
  });

  testWidgets('asks to be drawn properly once a resize may have ended',
      (tester) async {
    final painted = _Painted(ResizeSnapshot());
    addTearDown(painted.snapshot.dispose);
    var requests = 0;
    painted.snapshot.addListener(() => requests++);

    painted
      ..at(const Size(100, 100))
      ..at(const Size(102, 102));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(requests, 1);

    painted.at(const Size(102, 102));
    expect(painted.directDraws, 3);
  });
}
