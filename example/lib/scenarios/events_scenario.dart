import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../debug/debug_log.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Human-readable name for an [OctopusEvent].
///
/// Mirrors the iOS sample's `EventsViewModel.DisplayableEvent.eventName`
/// labels (see `Sample/OctopusSample/UI/Scenarios/Events/EventsViewModel.swift`)
/// so QA reads the same surface on both platforms. For [ScreenDisplayedEvent]
/// the label is expanded with the screen subtype (e.g. "Main Feed Screen
/// Displayed").
String _eventName(OctopusEvent event) => switch (event) {
  PostCreatedEvent() => 'Post Created',
  CommentCreatedEvent() => 'Comment Created',
  ReplyCreatedEvent() => 'Reply Created',
  ContentDeletedEvent(:final contentKind) => switch (contentKind) {
    ContentKind.post => 'Post Deleted',
    ContentKind.comment => 'Comment Deleted',
    ContentKind.reply => 'Reply Deleted',
  },
  ReactionModifiedEvent() => 'Reaction Modified',
  PollVotedEvent() => 'Poll Voted',
  ContentReportedEvent() => 'Content Reported',
  ProfileReportedEvent() => 'Profile Reported',
  GroupFollowingChangedEvent() => 'Group Following Changed',
  GamificationPointsGainedEvent() => 'Gamification Points Gained',
  GamificationPointsRemovedEvent() => 'Gamification Points Removed',
  ScreenDisplayedEvent(:final screen) => switch (screen) {
    MainFeedScreen() => 'Main Feed Screen Displayed',
    GroupsScreen() => 'Groups Screen Displayed',
    GroupDetailScreen() => 'Group Detail Screen Displayed',
    PostDetailScreen() => 'Post Detail Screen Displayed',
    CommentDetailScreen() => 'Comment Detail Screen Displayed',
    CreatePostScreen() => 'Create Post Screen Displayed',
    ProfileScreen() => 'Profile Screen Displayed',
    ActivityScreen() => 'Activity Screen Displayed',
    OtherUserProfileScreen() => 'Other Profile Screen Displayed',
    OtherUserPostsScreen() => 'Other User Posts Screen Displayed',
    EditProfileScreen() => 'Edit Profile Screen Displayed',
    ReportContentScreen() => 'Report Content Screen Displayed',
    ReportProfileScreen() => 'Report Profile Displayed',
    ValidateNicknameScreen() => 'Validate Nickname Screen Displayed',
    SettingsListScreen() => 'Settings List Screen Displayed',
    SettingsAccountScreen() => 'Account Settings Screen Displayed',
    ReportExplanationScreen() => 'Report Explanation Screen Displayed',
    DeleteAccountScreen() => 'Delete Account Screen Displayed',
    PostsFeedScreen() => 'Posts Feed Screen Displayed',
    UnknownScreen() => 'Unknown Screen Displayed',
  },
  NotificationClickedEvent() => 'Internal Notification Clicked',
  PostClickedEvent() => 'Post Clicked',
  TranslationButtonClickedEvent() => 'Translation Button Clicked',
  CommentButtonClickedEvent() => 'Comment Button Clicked',
  ReplyButtonClickedEvent() => 'Reply Button Clicked',
  SeeRepliesButtonClickedEvent() => 'See Replies Button Clicked',
  ProfileModifiedEvent() => 'Profile Modified',
  SessionStartedEvent() => 'Session Started',
  SessionStoppedEvent() => 'Session Stopped',
  UnknownEvent() => 'Unknown',
};

/// Structured parameter rows for an [OctopusEvent].
///
/// Each entry is a `(label, value)` tuple so callers can render the params as
/// a key/value list (iso the iOS sample's `EventsViewModel.params` strings,
/// just split at the colon).
List<(String, String)> _eventParams(OctopusEvent event) => switch (event) {
  PostCreatedEvent(
    :final postId,
    :final content,
    :final topicId,
    :final textLength,
  ) =>
    [
      ('Id', postId),
      ('Topic', topicId ?? '-'),
      ('Text length', textLength.toString()),
      ('Content', content.map((c) => c.name).join(', ')),
    ],
  CommentCreatedEvent(:final commentId, :final postId, :final textLength) => [
    ('Id', commentId),
    ('Post', postId),
    ('Text length', textLength.toString()),
  ],
  ReplyCreatedEvent(:final replyId, :final commentId, :final textLength) => [
    ('Id', replyId),
    ('Comment', commentId),
    ('Text length', textLength.toString()),
  ],
  ContentDeletedEvent(:final contentId, :final contentKind) => [
    ('Content Id', contentId),
    ('Content Kind', contentKind.name),
  ],
  ReactionModifiedEvent(
    :final contentId,
    :final contentKind,
    :final previousReaction,
    :final newReaction,
  ) =>
    [
      ('Content Id', contentId),
      ('Previous Reaction', previousReaction?.name ?? '-'),
      ('New Reaction', newReaction?.name ?? '-'),
      ('Content Kind', contentKind.name),
    ],
  PollVotedEvent(:final contentId, :final optionId) => [
    ('Content Id', contentId),
    ('Option Id', optionId),
  ],
  ContentReportedEvent(:final contentId, :final reasons) => [
    ('Content Id', contentId),
    ('Reasons', reasons.map((r) => r.name).join(', ')),
  ],
  ProfileReportedEvent(:final profileId, :final reasons) => [
    ('Profile Id', profileId),
    ('Reasons', reasons.map((r) => r.name).join(', ')),
  ],
  GroupFollowingChangedEvent(:final groupId, :final followed) => [
    ('Group Id', groupId),
    ('Followed', followed ? 'true' : 'false'),
  ],
  GamificationPointsGainedEvent(:final points, :final action) => [
    ('Action', action.name),
    ('Points gained', points.toString()),
  ],
  GamificationPointsRemovedEvent(:final points, :final action) => [
    ('Action', action.name),
    ('Points removed', points.toString()),
  ],
  ScreenDisplayedEvent(:final screen) => switch (screen) {
    MainFeedScreen(:final feedId) => [('Feed Id', feedId)],
    GroupsScreen() => const [],
    GroupDetailScreen(:final groupId, :final source) => [
      ('Group Id', groupId),
      ('Source', source.name),
    ],
    PostDetailScreen(:final postId) => [('Post Id', postId)],
    CommentDetailScreen(:final commentId) => [('Comment Id', commentId)],
    CreatePostScreen() => const [],
    ProfileScreen() => const [],
    ActivityScreen() => const [],
    OtherUserProfileScreen(:final profileId) => [('Profile Id', profileId)],
    OtherUserPostsScreen(:final profileId) => [('Profile Id', profileId)],
    EditProfileScreen() => const [],
    ReportContentScreen() => const [],
    ReportProfileScreen() => const [],
    ValidateNicknameScreen() => const [],
    SettingsListScreen() => const [],
    SettingsAccountScreen() => const [],
    ReportExplanationScreen() => const [],
    DeleteAccountScreen() => const [],
    PostsFeedScreen(:final feedId, :final relatedTopicId) => [
      ('Feed Id', feedId ?? '-'),
      ('Related Group Id', relatedTopicId ?? '-'),
    ],
    UnknownScreen(:final type) => [('Type', type)],
  },
  NotificationClickedEvent(:final notificationId, :final contentId) => [
    ('Notification Id', notificationId),
    ('Content Id', contentId ?? '-'),
  ],
  PostClickedEvent(:final postId, :final source) => [
    ('Post Id', postId),
    ('Source', source.name),
  ],
  TranslationButtonClickedEvent(
    :final contentId,
    :final contentKind,
    :final viewTranslated,
  ) =>
    [
      ('Content Id', contentId),
      ('Content Kind', contentKind.name),
      ('View Translated', viewTranslated ? 'true' : 'false'),
    ],
  CommentButtonClickedEvent(:final postId) => [('Post Id', postId)],
  ReplyButtonClickedEvent(:final commentId) => [('Comment Id', commentId)],
  SeeRepliesButtonClickedEvent(:final commentId) => [('Comment Id', commentId)],
  ProfileModifiedEvent(
    :final nicknameUpdated,
    :final bioUpdated,
    :final bioLength,
    :final pictureUpdated,
    :final hasPicture,
  ) =>
    [
      ('Nickname', nicknameUpdated ? 'Modified' : 'Unchanged'),
      (
        'Bio',
        bioUpdated ? 'Modified. New length: ${bioLength ?? '-'}' : 'Unchanged',
      ),
      (
        'Picture',
        pictureUpdated
            ? 'Modified. Has picture: ${hasPicture ?? '-'}'
            : 'Unchanged',
      ),
    ],
  SessionStartedEvent(:final sessionId) => [('Session Id', sessionId)],
  SessionStoppedEvent(:final sessionId) => [('Session Id', sessionId)],
  UnknownEvent(:final type) => [('Type', type)],
};

/// Events scenario — persistent `OctopusSDK.events` log.
///
/// Reads the session-long typed-event buffer recorded by [debugLog] (started at
/// app launch in `runOctopusDemo`). Because `OctopusSDK.events` is a
/// non-replaying broadcast stream, subscribing only when this screen opens
/// would miss every event fired beforehand (e.g. while the user was on the
/// Community tab); reading the persistent buffer instead shows the full
/// session's events whenever the scenario is opened. Renders the most recent
/// [RealDebugLog.maxTypedEvents] events in reverse-chronological order, each row
/// showing a human-readable event name + a list of key/value params. Matches
/// the iOS sample's persistent `EventsViewModel` — the surface the automated UI tests
/// reads.
class EventsScenario extends StatelessWidget {
  const EventsScenario({super.key});

  @override
  Widget build(BuildContext context) {
    return ScenarioScaffold(
      title: 'Events',
      api: 'OctopusSDK.events',
      description:
          'Persistent log of the typed events streamed by '
          'OctopusSDK.events, recorded from app launch. Interact with the '
          'embedded Community (Community tab), then reopen this scenario to see '
          'the events. Keeps the most recent '
          '${RealDebugLog.maxTypedEvents} events (reverse-chronological).',
      resultTestId: 'events-result',
      liveState: ListenableBuilder(
        listenable: debugLog,
        builder: (context, _) {
          final events = debugLog.typedEvents;
          final latest = events.isEmpty ? '—' : _eventName(events.last);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValueCard(
                title: 'Live state',
                rows: [
                  ('Events captured', events.length.toString()),
                  ('Latest event', latest),
                ],
              ),
              const SizedBox(height: 8),
              _EventList(events: events),
            ],
          );
        },
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-events-1',
          label: 'Preset 1 · Clear log',
          onRun: (setResult) async {
            try {
              final cleared = debugLog.typedEvents.length;
              demoLog.apiCall('events.clearLocalLog');
              debugLog.clearTypedEvents();
              setResult(
                cleared == 0
                    ? 'Log was already empty.'
                    : 'Cleared $cleared event${cleared == 1 ? '' : 's'} '
                          'from the local log.',
              );
            } catch (e) {
              setResult('Clear log failed: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}

/// Reverse-chronological list of captured events. Extracted so the scaffold's
/// `liveState` slot stays compact and the empty state is explicit.
class _EventList extends StatelessWidget {
  final List<OctopusEvent> events;

  const _EventList({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.list_alt, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No events yet. Interact with the SDK to see events appear '
                  'here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final reversed = events.reversed.toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < reversed.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _eventName(reversed[i]),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          for (final (label, value) in _eventParams(
                            reversed[i],
                          )) ...[
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$label: ',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: value,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < reversed.length - 1)
                Divider(height: 1, indent: 42, color: theme.dividerColor),
            ],
          ],
        ),
      ),
    );
  }
}
