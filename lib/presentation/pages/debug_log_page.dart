import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  static final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  static void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.add('[$timestamp] $message');
    // Keep only last 500 logs
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  void _copyLogs() {
    final logsText = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(8),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            final log = _logs[index];
            Color textColor = Colors.white;
            
            // Color code based on log type
            if (log.contains('❌')) {
              textColor = Colors.red;
            } else if (log.contains('✅')) {
              textColor = Colors.green;
            } else if (log.contains('🔍') || log.contains('🔗')) {
              textColor = Colors.blue;
            } else if (log.contains('⚠️')) {
              textColor = Colors.orange;
            } else if (log.contains('🚀')) {
              textColor = Colors.purple;
            }
            
            return Text(
              log,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: textColor,
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scrollToBottom,
        child: const Icon(Icons.arrow_downward),
        tooltip: 'Scroll to bottom',
      ),
    );
  }
}