import 'dart:io';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../models/product.dart';
import 'add_edit_screen.dart';
import '../settings/settings_manager.dart';
import '../database/database_helper.dart'; // импортируем DatabaseHelper

class DetailScreen extends StatefulWidget {
  final Product product;
  const DetailScreen({super.key, required this.product});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String _codeType = SettingsManager.codeTypeEAN13;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Логируем просмотр товара (если id не null)
    if (widget.product.id != null) {
      DatabaseHelper().logViewProduct(widget.product.id!);
    }
  }

  Future<void> _loadSettings() async {
    final settings = SettingsManager();
    final type = await settings.getCodeType();
    setState(() {
      _codeType = type;
      _isLoading = false;
    });
  }

  Barcode _getBarcode() {
    switch (_codeType) {
      case SettingsManager.codeTypeQR:
        return Barcode.qrCode();
      case SettingsManager.codeTypeDataMatrix:
        return Barcode.dataMatrix();
      case SettingsManager.codeTypeEAN13:
      default:
        return Barcode.ean13();
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
        title: Text(widget.product.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditScreen(product: widget.product),
                ),
              );
              if (result == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.product.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(widget.product.imagePath!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
                ),
              ),
            const SizedBox(height: 16),
            // Код с белым фоном
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: BarcodeWidget(
                barcode: _getBarcode(),
                data: widget.product.barcode,
                width: 250,
                height: 100,
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Штрихкод: ${widget.product.barcode}',
              style: const TextStyle(fontSize: 16),
            ),
            if (widget.product.qrCode != null && widget.product.qrCode!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'QR-код: ${widget.product.qrCode}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
            const Divider(height: 32),
            if (widget.product.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: widget.product.tags
                    .split(',')
                    .map((tag) => Chip(label: Text(tag.trim())))
                    .toList(),
              ),
            if (widget.product.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                widget.product.description,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}