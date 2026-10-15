import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

/// Last successful presets on one native SDK instance and community. AppState
/// keeps this holder across navigation, disconnect and user-session reset, just
/// as native overrides survive those operations. Switching community or stopping
/// the SDK replaces it; an in-flight preset cannot update the new holder.
class DebugScenarioOverrides {
  ({OctopusConsentTexts value, String label})? consentTexts;
  ({bool value, String label})? forceNicknameChoice;
  ({ProfileFieldsLock value, String label})? profileFieldsLock;
  ({ContentOptions value, String label})? contentOptions;
  ({TermsAcceptanceMode value, String label})? termsAcceptance;
}
