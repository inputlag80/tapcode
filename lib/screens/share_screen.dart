import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import 'scanner_screen.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  _ShareScreenState createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  bool _isSending = false;
  bool _isReceiving = false;
  String _status = 'Готов к обмену';
  HttpServer? _server;

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  // ===== ОТПРАВКА =====
  Future<void> _startServer() async {
    if (!mounted) return;
    setState(() {
      _isSending = true;
      _status = 'Запуск сервера...';
    });

    try {
      final db = DatabaseHelper();
      final products = await db.getAllProducts();
      final jsonData = jsonEncode({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'products': products.map((p) => p.toMap()).toList(),
      });

      final router = shelf_router.Router();
      router.get('/export', (shelf.Request request) {
        return shelf.Response.ok(jsonData, headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        });
      });

      // Получаем локальный IP
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      String ip = '127.0.0.1';
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (addr.address != '127.0.0.1') {
            ip = addr.address;
            break;
          }
        }
        if (ip != '127.0.0.1') break;
      }

      _server = await shelf_io.serve(router.call, '0.0.0.0', 0);
      int port = _server!.port;
      String url = 'http://$ip:$port/export';

      if (!mounted) {
        _server?.close();
        return;
      }

      setState(() {
        _status = 'Сервер запущен. Отсканируйте QR-код другим телефоном.';
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Отправка базы'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Отсканируйте QR-код другим телефоном'),
              const SizedBox(height: 16),
              // Оборачиваем QrImageView в SizedBox с фиксированными размерами
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: url,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text('IP: $ip\nПорт: $port', style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _server?.close();
                Navigator.pop(context);
                if (mounted) {
                  setState(() {
                    _isSending = false;
                    _status = 'Готов к обмену';
                  });
                }
              },
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _status = 'Ошибка: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка запуска сервера: $e')),
        );
      }
    }
  }

  // ===== ПОЛУЧЕНИЕ =====
  Future<void> _receiveDatabase() async {
    if (!mounted) return;
    setState(() => _isReceiving = true);
    try {
      final String? scannedUrl = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const ScannerScreen()),
      );
      if (scannedUrl == null || scannedUrl.isEmpty) {
        if (mounted) setState(() => _isReceiving = false);
        return;
      }

      if (mounted) setState(() => _status = 'Загрузка базы...');

      final response = await http.get(Uri.parse(scannedUrl));
      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }

      final String jsonData = response.body;
      final db = DatabaseHelper();

      final existingCount = (await db.getAllProducts()).length;
      String? action;
      if (existingCount > 0) {
        if (!mounted) return;
        action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Обнаружены существующие товары'),
            content: const Text('Выберите действие:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'replace'),
                child: const Text('Заменить всё'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'merge'),
                child: const Text('Дополнить новыми'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Отмена'),
              ),
            ],
          ),
        );
        if (action == 'cancel' || action == null) {
          if (mounted) setState(() => _isReceiving = false);
          return;
        }
      }

      if (action == 'replace') {
        await db.importDatabase(jsonData);
      } else if (action == 'merge') {
        await db.mergeProductsFromJson(jsonData);
      } else {
        await db.importDatabase(jsonData);
      }

      if (mounted) {
        setState(() {
          _isReceiving = false;
          _status = 'База успешно получена!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('База данных обновлена')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReceiving = false;
          _status = 'Ошибка: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка получения: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обмен базами'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Передайте свою базу другому кассиру\nили получите базу от коллеги.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _startServer,
                    icon: const Icon(Icons.send),
                    label: const Text('Отправить'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isReceiving ? null : _receiveDatabase,
                    icon: const Icon(Icons.download),
                    label: const Text('Получить'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              _status,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_isSending || _isReceiving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
