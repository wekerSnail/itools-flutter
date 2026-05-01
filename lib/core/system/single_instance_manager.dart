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

typedef FindWindowC = IntPtr Function(Pointer<Utf16>, Pointer<Utf16>);
typedef FindWindowDart = int Function(Pointer<Utf16>, Pointer<Utf16>);

typedef ShowWindowC = Int32 Function(IntPtr, Int32);
typedef ShowWindowDart = int Function(int, int);

typedef SetForegroundWindowC = Int32 Function(IntPtr);
typedef SetForegroundWindowDart = int Function(int);

typedef IsIconicC = Int32 Function(IntPtr);
typedef IsIconicDart = int Function(int);

class SingleInstanceManager {
  SingleInstanceManager._();

  static final SingleInstanceManager instance = SingleInstanceManager._();

  static const int _errorAlreadyExists = 183;
  static const int _swShow = 5;
  static const int _swRestore = 9;
  static const String _windowTitle = '工具集';
  static const String _mutexName = r'itools_flutter_single_instance_v1';
  
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

      final mutexNamePtr = _mutexName.toNativeUtf16();
      
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
        _focusExistingWindow();
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

  void _focusExistingWindow() {
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final findWindow =
          user32.lookupFunction<FindWindowC, FindWindowDart>('FindWindowW');
      final showWindow =
          user32.lookupFunction<ShowWindowC, ShowWindowDart>('ShowWindow');
      final setForegroundWindow = user32.lookupFunction<SetForegroundWindowC,
          SetForegroundWindowDart>('SetForegroundWindow');
      final isIconic = user32.lookupFunction<IsIconicC, IsIconicDart>('IsIconic');

      final titlePtr = _windowTitle.toNativeUtf16();
      final hwnd = findWindow(nullptr, titlePtr);
      calloc.free(titlePtr);

      if (hwnd == 0) {
        debugPrint('[SingleInstance] Existing window not found by title');
        return;
      }

      if (isIconic(hwnd) != 0) {
        showWindow(hwnd, _swRestore);
      }

      // Ensure hidden windows are shown before requesting focus.
      showWindow(hwnd, _swShow);
      final activated = setForegroundWindow(hwnd) != 0;
      debugPrint('[SingleInstance] Existing window activated: $activated');
    } catch (e) {
      debugPrint('[SingleInstance] Failed to focus existing window: $e');
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
