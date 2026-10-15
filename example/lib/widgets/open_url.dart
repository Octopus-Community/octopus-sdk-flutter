import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] with whatever app claims it; when nothing on the device does — the bare
/// AOSP emulator images the QA pipeline runs on ship with neither a browser nor a mail
/// client — copies it to the clipboard and says so, instead of leaving a dead button on
/// the screen that was about to file a report.
///
/// Ported iso from the Android sample (`ui/components/OpenUrl.kt`, PR #488/#489).
///
/// Not browser-only: `mailto:` links from the Community tab come through here too, which
/// is why the message below names no particular kind of app.
Future<void> openUrlOrCopy(
  BuildContext context,
  String url, {
  required String clipLabel,
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    final uri = Uri.parse(url);
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    if (uri.hasScheme && (!isWeb || uri.host.isNotEmpty)) {
      // Browser views accept only HTTP(S); mailto/tel/custom links need the OS.
      final effectiveMode = mode == LaunchMode.inAppBrowserView && !isWeb
          ? LaunchMode.externalApplication
          : mode;
      opened = await launchUrl(uri, mode: effectiveMode);
    }
  } on PlatformException {
    opened = false;
  } on MissingPluginException {
    // `flutter test` and any host without the plugin registered.
    opened = false;
  } on FormatException {
    opened = false;
  } on ArgumentError {
    opened = false;
  }
  if (opened) return;

  await Clipboard.setData(ClipboardData(text: url));
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'No app on this device can open that link — '
        'copied to the clipboard ($clipLabel)',
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}
