import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'products.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        qrCode TEXT,
        title TEXT NOT NULL,
        tags TEXT,
        description TEXT,
        imagePath TEXT,
        category TEXT,
        createdAt INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_category ON products(category)');

    await db.execute('''
      CREATE TABLE events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        product_id INTEGER,
        query TEXT,
        user TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_type ON events(type)');
    await db.execute('CREATE INDEX idx_timestamp ON events(timestamp)');

    // Новая таблица для истории сканирований
    await db.execute('''
      CREATE TABLE scan_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        found INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE products ADD COLUMN createdAt INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE events ADD COLUMN user TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE scan_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            found INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
    }
  }

  // ========== Продукты ==========
  Future<int> insertProduct(Product product) async {
    Database db = await database;
    Product newProduct = product;
    if (newProduct.createdAt == null) {
      newProduct = Product(
        id: product.id,
        barcode: product.barcode,
        qrCode: product.qrCode,
        title: product.title,
        tags: product.tags,
        description: product.description,
        imagePath: product.imagePath,
        category: product.category,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    int id = await db.insert('products', newProduct.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _insertEvent('add', productId: id);
    return id;
  }

  Future<int> updateProduct(Product product) async {
    Database db = await database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    String title = result.isNotEmpty ? result.first['title'] : '';
    await _insertEvent('delete', productId: id);
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> searchProducts(
    String query, {
    String? category,
    String sortBy = 'title',
    bool ascending = true,
  }) async {
    Database db = await database;
    if (query.trim().isNotEmpty) {
      await _insertEvent('search', query: query);
    }

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.trim().isNotEmpty) {
      whereClause = 'title LIKE ? OR tags LIKE ? OR barcode LIKE ? OR qrCode LIKE ? OR description LIKE ?';
      String likeQuery = '%$query%';
      whereArgs = [likeQuery, likeQuery, likeQuery, likeQuery, likeQuery];
    }

    if (category != null && category.isNotEmpty && category != 'Все') {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND category = ?';
      } else {
        whereClause = 'category = ?';
      }
      whereArgs.add(category);
    }

    String orderBy;
    switch (sortBy) {
      case 'category':
        orderBy = 'category';
        break;
      case 'createdAt':
        orderBy = 'createdAt';
        break;
      default:
        orderBy = 'title';
    }
    orderBy += ascending ? ' ASC' : ' DESC';

    List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<String>> getAllCategories() async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != "" ORDER BY category'
    );
    return result.map((row) => row['category'] as String).toList();
  }

  Future<List<Product>> getAllProducts() async {
    return searchProducts('', category: null, sortBy: 'title', ascending: true);
  }

  // ========== События (для статистики и истории) ==========
  Future<void> _insertEvent(String type, {int? productId, String? query}) async {
    final db = await database;
    await db.insert('events', {
      'type': type,
      'product_id': productId,
      'query': query,
      'user': '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> logViewProduct(int productId) async {
    await _insertEvent('view', productId: productId);
  }

  Future<List<Map<String, dynamic>>> getEvents({int limit = 100}) async {
    final db = await database;
    List<Map<String, dynamic>> events = await db.rawQuery('''
      SELECT e.*, p.title as product_title
      FROM events e
      LEFT JOIN products p ON e.product_id = p.id
      ORDER BY e.timestamp DESC
      LIMIT ?
    ''', [limit]);
    return events;
  }

  // ========== Статистика ==========
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    final totalProducts = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products')
    ) ?? 0;
    final totalAdds = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events WHERE type = "add"')
    ) ?? 0;
    final totalDeletes = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events WHERE type = "delete"')
    ) ?? 0;
    final totalSearches = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events WHERE type = "search"')
    ) ?? 0;
    final topQueries = await db.rawQuery('''
      SELECT query, COUNT(*) as count
      FROM events
      WHERE type = "search" AND query IS NOT NULL AND query != ""
      GROUP BY query
      ORDER BY count DESC
      LIMIT 5
    ''');
    final topProducts = await db.rawQuery('''
      SELECT p.id, p.title, COUNT(e.id) as views
      FROM events e
      JOIN products p ON e.product_id = p.id
      WHERE e.type = "view"
      GROUP BY e.product_id
      ORDER BY views DESC
      LIMIT 5
    ''');
    return {
      'totalProducts': totalProducts,
      'totalAdds': totalAdds,
      'totalDeletes': totalDeletes,
      'totalSearches': totalSearches,
      'topQueries': topQueries,
      'topProducts': topProducts,
    };
  }

  Future<void> clearStatistics() async {
    final db = await database;
    await db.delete('events');
  }

  // ========== Экспорт/импорт ==========
  Future<String> exportDatabase() async {
    final db = await database;
    List<Map<String, dynamic>> products = await db.query('products');
    List<Map<String, dynamic>> events = await db.query('events');
    List<Map<String, dynamic>> scanHistory = await db.query('scan_history');

    Map<String, dynamic> data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'products': products,
      'events': events,
      'scanHistory': scanHistory,
    };
    return jsonEncode(data);
  }

  Future<void> importDatabase(String jsonString) async {
    final db = await database;
    Map<String, dynamic> data = jsonDecode(jsonString);
    List products = data['products'] ?? [];

    await db.transaction((txn) async {
      await txn.delete('events');
      await txn.delete('scan_history');
      await txn.delete('products');

      for (var productMap in products) {
        productMap.remove('id');
        await txn.insert('products', productMap);
      }
    });
  }

  // ========== Слияние (merge) ==========
  Future<void> mergeProductsFromJson(String jsonString) async {
    final db = await database;
    Map<String, dynamic> data = jsonDecode(jsonString);
    List products = data['products'] ?? [];

    await db.transaction((txn) async {
      for (var productMap in products) {
        String barcode = productMap['barcode'];
        List<Map<String, dynamic>> existing = await txn.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [barcode],
        );
        if (existing.isEmpty) {
          productMap.remove('id');
          await txn.insert('products', productMap);
        }
      }
    });
  }

  // ========== История сканирований ==========
  Future<void> addScanHistory(String code, bool found) async {
    final db = await database;
    await db.insert('scan_history', {
      'code': code,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'found': found ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 100}) async {
    final db = await database;
    return await db.query(
      'scan_history',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<void> clearScanHistory() async {
    final db = await database;
    await db.delete('scan_history');
  }
}
