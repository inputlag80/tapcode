import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import 'add_edit_screen.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'history_screen.dart';
import 'scanner_screen.dart';
import 'share_screen.dart';
import '../settings/settings_manager.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  ListScreenState createState() => ListScreenState();
}

class ListScreenState extends State<ListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = false;

  String _selectedCategory = 'Все';
  List<String> _categories = ['Все'];
  String _sortBy = 'title';
  bool _sortAscending = true;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final db = DatabaseHelper();
    final cats = await db.getAllCategories();
    setState(() {
      _categories = ['Все', ...cats];
      if (_selectedCategory != 'Все' && !_categories.contains(_selectedCategory)) {
        _selectedCategory = 'Все';
      }
    });
  }

  Future<void> _loadProducts(String query) async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    final category = _selectedCategory == 'Все' ? null : _selectedCategory;
    List<Product> results = await db.searchProducts(
      query,
      category: category,
      sortBy: _sortBy,
      ascending: _sortAscending,
    );
    setState(() {
      _products = results;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    await _loadCategories();
    await _loadProducts(_searchController.text);
  }

  void _applyFilterAndSort() {
    _loadProducts(_searchController.text);
    _loadCategories();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadProducts(value);
    });
  }

  // ===== Действия =====
  Future<void> _editProduct(BuildContext context, Product product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditScreen(product: product)),
    );
    if (result == true) _refresh();
  }

  Future<void> _deleteProduct(Product product) async {
    await DatabaseHelper().deleteProduct(product.id!);
    _refresh();
  }

  // ===== Диалог с QR-кодом =====
  void _showBarcodeDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => FutureBuilder<String>(
        future: SettingsManager().getCodeType(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final codeType = snapshot.data!;
          Barcode barcode;
          switch (codeType) {
            case SettingsManager.codeTypeQR:
              barcode = Barcode.qrCode();
              break;
            case SettingsManager.codeTypeDataMatrix:
              barcode = Barcode.dataMatrix();
              break;
            default:
              barcode = Barcode.ean13();
          }
          return AlertDialog(
            title: Text(product.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: BarcodeWidget(
                    barcode: barcode,
                    data: product.barcode,
                    width: 300,
                    height: 150,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.barcode,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Закрыть'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== Сканер для поиска =====
  Future<void> _scanAndSearch(BuildContext context) async {
    final String? scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (scannedCode == null || scannedCode.isEmpty) return;

    _searchController.text = scannedCode;
    // Загружаем товары по этому коду
    await _loadProducts(scannedCode);

    // Проверяем, найден ли товар
    if (_products.isEmpty) {
      // Предлагаем создать новый товар
      _showCreateNewProductDialog(context, scannedCode);
    }
  }

  // ===== Диалог создания нового товара из отсканированного кода =====
  void _showCreateNewProductDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Товар не найден'),
        content: Text('Товар со штрих-кодом "$code" не найден в базе.\nХотите добавить его?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Закрываем диалог
              // Открываем экран добавления с заполненным штрих-кодом
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditScreen(
                    product: Product(
                      barcode: code,
                      title: '',
                      tags: '',
                      description: '',
                      qrCode: null, // можно оставить пустым
                    ),
                  ),
                ),
              );
              if (result == true) {
                _refresh();
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шпора кассира'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Панель фильтрации
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Row(
              children: [
                Flexible(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                      _applyFilterAndSort();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    isExpanded: true,
                    iconSize: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: '$_sortBy|$_sortAscending',
                    items: [
                      'title|true',
                      'title|false',
                      'category|true',
                      'category|false',
                      'createdAt|true',
                      'createdAt|false',
                    ].map((value) {
                      String label;
                      switch (value) {
                        case 'title|true':
                          label = 'Название ↑';
                          break;
                        case 'title|false':
                          label = 'Название ↓';
                          break;
                        case 'category|true':
                          label = 'Категория ↑';
                          break;
                        case 'category|false':
                          label = 'Категория ↓';
                          break;
                        case 'createdAt|true':
                          label = 'Дата ↑';
                          break;
                        case 'createdAt|false':
                          label = 'Дата ↓';
                          break;
                        default:
                          label = '';
                      }
                      return DropdownMenuItem(value: value, child: Text(label));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final parts = value.split('|');
                        setState(() {
                          _sortBy = parts[0];
                          _sortAscending = parts[1] == 'true';
                        });
                        _applyFilterAndSort();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    isExpanded: true,
                    iconSize: 20,
                  ),
                ),
              ],
            ),
          ),
          // Поиск
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => _scanAndSearch(context),
                  tooltip: 'Сканировать QR-код для поиска',
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Список с Pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _isLoading && _products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 80, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('Нет товаров. Добавьте первый!', style: TextStyle(fontSize: 16)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _scanAndSearch(context),
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Сканировать код для добавления'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Dismissible(
                                key: Key(product.id.toString()),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _deleteProduct(product),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                child: GestureDetector(
                                  onLongPress: () => _editProduct(context, product),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetailScreen(product: product),
                                    ),
                                  ),
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: ListTile(
                                      leading: product.imagePath != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                File(product.imagePath!),
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                              ),
                                            )
                                          : const Icon(Icons.inventory),
                                      title: Text(product.title),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.tags.isNotEmpty ? product.tags : 'без тегов',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (product.category != null && product.category!.isNotEmpty)
                                            Text(
                                              'Категория: ${product.category}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.qr_code),
                                            onPressed: () => _showBarcodeDialog(context, product),
                                            tooltip: 'Показать штрих-код',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _editProduct(context, product),
                                            tooltip: 'Редактировать',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _deleteProduct(product),
                                            tooltip: 'Удалить',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditScreen()),
          );
          if (result == true) _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}