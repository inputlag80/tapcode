import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _hasPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied || status.isRestricted) {
      // Запрашиваем разрешение
      final result = await Permission.camera.request();
      if (result.isGranted) {
        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
      } else {
        // Показываем сообщение, что разрешение не дано
        setState(() => _isLoading = false);
        _showPermissionDeniedDialog();
      }
    } else if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Нет доступа к камере'),
        content: const Text('Для сканирования кодов необходимо разрешить доступ к камере в настройках устройства.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // закрываем сканер
            },
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Наведите камеру на код')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasPermission
              ? MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (var barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        Navigator.pop(context, barcode.rawValue);
                        break;
                      }
                    }
                  },
                )
              : const Center(child: Text('Нет доступа к камере')),
    );
  }
}