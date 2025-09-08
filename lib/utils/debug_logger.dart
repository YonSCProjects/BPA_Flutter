import 'package:flutter/foundation.dart';
import '../presentation/pages/debug_log_page.dart';

class DebugLogger {
  static void log(String message) {
    // Always print to console
    print(message);
    
    // Also add to debug page if in debug mode
    // TODO: Implement debug page integration if needed
  }
}