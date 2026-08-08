import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeManager extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('themeMode');
    if (value == 'light') {
      state = ThemeMode.light;
    } else if (value == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final String val;
    switch (mode) {
      case ThemeMode.light: val = 'light';
      case ThemeMode.dark:  val = 'dark';
      case ThemeMode.system: val = 'system';
    }
    await prefs.setString('themeMode', val);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeManager, ThemeMode>(ThemeModeManager.new);
