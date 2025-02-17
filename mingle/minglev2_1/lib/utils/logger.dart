// lib/utils/logger.dart
import 'package:logging/logging.dart';

// Initialize the logger
void setupLogger() {
  Logger.root.level = Level.ALL; // Set the logging level
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    // You can add more output destinations here, such as writing to a file
    // or sending logs to a remote server.
  });
}

// Create a logger instance for your app
final Logger logger = Logger('AppLogger');