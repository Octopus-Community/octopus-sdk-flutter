/// Represents a push notification from the Octopus Community platform.
///
/// Use [OctopusSDK.isOctopusNotification] to check if a notification payload
/// originates from Octopus, then [OctopusSDK.getOctopusNotification] to parse
/// it into this typed object.
class OctopusNotification {
  /// The notification title (falls back to `aps.alert.title` when the
  /// payload is shaped as raw APNs `userInfo`).
  final String title;

  /// The notification body (falls back to `aps.alert.body` when the
  /// payload is shaped as raw APNs `userInfo`).
  final String body;

  /// The deep-link path used to navigate to the relevant content.
  final String linkPath;

  /// The post ID referenced by this notification, if any.
  final String? postId;

  /// The comment ID referenced by this notification, if any.
  final String? commentId;

  /// The reply ID referenced by this notification, if any.
  final String? replyId;

  /// The Octopus key/value pairs extracted from the push payload, flattened
  /// to `Map<String, String>` for transport across the platform channel.
  ///
  /// Forwarded to the native iOS SDK as the `notificationUserInfo` so the
  /// new fields the backend ships in the future pass through transparently.
  /// Defaults to an empty map for hand-built instances.
  final Map<String, String> rawPayload;

  const OctopusNotification({
    required this.title,
    required this.body,
    required this.linkPath,
    this.postId,
    this.commentId,
    this.replyId,
    this.rawPayload = const {},
  });

  /// Parses a push-notification payload into an [OctopusNotification].
  ///
  /// Accepts both shapes a Flutter app can encounter:
  ///
  /// - **Android FCM** (`RemoteMessage.data`): a flat map with the Octopus
  ///   keys (`is_octopus_notification`, `link_path`, `title`, `body`,
  ///   `post_id`, `comment_id`, `reply_id`) at the top level.
  /// - **iOS raw APNs `userInfo`**: a nested map with the standard `aps`
  ///   dict alongside a `data` envelope holding the Octopus keys. User-
  ///   facing copy normally lives in `aps.alert.title` / `aps.alert.body`.
  ///
  /// Returns `null` if `link_path` is missing — that is the only field
  /// navigation actually requires. `title` and `body` default to empty
  /// strings when absent in both the Octopus keys and `aps.alert`.
  static OctopusNotification? fromMap(Map payload) {
    final source = _octopusKeysFrom(payload);
    final linkPath = source['link_path'];
    if (linkPath is! String || linkPath.isEmpty) return null;

    String? readString(String key) {
      final v = source[key];
      return v is String ? v : null;
    }

    final apsAlert = _apsAlert(payload);
    final title = readString('title') ?? apsAlert['title'] ?? '';
    final body = readString('body') ?? apsAlert['body'] ?? '';

    final rawPayload = <String, String>{
      for (final entry in source.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
    if (title.isNotEmpty) rawPayload.putIfAbsent('title', () => title);
    if (body.isNotEmpty) rawPayload.putIfAbsent('body', () => body);

    return OctopusNotification(
      title: title,
      body: body,
      linkPath: linkPath,
      postId: readString('post_id'),
      commentId: readString('comment_id'),
      replyId: readString('reply_id'),
      rawPayload: Map.unmodifiable(rawPayload),
    );
  }

  /// Returns the inner map that holds the Octopus keys. For an APNs-shaped
  /// payload (with a `data` envelope) this is the `data` sub-map; otherwise
  /// it is the payload itself (Android FCM shape).
  static Map _octopusKeysFrom(Map payload) {
    final data = payload['data'];
    if (data is Map) return data;
    return payload;
  }

  /// Reads `aps.alert.title` / `aps.alert.body` strings from an APNs payload
  /// when present. Returns an empty map for non-APNs payloads.
  static Map<String, String> _apsAlert(Map payload) {
    final aps = payload['aps'];
    if (aps is! Map) return const {};
    final alert = aps['alert'];
    if (alert is! Map) return const {};
    final out = <String, String>{};
    final t = alert['title'];
    final b = alert['body'];
    if (t is String) out['title'] = t;
    if (b is String) out['body'] = b;
    return out;
  }

  /// Internal accessor used by [OctopusSDK.isOctopusNotification].
  static bool isOctopusFlag(Map payload) {
    final source = _octopusKeysFrom(payload);
    return source['is_octopus_notification'] == 'true' ||
        source['is_octopus_notification'] == true;
  }
}
