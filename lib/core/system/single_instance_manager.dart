import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef CreateMutexC = IntPtr Function(IntPtr, Int32, Pointer<Utf16>);
typedef CreateMutexDart = int Function(int, int, Pointer<Utf16>);

typedef ReleaseMutexC = Int32 Function(IntPtr);
typedef ReleaseMutexDart = int Function(int);

typedef CloseHandleC = Int32 Function(IntPtr);
typedef CloseHandleDart = int Function(int);

typedef GetLastErrorC = Uint32 Function();
typedef GetLastErrorDart = int Function();

class SingleInstanceManager {
  SingleInstanceManager._();

  static final SingleInstanceManager instance = SingleInstanceManager._();

  static const int _errorAlreadyExists = 183;
  
  int _mutexHandle = 0;
  bool _isFirstInstance = false;
  bool _acquired = false;

  bool get isFirstInstance => _isFirstInstance;

  bool tryAcquire() {
    if (!Platform.isWindows) {
      _isFirstInstance = true;
      return true;
    }

    if (_acquired) {
      return _isFirstInstance;
    }

    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      
      final createMutex = kernel32
          .lookupFunction<CreateMutexC, CreateMutexDart>('CreateMutexW');
      final getLastError = kernel32
          .lookupFunction<GetLastErrorC, GetLastErrorDart>('GetLastError');

      final mutexName = 'itools_app_mutex_${Platform.resolvedExecutable.hashCode}';
      final mutexNamePtr = mutexName.toNativeUtf16();
      
      _mutexHandle = createMutex(0, 0, mutexNamePtr);
      
      calloc.free(mutexNamePtr);

      if (_mutexHandle == 0) {
        debugPrint('[SingleInstance] Failed to create mutex, error: ${getLastError()}');
        _isFirstInstance = true;
        _acquired = true;
        return true;
      }

      final error = getLastError();
      debugPrint('[SingleInstance] CreateMutex result, handle: $_mutexHandle, error: $error');
      
      if (error == _errorAlreadyExists) {
        debugPrint('[SingleInstance] Another instance is already running');
        _isFirstInstance = false;
        _acquired = true;
        return false;
      }

      _isFirstInstance = true;
      _acquired = true;
      debugPrint('[SingleInstance] This is the first instance');
      return true;
    } catch (e) {
      debugPrint('[SingleInstance] Error: $e');
      _isFirstInstance = true;
      _acquired = true;
      return true;
    }
  }

  void dispose() {
    if (_mutexHandle != 0) {
      try {
        final kernel32 = DynamicLibrary.open('kernel32.dll');
        final closeHandle = kernel32
            .lookupFunction<CloseHandleC, CloseHandleDart>('CloseHandle');
        closeHandle(_mutexHandle);
        debugPrint('[SingleInstance] Mutex released');
      } catch (e) {
        debugPrint('[SingleInstance] Error releasing mutex: $e');
      }
      _mutexHandle = 0;
    }
  }
}
