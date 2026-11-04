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

/// Device biometric/PIN gate used before enabling automatic sudo answers.
///
/// Every method fails closed: any platform error or unavailable sensor
/// reports "not authenticated", so the caller falls back to the manual flow.
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

  /// Prompts the user with the device's own biometric/PIN screen.
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      if (!await isAvailable()) return false;
      return await _authenticator.authenticate(
        localizedReason: localizedReason,
      );
    } catch (_) {
      return false;
    }
  }
}
