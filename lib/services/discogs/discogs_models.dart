class DiscogsOAuthCredentials {
  const DiscogsOAuthCredentials({
    required this.token,
    required this.tokenSecret,
  });
  final String token;
  final String tokenSecret;
}

class DiscogsRequestToken {
  const DiscogsRequestToken({required this.token, required this.tokenSecret});
  final String token;
  final String tokenSecret;
}

class DiscogsAccount {
  const DiscogsAccount({
    required this.id,
    required this.username,
    this.resourceUrl,
  });
  final int id;
  final String username;
  final String? resourceUrl;
}

sealed class DiscogsFailure implements Exception {
  const DiscogsFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DiscogsAuthenticationFailure extends DiscogsFailure {
  const DiscogsAuthenticationFailure(super.message);
}

class DiscogsRateLimitFailure extends DiscogsFailure {
  const DiscogsRateLimitFailure(super.message);
}

class DiscogsNetworkFailure extends DiscogsFailure {
  const DiscogsNetworkFailure(super.message);
}

class DiscogsApiFailure extends DiscogsFailure {
  const DiscogsApiFailure(super.message, {this.statusCode});
  final int? statusCode;
}
