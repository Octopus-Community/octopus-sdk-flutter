import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// The same eight wording presets as the native samples and QA catalogue.
const consentTextsPresets = [
  (
    testId: 'qa-preset-consentTexts-1',
    label: "Preset 1 · Implicit — short notice with a link",
    mode: TermsAcceptanceMode.implicit,
    texts: OctopusConsentTexts.implicit(
      notice:
          "By posting, you agree to the [Pinecone Run Club charter](https://example.com/charter).",
    ),
  ),
  (
    testId: 'qa-preset-consentTexts-2',
    label: "Preset 2 · Multi checkbox — short labels with links",
    mode: TermsAcceptanceMode.explicitMultiCheckbox,
    texts: OctopusConsentTexts.multiCheckbox(
      termsLabel:
          "I accept the **club terms** ([read them](https://example.com/terms))",
      privacyLabel:
          "I accept the [privacy notice](https://example.com/privacy)",
      rulesLabel:
          "I will follow the [*trail etiquette*](https://example.com/etiquette)",
    ),
  ),
  (
    testId: 'qa-preset-consentTexts-3',
    label: "Preset 3 · Single checkbox — short label and text below",
    mode: TermsAcceptanceMode.explicitSingleCheckbox,
    texts: OctopusConsentTexts.singleCheckbox(
      label:
          "I accept the [club terms](https://example.com/terms) and the [trail etiquette](https://example.com/etiquette)",
      belowText:
          "Your data is handled as described in our [privacy notice](https://example.com/privacy).",
    ),
  ),
  (
    testId: 'qa-preset-consentTexts-4',
    label: "Preset 4 · Implicit — long notice (scrolls past 5 lines)",
    mode: TermsAcceptanceMode.implicit,
    texts: OctopusConsentTexts.implicit(
      notice:
          "By posting, you agree to the [Pinecone Run Club charter](https://example.com/charter) and to our [event rules](https://example.com/events).\n\n**Be kind on the trail.** Members who post race results, photos or routes keep the rights to them and let the club show them in the app.\n\n*Your data:* we keep your posts for as long as your account exists. Read the [privacy notice](https://example.com/privacy) to learn how to export or delete them.\n\nQuestions? Write to the volunteers through the [contact page](https://example.com/contact).",
    ),
  ),
  (
    testId: 'qa-preset-consentTexts-5',
    label: "Preset 5 · Multi checkbox — long labels, several links",
    mode: TermsAcceptanceMode.explicitMultiCheckbox,
    texts: OctopusConsentTexts.multiCheckbox(
      termsLabel:
          "I have read and accept the **Pinecone Run Club membership terms**, including the [event rules](https://example.com/events) and the [refund policy](https://example.com/refunds).\nMembership renews every season.",
      privacyLabel:
          "I accept the [privacy notice](https://example.com/privacy). *Race results are public* and stay on the club's leaderboard after I leave.",
      rulesLabel:
          "I will follow the [trail etiquette](https://example.com/etiquette): give way uphill, keep dogs on a leash, and take my litter home.\n\nRepeated breaches end a membership.",
    ),
  ),
  (
    testId: 'qa-preset-consentTexts-6',
    label: "Preset 6 · Single checkbox — long, multi-paragraph",
    mode: TermsAcceptanceMode.explicitSingleCheckbox,
    texts: OctopusConsentTexts.singleCheckbox(
      label:
          "I accept the **Pinecone Run Club membership terms** ([read them](https://example.com/terms)) and the [trail etiquette](https://example.com/etiquette).",
      belowText:
          "We use your posts, photos and race results to run the club.\n\nThey stay visible to members until you delete them. Read the [privacy notice](https://example.com/privacy) to export or erase your data, or write to the volunteers through the [contact page](https://example.com/contact).\n\n# This heading stays plain text\n- and so does this list item",
    ),
  ),
  (
    testId: 'qa-preset-consentTexts-7',
    label: "Preset 7 · Single checkbox — empty fields (SDK wordings)",
    mode: TermsAcceptanceMode.explicitSingleCheckbox,
    texts: OctopusConsentTexts.singleCheckbox(label: "", belowText: "   "),
  ),
  (
    testId: 'qa-preset-consentTexts-8',
    label: "Preset 8 · Multi checkbox with implicit texts (SDK wordings)",
    mode: TermsAcceptanceMode.explicitMultiCheckbox,
    texts: OctopusConsentTexts.implicit(
      notice:
          "By posting, you agree to the [Pinecone Run Club charter](https://example.com/charter).",
    ),
  ),
];

class ConsentTextsScenario extends StatefulWidget {
  const ConsentTextsScenario({super.key});
  @override
  State<ConsentTextsScenario> createState() => _ConsentTextsScenarioState();
}

class _ConsentTextsScenarioState extends State<ConsentTextsScenario> {
  Future<void> _apply(
    ScenarioResultSink setResult,
    String label,
    OctopusConsentTexts? texts,
    TermsAcceptanceMode? mode,
  ) async {
    final app = AppScope.of(context);
    final overrides = app.debugScenarioOverrides;
    try {
      await app.applyConsentTexts(texts, mode, label);
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      if (mounted) setState(() {});
      setResult(
        'Applied: $label. Open Community and make a first contribution with an unaccepted member.',
      );
    } catch (error) {
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      if (mounted) setState(() {});
      setResult('Consent override failed: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overrides = AppScope.of(context).debugScenarioOverrides;
    return ScenarioScaffold(
      key: ObjectKey(overrides),
      title: 'Consent Texts (community wording)',
      api: 'debugOverrideConsentTexts',
      verifyInCommunity: true,
      description:
          'Preview consent wordings. Each preset also applies an acceptance mode.',
      youWillSee:
          'custom markdown labels and links, or native wordings for empty fields and mode mismatch.',
      note:
          'Use a member who has not accepted the terms: a fresh guest or an unaccepted SSO member. An accepted member skips the sheet. Test links through the host URL handler, short and long wordings, and large text sizes. Clear restores both backend texts and mode. On iOS a build without access to OctopusCore reports UNSUPPORTED_PLATFORM.',
      resultTestId: 'consentTexts-result',
      liveState: KeyValueCard(
        title: 'Applied overrides',
        rows: [
          (
            'Consent texts',
            overrides.consentTexts?.value.toString() ?? '— (backend)',
          ),
          (
            'Terms acceptance',
            overrides.termsAcceptance?.value.name ?? '— (backend)',
          ),
        ],
      ),
      presets: [
        for (var i = 0; i < consentTextsPresets.length; i++)
          ScenarioPreset(
            testId: consentTextsPresets[i].testId,
            label: consentTextsPresets[i].label,
            onRun: (setResult) => _apply(
              setResult,
              consentTextsPresets[i].label,
              consentTextsPresets[i].texts,
              consentTextsPresets[i].mode,
            ),
          ),
        ScenarioPreset(
          testId: 'qa-preset-consentTexts-clear',
          label: 'Clear overrides (backend texts and mode)',
          onRun: (setResult) => _apply(
            setResult,
            'Clear overrides (backend texts and mode)',
            null,
            null,
          ),
        ),
      ],
    );
  }
}
