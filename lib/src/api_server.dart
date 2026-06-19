import 'package:flutter/foundation.dart' show immutable;

/// The specific reason an [ApiServer] host failed validation.
///
/// Mirrors the native SDK's `ApiServer.ValidationError` cases so the
/// validation contract is identical across Android, iOS, and Flutter.
enum ApiServerValidationErrorKind {
  /// The host string is empty.
  emptyHost,

  /// The host string contains whitespace.
  hostContainsWhitespace,

  /// The host string contains a scheme (e.g. `https://`).
  hostContainsScheme,

  /// The host string contains a path, a port, or a URL-authority
  /// metacharacter (`/`, `?`, `#`, `@`, or a single `:` port separator).
  hostContainsPortOrPath,

  /// The host string is a malformed IPv6 bracketed literal (e.g. an opening
  /// `[` without a closing `]`, characters outside the brackets, or nested
  /// brackets).
  invalidIPv6Bracketing,
}

/// Thrown by the [ApiServer] constructor when [ApiServer.host] is invalid.
///
/// Subclasses [ArgumentError] so callers that do not need to discriminate by
/// case can `catch (e) on ArgumentError`; inspect [kind] to react to the
/// specific reason.
class ApiServerValidationError extends ArgumentError {
  /// The specific validation rule that was violated.
  final ApiServerValidationErrorKind kind;

  ApiServerValidationError(this.kind, String message)
      : super.value(message, 'host');

  @override
  String toString() => 'ApiServerValidationError.${kind.name}: $message';
}

/// Server endpoint the SDK targets at initialization time.
///
/// Pass an [ApiServer] to [OctopusSDK.initialize] (or
/// [OctopusSDK.initializeOctopusAuth]) to route the SDK's gRPC traffic to a
/// custom [host] and [port]. When no [ApiServer] is provided, the SDK uses the
/// Octopus default endpoint over TLS.
///
/// The [host] is validated when the [ApiServer] is constructed; an invalid
/// host throws an [ApiServerValidationError]. Accepted forms:
/// - a DNS name (e.g. `"api.example.com"`)
/// - an IPv4 literal (e.g. `"192.0.2.10"`)
/// - an IPv6 literal, either bracketed (`"[::1]"`) or unbracketed (`"::1"`)
///
/// The host must not contain a scheme (`https://`), an embedded port (`:443`),
/// a path, or whitespace. Use the [port] parameter to set the port.
///
/// ## Transport security
///
/// The connection is established over TLS. [ApiServer] does not expose a
/// cleartext toggle; pointing the SDK at a server that does not accept TLS
/// surfaces as a connection failure at the first call.
///
/// ```dart
/// await OctopusSDK().initialize(
///   apiKey: 'your-api-key',
///   apiServer: ApiServer(host: 'api.example.com'),
/// );
/// ```
@immutable
class ApiServer {
  /// Server host. Hostname-only — see the accepted / rejected forms above.
  final String host;

  /// Server port. Defaults to `443`.
  final int port;

  /// Creates an [ApiServer] targeting [host] on [port].
  ///
  /// Throws an [ApiServerValidationError] if [host] is empty or malformed —
  /// see [ApiServerValidationErrorKind] for the rules.
  ApiServer({required this.host, this.port = 443}) {
    _validateHost(host);
  }

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'host': host,
        'port': port,
      };

  /// Validates [host] against the same rules as the native SDK, in the same
  /// order. Throws [ApiServerValidationError] on the first violation.
  static void _validateHost(String host) {
    if (host.isEmpty) {
      throw ApiServerValidationError(
        ApiServerValidationErrorKind.emptyHost,
        'host must not be empty.',
      );
    }
    // Rejects ASCII whitespace (space, tab, newline) — the only whitespace a
    // real hostname could plausibly contain. Exotic Unicode whitespace/format
    // characters (NBSP, NEL, FS/GS/RS/US) are not normalized identically by
    // the native Android (`Char.isWhitespace`) and iOS
    // (`.whitespacesAndNewlines`) validators, which themselves disagree; any
    // such host is rejected downstream by gRPC regardless. Parity on those
    // exotic characters is a native-level concern, not resolved here.
    if (RegExp(r'\s').hasMatch(host)) {
      throw ApiServerValidationError(
        ApiServerValidationErrorKind.hostContainsWhitespace,
        'host must not contain whitespace.',
      );
    }
    if (host.contains('://')) {
      throw ApiServerValidationError(
        ApiServerValidationErrorKind.hostContainsScheme,
        "host must not contain a scheme (e.g. 'https://').",
      );
    }
    const forbidden = ['/', '?', '#', '@'];
    if (forbidden.any(host.contains)) {
      throw ApiServerValidationError(
        ApiServerValidationErrorKind.hostContainsPortOrPath,
        "host must not contain a path, a port, or URL-authority "
        "metacharacters ('/', '?', '#', '@', ':'). Use the port parameter "
        "instead.",
      );
    }

    // Bracket / IPv6 handling.
    if (host.startsWith('[')) {
      if (!host.endsWith(']') || host.length < 3) {
        throw ApiServerValidationError(
          ApiServerValidationErrorKind.invalidIPv6Bracketing,
          'host is a malformed IPv6 bracketed literal.',
        );
      }
      final inner = host.substring(1, host.length - 1);
      if (inner.contains('[') || inner.contains(']')) {
        throw ApiServerValidationError(
          ApiServerValidationErrorKind.invalidIPv6Bracketing,
          'host is a malformed IPv6 bracketed literal.',
        );
      }
      // `:` is allowed inside brackets (IPv6 separator). gRPC surfaces a
      // connection error later if the literal is otherwise invalid.
      return;
    }
    // Stray brackets without a leading `[` are malformed.
    if (host.contains('[') || host.contains(']')) {
      throw ApiServerValidationError(
        ApiServerValidationErrorKind.invalidIPv6Bracketing,
        'host is a malformed IPv6 bracketed literal.',
      );
    }

    // Colon rule: exactly one `:` looks like host:port, reject. Two or more
    // is an unbracketed IPv6 literal, accept.
    final colonCount = ':'.allMatches(host).length;
    if (colonCount == 1) {
      throw ApiServerValidationError(
        ApiServerValidationErrorKind.hostContainsPortOrPath,
        "host must not contain a path, a port, or URL-authority "
        "metacharacters ('/', '?', '#', '@', ':'). Use the port parameter "
        "instead.",
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiServer && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'ApiServer(host: $host, port: $port)';
}
