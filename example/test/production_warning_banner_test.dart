import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/main.dart'
    show octopusDemoAppBuilder, octopusDemoAppBuilderWith;
import 'package:octopus_sdk_flutter_example/widgets/production_warning_banner.dart';

// The banner is internal-builds-only since 2026-08-26
// (`octopusShowsServerWarning` = `OCTOPUS_INTERNAL` define AND no host
// injected): a client building the mirrored sample nominally targets
// production with their own key, so for them the banner must never appear.
// `flutter test` runs with no dart-defines at all, which is exactly that
// client path — the first test locks it. The remaining tests force the
// banner on through `octopusDemoAppBuilderWith(showWarning: true)`, the
// test-only injection point, because no define can flip the real predicate
// from inside a default `flutter test` run.
//
// Why the semantics test exists: an on-device `uiautomator` pass (QA lot 3,
// D7.3) repeatedly failed to surface the banner's text in the Android
// accessibility tree across 3 separate runs (including a clean
// uninstall/reinstall), while the on-screen layout geometry it *could*
// capture stayed consistent with the banner actually occupying its expected
// height. Root cause (found host-side, bisected in this suite's harness):
// the banner was painted BEFORE the Navigator, whose route machinery blocks
// the semantics of everything painted before it — even a bare
// `Semantics(label:)` in that position produced no node. The fix in
// `octopusDemoAppBuilder` paints the banner after the Navigator (list order)
// while keeping it visually on top (`verticalDirection.up`); the semantics
// test below locks the node's presence so the regression cannot silently
// return.
void main() {
  // Pumps the real `MaterialApp.builder` wiring — the same Column layout the
  // app ships, via [octopusDemoAppBuilderWith] (report 18's M2: import the
  // real builder, never a hand-copied duplicate). The banner is a `Column`
  // sibling ABOVE the routed content, i.e. outside the Navigator/Overlay
  // that dialogs and modal sheets render into, so it structurally cannot be
  // painted over by anything the routed content pushes, no z-order stacking
  // involved; a regression in the real builder now fails these tests too,
  // which a copy could never catch.
  Widget appWithBanner({required Widget home, bool? showWarning}) =>
      MaterialApp(
        home: home,
        builder: showWarning == null
            ? octopusDemoAppBuilder
            : (context, child) => octopusDemoAppBuilderWith(
                context,
                child,
                showWarning: showWarning,
              ),
      );

  testWidgets(
    'the banner renders NOTHING on the default (client-parity) path — '
    'flutter test injects no OCTOPUS_INTERNAL define, same as a public '
    'clone or a store build',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        appWithBanner(home: const Scaffold(body: SizedBox())),
      );

      // The real builder still mounts the widget, but it must collapse to
      // nothing: no size, no text, no semantics node.
      expect(find.byType(ProductionWarningBanner), findsOneWidget);
      expect(
        tester.getSize(find.byType(ProductionWarningBanner)),
        Size.zero,
        reason:
            'a client build must never see the warning banner — its nominal '
            'configuration IS the production server',
      );
      expect(find.textContaining('PRODUCTION SERVER'), findsNothing);
      expect(find.bySemanticsLabel('Production server warning'), findsNothing);

      semantics.dispose();
    },
  );

  testWidgets(
    'the production banner renders its warning text on an internal build '
    'targeting prod (forced through the test-only injection point)',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        appWithBanner(
          home: const Scaffold(body: SizedBox()),
          showWarning: true,
        ),
      );

      expect(find.byType(ProductionWarningBanner), findsOneWidget);
      expect(find.text('PRODUCTION SERVER — api.8pus.io'), findsOneWidget);
      expect(
        find.text(
          'Client communities may be reachable. DO NOT publish test content.',
        ),
        findsOneWidget,
      );

      // The banner must exist in the SEMANTICS tree, not just the widget
      // tree: painted before the Navigator it silently loses every node
      // (see the header comment), which is invisible to the widget-tree
      // assertions above. Its label AND its text content must both survive.
      expect(
        find.bySemanticsLabel('Production server warning'),
        findsOneWidget,
        reason:
            'banner lost its semantics node — was it moved back before '
            'the Navigator in octopusDemoAppBuilder?',
      );
      expect(
        find.bySemanticsLabel(RegExp('PRODUCTION SERVER')),
        findsOneWidget,
      );

      // And it must still be pinned at the very top: verticalDirection.up
      // only exists to keep the paint order fix from changing the layout.
      expect(tester.getTopLeft(find.byType(ProductionWarningBanner)).dy, 0);

      semantics.dispose();
    },
  );

  testWidgets(
    'the production banner stays rendered and above a modal bottom sheet '
    'once one is opened over it',
    (tester) async {
      await tester.pumpWidget(
        appWithBanner(
          home: const Scaffold(body: Center(child: _SheetOpener())),
          showWarning: true,
        ),
      );

      // Sanity: the banner is up, pinned at the very top, before anything
      // is tapped.
      expect(find.byType(ProductionWarningBanner), findsOneWidget);
      expect(tester.getTopLeft(find.byType(ProductionWarningBanner)).dy, 0);
      final bannerBottom = tester
          .getBottomLeft(find.byType(ProductionWarningBanner))
          .dy;

      // Open a real modal bottom sheet — the primitive every sample modal is
      // built on (the SDK sheet presentation, the pickers), not a synthetic
      // stand-in.
      await tester.tap(find.bySemanticsIdentifier('sheet-open-button'));
      await tester.pumpAndSettle();

      // The modal really is open.
      expect(find.byType(_TestSheet), findsOneWidget);

      // The banner is still there, unchanged, still pinned at the top —
      // opening the modal never removed or displaced it.
      expect(find.byType(ProductionWarningBanner), findsOneWidget);
      expect(find.text('PRODUCTION SERVER — api.8pus.io'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(ProductionWarningBanner)).dy, 0);
      expect(
        tester.getBottomLeft(find.byType(ProductionWarningBanner)).dy,
        bannerBottom,
      );

      // The literal D7.3 claim: the modal's own top edge sits at or below
      // the banner's bottom edge — the sheet never paints over the banner's
      // rows, regardless of how tall the sheet is dragged.
      final modalTop = tester.getTopLeft(find.byType(_TestSheet)).dy;
      expect(
        modalTop,
        greaterThanOrEqualTo(bannerBottom),
        reason: "the modal must never cover the banner's rows",
      );
    },
  );
}

/// Opens a plain modal bottom sheet — stands in for every modal the sample can
/// put over the banner.
class _SheetOpener extends StatelessWidget {
  const _SheetOpener();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'sheet-open-button',
      button: true,
      child: TextButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _TestSheet(),
        ),
        child: const Text('Open sheet'),
      ),
    );
  }
}

class _TestSheet extends StatelessWidget {
  const _TestSheet();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 400, child: Center(child: Text('Sheet content')));
}
