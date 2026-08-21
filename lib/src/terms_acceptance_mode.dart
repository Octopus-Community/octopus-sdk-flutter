/// How users must accept the legal documents (terms, privacy policy,
/// community rules) at their first contribution.
///
/// Internal test affordance mirroring the native SDKs' debug-only
/// `debugOverrideTermsAcceptanceMode` (Android `@InternalOctopusApi`, iOS
/// `@_spi(OctopusInternalTesting)`): it locally overrides the terms
/// acceptance mode without a backend-driven config, for exercising the
/// explicit-consent modes in development builds and the sample app. **Not
/// part of the supported public API** — it may change or be removed at any
/// time.
///
/// - [implicit]: today's default — a legal disclaimer is shown at the bottom
///   of the editor and acceptance is implicit when the user publishes.
/// - [explicitMultiCheckbox]: a bottom sheet with **one checkbox per legal
///   document** (all required) is shown at the first contribution; publishing
///   is gated until every box is checked.
/// - [explicitSingleCheckbox]: same bottom sheet with **a single combined
///   checkbox** (plus a passive privacy-policy acknowledgement); publishing
///   is gated until that box is checked.
enum TermsAcceptanceMode {
  /// Implicit acceptance, no consent sheet (today's default).
  implicit,

  /// One checkbox per legal document, all required.
  explicitMultiCheckbox,

  /// A single combined checkbox plus a passive privacy-policy
  /// acknowledgement.
  explicitSingleCheckbox;

  /// Converts to the string value expected by the native SDKs.
  ///
  /// Wire format mirrors the native enum names: `IMPLICIT`,
  /// `EXPLICIT_MULTI_CHECKBOX`, `EXPLICIT_SINGLE_CHECKBOX`. These strings
  /// must match the keys handled by the Android Kotlin bridge, which
  /// silently drops any value it does not recognize.
  String toNativeValue() {
    switch (this) {
      case TermsAcceptanceMode.implicit:
        return 'IMPLICIT';
      case TermsAcceptanceMode.explicitMultiCheckbox:
        return 'EXPLICIT_MULTI_CHECKBOX';
      case TermsAcceptanceMode.explicitSingleCheckbox:
        return 'EXPLICIT_SINGLE_CHECKBOX';
    }
  }
}
