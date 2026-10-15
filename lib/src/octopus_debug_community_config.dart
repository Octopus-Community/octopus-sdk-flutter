import 'package:flutter/foundation.dart' show immutable;

import 'consent_texts.dart';
import 'terms_acceptance_mode.dart';

/// Debug-only snapshot of the community config the native SDK currently holds
/// (the backend's GetConfig response, with any local `debugOverride*` applied
/// on top — the same effective config the SDK UI consumes).
///
/// Returned by [OctopusSDK.debugGetCommunityConfig], so a test app can display
/// the live server state next to the API key it runs on. Mirrors the React
/// Native SDK's `OctopusDebugCommunityConfig`. **Not part of the supported
/// public API** — it may change or be removed at any time.
@immutable
class OctopusDebugCommunityConfig {
  /// The Unified Profile activation flag (`CommunityConfig.exposeClientUserId`).
  ///
  /// When `true`, profile taps inside the SDK UI are routed to the host's
  /// `onNavigateToProfile` callback instead of the SDK's own profile screen —
  /// provided the host wired that callback.
  final bool exposeClientUserId;

  /// Whether a strong action (post, comment, react…) requires a signed-in user.
  final bool forceLoginOnStrongActions;

  /// Whether member profiles display the account age.
  final bool displayAccountAge;

  /// How users accept the legal documents, or `null` when the native side
  /// reported a mode this plugin version does not know.
  final TermsAcceptanceMode? termsAcceptanceMode;

  /// Whether an unconfirmed member must type a nickname before contributing.
  /// Missing flags from older native bridges default to `false`.
  final bool forceNicknameChoice;

  /// Effective community consent wordings, or `null` for native wordings.
  final OctopusConsentTexts? consentTexts;

  /// Creates a snapshot. Apps never need to build one outside of tests.
  const OctopusDebugCommunityConfig({
    required this.exposeClientUserId,
    required this.forceLoginOnStrongActions,
    required this.displayAccountAge,
    this.termsAcceptanceMode,
    this.forceNicknameChoice = false,
    this.consentTexts,
  });

  /// Decodes the platform-channel representation. Reads defensively: a
  /// missing or wrong-typed flag reads `false`, an unknown mode reads `null`.
  factory OctopusDebugCommunityConfig.fromWire(Map<dynamic, dynamic> wire) {
    bool flag(String key) => wire[key] is bool && wire[key] as bool;
    return OctopusDebugCommunityConfig(
      exposeClientUserId: flag('exposeClientUserId'),
      forceLoginOnStrongActions: flag('forceLoginOnStrongActions'),
      displayAccountAge: flag('displayAccountAge'),
      forceNicknameChoice: flag('forceNicknameChoice'),
      consentTexts: OctopusConsentTexts.fromWire(wire['consentTexts']),
      termsAcceptanceMode: _parseTermsAcceptanceMode(
        wire['termsAcceptanceMode'],
      ),
    );
  }

  /// Both bridges send the Android enum spelling (`IMPLICIT`,
  /// `EXPLICIT_MULTI_CHECKBOX`, `EXPLICIT_SINGLE_CHECKBOX`) — the inverse of
  /// [TermsAcceptanceMode.toNativeValue].
  static TermsAcceptanceMode? _parseTermsAcceptanceMode(Object? value) {
    for (final mode in TermsAcceptanceMode.values) {
      if (mode.toNativeValue() == value) return mode;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is OctopusDebugCommunityConfig &&
      other.exposeClientUserId == exposeClientUserId &&
      other.forceLoginOnStrongActions == forceLoginOnStrongActions &&
      other.displayAccountAge == displayAccountAge &&
      other.termsAcceptanceMode == termsAcceptanceMode &&
      other.forceNicknameChoice == forceNicknameChoice &&
      other.consentTexts == consentTexts;

  @override
  int get hashCode => Object.hash(
    exposeClientUserId,
    forceLoginOnStrongActions,
    displayAccountAge,
    termsAcceptanceMode,
    forceNicknameChoice,
    consentTexts,
  );

  @override
  String toString() =>
      'OctopusDebugCommunityConfig(exposeClientUserId: $exposeClientUserId, '
      'forceLoginOnStrongActions: $forceLoginOnStrongActions, '
      'displayAccountAge: $displayAccountAge, '
      'termsAcceptanceMode: $termsAcceptanceMode, '
      'forceNicknameChoice: $forceNicknameChoice, consentTexts: $consentTexts)';
}
