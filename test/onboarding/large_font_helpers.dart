import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The matrix of the large-font tests and the helpers that check that every
/// action of a screen can be reached. Shared by `large_font_test.dart` and the
/// large-font tests of other features.

/// Small screens of the matrix.
const largeFontSizes = [Size(320, 640), Size(360, 740), Size(411, 800)];

/// System font scales of the matrix.
const largeFontScales = [1.3, 1.5, 2.0, 3.0];

/// UI languages of the matrix.
const largeFontLanguages = ['en', 'pl'];

/// Sets the screen [size], the font [scale] and the UI language [lang] of
/// [tester] for one test.
void configure(WidgetTester tester, String lang, double scale, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.localesTestValue = [Locale(lang)];
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
}

/// Scrolls the last scrollable until [finder] is built.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  final list = scrollables.last;
  for (final delta in [300.0, -300.0]) {
    for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
      await tester.drag(list, Offset(0, delta));
      await tester.pump();
    }
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Scrolls to [finder], checks that it is fully visible and not covered by
/// the bottom bar, and optionally taps it.
Future<void> reach(
  WidgetTester tester,
  Finder finder, {
  bool tap = true,
  bool settle = true,
}) async {
  await scrollTo(tester, finder);
  expect(finder, findsOneWidget, reason: 'not found: $finder');
  await tester.ensureVisible(finder);
  // A screen with an endless progress animation never settles.
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(seconds: 1));
  final rect = tester.getRect(finder);
  final screen = tester.view.physicalSize;
  var bottom = screen.height;
  final nav = find.byType(NavigationBar).hitTestable();
  final inNav = find
      .descendant(of: find.byType(NavigationBar), matching: finder)
      .evaluate()
      .isNotEmpty;
  if (nav.evaluate().isNotEmpty && !inNav) bottom = tester.getTopLeft(nav).dy;
  expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
  expect(rect.right, lessThanOrEqualTo(screen.width), reason: '$finder');
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
  // A tile taller than the visible area is aligned to the top of the list;
  // it must show at least as much as a finger needs (48 px) or all of it.
  final visible = rect.intersect(Rect.fromLTWH(0, 0, screen.width, bottom));
  expect(
    visible.height,
    greaterThanOrEqualTo(rect.height < 48 ? rect.height : 48),
    reason: 'hidden: $finder',
  );
  if (!tap) return;
  if (rect.bottom <= bottom) {
    await tester.tap(finder);
  } else {
    await tester.tapAt(visible.center);
  }
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(seconds: 1));
}
