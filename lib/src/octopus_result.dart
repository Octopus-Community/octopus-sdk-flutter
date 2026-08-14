import 'package:flutter/foundation.dart' show immutable;

/// Marker interface for the typed errors carried by [OctopusInvalidArguments].
///
/// Mirrors the native SDK's `ServerError`. Concrete error sealed classes (e.g.
/// `OverrideCommunityAccessError`) implement this so every variant exposes a
/// human-readable [errorMessage].
abstract interface class OctopusServerError {
  /// A human-readable description of the error.
  String get errorMessage;
}

/// The outcome of an SDK operation that can fail in a typed way.
///
/// Mirrors the native Android `OctopusResult<Data, ServerError>`: either a
/// [OctopusSuccess] carrying [D] data, or an [OctopusFailure]. Failures split
/// into:
/// - [OctopusConnectionFailure] — transport/auth failures that carry no typed
///   error ([OctopusNoNetwork], [OctopusContentUnavailable],
///   [OctopusUserNotAuthenticated], [OctopusPermissionDenied],
///   [OctopusStatusError]);
/// - [OctopusInvalidArguments] — a list of typed [E] errors.
///
/// Pattern-match exhaustively. Two rules, both on the typed-error arm: write its
/// type argument as `OctopusInvalidArguments<OctopusServerError>` whatever [E]
/// is, and narrow [OctopusInvalidArguments.errors] with `whereType<…>()` (or
/// [OctopusInvalidArguments.filterErrors]) before reaching a leaf's members.
/// ```dart
/// switch (result) {
///   case OctopusSuccess(:final data): ...;
///   case OctopusConnectionFailure(): ...; // all 5 connection failures
///   case OctopusInvalidArguments<OctopusServerError>(:final errors): ...;
/// }
/// ```
/// or use the helpers ([onSuccess], [onFailure], [getOrElse], [mapSuccess], …).
///
/// Why the wide type argument: the analyzer builds the sealed subtype space from
/// each subtype's declared **bound**, so the arm it wants is always
/// `OctopusInvalidArguments<OctopusServerError>`. Naming the narrower leaf
/// (`OctopusInvalidArguments<ClientPostError>` on a
/// `OctopusResult<OctopusPost, ClientPostError>`, say) leaves the switch
/// `non_exhaustive_switch_statement`. The wide arm still matches a narrow
/// instance at run time — Dart class generics are covariant — but it binds
/// [OctopusInvalidArguments.errors] as `List<OctopusServerError>`, which is
/// where the second rule comes from.
@immutable
sealed class OctopusResult<D, E extends OctopusServerError> {
  const OctopusResult();

  /// Whether this is an [OctopusSuccess]. When `true`, [isFailure] is `false`.
  bool get isSuccess => this is OctopusSuccess;

  /// Whether this is an [OctopusFailure]. When `true`, [isSuccess] is `false`.
  bool get isFailure => this is OctopusFailure;

  /// Decodes a platform-channel failure map into the matching
  /// [OctopusFailure]. The wire shape is produced by both native bridges:
  /// `{ "kind": <connection-kind> }` for connection failures (with `reason`
  /// for auth failures and `code`/`description` for `statusError`), or
  /// `{ "kind": "invalidArguments", "errors": [ <error-map>, ... ] }` for typed
  /// errors. [errorParser] maps each error map to a typed [E].
  ///
  /// Only call this for the failure branch (success is built by the caller,
  /// which knows the data type — including `void`).
  ///
  /// Reads defensively: malformed or unexpectedly-typed fields (e.g. from a
  /// Dart-plugin ↔ native version skew) degrade to an [OctopusStatusError]
  /// rather than throwing a cast error into the host app.
  static OctopusFailure<E> failureFromWire<E extends OctopusServerError>(
    Map<dynamic, dynamic> wire,
    E Function(Map<String, dynamic> error) errorParser,
  ) {
    final kind = wire['kind'];
    final reason = wire['reason'] is String ? wire['reason'] as String : null;
    switch (kind) {
      case 'noNetwork':
        return const OctopusNoNetwork();
      case 'contentUnavailable':
        return const OctopusContentUnavailable();
      case 'userNotAuthenticated':
        return OctopusUserNotAuthenticated(reason);
      case 'permissionDenied':
        return OctopusPermissionDenied(reason);
      case 'statusError':
        final code = wire['code'];
        return OctopusStatusError(
          code: code is num ? code.toInt() : -1,
          description: wire['description'] is String
              ? wire['description'] as String
              : null,
        );
      case 'invalidArguments':
        final raw = wire['errors'];
        final parsed = <E>[
          if (raw is List)
            for (final e in raw.whereType<Map>())
              errorParser(Map<String, dynamic>.from(e)),
        ];
        if (parsed.isEmpty) {
          return const OctopusStatusError(
            code: -1,
            description: 'invalidArguments failure carried no usable errors',
          );
        }
        return OctopusInvalidArguments<E>(parsed);
      default:
        return OctopusStatusError(
          code: -1,
          description: 'Unknown failure kind: $kind',
        );
    }
  }
}

/// A successful [OctopusResult] carrying [data].
@immutable
final class OctopusSuccess<D, E extends OctopusServerError>
    extends OctopusResult<D, E> {
  /// The success payload. For operations that return no value the type
  /// argument is `void`.
  final D data;

  const OctopusSuccess(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusSuccess<D, E> && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'OctopusSuccess($data)';
}

/// A failed [OctopusResult].
///
/// Generic only over the error type [E] (it carries no success data, so its
/// data type is the bottom type `Never` — making any failure assignable to any
/// `OctopusResult<D, E>`, mirroring the native `Failure : OctopusResult<Nothing, E>`).
@immutable
sealed class OctopusFailure<E extends OctopusServerError>
    extends OctopusResult<Never, E> {
  const OctopusFailure();
}

/// A failure with no typed error — a transport- or auth-level problem.
///
/// Mirrors the native `Failure.Connection` marker. These carry no [E], so they
/// fit into an `OctopusResult<D, E>` for any [E].
@immutable
sealed class OctopusConnectionFailure extends OctopusFailure<Never> {
  const OctopusConnectionFailure();
}

/// No network connection was available.
@immutable
final class OctopusNoNetwork extends OctopusConnectionFailure {
  const OctopusNoNetwork();
  @override
  bool operator ==(Object other) => other is OctopusNoNetwork;
  @override
  int get hashCode => (OctopusNoNetwork).hashCode;
  @override
  String toString() => 'OctopusNoNetwork()';
}

/// The requested content is unavailable.
@immutable
final class OctopusContentUnavailable extends OctopusConnectionFailure {
  const OctopusContentUnavailable();
  @override
  bool operator ==(Object other) => other is OctopusContentUnavailable;
  @override
  int get hashCode => (OctopusContentUnavailable).hashCode;
  @override
  String toString() => 'OctopusContentUnavailable()';
}

/// The user is not authenticated.
@immutable
final class OctopusUserNotAuthenticated extends OctopusConnectionFailure {
  /// Optional reason returned by the SDK.
  final String? reason;
  const OctopusUserNotAuthenticated([this.reason]);
  @override
  bool operator ==(Object other) =>
      other is OctopusUserNotAuthenticated && other.reason == reason;
  @override
  int get hashCode => reason.hashCode;
  @override
  String toString() => 'OctopusUserNotAuthenticated($reason)';
}

/// The user lacks permission for the operation.
@immutable
final class OctopusPermissionDenied extends OctopusConnectionFailure {
  /// Optional reason returned by the SDK.
  final String? reason;
  const OctopusPermissionDenied([this.reason]);
  @override
  bool operator ==(Object other) =>
      other is OctopusPermissionDenied && other.reason == reason;
  @override
  int get hashCode => reason.hashCode;
  @override
  String toString() => 'OctopusPermissionDenied($reason)';
}

/// The server returned an error status.
@immutable
final class OctopusStatusError extends OctopusConnectionFailure {
  /// The server status code.
  final int code;

  /// Optional server-provided description.
  final String? description;

  const OctopusStatusError({required this.code, this.description});
  @override
  bool operator ==(Object other) =>
      other is OctopusStatusError &&
      other.code == code &&
      other.description == description;
  @override
  int get hashCode => Object.hash(code, description);
  @override
  String toString() =>
      'OctopusStatusError(code: $code, description: $description)';
}

/// One or more typed validation/business errors.
///
/// Mirrors the native `Failure.InvalidArguments<E>(errors)`.
@immutable
final class OctopusInvalidArguments<E extends OctopusServerError>
    extends OctopusFailure<E> {
  /// The errors returned by the SDK. Never empty.
  final List<E> errors;

  const OctopusInvalidArguments(this.errors)
      : assert(errors.length > 0,
            'OctopusInvalidArguments requires at least one error');

  /// The first (primary) error.
  E get error => errors.first;

  /// A combined message of all [errors], bullet-pointed when there is more
  /// than one.
  String get errorMessage => errors.length > 1
      ? errors.map((e) => '- ${e.errorMessage}').join('\n')
      : errors.first.errorMessage;

  /// Whether any error is of type [T].
  bool hasError<T>() => errors.any((e) => e is T);

  /// All errors of type [T].
  List<T> filterErrors<T>() => errors.whereType<T>().toList();

  /// Whether any error matches [predicate].
  bool anyError(bool Function(E) predicate) => errors.any(predicate);

  @override
  bool operator ==(Object other) =>
      other is OctopusInvalidArguments<E> && _listEquals(other.errors, errors);

  @override
  int get hashCode => Object.hashAll(errors);

  @override
  String toString() => 'OctopusInvalidArguments($errors)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Functional helpers on [OctopusResult], mirroring the native extension API.
extension OctopusResultExtensions<D, E extends OctopusServerError>
    on OctopusResult<D, E> {
  /// Transforms the success value, passing failures through unchanged.
  OctopusResult<ND, E> mapSuccess<ND>(ND Function(D data) transform) {
    final self = this;
    if (self is OctopusSuccess<D, E>) {
      return OctopusSuccess<ND, E>(transform(self.data));
    }
    // A failure carries no data, so it is an OctopusResult<Never, E>,
    // assignable to OctopusResult<ND, E> for any ND.
    return self as OctopusFailure<E>;
  }

  /// Transforms each typed error inside an [OctopusInvalidArguments].
  /// Successes and connection failures pass through unchanged.
  OctopusResult<D, NE> mapErrors<NE extends OctopusServerError>(
      NE Function(E error) transform) {
    final self = this;
    if (self is OctopusInvalidArguments<E>) {
      return OctopusInvalidArguments<NE>(self.errors.map(transform).toList());
    }
    if (self is OctopusSuccess<D, E>) {
      return OctopusSuccess<D, NE>(self.data);
    }
    // Connection failure: carries no E, assignable to any error type.
    return self as OctopusConnectionFailure;
  }

  /// Runs [block] with the success data when successful; returns `this`.
  OctopusResult<D, E> onSuccess(void Function(D data) block) {
    final self = this;
    if (self is OctopusSuccess<D, E>) block(self.data);
    return this;
  }

  /// Runs [block] with the failure when failed; returns `this`.
  OctopusResult<D, E> onFailure(
      void Function(OctopusFailure<E> failure) block) {
    final self = this;
    if (self is OctopusFailure<E>) block(self);
    return this;
  }

  /// Runs [block] with the first typed error of an [OctopusInvalidArguments];
  /// returns `this`.
  OctopusResult<D, E> onError(void Function(E error) block) {
    final self = this;
    if (self is OctopusInvalidArguments<E>) block(self.error);
    return this;
  }

  /// The success data, or `null` on failure.
  D? getOrNull() {
    final self = this;
    return self is OctopusSuccess<D, E> ? self.data : null;
  }

  /// The success data, or the result of [onFailure] when failed.
  D getOrElse(D Function(OctopusFailure<E> failure) onFailure) {
    final self = this;
    if (self is OctopusSuccess<D, E>) return self.data;
    return onFailure(self as OctopusFailure<E>);
  }
}
