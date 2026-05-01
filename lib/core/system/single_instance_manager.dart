import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef CreateMutexC = IntPtr Function(IntPtr, Int32, Pointer<Utf16>);
typedef CreateMutexDart = int Function(int, int, Pointer<Utf16>);

typedef CloseHandleC = Int32 Function(IntPtr);
typedef CloseHandleDart = int Function(int);

typedef GetLastErrorC = Uint32 Function();
typedef GetLastErrorDart = int Function();

class SingleInstanceManager {
  SingleInstanceManager._();

  static final SingleInstanceManager instance = SingleInstanceManager._();

  static const String _mutexName = 'Global\\itools_single_instance_mutex';
  static const int _errorAlreadyExists = 183;
  
  int _mutexHandle = 0;
  bool _isFirstInstance = false;

  bool get isFirstInstance => _isFirstInstance;

  bool tryAcquire() {
    if (!Platform.isWindows) {
      _isFirstInstance = true;
      return true;
    }

    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      
      final createMutex = kernel32
          .lookupFunction<CreateMutexC, CreateMutexDart>('CreateMutexW');
      final closeHandle = kernel32
          .lookupFunction<CloseHandleC, CloseHandleDart>('CloseHandle');
      final getLastError = kernel32
          .lookupFunction<GetLastErrorC, GetLastErrorDart>('GetLastError');

      final mutexNamePtr = _mutexName.toNativeUtf16();
      
      _mutexHandle = createMutex(0, 1, mutexNamePtr);
      
      calloc.free(mutexNamePtr);

      if (_mutexHandle == 0) {
        debugPrint('[SingleInstance] Failed to create mutex');
        _isFirstInstance = true;
        return true;
      }

      final error = getLastError();
      if (error == _errorAlreadyExists) {
        debugPrint('[SingleInstance] Another instance is already running');
        closeHandle(_mutexHandle);
        _mutexHandle = 0;
        _isFirstInstance = false;
        return false;
      }

      _isFirstInstance = true;
      debugPrint('[SingleInstance] This is the first instance');
      return true;
    } catch (e) {
      debugPrint('[SingleInstance] Error: $e');
      _isFirstInstance = true;
      return true;
    }
  }

  void dispose() {
    if (_mutexHandle != 0) {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final closeHandle = kernel32
          .lookupFunction<CloseHandleC, CloseHandleDart>('CloseHandle');
      closeHandle(_mutexHandle);
      _mutexHandle = 0;
    }
  }
}
