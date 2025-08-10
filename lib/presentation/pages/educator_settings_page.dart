import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../core/educator_mappings.dart';

/// Settings page for configuring educator mappings
/// Allows teachers to map class names to educator emails
class EducatorSettingsPage extends StatefulWidget {
  const EducatorSettingsPage({super.key});

  @override
  State<EducatorSettingsPage> createState() => _EducatorSettingsPageState();
}

class _EducatorSettingsPageState extends State<EducatorSettingsPage> {
  Map<String, String> _mappings = {};
  final _classController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMappings();
  }

  @override
  void dispose() {
    _classController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final mappingsJson = prefs.getString('educator_mappings');
    if (mappingsJson != null) {
      setState(() {
        _mappings = Map<String, String>.from(json.decode(mappingsJson));
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMappings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('educator_mappings', json.encode(_mappings));
    
    // Update the global educator mappings
    await EducatorMappings.updateMappings(_mappings);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ההגדרות נשמרו בהצלחה',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      // Return true to indicate changes were made
      Navigator.of(context).pop(true);
    }
  }

  void _addMapping() {
    final className = _classController.text.trim();
    final email = _emailController.text.trim();
    
    if (className.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'נא למלא את שם הכיתה וכתובת המייל',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'כתובת מייל לא תקינה',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _mappings[className] = email;
    });
    
    _classController.clear();
    _emailController.clear();
    _saveMappings();
  }

  void _removeMapping(String className) {
    setState(() {
      _mappings.remove(className);
    });
    _saveMappings();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('הגדרות שיתוף למדריכים'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Add new mapping section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'הוסף מיפוי חדש',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _classController,
                                decoration: const InputDecoration(
                                  labelText: 'שם הכיתה',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'מייל המדריך',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _addMapping,
                              icon: const Icon(Icons.add_circle),
                              color: Colors.green,
                              iconSize: 32,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'הערה: המדריך צריך לשתף איתך את הגיליון שלו עם הרשאות עריכה',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List of existing mappings
                  Expanded(
                    child: _mappings.isEmpty
                        ? const Center(
                            child: Text(
                              'אין מיפויים מוגדרים',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _mappings.length,
                            itemBuilder: (context, index) {
                              final className = _mappings.keys.elementAt(index);
                              final email = _mappings[className]!;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.school,
                                    color: Colors.blue,
                                  ),
                                  title: Text(
                                    className,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    email,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeMapping(className),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}