import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xekveefmrwszyvkmhxvy.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhla3ZlZWZtcndzenl2a21oeHZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0MTkyODYsImV4cCI6MjEwNzk5NTI4Nn0.4inVz6rbqwyfwkfzCNQGv8qZFb5JIpsZ3ZrvpmRkKhI',
  );

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase initialization skipped or offline: $e');
    }
  }

  /// Check if the device currently has active network connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
  }
}
