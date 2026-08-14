import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/auth/connect_user_result.dart';

void main() {
  group('describeConnectUserFailure', () {
    test('returns null for a success result', () {
      expect(
        describeConnectUserFailure(
          const OctopusSuccess<void, ClientUserError>(null),
        ),
        isNull,
      );
    });

    test('a connection failure renders without a typed error', () {
      expect(
        describeConnectUserFailure(const OctopusNoNetwork()),
        contains('connection layer'),
      );
    });

    test('each ClientUserError leaf yields its own label', () {
      // Every leaf carries the SAME errorMessage ('msg') on purpose: the only
      // thing that can tell the six outputs apart is the `label` the switch
      // in describeConnectUserFailure maps each leaf to.
      //
      // Pinned leaf-by-leaf rather than merely checked for distinctness. Six
      // distinct labels stay six distinct labels when two arms are SWAPPED, so
      // a `hasLength(6)` assertion catches collisions and misses permutations —
      // and in a hand-written six-arm switch a swap is the likelier copy-paste
      // bug. Measured: swapping the Banned and Profile arms (so a banned user
      // is told "Profile" and a rejected nickname "Banned") left a
      // distinctness-only version of this test green.
      final expected = <(ClientUserError, String)>[
        (
          const ClientUserMissingTokenError('msg'),
          'ClientUserMissingToken: msg',
        ),
        (const ClientUserBannedError('msg'), 'ClientUserBanned: msg'),
        (const ClientUserProfileError('msg'), 'ClientUserProfile: msg'),
        (
          const ClientUserInvalidTokenError('msg'),
          'ClientUserInvalidToken: msg',
        ),
        (
          const ClientUserCommunityAccessDeniedError('msg'),
          'ClientUserCommunityAccessDenied: msg',
        ),
        (const ClientUserOtherError('msg'), 'ClientUserOther: msg'),
      ];

      for (final (leaf, label) in expected) {
        expect(
          describeConnectUserFailure(
            OctopusInvalidArguments<ClientUserError>([leaf]),
          ),
          'connectUser refused: $label',
          reason: '${leaf.runtimeType} must render its own label',
        );
      }

      // Still worth asserting jointly: six leaves, six distinct labels.
      expect(expected.map((e) => e.$2).toSet(), hasLength(expected.length));
    });
  });
}
