import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final ApiClient api;
  AppUser? user;
  bool ready = false;
  ThemeMode themeMode = ThemeMode.system;
  AppState(this.api) {
    api.onExpired = () {
      user = null;
      notifyListeners();
    };
  }
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = switch (prefs.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    try {
      await api.restore();
      if (api.session != null) {
        user = AppUser.fromJson(
          Map<String, dynamic>.from(api.session!['user']),
        );
        user = AppUser.fromJson(await api.json('/auth/me'));
      }
    } catch (_) {
      if (api.session == null) user = null;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final value = await api.json(
      '/auth/login',
      method: 'POST',
      data: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    await api.save(value);
    user = AppUser.fromJson(Map<String, dynamic>.from(value['user']));
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.request(
        '/auth/logout',
        method: 'POST',
        data: {'refreshToken': api.session?['refreshToken']},
        authenticated: false,
      );
    } catch (_) {
      /* Local logout still clears this device. */
    }
    await api.clear();
    user = null;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      'theme',
      value.name,
    );
  }
}
