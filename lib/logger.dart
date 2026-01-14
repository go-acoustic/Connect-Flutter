import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Log level configuration for the Connect SDK
enum ConnectLogLevel {
  /// Automatic mode - debug logs in debug builds, error logs in release builds (default)
  auto,
  /// No logging
  off,
  /// Only error messages
  error,
  /// Debug and error messages
  debug,
  /// All messages including trace, debug, and error
  trace,
}

/// Configuration holder for logging settings
class LoggerConfig {
  static ConnectLogLevel _logLevel = ConnectLogLevel.auto;

  /// Gets the current log level
  static ConnectLogLevel get logLevel => _logLevel;

  /// Sets the log level for the SDK
  ///
  /// [level] The desired log level
  ///
  /// Example:
  /// ```dart
  /// LoggerConfig.setLogLevel(ConnectLogLevel.trace);
  /// ```
  static void setLogLevel(ConnectLogLevel level) {
    _logLevel = level;
  }
}

class DebugOnlyFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Check configured log level first
    final configuredLevel = LoggerConfig.logLevel;

    // Check against configured level
    switch (configuredLevel) {
      case ConnectLogLevel.auto:
        // Auto mode: use release mode to determine behavior
        if (kReleaseMode) {
          return event.level == Level.error;
        }
        return (event.level == Level.debug ||
            event.level == Level.trace ||
            event.level == Level.error);
      case ConnectLogLevel.off:
        return false;
      case ConnectLogLevel.error:
        return event.level == Level.error;
      case ConnectLogLevel.debug:
        return (event.level == Level.debug ||
            event.level == Level.error);
      case ConnectLogLevel.trace:
        return (event.level == Level.debug ||
            event.level == Level.trace ||
            event.level == Level.error);
    }
  }
}

// ignore: non_constant_identifier_names
int logMethodCount = 0;

class ConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}

final dynamic _prettyPrinter = PrettyPrinter(
  methodCount: logMethodCount, // number of method calls to be displayed
  errorMethodCount: 8, // number of method calls if stacktrace is provided
  lineLength: 140, // width of the output
  colors: false, // Colorful log messages
  printEmojis: false, // Print an emoji for each log message
);

final dynamic _verbosePrinter =
    io.Platform.isIOS ? _prettyPrinter : SimplePrinter();

final Logger tlLogger = Logger(
  filter: DebugOnlyFilter(),
  printer: HybridPrinter(_prettyPrinter, trace: _verbosePrinter),
  output: ConsoleOutput(),
);
