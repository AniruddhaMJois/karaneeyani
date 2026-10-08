import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinAuthService extends ChangeNotifier {
  static const String _pinHashKey = 'user_6digit_pin_hash';
  static const String _bioEnabledKey = 'user_bio_auth_enabled';
  static const String _isConfiguredKey = 'pin_auth_configured_flag';

  bool _isPinSet = false;
  bool _isBiometricsEnabled = false;
  bool _isLocked = true;
  bool _isInitialized = false;

  bool get isPinSet => _isPinSet;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isLocked => _isLocked;
  bool get isInitialized => _isInitialized;

  PinAuthService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_pinHashKey);
    _isPinSet = hash != null && hash.isNotEmpty;
    _isBiometricsEnabled = prefs.getBool(_bioEnabledKey) ?? false;
    _isLocked = _isPinSet;
    _isInitialized = true;
    notifyListeners();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode('karaneeyaani_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  Future<bool> setupPin(String pin, {bool enableBiometrics = false}) async {
    if (pin.length != 6) return false;
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(pin);
    await prefs.setString(_pinHashKey, hash);
    await prefs.setBool(_bioEnabledKey, enableBiometrics);
    await prefs.setBool(_isConfiguredKey, true);

    _isPinSet = true;
    _isBiometricsEnabled = enableBiometrics;
    _isLocked = false;
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    if (pin.length != 6) return false;
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_pinHashKey);
    if (savedHash == null) return false;

    final inputHash = _hashPin(pin);
    if (inputHash == savedHash) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (newPin.length != 6) return false;
    final valid = await verifyPin(oldPin);
    if (!valid) return false;

    final prefs = await SharedPreferences.getInstance();
    final newHash = _hashPin(newPin);
    await prefs.setString(_pinHashKey, newHash);
    notifyListeners();
    return true;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    _isBiometricsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bioEnabledKey, enabled);
    notifyListeners();
  }

  void lock() {
    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_bioEnabledKey);
    await prefs.remove(_isConfiguredKey);
    _isPinSet = false;
    _isBiometricsEnabled = false;
    _isLocked = false;
    notifyListeners();
  }
}
