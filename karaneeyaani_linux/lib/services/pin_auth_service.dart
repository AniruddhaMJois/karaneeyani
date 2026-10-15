import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinAuthService extends ChangeNotifier {
  static const String hardcodedOtp = '123456';
  static const String _isLoggedInKey = 'user_is_logged_in';
  static const String _phoneNumberKey = 'user_phone_number';
  static const String _userNameKey = 'user_display_name';
  static const String _pinHashKey = 'user_6digit_pin_hash';

  bool _isAuthenticated = false;
  String _phoneNumber = '';
  String _userName = '';
  bool _isPinSet = false;
  bool _isLocked = true;
  bool _isInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  String get phoneNumber => _phoneNumber;
  String get userName => _userName;
  bool get hasName => _userName.trim().isNotEmpty;
  bool get isPinSet => _isPinSet;
  bool get isLocked => _isLocked;
  bool get isInitialized => _isInitialized;

  PinAuthService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool(_isLoggedInKey) ?? false;
    _phoneNumber = prefs.getString(_phoneNumberKey) ?? '';
    _userName = prefs.getString(_userNameKey) ?? '';
    final pinHash = prefs.getString(_pinHashKey);
    _isPinSet = pinHash != null && pinHash.isNotEmpty;
    // Compulsory lock on startup if PIN is set
    _isLocked = _isPinSet;
    _isInitialized = true;
    notifyListeners();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode('karaneeyaani_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  Future<bool> setupPin(String pin) async {
    if (pin.length != 6) return false;
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(pin);
    await prefs.setString(_pinHashKey, hash);
    _isPinSet = true;
    _isLocked = false;
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    if (pin.length != 6) return false;
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_pinHashKey);
    if (savedHash == null) return false;

    if (_hashPin(pin) == savedHash) {
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
    await prefs.setString(_pinHashKey, _hashPin(newPin));
    notifyListeners();
    return true;
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, _userName);
    notifyListeners();
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    final cleanOtp = otp.trim();
    if (cleanOtp == hardcodedOtp) {
      _isAuthenticated = true;
      _phoneNumber = phone.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_phoneNumberKey, _phoneNumber);
      notifyListeners();
      return true;
    }
    return false;
  }

  void lock() {
    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _isLocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    notifyListeners();
  }
}
