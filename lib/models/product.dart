class Product {
  int? id;
  String barcode;
  String? qrCode;
  String title;
  String tags;
  String description;
  String? imagePath;
  String? category; // новая категория
  int? createdAt;  // время создания (Unix timestamp)

  Product({
    this.id,
    required this.barcode,
    this.qrCode,
    required this.title,
    required this.tags,
    required this.description,
    this.imagePath,
    this.category,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'qrCode': qrCode,
      'title': title,
      'tags': tags,
      'description': description,
      'imagePath': imagePath,
      'category': category,
      'createdAt': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      qrCode: map['qrCode'],
      title: map['title'],
      tags: map['tags'] ?? '',
      description: map['description'] ?? '',
      imagePath: map['imagePath'],
      category: map['category'],
      createdAt: map['createdAt'],
    );
  }
}