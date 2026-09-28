/// The public half's seam to Send feedback.
///
/// Send feedback is a development-build-only screen, and it lives under
/// `lib/debug/internal/`. A screen that ships — Settings does — must never `import` that
/// directory directly, or it would depend on a file a trimmed source tree does not carry.
///
/// So this file, which ships, owns a nullable hook. It is `null` in every build that does
/// not install one — a plain clone, a store build, `flutter test` — and Settings simply
/// hides the row. `lib/debug/internal/send_feedback.dart` installs the real opener, and
/// `lib/debug/internal/main_debug.dart` is the entrypoint that calls it.
///
/// Same shape as the `DemoLogSink` seam in `app_log.dart`, and for the same reason.
library;

import 'package:flutter/widgets.dart';

/// What the sheet reports about where the tester was and what the app was set to.
///
/// Deliberately carries **no API key and no community name** — only an environment
/// *label*. Everything in this record is destined for a GitHub issue body.
class FeedbackContext {
  const FeedbackContext({
    required this.where,
    required this.environment,
    required this.togglesSummary,
    required this.platform,
    required this.versions,
  });

  /// Where the tester was when they hit the button — "Scenarios › locale", never
  /// "Settings", which is only where the button happens to live.
  final String where;

  /// The environment **label** (Demo / Production / Custom host). Never the key.
  final String environment;

  /// `FeatureToggles.summaryLine`.
  final String togglesSummary;

  /// "Android 14 · Pixel 7" — the device, resolved by the public half, which already
  /// holds the package info the About screen shows.
  final String platform;

  /// SDK version + sample version.
  final String versions;
}

/// Opens the Send feedback sheet. `null` unless an internal build installed one.
Future<void> Function(BuildContext context, FeedbackContext report)?
sampleFeedbackOpener;
