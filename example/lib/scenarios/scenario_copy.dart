/// Product wording shared by the Android and Flutter samples.
class ScenarioCopy {
  const ScenarioCopy(this.title, this.description, this.youWillSee);
  final String title;
  final String description;
  final String youWillSee;
}

const scenarioCopy = <String, ScenarioCopy>{
  "unifiedProfile": ScenarioCopy(
    "Unified Profile",
    "Open member profiles in the host app or in the community.",
    "with the switch on, a member with an app id opens Client profile and the home profile button opens Activity; with it off, both open native profiles.",
  ),
  "connection": ScenarioCopy(
    "Sign in and out as the demo user",
    "The community shows the demo user as signed in: they can post, react and be notified.",
    "the Community tab greets the demo user, and the composer unlocks.",
  ),
  "groups": ScenarioCopy(
    "Browse the community's groups",
    "Every group the community offers, with whether the demo user follows it.",
    "the group list, with a follow state on each row.",
  ),
  "syncFollowGroups": ScenarioCopy(
    "Follow or unfollow every group at once",
    "The follow state of every group flips in one call, and the community reflects it.",
    "every group's follow state matching what you just applied.",
  ),
  "notSeenNotifications": ScenarioCopy(
    "Set the unread notification count",
    "The notification badge in the community carries the number you set.",
    "the notification badge carrying the count you sent.",
  ),
  "pushNotifications": ScenarioCopy(
    "Open a post from a push notification",
    "A simulated push is recognised as an Octopus one and opens the post it points at.",
    "the community opening on the post the notification named.",
  ),
  "communityAccess": ScenarioCopy(
    "Grant or deny access to the community",
    "The community either opens normally, or shows its no-access state.",
    "the community opening, or its no-access screen.",
  ),
  "customEvents": ScenarioCopy(
    "Send a custom analytics event",
    "The event shows up in the Events log, with the properties you attached.",
    "the event at the top of the Events log.",
  ),
  "locale": ScenarioCopy(
    "Switch the community's language",
    "The community's own labels switch to the language you picked.",
    "the community's buttons and labels in the language you picked.",
  ),
  "lifecycle": ScenarioCopy(
    "Restart or stop the SDK",
    "The session ends and the community goes back to its not-connected state.",
    "the community back in its not-connected state.",
  ),
  "bridge": ScenarioCopy(
    "Open the post attached to a product",
    "A post tied to a host object opens — created on the spot the first time you ask for it.",
    "the post for that object, and your reaction on it.",
  ),
  "createPost": ScenarioCopy(
    "Start a post from the host app",
    "The composer opens pre-filled with the text, image or link the host handed over.",
    "the composer, pre-filled with what the host passed.",
  ),
  "reactions": ScenarioCopy(
    "React to a post from the host app",
    "The reaction you picked shows on that post in the community.",
    "your reaction on the post you named.",
  ),
  "theme": ScenarioCopy(
    "Apply the host's brand to the community",
    "The community adopts the host's colours, fonts and logo — or drops back to the SDK's own look.",
    "the community in the host's colours, or in the SDK's default look.",
  ),
  "communityData": ScenarioCopy(
    "Read a member's community profile",
    "The member's community profile comes back, and keeps updating while you watch it.",
    "the member's community profile id, message count and gamification level. The Observe preset keeps these values updating.",
  ),
  "profileFieldsLock": ScenarioCopy(
    "Lock the profile fields the host owns",
    "The locked fields turn read-only in the community's profile editor.",
    "the locked fields greyed out in the profile editor.",
  ),
  "contentOptions": ScenarioCopy(
    "Change content options and post taps",
    "Try content creation options and post image or group name navigation.",
    "the allowed content types in the composer and the selected post tap behaviour.",
  ),
  "forceNicknameChoice": ScenarioCopy(
    "Force Nickname Choice",
    "Choose the initial nickname before a first contribution.",
    "an empty field when On, or the generated nickname when Off.",
  ),
  "consentTexts": ScenarioCopy(
    "Consent Texts (community wording)",
    "Show community consent wordings and native fallback.",
    "custom labels and links, or native wordings for empty or mismatched fields.",
  ),
  "termsAcceptance": ScenarioCopy(
    "Change how members accept the terms",
    "The community asks for consent the way you picked, or stops asking altogether.",
    "the consent step in the form you chose, or no consent step at all.",
  ),
  "events": ScenarioCopy(
    "Watch what the SDK reports",
    "Every event the SDK emits, live, as the community is used.",
    "the event stream filling up as you use the community.",
  ),
  "refreshEntitlements": ScenarioCopy(
    "Re-issue the demo user's entitlements",
    "The community picks up the entitlements you edited, without signing out.",
    "the abilities you granted, available in the community.",
  ),
  "groupAccessDenied": ScenarioCopy(
    "Handle a member reaching a closed group",
    "The host is told a group was refused, instead of the community handling it alone.",
    "the host's own access-denied screen instead of the SDK's.",
  ),
  "initialScreen": ScenarioCopy(
    "Open the community on a chosen screen",
    "The community opens directly on the member, profile or feed you picked.",
    "the community already on the screen you asked for.",
  ),
  "fullscreen": ScenarioCopy(
    "Open the community full screen",
    "The community takes the whole screen, outside the tab bar.",
    "the community covering the screen; the back gesture returns here.",
  ),
  "modal": ScenarioCopy(
    "Open the community as a modal",
    "The community covers the screen in a host-owned modal that you close yourself.",
    "the community in a modal, closed by the X that leads the community's header.",
  ),
  "sheet": ScenarioCopy(
    "Open the community as a bottom sheet",
    "The community slides over this screen; swipe down to come back.",
    "the community at sheet height, its own navigation staying inside the sheet.",
  ),
  "trackABTests": ScenarioCopy(
    "Report which cohort the member is in",
    "The community opens for the cohort you granted, and refuses the other one.",
    "the community open, or the refusal the other cohort gets.",
  ),
  "forceOctopusABTests": ScenarioCopy(
    "Force Octopus's own A/B decision",
    "The community's own access rule is overridden — granted or denied — until you clear it.",
    "the community following your forced value, not its own.",
  ),
};
