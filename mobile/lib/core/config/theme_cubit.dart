import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeCubit que persiste la preferencia del usuario usando SharedPreferences.
/// Elimina la necesidad de volver a seleccionar el tema al reiniciar la app.
class ThemeCubit extends Cubit<ThemeMode> {
  static const _themeKey = 'theme_mode';
  SharedPreferences? _prefs;

  ThemeCubit() : super(ThemeMode.system) {
    _loadTheme();
  }

  /// Carga la preferencia guardada al iniciar
  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString(_themeKey);
    if (saved != null) {
      final mode = ThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => ThemeMode.system,
      );
      emit(mode);
    }
  }

  /// Alterna entre claro y oscuro
  void toggleTheme() {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveAndEmit(newMode);
  }

  /// Establece un modo específico
  void setTheme(ThemeMode mode) {
    _saveAndEmit(mode);
  }

  void _saveAndEmit(ThemeMode mode) {
    _prefs?.setString(_themeKey, mode.name);
    emit(mode);
  }
}
