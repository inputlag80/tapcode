import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../settings/settings_manager.dart';
import '../database/database_helper.dart';
import 'list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsManager _settings = SettingsManager();
  String _theme = 'dark';
  String _language = 'ru';
  String _codeType = SettingsManager.codeTypeEAN13;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final theme = await _settings.getTheme();
    final language = await _settings.getLanguage();
    final codeType = await _settings.getCodeType();
    setState(() {
      _theme = theme;
      _language = language;
      _codeType = codeType;
      _isLoading = false;
    });
  }

  // ===== Экспорт базы =====
  Future<void> _exportDatabase() async {
    try {
      final db = DatabaseHelper();
      final jsonData = await db.exportDatabase();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/tapcode_backup.json');
      await file.writeAsString(jsonData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Резервная копия базы данных "Шпора кассира"',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    }
  }

  // ===== Импорт базы =====
  Future<void> _importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return;

      final file = File(result.files.single.path!);
      final jsonData = await file.readAsString();

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импорт базы данных'),
          content: const Text('Это действие полностью заменит текущую базу данных. Все существующие товары и события будут удалены. Продолжить?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Импортировать', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      final db = DatabaseHelper();
      await db.importDatabase(jsonData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('База данных успешно импортирована')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ListScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Тема
          ListTile(
            title: const Text('Тема'),
            subtitle: Text(_theme == 'dark' ? 'Тёмная' : 'Светлая'),
            trailing: Switch(
              value: _theme == 'dark',
              onChanged: (value) {
                _settings.saveTheme(value ? 'dark' : 'light');
                setState(() => _theme = value ? 'dark' : 'light');
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Перезапустите приложение'),
                    content: const Text('Для применения темы перезапустите приложение вручную.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          // Язык
          ListTile(
            title: const Text('Язык интерфейса'),
            subtitle: Text(_language == 'ru' ? 'Русский' : 'English'),
            trailing: DropdownButton<String>(
              value: _language,
              items: const [
                DropdownMenuItem(value: 'ru', child: Text('Русский')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _settings.saveLanguage(value);
                  setState(() => _language = value);
                }
              },
            ),
          ),
          const Divider(),
          // Тип кода
          ListTile(
            title: const Text('Тип кода по умолчанию'),
            subtitle: Text(_getCodeTypeName(_codeType)),
            trailing: DropdownButton<String>(
              value: _codeType,
              items: const [
                DropdownMenuItem(
                  value: SettingsManager.codeTypeQR,
                  child: Text('QR-код'),
                ),
                DropdownMenuItem(
                  value: SettingsManager.codeTypeDataMatrix,
                  child: Text('DataMatrix'),
                ),
                DropdownMenuItem(
                  value: SettingsManager.codeTypeEAN13,
                  child: Text('EAN-13'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _settings.saveCodeType(value);
                  setState(() => _codeType = value);
                }
              },
            ),
          ),
          const Divider(),
          // ===== РЕЗЕРВНОЕ КОПИРОВАНИЕ =====
          ListTile(
            title: const Text('Резервное копирование'),
            subtitle: const Text('Экспорт или импорт всей базы данных'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.green),
                  onPressed: _exportDatabase,
                  tooltip: 'Экспорт',
                ),
                IconButton(
                  icon: const Icon(Icons.file_download, color: Colors.blue),
                  onPressed: _importDatabase,
                  tooltip: 'Импорт',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'При смене темы или языка требуется перезапуск приложения.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getCodeTypeName(String type) {
    switch (type) {
      case SettingsManager.codeTypeQR:
        return 'QR-код';
      case SettingsManager.codeTypeDataMatrix:
        return 'DataMatrix';
      case SettingsManager.codeTypeEAN13:
        return 'EAN-13';
      default:
        return 'EAN-13';
    }
  }
}