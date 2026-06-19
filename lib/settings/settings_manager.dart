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
  final SettingsManager _settings = SettingsManager.instance;

  @override
  void initState() {
    super.initState();
    // Подписываемся на изменения настроек
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Просто перестраиваем экран
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Тема'),
            subtitle: Text(_settings.theme == 'dark' ? 'Тёмная' : 'Светлая'),
            trailing: Switch(
              value: _settings.theme == 'dark',
              onChanged: (value) {
                _settings.saveTheme(value ? 'dark' : 'light');
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Язык интерфейса'),
            subtitle: Text(_settings.language == 'ru' ? 'Русский' : 'English'),
            trailing: DropdownButton<String>(
              value: _settings.language,
              items: const [
                DropdownMenuItem(value: 'ru', child: Text('Русский')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _settings.saveLanguage(value);
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Тип кода по умолчанию'),
            subtitle: Text(_getCodeTypeName(_settings.codeType)),
            trailing: DropdownButton<String>(
              value: _settings.codeType,
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
                }
              },
            ),
          ),
          const Divider(),
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

  // ===== Экспорт/импорт (без изменений) =====
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
}
