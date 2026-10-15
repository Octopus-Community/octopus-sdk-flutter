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

// ── Tokens ────────────────────────────────────────────────────────────────
// DS roles from the Android sample's SampleTokens.kt. All host screens and
// buildAppTheme consume these values; native SDK theme capabilities stay separate.
const Color sampleNavy = Color(0xFF0F1B2D);
const Color sampleAccentBlue = Color(0xFF1D88FE);
const Color sampleAccentLight = Color(0xFF095FBF);
const Color sampleLightBackground = Color(0xFFF5F7FA);
const Color sampleTint = Color(0xFFFFFFFF);
const Color sampleLightSurface2 = Color(0xFFE4E8EE);
const Color sampleLightSurface3 = Color(0xFFDAE0E8);
const Color sampleLightSecondary = Color(0xFF566170);
const Color sampleLightBorder = Color(0xFFC2CAD5);
const Color sampleLightHairline = Color(0xFFE4E7EC);
const Color sampleLightControlOutline = Color(0xFF747E8C);
const Color sampleLightAccentTint = Color(0xFFE8F2FF);
const Color sampleLightAccentContainer = Color(0xFFD4E6FF);
const Color sampleLightOnAccentContainer = Color(0xFF0A3D7A);
const Color sampleDarkSurface = Color(0xFF070D17);
const Color sampleDarkCard = Color(0xFF18253B);
const Color sampleDarkElevated = Color(0xFF22324C);
const Color sampleDarkHover = Color(0xFF2E405C);
const Color sampleDarkDivider = Color(0x14FFFFFF);
const Color sampleDarkBorderStrong = Color(0xFF8093AB);
const Color sampleDarkControlOutline = Color(0xFFB7C7DD);
const Color sampleDarkText = Color(0xFFF2F5F9);
const Color sampleDarkBody = sampleDarkText;
const Color sampleDarkSecondary = Color(0xFFA3B0C2);
const Color sampleAccentDark = Color(0xFF7FB8FF);
const Color sampleDarkPrimaryLow = Color(0xFF1B3556);
const Color sampleDarkPrimaryHigh = sampleAccentDark;
const Color sampleDarkAccentContainer = Color(0xFF2A5EA0);
const Color sampleDarkOnAccentContainer = Color(0xFFE3EFFF);
const Color sampleDarkButton = Color(0xFF1570D9);
const Color sampleDanger = Color(0xFFB03A4E);
const Color sampleDarkDanger = Color(0xFFF0A0A8);
const Color sampleDarkError = sampleDarkDanger;
const Color sampleDarkOnError = Color(0xFF0A121E);
const Color sampleDangerTint = Color(0xFFF8EDEF);
const Color sampleDarkDangerTint = Color(0xFF3F2E43);
const Color sampleDangerBorder = sampleLightBorder;
const Color sampleDarkDangerBorder = sampleDarkBorderStrong;
const Color sampleAmber = Color(0xFF7A5716);
const Color sampleDarkAmber = Color(0xFFE2BD78);
const Color sampleAmberTint = Color(0xFFF9F2E6);
const Color sampleDarkAmberTint = Color(0xFF3A3222);
const Color sampleAmberBorder = sampleLightBorder;
const Color sampleDarkAmberBorder = sampleDarkBorderStrong;
const Color sampleGuestAmber = Color(0xFFD6A54C);
const Color sampleGuestAmberText = sampleAmber;
// Success fill and text are different roles: the bright fill is not AA text.
const Color sampleGreenFill = Color(0xFF30B653);
const Color sampleGreen = Color(0xFF176830);
const Color sampleDarkGreen = Color(0xFF8FE0A8);
const Color sampleGreenTint = Color(0xFFE3F5E8);
const Color sampleDarkGreenTint = Color(0xFF14301F);
const Color sampleGreenBorder = sampleLightBorder;
const Color sampleDarkGreenBorder = sampleDarkBorderStrong;
const Color sampleAccentInk = sampleNavy;
const Color sampleCodeSurface = sampleNavy;
const Color sampleDarkCodeSurface = Color(0xFF03060C);
const Color sampleDemoBackground = Color(0xFF1B1035);
const Color sampleDemoLink = Color(0xFFFFC857);
const Color sampleCodeText = Color(0xFFD7E3F2);
const Color sampleDarkSnackBarBackground = Color(0xFFE6EAF0);
const Color sampleDarkSnackBarAction = Color(0xFF0A66CC);

Color get sampleDarkChipFill => sampleAccentDark.withValues(alpha: 0.10);
Color get sampleDarkChipBorder => sampleAccentDark.withValues(alpha: 0.28);
Color sampleAccent(Brightness b) =>
    b == Brightness.dark ? sampleAccentDark : sampleAccentLight;
Color sampleButtonBackground(Brightness b) =>
    b == Brightness.dark ? sampleDarkButton : sampleNavy;
Color sampleControlAccent(Brightness b) => sampleAccentBlue;
Color sampleOnAccentColor(Brightness b) =>
    b == Brightness.dark ? sampleDarkSurface : sampleTint;
Color sampleOnControlAccent(Brightness b) => Colors.white;
Color sampleAccentTintFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkPrimaryLow : sampleLightAccentTint;
Color sampleSurface2For(Brightness b) =>
    b == Brightness.dark ? sampleDarkElevated : sampleLightSurface2;
Color sampleSurface3For(Brightness b) =>
    b == Brightness.dark ? sampleDarkHover : sampleLightSurface3;
Color sampleTintFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkCard : sampleTint;
Color sampleBorderFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkBorderStrong : sampleLightBorder;
Color sampleControlOutlineFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkControlOutline : sampleLightControlOutline;
// Two dark-mode pixels keep a full-color stroke visible between antialiased
// edges. A one-pixel outline can otherwise blend entirely into the surface.
double sampleOutlineWidthFor(Brightness b) => b == Brightness.dark ? 2 : 1;
Color sampleScenarioBorderFor(Brightness b) => b == Brightness.dark
    ? sampleDarkBorderStrong
    : sampleAccent(b).withValues(alpha: .35);
Color sampleDangerFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkDanger : sampleDanger;
Color sampleAmberFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkAmber : sampleAmber;
Color sampleGreenFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkGreen : sampleGreen;
Color sampleSnackBarBackgroundFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkSnackBarBackground : sampleNavy;
Color sampleSnackBarContentFor(Brightness b) =>
    b == Brightness.dark ? sampleNavy : sampleDarkText;
Color sampleSnackBarActionFor(Brightness b) =>
    b == Brightness.dark ? sampleDarkSnackBarAction : sampleAccentDark;
const String sampleMonoFamily = 'monospace';

/// Shared four-point spacing grid.
abstract final class SampleSpacing {
  static const double space1 = 4,
      space2 = 8,
      space3 = 12,
      space4 = 16,
      space5 = 20,
      space6 = 24,
      space8 = 32,
      space10 = 40;
  static const double gutter = space4, groupGap = space6;
  static const screen = EdgeInsets.fromLTRB(gutter, space4, gutter, space6);
}

abstract final class SampleRadius {
  static const double sm = 6, md = 8, lg = 12, xl = 16, pill = 999;
}

abstract final class SampleSize {
  // 48 logical pixels also clears the iOS 44pt minimum.
  static const double touchMin = 48,
      rowMin = 56,
      scenarioRowMin = 64,
      badgeHeight = 28,
      searchHeight = 64,
      actionHeight = 56;
}

/// Platform system font, no bundled commercial font. Sizes never below 12.
abstract final class SampleTypography {
  static const double captionSize = 12;
  static TextStyle _style(double size, double line, FontWeight weight) =>
      TextStyle(fontSize: size, height: line / size, fontWeight: weight);
  static final textTheme = TextTheme(
    displayLarge: _style(34, 40, FontWeight.w600),
    displayMedium: _style(30, 38, FontWeight.w600),
    displaySmall: _style(28, 36, FontWeight.w600),
    headlineLarge: _style(28, 36, FontWeight.w600),
    headlineMedium: _style(26, 34, FontWeight.w600),
    headlineSmall: _style(26, 34, FontWeight.w600),
    titleLarge: _style(22, 28, FontWeight.w600),
    titleMedium: _style(18, 24, FontWeight.w600),
    titleSmall: _style(14, 20, FontWeight.w600),
    bodyLarge: _style(16, 22, FontWeight.w400),
    bodyMedium: _style(14, 20, FontWeight.w400),
    bodySmall: _style(12, 16, FontWeight.w500),
    labelLarge: _style(14, 20, FontWeight.w600),
    labelMedium: _style(12, 16, FontWeight.w600),
    labelSmall: _style(12, 16, FontWeight.w600),
  );
  static const scenarioTitle = TextStyle(
    fontSize: 12.5,
    height: 20 / 12.5,
    fontWeight: FontWeight.w600,
  );
  static const buttonLabel = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );
  static const monoSmall = TextStyle(
    fontFamily: sampleMonoFamily,
    fontSize: 12,
    height: 16 / 12,
  );
  static const mono = TextStyle(
    fontFamily: sampleMonoFamily,
    fontSize: 13,
    height: 18 / 13,
  );
}

// ── App bar ────────────────────────────────────────────────────────────────

/// Text title kept for existing small sample bars.
class SampleAppBarTitle extends StatelessWidget {
  const SampleAppBarTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title);
}

/// Compact platform marker: a 28 dp circle, accessible platform name.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'platform-badge',
    label: 'Flutter',
    child: Container(
      width: SampleSize.badgeHeight,
      height: SampleSize.badgeHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: const Icon(Icons.flutter_dash, size: 16, color: sampleAccentBlue),
    ),
  );
}

enum SampleTopBarSize { small, medium, large }

/// Android's 64 / 112 / 152 dp bars. Expanded titles grow when text wraps.
///
/// Use as [SampleScaffold.appBar]: that scaffold calls [bar] with the current
/// context to obtain the actual height at the current text scale and scroll
/// position. [preferredSize] is only the unscaled baseline; passing this widget
/// directly to [Scaffold.appBar] cannot reserve the height of a scaled title.
class SampleTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SampleTopAppBar({
    super.key,
    required this.title,
    this.size = SampleTopBarSize.small,
    this.collapsed = false,
    this.showPlatformBadge = false,
    this.leading,
    this.actions = const [],
  });
  final String title;
  final SampleTopBarSize size;
  final bool collapsed, showPlatformBadge;
  final Widget? leading;
  final List<Widget> actions;
  @override
  Size get preferredSize => Size.fromHeight(
    collapsed || size == SampleTopBarSize.small
        ? 64
        : size == SampleTopBarSize.large
        ? 152
        : 112,
  );

  PreferredSizeWidget bar(BuildContext context, {bool scrolled = false}) {
    final expanded = !collapsed && !scrolled && size != SampleTopBarSize.small;
    final style = Theme.of(context).textTheme.headlineLarge!.copyWith(
      fontSize: size == SampleTopBarSize.large ? 36 : 28,
      height: size == SampleTopBarSize.large ? 44 / 36 : 36 / 28,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 3,
    )..layout(maxWidth: math.max(1, MediaQuery.sizeOf(context).width - 32));
    final titleHeight = math.max(
      size == SampleTopBarSize.large ? 88.0 : 48.0,
      painter.height + 12,
    );
    return AppBar(
      toolbarHeight: math.max(64, scaler.scale(22) + 24),
      leading: leading,
      title: expanded ? null : Text(title),
      actions: [
        ...actions,
        if (showPlatformBadge)
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 12),
            child: PlatformBadge(),
          ),
      ],
      bottom: expanded
          ? PreferredSize(
              preferredSize: Size.fromHeight(titleHeight),
              child: SizedBox(
                width: double.infinity,
                height: titleHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Text(title, style: style, maxLines: 3),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => bar(context);
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
    final section = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SampleSpacing.space4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(
          color: borderColor ?? colors.border,
          width: sampleOutlineWidthFor(brightness),
        ),
        borderRadius: BorderRadius.circular(SampleRadius.md),
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
                    color: tone == SampleTone.neutral
                        ? theme.colorScheme.onSurface
                        : colors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: SampleSpacing.space3),
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
        dark ? sampleDarkGreenTint : sampleGreenTint,
        dark ? sampleDarkGreenBorder : sampleGreenBorder,
        sampleGreenFor(brightness),
      ),
    };
  }
}

/// A `label → value` row, the unit of every summary block in the sample.
class SampleKeyValue extends StatelessWidget {
  const SampleKeyValue(
    this.label,
    this.value, {
    super.key,
    this.mono = false,
    this.caption = false,
  });
  final String label, value;
  final bool mono, caption;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = caption
        ? theme.textTheme.bodySmall!
        : theme.textTheme.bodyMedium!;
    final labelStyle = style.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = style.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w500,
      fontFamily: mono ? sampleMonoFamily : null,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(String text, TextStyle style) => (TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout()).width;
        final fits =
            width(label, labelStyle) + 12 + width(value, valueStyle) <=
            constraints.maxWidth;
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              Text(value, style: valueStyle),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value, style: valueStyle, textAlign: TextAlign.end),
            ),
          ],
        );
      },
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
        color: sampleAccentTintFor(brightness),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        api,
        style: SampleTypography.monoSmall.copyWith(
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
    final tile = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SampleSize.rowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: danger ? color : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: color,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(SampleSpacing.space3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? sampleDarkCodeSurface
            : sampleCodeSurface,
        borderRadius: BorderRadius.circular(SampleRadius.md),
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
          fontSize: SampleTypography.mono.fontSize,
          height: SampleTypography.mono.height,
          color: sampleCodeText,
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
    final messageRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_icon, size: 20, color: colors.foreground),
        const SizedBox(width: SampleSpacing.space3),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.foreground,
            ),
          ),
        ),
      ],
    );
    final actions = <Widget>[
      if (secondaryActionLabel case final label? when onSecondaryAction != null)
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
    ];
    final band = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tone == SampleTone.neutral
            ? sampleAccentTintFor(theme.brightness)
            : colors.background,
        border: Border.all(color: colors.foreground.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(SampleRadius.lg),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (MediaQuery.textScalerOf(context).scale(12) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  messageRow,
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: SampleSpacing.space2,
                    children: actions,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: messageRow),
                ...actions,
              ],
            );
          },
        ),
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
            minimumSize: const Size(SampleSize.touchMin, SampleSize.touchMin),
            foregroundColor: sampleAccent(theme.brightness),
          ),
          child: Text('$label ›'),
        ),
      ),
    );
  }
}

/// Danger capsule: tonal fill, danger border and ink.
ButtonStyle sampleDangerButtonStyle(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  final danger = sampleDangerFor(brightness);
  return OutlinedButton.styleFrom(
    foregroundColor: danger,
    backgroundColor: SampleTone.danger.resolve(brightness).background,
    side: BorderSide(color: danger),
    minimumSize: const Size(SampleSize.touchMin, SampleSize.touchMin),
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

/// Page ground shared with Android.
class SampleScaffold extends StatefulWidget {
  const SampleScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  @override
  State<SampleScaffold> createState() => _SampleScaffoldState();
}

class _SampleScaffoldState extends State<SampleScaffold> {
  bool _scrolled = false;

  @override
  void didUpdateWidget(SampleScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBar = oldWidget.appBar;
    final newBar = widget.appBar;
    if (oldBar is! SampleTopAppBar ||
        newBar is! SampleTopAppBar ||
        oldBar.title != newBar.title) {
      _scrolled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bar = widget.appBar;
    return Scaffold(
      appBar: bar is SampleTopAppBar
          ? bar.bar(context, scrolled: _scrolled)
          : bar,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (bar is SampleTopAppBar &&
              bar.size != SampleTopBarSize.small &&
              notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical) {
            // Collapsing the bar can itself clamp a short list to zero. Keep
            // it collapsed when the content now fits so its bottom stays visible.
            if (notification is ScrollEndNotification &&
                notification.metrics.extentBefore == 0 &&
                notification.metrics.maxScrollExtent > 0) {
              if (_scrolled) setState(() => _scrolled = false);
            } else if ((notification is ScrollUpdateNotification &&
                    notification.dragDetails != null) ||
                (notification is OverscrollNotification &&
                    notification.dragDetails != null)) {
              // Drag updates control collapse; programmatic and ballistic
              // endings use the guarded reset above.
              final scrolled =
                  notification.metrics.extentBefore > 0 ||
                  (notification is OverscrollNotification &&
                      notification.overscroll > 0);
              if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
            }
          }
          return false;
        },
        child: widget.body,
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}

/// Tinted, 16 dp scenario block with its own 48 dp header.
class SampleScenarioBlock extends StatelessWidget {
  const SampleScenarioBlock({
    super.key,
    required this.title,
    required this.child,
    this.icon = Icons.play_arrow_outlined,
    this.identifier,
  });
  final String title;
  final Widget child;
  final IconData icon;
  final String? identifier;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final block = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: sampleAccentTintFor(b),
        border: Border.all(
          color: sampleScenarioBorderFor(b),
          width: sampleOutlineWidthFor(b),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Icon(icon, size: 20, color: sampleAccent(b)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: SampleTypography.buttonLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
    return identifier == null
        ? block
        : Semantics(identifier: identifier!, container: true, child: block);
  }
}

/// Nested Parameters / live-config panel, 12 dp radius and padding.
class SamplePanel extends StatelessWidget {
  const SamplePanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: sampleAccentTintFor(Theme.of(context).brightness),
      border: Border.all(
        color: sampleBorderFor(Theme.of(context).brightness),
        width: sampleOutlineWidthFor(Theme.of(context).brightness),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class SampleTypePill extends StatelessWidget {
  const SampleTypePill(this.type, {super.key});
  final String type;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: sampleSurface3For(Theme.of(context).brightness),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(type, style: SampleTypography.monoSmall),
  );
}

class SampleParameterRow extends StatelessWidget {
  const SampleParameterRow({
    super.key,
    required this.name,
    required this.value,
    this.type,
  });
  final String name, value;
  final String? type;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name, style: SampleTypography.monoSmall),
            if (type != null) SampleTypePill(type!),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class SampleGroupHeader extends StatelessWidget {
  const SampleGroupHeader(this.title, {super.key, this.count, this.identifier});
  final String title;
  final String? count, identifier;
  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: sampleSurface3For(Theme.of(context).brightness),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count!,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ],
      ),
    );
    return identifier == null
        ? header
        : Semantics(identifier: identifier!, child: header);
  }
}

class SampleListDivider extends StatelessWidget {
  const SampleListDivider({super.key, this.leading = 16});
  final double leading;
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: leading, endIndent: 16);
}

class SampleListGroup extends StatelessWidget {
  const SampleListGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SampleListDivider(),
          child,
        ],
      ],
    ),
  );
}

class SampleSwitchRow extends StatelessWidget {
  const SampleSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
    value: value,
    onChanged: onChanged,
  );
}

/// Horizontal capsules; long labels use the Android chip-row fallback.
class SampleSegmentedChoice<T> extends StatelessWidget {
  const SampleSegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.disabledOptions = const {},
  });
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final Set<T> disabledOptions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final longest = options.fold<int>(0, (n, o) => math.max(n, o.$2.length));
      final scaler = MediaQuery.textScalerOf(context);
      final neededWidth = options.fold<double>(
        0,
        (n, o) =>
            n +
            40 +
            (TextPainter(
              text: TextSpan(
                text: o.$2,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout()).width,
      );
      final chips =
          options.length > 4 ||
          longest > 12 ||
          (options.length > 3 && longest > 8) ||
          neededWidth > constraints.maxWidth;
      if (chips) {
        return _SampleScrollableChoice<T>(
          options: options,
          selected: selected,
          onChanged: onChanged,
          disabledOptions: disabledOptions,
        );
      }
      return SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          segments: [
            for (final (value, label) in options)
              ButtonSegment<T>(
                value: value,
                label: Text(label),
                enabled: onChanged != null && !disabledOptions.contains(value),
              ),
          ],
          selected: {selected},
          onSelectionChanged: onChanged == null
              ? null
              : (values) => onChanged!(values.single),
          style: const ButtonStyle(
            shape: WidgetStatePropertyAll(StadiumBorder()),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      );
    },
  );
}

class _SampleScrollableChoice<T> extends StatefulWidget {
  const _SampleScrollableChoice({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.disabledOptions,
  });
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final Set<T> disabledOptions;
  @override
  State<_SampleScrollableChoice<T>> createState() =>
      _SampleScrollableChoiceState<T>();
}

class _SampleScrollableChoiceState<T>
    extends State<_SampleScrollableChoice<T>> {
  final _controller = ScrollController();
  final _selectedKey = GlobalKey();
  T? _lastSelected;
  double? _lastWidth, _lastScale;
  bool _centered = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16);
      if (!_centered ||
          _lastSelected != widget.selected ||
          _lastWidth != constraints.maxWidth ||
          _lastScale != scale) {
        _lastSelected = widget.selected;
        _lastWidth = constraints.maxWidth;
        _lastScale = scale;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) return;
          final target = _selectedKey.currentContext?.findRenderObject();
          if (target == null) return;
          _controller.position.ensureVisible(
            target,
            alignment: .5,
            duration: _centered
                ? const Duration(milliseconds: 160)
                : Duration.zero,
          );
          _centered = true;
        });
      }
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final edge = math.min(20 / bounds.width, .5);
          return LinearGradient(
            colors: const [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, edge, 1 - edge, 1],
          ).createShader(bounds);
        },
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              for (final (i, option) in widget.options.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                ChoiceChip(
                  key: widget.selected == option.$1 ? _selectedKey : null,
                  label: Text(option.$2),
                  selected: widget.selected == option.$1,
                  onSelected:
                      widget.onChanged == null ||
                          widget.disabledOptions.contains(option.$1)
                      ? null
                      : (_) => widget.onChanged!(option.$1),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class SampleSearchField extends StatelessWidget {
  const SampleSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search scenarios',
  });
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: SampleSize.searchHeight),
    child: TextField(
      onChanged: onChanged,
      maxLines: 1,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
        constraints: const BoxConstraints(minHeight: SampleSize.searchHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 21,
        ),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

/// Fixed bottom action on a surface with a hairline, clear of system insets.
class SampleActionBar extends StatelessWidget {
  const SampleActionBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: FilledButtonTheme(
        data: FilledButtonThemeData(
          style:
              (Theme.of(context).filledButtonTheme.style ?? const ButtonStyle())
                  .copyWith(
                    minimumSize: const WidgetStatePropertyAll(
                      Size(double.infinity, 56),
                    ),
                  ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SampleSize.actionHeight),
          child: child,
        ),
      ),
    ),
  );
}

enum SampleStatus { ready, running, passed, failed, blocked, notApplicable }

class SampleStatusBadge extends StatelessWidget {
  const SampleStatusBadge({
    super.key,
    required this.status,
    required this.label,
  });
  final SampleStatus status;
  final String label;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final (fill, ink, icon) = switch (status) {
      SampleStatus.passed => (
        SampleTone.success.resolve(b).background,
        sampleGreenFor(b),
        Icons.check,
      ),
      SampleStatus.failed => (
        SampleTone.danger.resolve(b).background,
        sampleDangerFor(b),
        Icons.close,
      ),
      SampleStatus.blocked => (
        SampleTone.warning.resolve(b).background,
        sampleAmberFor(b),
        Icons.lock_outline,
      ),
      SampleStatus.running => (
        sampleAccentTintFor(b),
        sampleAccent(b),
        Icons.play_arrow,
      ),
      SampleStatus.ready => (
        Colors.transparent,
        sampleAccent(b),
        Icons.play_arrow,
      ),
      SampleStatus.notApplicable => (
        Colors.transparent,
        Theme.of(context).colorScheme.onSurfaceVariant,
        Icons.remove,
      ),
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: ink, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared primary / secondary / danger capsule. Leading icons use 16dp padding.
class SamplePillButton extends StatelessWidget {
  const SamplePillButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.secondary = false,
    this.danger = false,
    this.minHeight = 48,
    this.icon,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool secondary, danger;
  final double minHeight;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final style =
        (danger ? sampleDangerButtonStyle(context) : const ButtonStyle())
            .copyWith(
              minimumSize: WidgetStatePropertyAll(Size(48, minHeight)),
              padding: WidgetStatePropertyAll(
                EdgeInsetsDirectional.only(
                  start: icon == null ? 24 : 16,
                  end: 24,
                ),
              ),
              shape: const WidgetStatePropertyAll(StadiumBorder()),
              textStyle: const WidgetStatePropertyAll(
                SampleTypography.buttonLabel,
              ),
            );
    final content = icon == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: child),
            ],
          );
    return secondary || danger
        ? OutlinedButton(onPressed: onPressed, style: style, child: content)
        : FilledButton(onPressed: onPressed, style: style, child: content);
  }
}
