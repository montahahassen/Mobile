import 'dart:io';

import 'package:flutter/foundation.dart';

/// Persistence contract for storing the serialized [AuthSession].
abstract class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// In-memory [SessionStorage] used in tests and as a web fallback.
class InMemorySessionStorage implements SessionStorage {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }

  @override
  Future<void> delete() async {
    _value = null;
  }
}

/// Pure-Dart file-backed [SessionStorage] avoiding native plugin symlinks.
class FileSessionStorage implements SessionStorage {
  FileSessionStorage({String fileName = 'greenhouse_auth_session.json'})
      : _file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');

  final File _file;

  @override
  Future<String?> read() async {
    try {
      if (!await _file.exists()) return null;
      final content = await _file.readAsString();
      return content.trim().isEmpty ? null : content;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    await _file.writeAsString(value, flush: true);
  }

  @override
  Future<void> delete() async {
    try {
      if (await _file.exists()) {
        await _file.delete();
      }
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
}

/// Returns the default [SessionStorage] implementation for the current platform.
SessionStorage createDefaultSessionStorage() {
  if (kIsWeb) {
    return InMemorySessionStorage();
  }
  return FileSessionStorage();
}
