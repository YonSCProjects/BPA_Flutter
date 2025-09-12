import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../services/backup_recovery_service.dart';
import '../../services/google_sheets_service.dart';
import '../../services/google_auth_service.dart';
import '../../core/theme/app_colors.dart';

/// Page for managing backups and recovery
class BackupRecoveryPage extends StatefulWidget {
  const BackupRecoveryPage({Key? key}) : super(key: key);

  @override
  State<BackupRecoveryPage> createState() => _BackupRecoveryPageState();
}

class _BackupRecoveryPageState extends State<BackupRecoveryPage> {
  late BackupRecoveryService _backupService;
  List<BackupFileInfo> _availableBackups = [];
  bool _isLoadingBackups = false;

  @override
  void initState() {
    super.initState();
    _initializeBackupService();
    _loadAvailableBackups();
  }

  void _initializeBackupService() {
    final sheetsService = context.read<GoogleSheetsService>();
    final authService = context.read<GoogleAuthService>();
    
    _backupService = BackupRecoveryService(
      sheetsService: sheetsService,
      authService: authService,
    );
  }

  Future<void> _loadAvailableBackups() async {
    setState(() => _isLoadingBackups = true);
    
    try {
      final backups = await _backupService.getAvailableBackups();
      setState(() => _availableBackups = backups);
    } catch (e) {
      debugPrint('Error loading backups: $e');
    } finally {
      setState(() => _isLoadingBackups = false);
    }
  }

  Future<void> _createBackup() async {
    final confirmed = await _showConfirmationDialog(
      title: 'יצירת גיבוי',
      message: 'האם ברצונך ליצור גיבוי של כל הנתונים?',
      confirmText: 'צור גיבוי',
    );

    if (!confirmed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await _backupService.createBackup();
    
    Navigator.pop(context); // Close loading dialog

    if (success) {
      _showSuccessSnackbar('הגיבוי נוצר בהצלחה');
      await _loadAvailableBackups();
    } else {
      _showErrorSnackbar(_backupService.error ?? 'שגיאה ביצירת גיבוי');
    }
  }

  Future<void> _restoreFromBackup(String filePath) async {
    final confirmed = await _showConfirmationDialog(
      title: 'שחזור מגיבוי',
      message: 'האם ברצונך לשחזר את הנתונים מהגיבוי? פעולה זו תוסיף את הנתונים לגיליון הקיים.',
      confirmText: 'שחזר',
      isDestructive: true,
    );

    if (!confirmed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await _backupService.restoreFromBackup(filePath);
    
    Navigator.pop(context); // Close loading dialog

    if (success) {
      _showSuccessSnackbar('השחזור הושלם בהצלחה');
    } else {
      _showErrorSnackbar(_backupService.error ?? 'שגיאה בשחזור מגיבוי');
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'בחר קובץ גיבוי',
      );

      if (result != null && result.files.single.path != null) {
        await _restoreFromBackup(result.files.single.path!);
      }
    } catch (e) {
      _showErrorSnackbar('שגיאה בבחירת קובץ: ${e.toString()}');
    }
  }

  Future<void> _exportToCSV() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final filePath = await _backupService.exportToCSV();
    
    Navigator.pop(context); // Close loading dialog

    if (filePath != null) {
      _showSuccessSnackbar('הנתונים יוצאו בהצלחה ל-CSV');
    } else {
      _showErrorSnackbar('שגיאה בייצוא לקובץ CSV');
    }
  }

  Future<void> _deleteBackup(BackupFileInfo backup) async {
    final confirmed = await _showConfirmationDialog(
      title: 'מחיקת גיבוי',
      message: 'האם ברצונך למחוק את הגיבוי "${backup.name}"?',
      confirmText: 'מחק',
      isDestructive: true,
    );

    if (!confirmed) return;

    final success = await _backupService.deleteBackup(backup.path);
    
    if (success) {
      _showSuccessSnackbar('הגיבוי נמחק בהצלחה');
      await _loadAvailableBackups();
    } else {
      _showErrorSnackbar('שגיאה במחיקת הגיבוי');
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, textDirection: TextDirection.rtl),
        content: Text(message, textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? Colors.red : null,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('גיבוי ושחזור'),
          backgroundColor: AppColors.primary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Action buttons
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'פעולות גיבוי',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createBackup,
                        icon: const Icon(Icons.backup),
                        label: const Text('יצירת גיבוי חדש'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _importBackup,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('ייבוא גיבוי מקובץ'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _exportToCSV,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('ייצוא ל-CSV'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Available backups list
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'גיבויים זמינים',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _loadAvailableBackups,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingBackups)
                          const Center(child: CircularProgressIndicator())
                        else if (_availableBackups.isEmpty)
                          const Center(
                            child: Text(
                              'אין גיבויים זמינים',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: _availableBackups.length,
                              itemBuilder: (context, index) {
                                final backup = _availableBackups[index];
                                return ListTile(
                                  leading: const Icon(Icons.backup),
                                  title: Text(backup.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('תאריך: ${backup.createdFormatted}'),
                                      if (backup.recordCount != null)
                                        Text('רשומות: ${backup.recordCount}'),
                                      if (backup.userEmail != null)
                                        Text('משתמש: ${backup.userEmail}'),
                                      Text('גודל: ${backup.sizeFormatted}'),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.restore),
                                        onPressed: () => _restoreFromBackup(backup.path),
                                        tooltip: 'שחזר',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share),
                                        onPressed: () => _backupService.shareBackup(backup.path),
                                        tooltip: 'שתף',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteBackup(backup),
                                        tooltip: 'מחק',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}