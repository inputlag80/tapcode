import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  static const String _keyTheme = 'theme';
  static const String _keyLanguage = 'language';
  static const String _keyCodeType = 'codeType';
  static const String _keyFirstLaunch = 'first_launch';

  static const String codeTypeQR = 'qr';
  static const String codeTypeDataMatrix = 'datamatrix';
  static const String codeTypeEAN13 = 'ean13';

  String _theme = 'dark';
  String _language = 'ru';
  String _codeType = codeTypeEAN13;

  SettingsManager() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _theme = prefs.getString(_keyTheme) ?? 'dark';
    _language = prefs.getString(_keyLanguage) ?? 'ru';
    _codeType = prefs.getString(_keyCodeType) ?? codeTypeEAN13;
    notifyListeners();
  }

  // Геттеры
  String get theme => _theme;
  String get language => _language;
  String get codeType => _codeType;
  ThemeMode get themeMode => _theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
  Locale get locale => Locale(_language, _language.toUpperCase());

  // Методы сохранения
  Future<void> saveTheme(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, themeMode);
    _theme = themeMode;
    notifyListeners();
  }

  Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, languageCode);
    _language = languageCode;
    notifyListeners();
  }

  Future<void> saveCodeType(String codeType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCodeType, codeType);
    _codeType = codeType;
    notifyListeners();
  }

  // Флаг первого запуска
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  Future<void> setFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
  }

  // Статический синглтон
  static SettingsManager? _instance;
  static SettingsManager get instance {
    _instance ??= SettingsManager();
    return _instance!;
  }
}
