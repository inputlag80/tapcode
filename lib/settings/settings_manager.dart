import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const String _keyTheme = 'theme';
  static const String _keyLanguage = 'language';
  static const String _keyCodeType = 'codeType';

  // Типы кода
  static const String codeTypeQR = 'qr';
  static const String codeTypeDataMatrix = 'datamatrix';
  static const String codeTypeEAN13 = 'ean13';

  Future<void> saveTheme(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, themeMode);
  }

  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTheme) ?? 'dark';
  }

  Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, languageCode);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'ru';
  }

  Future<void> saveCodeType(String codeType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCodeType, codeType);
  }

  Future<String> getCodeType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCodeType) ?? codeTypeEAN13;
  }
}