import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Injectable device-authentication boundary so the gate can be tested with a
/// fake and fails closed on any platform error.
abstract interface class DeviceAuthenticator {
  Future<bool> isDeviceSupported();

  Future<bool> authenticate({required String localizedReason});
}

class LocalAuthDeviceAuthenticator implements DeviceAuthenticator {
  final LocalAuthentication _auth;

  LocalAuthDeviceAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  @override
  Future<bool> authenticate({required String localizedReason}) =>
      _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
}

enum BiometricGateResult { authenticated, notAvailable, cancelled, error }

class BiometricGateOutcome {
  final BiometricGateResult result;
  final String? errorCode;

  const BiometricGateOutcome(this.result, [this.errorCode]);

  static const authenticated = BiometricGateOutcome(
    BiometricGateResult.authenticated,
  );
  static const notAvailable = BiometricGateOutcome(
    BiometricGateResult.notAvailable,
  );
  static const cancelled = BiometricGateOutcome(BiometricGateResult.cancelled);
  static BiometricGateOutcome error(String code) =>
      BiometricGateOutcome(BiometricGateResult.error, code);
}

/// Device biometric/PIN gate used before enabling automatic sudo answers.
///
/// Every method fails closed: any platform error or unavailable sensor is
/// reported as a non-authenticated [BiometricGateOutcome] carrying the platform
/// error code, so the UI can say *why* the gate did not open instead of
/// silently reverting a toggle.
class BiometricGate {
  final DeviceAuthenticator _authenticator;

  BiometricGate({DeviceAuthenticator? authenticator})
    : _authenticator = authenticator ?? LocalAuthDeviceAuthenticator();

  /// True when the device can gate with a biometric or device PIN.
  Future<bool> isAvailable() async {
    try {
      return await _authenticator.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user with the device's own biometric/PIN screen and reports
  /// the precise outcome.
  Future<BiometricGateOutcome> authenticateDetailed({
    required String localizedReason,
  }) async {
    try {
      if (!await isAvailable()) return BiometricGateOutcome.notAvailable;
      final ok = await _authenticator.authenticate(
        localizedReason: localizedReason,
      );
      return ok
          ? BiometricGateOutcome.authenticated
          : BiometricGateOutcome.cancelled;
    } on PlatformException catch (e) {
      return BiometricGateOutcome.error(e.code);
    } catch (_) {
      return BiometricGateOutcome.error('unknown');
    }
  }

  /// Convenience bool wrapper around [authenticateDetailed].
  Future<bool> authenticate({required String localizedReason}) async =>
      (await authenticateDetailed(localizedReason: localizedReason)).result ==
      BiometricGateResult.authenticated;
}
