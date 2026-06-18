import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import 'scanner_screen.dart';

class AddEditScreen extends StatefulWidget {
  final Product? product;
  const AddEditScreen({super.key, this.product});

  @override
  AddEditScreenState createState() => AddEditScreenState();
}

class AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barcodeController;
  late TextEditingController _qrCodeController;
  late TextEditingController _titleController;
  late TextEditingController _tagsController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _qrCodeController = TextEditingController(text: widget.product?.qrCode ?? '');
    _titleController = TextEditingController(text: widget.product?.title ?? '');
    _tagsController = TextEditingController(text: widget.product?.tags ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
    _imagePath = widget.product?.imagePath;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 300,
      maxHeight: 300,
      imageQuality: 70,
    );
    if (image != null) {
      final dir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(join(dir.path, 'product_images'));
      if (!await imageDir.exists()) await imageDir.create();
      String filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      String path = join(imageDir.path, filename);
      await File(image.path).copy(path);
      setState(() => _imagePath = path);
    }
  }

  Future<void> _save(BuildContext ctx) async {
    if (_formKey.currentState!.validate()) {
      final product = Product(
        id: widget.product?.id,
        barcode: _barcodeController.text.trim(),
        qrCode: _qrCodeController.text.trim().isEmpty ? null : _qrCodeController.text.trim(),
        title: _titleController.text.trim(),
        tags: _tagsController.text.trim(),
        description: _descriptionController.text.trim(),
        imagePath: _imagePath,
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        createdAt: widget.product?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      );
      final db = DatabaseHelper();
      try {
        if (widget.product == null) {
          await db.insertProduct(product);
        } else {
          await db.updateProduct(product);
        }
        if (mounted) Navigator.pop(ctx, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Ошибка сохранения: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final BuildContext ctx = context;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Добавить товар' : 'Редактировать'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Штрихкод + сканер
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(labelText: 'Штрихкод (EAN-13)'),
                      validator: (v) => v!.trim().isEmpty ? 'Обязательное поле' : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final code = await Navigator.push<String>(
                        ctx,
                        MaterialPageRoute(builder: (_) => const ScannerScreen()),
                      );
                      if (code != null && code.isNotEmpty) {
                        setState(() => _barcodeController.text = code);
                      }
                    },
                    tooltip: 'Сканировать штрихкод',
                  ),
                ],
              ),
              // QR-код
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qrCodeController,
                      decoration: const InputDecoration(labelText: 'QR-код (с ценника, опционально)'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final code = await Navigator.push<String>(
                        ctx,
                        MaterialPageRoute(builder: (_) => const ScannerScreen()),
                      );
                      if (code != null && code.isNotEmpty) {
                        setState(() => _qrCodeController.text = code);
                      }
                    },
                    tooltip: 'Сканировать QR-код',
                  ),
                ],
              ),
              // Название
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (v) => v!.trim().isEmpty ? 'Введите название' : null,
              ),
              // Теги
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Теги (через запятую)'),
              ),
              // Описание
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              // Категория
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Категория (например: Молочка, Хлеб)'),
              ),
              // Фото
              Row(
                children: [
                  Expanded(
                    child: _imagePath != null
                        ? Column(
                            children: [
                              Image.file(File(_imagePath!), height: 80, fit: BoxFit.cover),
                              const SizedBox(height: 4),
                              const Text('Фото добавлено'),
                            ],
                          )
                        : const Text('Нет фото'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _pickImage,
                    tooltip: 'Сделать фото',
                  ),
                  if (_imagePath != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _imagePath = null),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _save(ctx),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
