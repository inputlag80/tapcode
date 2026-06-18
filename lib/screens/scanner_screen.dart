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
  bool _torchOn = false;
  bool _codeDetected = false; // для подсветки рамки

  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    autoStart: true,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 50,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied || status.isRestricted) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
      } else {
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
              Navigator.pop(context);
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

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() {
      _torchOn = !_torchOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Наведите камеру на код'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
            tooltip: 'Включить/выключить фонарик',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasPermission
              ? Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final barcode = barcodes.first;
                          // Подсвечиваем рамку
                          if (!_codeDetected) {
                            setState(() {
                              _codeDetected = true;
                            });
                          }
                          // Возвращаем результат
                          if (barcode.rawValue != null) {
                            Navigator.pop(context, barcode.rawValue);
                          }
                        } else {
                          if (_codeDetected) {
                            setState(() {
                              _codeDetected = false;
                            });
                          }
                        }
                      },
                      overlayBuilder: (context, constraints) {
                        return Center(
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _codeDetected
                                    ? Colors.greenAccent
                                    : Colors.white54,
                                width: _codeDetected ? 3 : 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _codeDetected
                                  ? [
                                      const BoxShadow(
                                        color: Colors.greenAccent,
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: _codeDetected
                                ? const Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                      size: 50,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.crop_free,
                                      color: Colors.white54,
                                      size: 60,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    // Подсказка внизу
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _codeDetected
                                ? '✅ Код найден!'
                                : 'Наведите на код (QR, DataMatrix, EAN-13)',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(child: Text('Нет доступа к камере')),
    );
  }
}
