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

import 'dart:math' as math;

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

// Dark ladder, aligned on the octopuscommunity.com site: ink → navy →
// navy-2, each step a bluish navy rather than a neutral grey, so depth reads
// as depth instead of flat grey slabs.
// Dark role → flat sRGB → OctopusTheme token (shell-only if absent).
// Page / onPrimary → #070D17 (site `--ink`) → background / onPrimary.
// Card → #0F1B2D (brand navy) → shell surface (SDK has no surface token).
// Hairline → #1E2A3D (site `--line`) → shell outlineVariant (SDK has no
// divider token).
// Strong hairline → #243349 → shell only (current-configuration frame).
// Elevated → #16243A (site `--navy-2`) → shell overlays (SDK has no elevated
// token).
// Hover / pressed → #1D2E48 → shell states (SDK has no hover token).
// Heading → #F2F6FC → shell onSurface (SDK has no gray ramp).
// Body → #E9F0FA → shell body text (SDK has no gray ramp).
// Caption → #8C9AB0 → shell onSurfaceVariant (SDK has no gray ramp).
// Accent → #66B0FF → primaryMain / link.
// Tinted container → #16273C → primaryLowContrast.
// Progress / focus → #8FC6FF → primaryHighContrast.
//
// Text ladder measured on page / card / elevated / hover: heading
// 17.95 / 15.94 / 14.37 / 12.60:1, body 16.97 / 15.07 / 13.59 / 11.92:1,
// caption 6.83 / 6.06 / 5.46 / 4.79:1 — the caption clears 4.5:1 on hover too.
const Color sampleDarkSurface = Color(0xFF070D17);
const Color sampleDarkCard = sampleNavy;
// Decorative only (1.06–1.35:1 on the ladder) — never a control boundary.
const Color sampleDarkDivider = Color(0xFF1E2A3D);
// One step above [sampleDarkDivider], for a block that has to stand out from
// its neighbours. Still decorative (1.22:1 on [sampleDarkElevated]).
const Color sampleDarkBorderStrong = Color(0xFF243349);
const Color sampleDarkElevated = Color(0xFF16243A);
const Color sampleDarkHover = Color(0xFF1D2E48);
const Color sampleDarkText = Color(0xFFF2F6FC);
const Color sampleDarkBody = Color(0xFFE9F0FA);
const Color sampleDarkSecondary = Color(0xFF8C9AB0);
const Color sampleAccentDark = Color(0xFF66B0FF);
const Color sampleDarkPrimaryLow = Color(0xFF16273C);
const Color sampleDarkPrimaryHigh = Color(0xFF8FC6FF);

// off-table: non-text control boundary ≥ 3:1 (WCAG 1.4.11)
// 4.65:1 on page, 4.13:1 on card, 3.72:1 on elevated, 3.27:1 on hover —
// the bluish hairlines above measure 1.06–1.52:1 and cannot carry this role.
const Color sampleDarkControlOutline = Color(0xFF6A7D9B);

// off-table: the light twin of [sampleDarkControlOutline], the Android
// sample's light scheme `outline` (grey/500). 5.06:1 on the white card and
// page — the light framed-block border is transparent ([sampleBorderFor]) and
// cannot carry a control boundary.
const Color sampleLightControlOutline = Color(0xFF6D6E78);

// off-table: semantic error colour, AA on card and elevated
const Color sampleDarkDanger = Color(0xFFFF6B8F);
// off-table: Material semantic error foreground
const Color sampleDarkError = Color(0xFFFFB4AB);
// off-table: Material semantic ink on error
const Color sampleDarkOnError = Color(0xFF690005);
// off-table: semantic warning text
const Color sampleDarkAmber = Color(0xFFF1D390);
// off-table: semantic success text
const Color sampleDarkGreen = Color(0xFF6FD98A);
// off-table: semantic error band fill
const Color sampleDarkDangerTint = Color(0xFF2A171C);
// off-table: semantic error border
const Color sampleDarkDangerBorder = Color(0xFF5E3038);
// off-table: semantic warning band fill
const Color sampleDarkAmberTint = Color(0xFF2A2216);
// off-table: semantic warning border
const Color sampleDarkAmberBorder = Color(0xFF5C4A24);
// off-table: semantic success band fill
const Color sampleDarkGreenTint = Color(0xFF16281B);
// off-table: semantic success border
const Color sampleDarkGreenBorder = Color(0xFF2E5537);

/// Ink on the light theme's control fills; preserved for light-mode contrast.
const Color sampleAccentInk = Color(0xFF142238);

// off-table: translucent accent chip fill, 10% Signal blue
Color get sampleDarkChipFill => sampleAccentDark.withValues(alpha: 0.10);
// off-table: translucent accent badge border, 28% Signal blue. Decorative
// (1.69–1.75:1 on the ladder): non-interactive badges only (platform badge,
// API and source pills, the Custom marker). An interactive chip takes
// [sampleControlOutlineFor], or [sampleAccentDark] when selected.
Color get sampleDarkChipBorder => sampleAccentDark.withValues(alpha: 0.28);

// off-table: the dark-theme radial halo, the brand blue at 12%. Flattens to
// #0A1C33 over the page at its peak, where [sampleDarkSecondary] still reads
// 6.0:1, and the app-bar title and icons ([sampleDarkText]) far more.
Color get sampleDarkHalo => sampleAccentBlue.withValues(alpha: 0.12);

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
// off-table: semantic guest status dot
const Color sampleGuestAmber = Color(0xFFD99A2B);

/// Guest connection status **text** — `#8A5A00`, the darker member of the
/// same amber pair as [sampleGuestAmber]. Spec 02 draws the GUEST chip's dot
/// and text in two different shades of the same hue (the dot stays the
/// brighter `#D99A2B`, only the label text uses this darker one) rather than
/// painting both the same color.
// off-table: semantic guest status text
const Color sampleGuestAmberText = Color(0xFF8A5A00);

/// Success / connected.
// off-table: semantic connected status
const Color sampleGreen = Color(0xFF30B653);

/// Ground of the `Result` code block on a scenario screen.
const Color sampleCodeSurface = Color(0xFF0F1B2D);

/// The accent as a **label**: nav-item accent, section-label and API-pill
/// text, app-bar-adjacent text buttons, row icons, outline buttons. Navy in
/// light theme, [sampleAccentDark] in dark. The saturated [sampleAccentBlue]
/// remains reserved for light-theme control fills.
Color sampleAccent(Brightness brightness) =>
    brightness == Brightness.dark ? sampleAccentDark : sampleNavy;

/// The accent as a control **fill**: switch tracks, radio marks, the
/// selected segment/chip. A fill answers to a lower bar than a label, so
/// light theme keeps the saturated [sampleAccentBlue] that would be
/// unreadable as text; dark theme takes the same lighter step as
/// [sampleAccent], so one accent hue is in force per theme rather than two.
Color sampleControlAccent(Brightness brightness) =>
    brightness == Brightness.dark ? sampleAccentDark : sampleAccentBlue;

/// Foreground on primary controls: white in light mode, Signal ink in dark.
Color sampleOnAccentColor(Brightness brightness) =>
    brightness == Brightness.dark ? sampleDarkSurface : Colors.white;

/// Text on selected control fills, with the light theme's ink preserved.
Color sampleOnControlAccent(Brightness brightness) =>
    brightness == Brightness.dark ? sampleDarkSurface : sampleAccentInk;

/// Ordinary card surface.
Color sampleTintFor(Brightness brightness) =>
    brightness == Brightness.dark ? sampleDarkCard : sampleTint;

/// Navy hairline in dark mode; light cards remain borderless.
///
/// Decorative only — framed blocks, clickable card frames, the non-interactive
/// API pill. A card is identified by its title and content, so its frame is
/// not the boundary WCAG 1.4.11 asks to hold 3:1. An unfilled control whose
/// outline *is* its only boundary takes [sampleControlOutlineFor] instead.
Color sampleBorderFor(Brightness brightness) =>
    brightness == Brightness.dark ? sampleDarkDivider : Colors.transparent;

/// Boundary of an unfilled control — outlined button or pill, unselected chip
/// or segment — held to 3:1 against the surface in both themes (WCAG 1.4.11):
/// [sampleDarkControlOutline] 3.27–4.65:1 on the dark ladder,
/// [sampleLightControlOutline] 5.06:1 on white.
Color sampleControlOutlineFor(Brightness brightness) =>
    brightness == Brightness.dark
    ? sampleDarkControlOutline
    : sampleLightControlOutline;

/// Danger color that holds contrast under [brightness] (the light-mode
/// [sampleDanger] measures under 4.5:1 on the dark ground).
Color sampleDangerFor(Brightness brightness) =>
    brightness == Brightness.dark ? sampleDarkDanger : sampleDanger;

/// Amber that holds contrast under [brightness], same reason as above.
Color sampleAmberFor(Brightness brightness) =>
    brightness == Brightness.dark ? sampleDarkAmber : sampleAmber;

/// Success green that holds contrast under [brightness].
Color sampleGreenFor(Brightness brightness) =>
    brightness == Brightness.dark ? sampleDarkGreen : sampleGreen;

/// The monospace family used by every code block and API pill. `monospace`
/// resolves to the platform's own (Roboto Mono / Menlo) — no bundled font.
const String sampleMonoFamily = 'monospace';

// ── App bar ────────────────────────────────────────────────────────────────

/// App-bar title: the screen name plus the platform badge glued to it.
///
/// The badge is part of the *title*, not an action: it says which sample you
/// are holding, which matters the moment three of them are installed on one
/// device. Signal blue in dark mode; translucent white in light mode.
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? sampleAccentDark : const Color(0xD9FFFFFF);
    return Semantics(
      identifier: 'platform-badge',
      label: 'Flutter',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: dark ? sampleDarkChipFill : const Color(0x1FFFFFFF),
          border: dark ? Border.all(color: sampleDarkChipBorder) : null,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flutter_dash, size: 13, color: fg),
            const SizedBox(width: 4),
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
    this.borderColor,
  });

  final String title;
  final Widget child;

  /// Optional control on the header line (an `Edit` button, a quick toggle).
  final Widget? trailing;
  final SampleTone tone;
  final String? identifier;

  /// Overrides the [tone]'s frame, for a block that has to stand out from its
  /// neighbours (Home's `Current configuration` in dark theme). Null keeps the
  /// tone's border.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colors = tone.resolve(brightness);
    final neutralDark =
        brightness == Brightness.dark && tone == SampleTone.neutral;
    final section = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: borderColor ?? colors.border),
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
                    // Dark theme: a neutral card's title is primary text, not
                    // the accent, so it never reads as a link on the navy.
                    color: neutralDark ? sampleDarkText : colors.foreground,
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
        dark ? sampleDarkDangerTint : sampleDangerTint,
        dark ? sampleDarkDangerBorder : sampleDangerBorder,
        sampleDangerFor(brightness),
      ),
      SampleTone.warning => SampleToneColors(
        dark ? sampleDarkAmberTint : sampleAmberTint,
        dark ? sampleDarkAmberBorder : sampleAmberBorder,
        sampleAmberFor(brightness),
      ),
      SampleTone.success => SampleToneColors(
        dark ? sampleDarkGreenTint : const Color(0xFFE7F6EA),
        dark ? sampleDarkGreenBorder : const Color(0xFFB7E2C2),
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
                      // bodySmall is the caption grey in dark theme; a value
                      // is body text whatever its family.
                      color: theme.brightness == Brightness.dark
                          ? sampleDarkBody
                          : null,
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
        color: brightness == Brightness.dark
            ? sampleDarkChipFill
            : sampleTintFor(brightness),
        border: Border.all(
          color: brightness == Brightness.dark
              ? sampleDarkChipBorder
              : sampleBorderFor(brightness),
        ),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? sampleDarkCard
            : sampleCodeSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      // Wraps rather than scrolls sideways. Inside the scenario's vertical
      // ListView a horizontal scroller was a truncated single line for anyone
      // who did not think to drag it — and a result payload is prose plus a
      // symbol name, which reads fine wrapped. Selectable so a tester can lift
      // the payload into a ticket.
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: sampleMonoFamily,
          fontSize: 12,
          height: 1.45,
          color: Theme.of(context).brightness == Brightness.dark
              ? sampleDarkText
              : Colors.white.withValues(alpha: 0.92),
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
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionIdentifier,
  });

  final SampleTone tone;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? identifier;

  /// Optional second action, rendered before the primary one — for a band
  /// whose message names a place to go as well as something to retry.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionIdentifier;

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
          if (secondaryActionLabel case final label?
              when onSecondaryAction != null)
            _identified(
              secondaryActionIdentifier,
              TextButton(
                onPressed: onSecondaryAction,
                style: TextButton.styleFrom(foregroundColor: colors.foreground),
                child: Text(label),
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

Widget _identified(String? identifier, Widget child) => identifier == null
    ? child
    : Semantics(identifier: identifier, button: true, child: child);

/// An in-app link: a short `label ›` in the accent colour, left-aligned, with
/// a 48dp touch target so it survives a large font and a thumb.
///
/// For text that names a place in the app ("reconnect from Settings ›
/// Account"): the pointer becomes the way there instead of directions to it.
class SampleLink extends StatelessWidget {
  const SampleLink({
    super.key,
    required this.label,
    required this.onTap,
    this.identifier,
  });

  final String label;
  final VoidCallback onTap;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: _identified(
        identifier,
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 4),
            minimumSize: const Size(0, 48),
            foregroundColor: theme.colorScheme.primary,
          ),
          child: Text('$label ›'),
        ),
      ),
    );
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
          ? sampleDarkDangerBorder
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

/// The [Scaffold] of every sample-owned screen: the page colour and, in dark
/// theme only, the brand halo — a radial glow of [sampleDarkHalo] fading to
/// transparent, centred on the top-right corner of the screen with a radius
/// of the screen width (the design shared by the five samples).
///
/// The halo is painted around the [Scaffold], not inside its body, so it is
/// fixed to the viewport and runs behind the [appBar] too: the scaffold is
/// transparent and, in dark theme, so is the app bar — which also never tints
/// on scroll — so the glow shows through the header with no hard edge or
/// lighter band. Light theme renders as before (the page colour, the navy
/// app bar).
///
/// Routes that embed the SDK's community view keep a plain [Scaffold]; the
/// shell passes [halo] false on its Community tab, which keeps the tree shape
/// (and so the scaffold's state) while painting only the page colour.
class SampleScaffold extends StatelessWidget {
  const SampleScaffold({
    super.key,
    this.halo = true,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  /// Whether the dark-theme halo is painted. Light theme never paints it.
  final bool halo;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: CustomPaint(
        painter: dark && halo ? SampleHaloPainter(sampleDarkHalo) : null,
        child: Theme(
          data: theme.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            appBarTheme: dark
                ? theme.appBarTheme.copyWith(
                    backgroundColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                  )
                : null,
          ),
          child: Scaffold(
            appBar: appBar,
            body: body,
            bottomNavigationBar: bottomNavigationBar,
          ),
        ),
      ),
    );
  }
}

/// Paints the dark-theme halo of [SampleScaffold]. Public for tests only, so
/// the geometry — centre, radius, colour stops — can be asserted rather than
/// taken on trust.
@visibleForTesting
class SampleHaloPainter extends CustomPainter {
  const SampleHaloPainter(this.color);

  final Color color;

  /// The gradient painted over a viewport of [size]: centred on the top-right
  /// corner with a radius of the viewport width. [RadialGradient.radius] is a
  /// fraction of the shorter side, hence the ratio. The end stop is the halo
  /// colour at zero alpha, so the fade never interpolates through black.
  RadialGradient gradientFor(Size size) => RadialGradient(
    center: Alignment.topRight,
    radius: size.width / math.min(size.width, size.height),
    colors: [color, color.withValues(alpha: 0)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = gradientFor(size).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(SampleHaloPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Wraps the scrolling content that sits above a sample screen's bottom
/// action area (Home's dock, Config's `Start SDK`, a scenario's `Run`).
///
/// Dark theme: the action area has no opaque band and no hairline — its
/// buttons sit on the page and the halo — so the content scrolling out
/// fades to transparent over its last [height] instead of being cut at a hard
/// edge. It is a mask on the content, not a page-coloured overlay: whatever
/// is behind shows through unchanged, including the halo where a wide window
/// (tablet, landscape) lets it reach the bottom — an overlay ending on the
/// opaque page colour left a faint step there. Light theme returns [child]
/// untouched.
class SampleDockFade extends StatelessWidget {
  const SampleDockFade({super.key, required this.child});

  final Widget child;

  /// Height of the fade at the bottom of [child].
  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) =>
          maskFor(bounds.size).createShader(Offset.zero & bounds.size),
      child: child,
    );
  }

  /// The alpha mask over content of [size]: opaque down to [height] above the
  /// bottom, then linearly transparent. Public for tests only.
  @visibleForTesting
  static LinearGradient maskFor(Size size) {
    final start = size.height <= height ? 0.0 : 1 - height / size.height;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
      stops: [0, start, 1],
    );
  }
}
