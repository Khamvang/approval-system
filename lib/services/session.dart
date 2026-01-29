import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _keyUser = 'session_user';
  static const _keyLastActivity = 'session_last_activity';
  static const _keyLanguage = 'session_language';
  static const _keyTimeoutMinutes = 'session_timeout_minutes';

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_keyUser, json.encode(user));
    prefs.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyUser);
    if (s == null) return null;
    try {
      return Map<String, dynamic>.from(json.decode(s));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await prefs.remove(_keyLastActivity);
  }

  static Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<int?> getLastActivityMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastActivity);
  }

  // Language preference (e.g. 'en', 'th')
  static Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, lang);
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage);
  }

  // Session timeout in minutes
  static Future<void> setTimeoutMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimeoutMinutes, minutes);
  }

  static Future<int?> getTimeoutMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTimeoutMinutes);
  }

  // Recent users stored as JSON list of user maps
  static const _keyRecentUsers = 'session_recent_users';

  static Future<List<Map<String, dynamic>>> getRecentUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyRecentUsers);
    if (s == null) return [];
    try {
      final list = json.decode(s) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addRecentUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final cur = await getRecentUsers();
    // keep only unique by email
    final email = (user['email'] ?? '').toString();
    final filtered = cur.where((u) => (u['email'] ?? '') != email).toList();
    filtered.insert(0, user);
    // trim to last 10
    final trimmed = filtered.take(10).toList();
    await prefs.setString(_keyRecentUsers, json.encode(trimmed));
  }

  static Future<void> clearRecentUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecentUsers);
  }

  // Save password for an email on this browser (used only when user checks Remember)
  static const _keySavedPasswords = 'session_saved_passwords';

  static Future<Map<String, String>> _loadSavedPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keySavedPasswords);
    if (s == null) return {};
    try {
      final m = json.decode(s) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePasswordForEmail(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadSavedPasswords();
    map[email] = password;
    await prefs.setString(_keySavedPasswords, json.encode(map));
  }

  static Future<String?> getSavedPasswordForEmail(String email) async {
    final map = await _loadSavedPasswords();
    return map[email];
  }

  static Future<void> clearSavedPasswordForEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadSavedPasswords();
    map.remove(email);
    await prefs.setString(_keySavedPasswords, json.encode(map));
  }
}
