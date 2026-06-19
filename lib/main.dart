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
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
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
