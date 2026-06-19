import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  _ScanHistoryScreenState createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = DatabaseHelper();
    final data = await db.getScanHistory();
    setState(() {
      _history = data;
      _isLoading = false;
    });
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История сканирований'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final db = DatabaseHelper();
              await db.clearScanHistory();
              _loadHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('История очищена')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('Нет сканирований'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return ListTile(
                      leading: Icon(
                        item['found'] == 1 ? Icons.check_circle : Icons.error,
                        color: item['found'] == 1 ? Colors.green : Colors.red,
                      ),
                      title: Text(item['code']),
                      subtitle: Text(_formatTimestamp(item['timestamp'])),
                      trailing: Text(
                        item['found'] == 1 ? 'Найден' : 'Не найден',
                        style: TextStyle(
                          color: item['found'] == 1 ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}