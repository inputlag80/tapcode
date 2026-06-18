import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final db = DatabaseHelper();
    final stats = await db.getStatistics();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _clearStats() async {
    final db = DatabaseHelper();
    await db.clearStatistics();
    _loadStatistics();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Статистика очищена')),
    );
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
        title: const Text('Статистика'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Очистить статистику'),
                content: const Text('Вы уверены, что хотите очистить всю статистику?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearStats();
                    },
                    child: const Text('Очистить'),
                  ),
                ],
              ),
            ),
            tooltip: 'Очистить статистику',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Общие показатели
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Общая информация',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Всего товаров', _stats['totalProducts'] ?? 0),
                    _buildStatRow('Добавлено', _stats['totalAdds'] ?? 0),
                    _buildStatRow('Удалено', _stats['totalDeletes'] ?? 0),
                    _buildStatRow('Поисковых запросов', _stats['totalSearches'] ?? 0),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Топ запросов
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Самые частые поисковые запросы',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_stats['topQueries'] != null && (_stats['topQueries'] as List).isNotEmpty)
                      ...(_stats['topQueries'] as List).map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['query'] ?? ''),
                              Text('${item['count']} раз',
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      const Text('Нет данных',
                          style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Топ товаров
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Самые просматриваемые товары',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_stats['topProducts'] != null && (_stats['topProducts'] as List).isNotEmpty)
                      ...(_stats['topProducts'] as List).map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'] ?? 'Без названия',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('${item['views']} просмотров',
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      const Text('Нет данных',
                          style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}