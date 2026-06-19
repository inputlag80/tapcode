import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/list_screen.dart';
import 'settings/settings_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SettingsManager _settings = SettingsManager.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isFirst = await _settings.isFirstLaunch();
      if (isFirst && mounted) {
        _showMasterScreen();
      }
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  void _showMasterScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Добро пожаловать в "Шпора кассира"!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('1. Добавляйте товары через сканер или вручную.'),
            SizedBox(height: 8),
            Text('2. Ищите по названию, категории или штрих-коду.'),
            SizedBox(height: 8),
            Text('3. Обменивайтесь базами с коллегами через QR-код.'),
            SizedBox(height: 8),
            Text('4. Смотрите статистику и историю действий.'),
            SizedBox(height: 8),
            Text('5. Сканируйте коды для быстрого поиска и создания.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _settings.setFirstLaunchDone();
            },
            child: const Text('Понятно!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Шпора кассира',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.blue),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      themeMode: _settings.themeMode,
      locale: _settings.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      home: const ListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
