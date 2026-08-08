import 'dart:collection';
import 'dart:io' show Platform;

class RateLimitConfig {
  final int maxAttempts;
  final int maxAccountAttempts;
  final Duration window;
  final Duration cooldown;

  const RateLimitConfig({
    this.maxAttempts = 5,
    this.maxAccountAttempts = 10,
    this.window = const Duration(minutes: 1),
    this.cooldown = const Duration(minutes: 5),
  });

  factory RateLimitConfig.fromEnvironment() {
    return RateLimitConfig(
      maxAttempts: _envInt('RATE_LIMIT_MAX_ATTEMPTS', 5),
      maxAccountAttempts: _envInt('RATE_LIMIT_MAX_ACCOUNT_ATTEMPTS', 10),
      window: Duration(
        seconds: _envInt('RATE_LIMIT_WINDOW_SECONDS', 60),
      ),
      cooldown: Duration(
        minutes: _envInt('RATE_LIMIT_COOLDOWN_MINUTES', 5),
      ),
    );
  }

  static int _envInt(String key, int fallback) {
    final val = Platform.environment[key];
    if (val == null || val.isEmpty) return fallback;
    return int.tryParse(val) ?? fallback;
  }
}

class RateLimitEntry {
  final Queue<DateTime> timestamps = Queue<DateTime>();
  DateTime? cooldownUntil;
}

class RateLimiter {
  final RateLimitConfig _config;
  final Map<String, RateLimitEntry> _deviceEntries = {};
  final Map<String, RateLimitEntry> _accountEntries = {};

  RateLimiter({RateLimitConfig? config})
      : _config = config ?? RateLimitConfig.fromEnvironment();

  RateLimitResult attempt({String? deviceId, String? accountId}) {
    final now = DateTime.now();

    if (deviceId != null) {
      final result = _checkEntry(_deviceEntries, deviceId, _config.maxAttempts, now);
      if (!result.allowed) return result;
    }

    if (accountId != null) {
      final result = _checkEntry(_accountEntries, accountId, _config.maxAccountAttempts, now);
      if (!result.allowed) return result;
    }

    if (deviceId != null) {
      _deviceEntries.putIfAbsent(deviceId, () => RateLimitEntry()).timestamps.add(now);
    }
    if (accountId != null) {
      _accountEntries.putIfAbsent(accountId, () => RateLimitEntry()).timestamps.add(now);
    }

    return const RateLimitResult(allowed: true);
  }

  RateLimitResult _checkEntry(
    Map<String, RateLimitEntry> entries,
    String key,
    int maxAttempts,
    DateTime now,
  ) {
    final entry = entries.putIfAbsent(key, () => RateLimitEntry());

    if (entry.cooldownUntil != null && now.isBefore(entry.cooldownUntil!)) {
      return RateLimitResult(
        allowed: false,
        retryAfter: entry.cooldownUntil!.difference(now),
        reason: 'Too many attempts. Please wait.',
      );
    }

    while (entry.timestamps.isNotEmpty &&
        now.difference(entry.timestamps.first) > _config.window) {
      entry.timestamps.removeFirst();
    }

    if (entry.timestamps.length >= maxAttempts) {
      entry.cooldownUntil = now.add(_config.cooldown);
      entry.timestamps.clear();
      return RateLimitResult(
        allowed: false,
        retryAfter: _config.cooldown,
        reason: 'Too many attempts. Please wait ${_config.cooldown.inMinutes} minutes.',
      );
    }

    return const RateLimitResult(allowed: true);
  }

  void reset({String? deviceId, String? accountId}) {
    if (deviceId != null) _deviceEntries.remove(deviceId);
    if (accountId != null) _accountEntries.remove(accountId);
  }
}

class RateLimitResult {
  final bool allowed;
  final Duration? retryAfter;
  final String? reason;

  const RateLimitResult({
    required this.allowed,
    this.retryAfter,
    this.reason,
  });
}