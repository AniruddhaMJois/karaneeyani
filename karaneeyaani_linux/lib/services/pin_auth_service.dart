import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinAuthService extends ChangeNotifier {
  static const String hardcodedOtp = '123456';
  static const String _isLoggedInKey = 'user_is_logged_in';
  static const String _phoneNumberKey = 'user_phone_number';
  static const String _userNameKey = 'user_display_name';

  bool _isAuthenticated = false;
  String _phoneNumber = '';
  String _userName = '';
  bool _isInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  String get phoneNumber => _phoneNumber;
  String get userName => _userName;
  bool get hasName => _userName.trim().isNotEmpty;
  bool get isInitialized => _isInitialized;

  // Compatibility flags
  bool get isPinSet => _isAuthenticated;
  bool get isLocked => !_isAuthenticated;
  bool get isBiometricsEnabled => false;

  PinAuthService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool(_isLoggedInKey) ?? false;
    _phoneNumber = prefs.getString(_phoneNumberKey) ?? '';
    _userName = prefs.getString(_userNameKey) ?? '';
    _isInitialized = true;
    notifyListeners();
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

  Future<void> logout() async {
    _isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    notifyListeners();
  }

  void lock() {
    logout();
  }
}
