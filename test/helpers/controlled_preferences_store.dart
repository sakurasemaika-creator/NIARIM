import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class ControlledPreferencesStore extends InMemorySharedPreferencesStore {
  ControlledPreferencesStore(super.data) : super.withData();

  bool failWrites = false;
  bool throwOnFailure = false;
  bool Function(String key, Object value)? reject;
  Completer<void>? nextWriteGate;
  final writes = <({String key, Object value})>[];

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.startsWith('flutter.work_')) {
      writes.add((key: key, value: value));
      final gate = nextWriteGate;
      nextWriteGate = null;
      if (gate != null) await gate.future;
      if (failWrites || (reject?.call(key, value) ?? false)) {
        if (throwOnFailure) {
          throw PlatformException(code: 'audit-store-unavailable');
        }
        return false;
      }
    }
    return super.setValue(type, key, value);
  }
}
