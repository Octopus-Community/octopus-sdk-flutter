/// The sample's shared design tokens and the small set of widgets built on
/// them — the Flutter half of the cross-sample design identity (Android, iOS,
/// Flutter, React Native and Unity all draw the same sample from these values).
///
/// Why a token file rather than `Theme.of(context)` everywhere: several of
/// these roles have no Material 3 counterpart at all (a "tinted band"
/// background, a success green, the dark code-block ground), and the ones that
/// do would resolve to whatever the Material default is on the current Flutter
/// version. Posing them explicitly is what keeps the five samples looking like
/// one product.
///
/// Nothing here is localized: the sample is English-only by design.
library;

import 'package:flutter/material.dart';

// ── Palette ────────────────────────────────────────────────────────────────

/// App bar, primary buttons (light mode), section-label text (both modes).
///
/// Refresh-2026 charter: navy, replacing the previous teal. 17.28:1 on white.
const Color sampleNavy = Color(0xFF0F1B2D);

/// The brand blue as a **fill**: switch tracks, segmented selection, chips —
/// light theme only. 3.50:1 on white — under the text-contrast floor, so this
/// value must never be a label or icon color; use [sampleAccentDark] for that
/// role in dark theme, via [sampleControlAccent]/[sampleAccent]. Its readable
/// ink is [sampleAccentInk] (4.56:1), where white would be 3.50:1.
const Color sampleAccentBlue = Color(0xFF1D88FE);

/// The accent role on dark surfaces: text, icons and control fills alike.
///
/// A lighter step of the brand blue — [sampleAccentBlue] is almost never
/// drawn on the dark page background; it lands on a raised container or on
/// its own 12-15% tint, where it falls to 3.28-4.02:1. This value reads
/// 7.21:1 on the dark page background and 4.74:1 over its own 15% navigation
/// indicator, the worst path in the app.
const Color sampleAccentDark = Color(0xFF6FB2FF);

/// The ink that reads on an accent fill, in both themes: 4.56:1 on
/// [sampleAccentBlue], 7.21:1 on [sampleAccentDark], where white would be
/// 3.50:1 and 2.21:1.
const Color sampleAccentInk = Color(0xFF142238);

/// Ground of a framed sample block (light mode). The charter's surfaces carry
/// no tint of their own — this is the plain light surface.
const Color sampleTint = Color(0xFFFFFFFF);

/// Danger text and icons (Disconnect, Reset data).
const Color sampleDanger = Color(0xFF9E243F);

/// Danger border / tint — the blocking Community band, the Danger zone frame.
const Color sampleDangerBorder = Color(0xFFE4B7C0);
const Color sampleDangerTint = Color(0xFFFCEDEF);

/// Degraded state (read-only, warning band) — the band's *text* color, not
/// the guest-status role (see [sampleGuestAmber], a distinct token for a
/// distinct role even though both are amber).
const Color sampleAmber = Color(0xFF7A4B08);
const Color sampleAmberBorder = Color(0xFFF1D390);
const Color sampleAmberTint = Color(0xFFFFF7E6);

/// Guest connection status (Home's CONNECTED/GUEST/OFF chip and dot) — fixed
/// `#D99A2B` in both brightnesses per the 2026-08-28 design delta. Distinct
/// from [sampleAmber]/[sampleAmberFor], which color the degraded-band body
/// text and stay contrast-adjusted per brightness: same amber family, a
/// different role that does not need the same adjustment.
const Color sampleGuestAmber = Color(0xFFD99A2B);

/// Guest connection status **text** — `#8A5A00`, the darker member of the
/// same amber pair as [sampleGuestAmber]. Spec 02 draws the GUEST chip's dot
/// and text in two different shades of the same hue (the dot stays the
/// brighter `#D99A2B`, only the label text uses this darker one) rather than
/// painting both the same color.
const Color sampleGuestAmberText = Color(0xFF8A5A00);

/// Success / connected.
const Color sampleGreen = Color(0xFF30B653);

/// Dark-mode ground.
const Color sampleDarkSurface = Color(0xFF0B1421);

/// Ground of the `Result` code block on a scenario screen.
const Color sampleCodeSurface = Color(0xFF0F1B2D);

/// The accent as a **label**: nav-item accent, section-label and API-pill
/// text, app-bar-adjacent text buttons, row icons, outline buttons. Navy in
/// light theme, [sampleAccentDark] in dark — navy measures 1.08:1 on the dark
/// surface, and [sampleAccentBlue] falls under the floor once it lands on a
/// raised container (see [sampleAccentDark]'s doc). Never [sampleAccentBlue]
/// directly: that value is fill-only, per the charter's contrast rule.
Color sampleAccent(Brightness brightness) =>
    brightness == Brightness.dark ? sampleAccentDark : sampleNavy;

/// The accent as a control **fill**: switch tracks, radio marks, the
/// selected segment/chip. A fill answers to a lower bar than a label, so
/// light theme keeps the saturated [sampleAccentBlue] that would be
/// unreadable as text; dark theme takes the same lighter step as
/// [sampleAccent], so one accent hue is in force per theme rather than two.
Color sampleControlAccent(Brightness brightness) =>
    brightness == Brightness.dark ? sampleAccentDark : sampleAccentBlue;

/// The ink that reads on a [sampleAccent] fill (navy in light,
/// [sampleAccentDark] in dark) — the primary pill's label — and on the
/// switch thumb, which sits over [sampleControlAccent] but is a graphical
/// control rather than text, so it answers to the 3:1 non-text floor, not
/// 4.5:1. White in light theme (17.28:1 on navy; 3.50:1 is the thumb's
/// figure over the light [sampleControlAccent] track, never used for actual
/// text on that fill — see [sampleOnControlAccent]); [sampleAccentInk] in
/// dark (7.21:1 on [sampleAccentDark], where white would be 2.21:1).
Color sampleOnAccentColor(Brightness brightness) =>
    brightness == Brightness.dark ? sampleAccentInk : Colors.white;

/// The ink that reads as **text** on a [sampleControlAccent] fill — e.g. a
/// selected segmented-button label. [sampleAccentInk] in both themes:
/// 4.56:1 on [sampleAccentBlue] (the light-theme fill), 7.21:1 on
/// [sampleAccentDark] (the dark-theme fill) — white would be 3.50:1 in
/// light, clearing only the 3:1 non-text floor [sampleOnAccentColor] relies
/// on for the switch thumb, never the 4.5:1 a label needs.
Color sampleOnControlAccent(Brightness _) => sampleAccentInk;

/// Ground of a framed block under [brightness] — the charter's plain surface
/// color, not a tint: white in light, the dark card surface in dark.
Color sampleTintFor(Brightness brightness) =>
    brightness == Brightness.dark ? const Color(0xFF142238) : sampleTint;

/// Border of a framed block under [brightness]. Charter surfaces are
/// borderless in both brightnesses — the parameter is intentionally unused,
/// kept so call sites read the same as every other `...For(brightness)`
/// token and stay untouched if a future surface needs a real border back.
Color sampleBorderFor(Brightness _) => Colors.transparent;

/// Danger color that holds contrast under [brightness] (the light-mode
/// [sampleDanger] measures under 4.5:1 on the dark ground).
Color sampleDangerFor(Brightness brightness) =>
    brightness == Brightness.dark ? const Color(0xFFFF3366) : sampleDanger;

/// Amber that holds contrast under [brightness], same reason as above.
Color sampleAmberFor(Brightness brightness) =>
    brightness == Brightness.dark ? const Color(0xFFF1D390) : sampleAmber;

/// Success green that holds contrast under [brightness].
Color sampleGreenFor(Brightness brightness) =>
    brightness == Brightness.dark ? const Color(0xFF6FD98A) : sampleGreen;

/// The monospace family used by every code block and API pill. `monospace`
/// resolves to the platform's own (Roboto Mono / Menlo) — no bundled font.
const String sampleMonoFamily = 'monospace';

// ── App bar ────────────────────────────────────────────────────────────────

/// App-bar title: the screen name plus the platform badge glued to it.
///
/// The badge is part of the *title*, not an action: it says which sample you
/// are holding, which matters the moment three of them are installed on one
/// device. Monochrome white glyph on a translucent white pill — never a
/// multicolor platform logo, never a bare text chip.
class SampleAppBarTitle extends StatelessWidget {
  const SampleAppBarTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      const PlatformBadge(),
    ],
  );
}

/// The « Flutter » platform pill.
///
/// `Icons.flutter_dash` is Material's own monochrome Flutter glyph, so the
/// badge needs no bundled asset and cannot drift into the multicolor logo.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({super.key});

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xD9FFFFFF); // white, .85
    return Semantics(
      identifier: 'platform-badge',
      label: 'Flutter',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF), // white .12
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flutter_dash, size: 13, color: fg),
            SizedBox(width: 4),
            Text(
              'Flutter',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Building blocks ────────────────────────────────────────────────────────

/// A labelled group of rows on a framed, tinted ground — the Config sections,
/// Home's `Current configuration`, the scenario detail zones.
class SampleSection extends StatelessWidget {
  const SampleSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.tone = SampleTone.neutral,
    this.identifier,
  });

  final String title;
  final Widget child;

  /// Optional control on the header line (an `Edit` button, a quick toggle).
  final Widget? trailing;
  final SampleTone tone;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colors = tone.resolve(brightness);
    final section = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          // The frame paints a background, and a ListTile-family widget paints
          // its own background + ink on the NEAREST Material ancestor — which
          // would be behind that frame, hiding the splash. A transparent
          // Material right here gives any tile inside the section its own ink
          // surface in front of the frame (and satisfies the framework
          // assertion that flags the sandwich).
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
    if (identifier == null) return section;
    return Semantics(identifier: identifier!, container: true, child: section);
  }
}

/// Semantic tone of a band / framed block.
enum SampleTone { neutral, danger, warning, success }

/// The three colors a [SampleTone] resolves to under a brightness.
class SampleToneColors {
  const SampleToneColors(this.background, this.border, this.foreground);
  final Color background;
  final Color border;
  final Color foreground;
}

extension SampleToneX on SampleTone {
  SampleToneColors resolve(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      SampleTone.neutral => SampleToneColors(
        sampleTintFor(brightness),
        sampleBorderFor(brightness),
        // A label, not a fill: navy in light theme, the lighter accent step
        // in dark — see [sampleAccent]. [sampleAccentBlue] would fall under
        // the 4.5:1 floor once it lands on the section's own surface.
        sampleAccent(brightness),
      ),
      SampleTone.danger => SampleToneColors(
        dark ? const Color(0xFF2A171C) : sampleDangerTint,
        dark ? const Color(0xFF5E3038) : sampleDangerBorder,
        sampleDangerFor(brightness),
      ),
      SampleTone.warning => SampleToneColors(
        dark ? const Color(0xFF2A2216) : sampleAmberTint,
        dark ? const Color(0xFF5C4A24) : sampleAmberBorder,
        sampleAmberFor(brightness),
      ),
      SampleTone.success => SampleToneColors(
        dark ? const Color(0xFF16281B) : const Color(0xFFE7F6EA),
        dark ? const Color(0xFF2E5537) : const Color(0xFFB7E2C2),
        sampleGreenFor(brightness),
      ),
    };
  }
}

/// A `label → value` row, the unit of every summary block in the sample.
class SampleKeyValue extends StatelessWidget {
  const SampleKeyValue(this.label, this.value, {super.key, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? theme.textTheme.bodySmall?.copyWith(
                      fontFamily: sampleMonoFamily,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The monospace pill carrying the name of the SDK API a scenario calls
/// (`connectUser`, `navigateToOctopusHome`, …) — the thing a developer scans
/// a scenario list for.
class ApiPill extends StatelessWidget {
  const ApiPill(this.api, {super.key});

  final String api;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: sampleTintFor(brightness),
        border: Border.all(color: sampleBorderFor(brightness)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        api,
        style: TextStyle(
          fontFamily: sampleMonoFamily,
          fontSize: 11.5,
          // A label, not a fill — same accent/brightness split as
          // [SampleTone.neutral]'s section-label text.
          color: sampleAccent(brightness),
        ),
      ),
    );
  }
}

/// A coloured status dot — CONNECTED / GUEST / OFF, READY.
class SampleDot extends StatelessWidget {
  const SampleDot(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A navigation row: icon, title, current-value subtitle, chevron. The only
/// row shape Settings uses — every line is a navigation, so every line has a
/// chevron.
class SampleNavTile extends StatelessWidget {
  const SampleNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.identifier,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? identifier;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger
        ? sampleDangerFor(theme.brightness)
        : theme.colorScheme.onSurface;
    // Same reason as in [SampleSection]: this tile is also used inside bare
    // decorated frames, so it carries its own transparent ink surface.
    final tile = Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
    if (identifier == null) return tile;
    return Semantics(identifier: identifier!, button: true, child: tile);
  }
}

/// A dark monospace block — the raw `OctopusResult`, a debug payload.
class SampleCodeBlock extends StatelessWidget {
  const SampleCodeBlock(this.text, {super.key, this.identifier});

  final String text;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sampleCodeSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      // Wraps rather than scrolls sideways. Inside the scenario's vertical
      // ListView a horizontal scroller was a truncated single line for anyone
      // who did not think to drag it — and a result payload is prose plus a
      // symbol name, which reads fine wrapped. Selectable so a tester can lift
      // the payload into a ticket.
      child: SelectableText(
        text,
        // White at 92% opacity, not a fixed hex — same ink the Android
        // sample's `CodeResultBlock` uses on its own `CodeBlock` ground.
        style: TextStyle(
          fontFamily: sampleMonoFamily,
          fontSize: 12,
          height: 1.45,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
    if (identifier == null) return block;
    return Semantics(identifier: identifier!, container: true, child: block);
  }
}

/// A sample-layer status band: cause, then one action. Never a modal dialog
/// for a network error, never a toast for a blocking state.
class SampleBand extends StatelessWidget {
  const SampleBand({
    super.key,
    required this.tone,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.identifier,
  });

  final SampleTone tone;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? identifier;

  /// The band's cause, read at a glance — never a bare "APP" text badge: the
  /// grammar (spec 04/08) is an icon, not a source label.
  IconData get _icon => switch (tone) {
    SampleTone.danger => Icons.warning_amber_rounded,
    SampleTone.warning => Icons.lock_outline,
    SampleTone.success => Icons.check_circle_outline,
    SampleTone.neutral => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = tone.resolve(theme.brightness);
    final band = Container(
      width: double.infinity,
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Icon(_icon, size: 18, color: colors.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.foreground,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: colors.foreground),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (identifier == null) return band;
    return Semantics(identifier: identifier!, container: true, child: band);
  }
}

/// Style for a danger action: white pill, danger border, danger text.
ButtonStyle sampleDangerButtonStyle(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  final danger = sampleDangerFor(brightness);
  return OutlinedButton.styleFrom(
    foregroundColor: danger,
    side: BorderSide(
      color: brightness == Brightness.dark
          ? const Color(0xFF5E3038)
          : sampleDangerBorder,
    ),
    minimumSize: const Size.fromHeight(48),
    shape: const StadiumBorder(),
  );
}

/// Shows the sample's transient confirmation (grammar D): a reversible action
/// that already happened, with an Undo when one exists.
void showSampleSnackBar(
  BuildContext context,
  String message, {
  String? undoLabel,
  VoidCallback? onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // Snackbars QUEUE: each one waits out the previous, so a screen where the
  // user flips a setting a few times (Appearance, Language) ends up showing a
  // toast long after the gesture, across tab changes. Drop whatever is on
  // screen and state the duration rather than inheriting it.
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      // `persist` DEFAULTS TO `action != null`: a snackbar carrying an action
      // never auto-dismisses, and `duration` is then dead code — the timer
      // fires and returns without hiding anything. That is what kept "Theme
      // applied" on screen across tab changes. Opt out explicitly.
      persist: false,
      action: (undoLabel != null && onUndo != null)
          ? SnackBarAction(label: undoLabel, onPressed: onUndo)
          : null,
    ),
  );
}
