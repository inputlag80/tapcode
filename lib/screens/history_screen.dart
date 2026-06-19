import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = DatabaseHelper();
    final events = await db.getEvents(limit: 200);
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getActionLabel(String type) {
    switch (type) {
      case 'add': return '➕ Добавление';
      case 'delete': return '🗑️ Удаление';
      case 'view': return '👁️ Просмотр';
      case 'search': return '🔍 Поиск';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История действий'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('Нет событий'))
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final type = event['type'] ?? '';
                    final title = event['product_title'] ?? '';
                    final query = event['query'] ?? '';
                    final timestamp = event['timestamp'] ?? 0;

                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(_getActionLabel(type)),
                      subtitle: Text(
                        title.isNotEmpty
                            ? '$title  •  ${_formatTimestamp(timestamp)}'
                            : query.isNotEmpty
                                ? 'Запрос: "$query"  •  ${_formatTimestamp(timestamp)}'
                                : _formatTimestamp(timestamp),
                        maxLines: 2,
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}
