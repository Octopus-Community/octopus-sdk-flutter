// Internal bookkeeping shared by the persistent native-to-Dart token provider
// lifecycle. This library is not exported by the public SDK barrel.

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Registered token providers, in registration order.
@visibleForTesting
final Map<String, Future<String> Function()> clientUserTokenProviders =
    <String, Future<String> Function()>{};

/// Outstanding token requests per registration.
@visibleForTesting
final Map<String, int> clientUserTokenRequestsInFlight = <String, int>{};

/// Superseded registrations retained until their last request settles.
@visibleForTesting
final Set<String> supersededClientUserTokenProviders = <String>{};

/// Registrations whose native connect call has not settled yet.
@visibleForTesting
final Set<String> connectingClientUserTokenProviders = <String>{};
