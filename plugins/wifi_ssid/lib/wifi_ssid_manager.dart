import 'package:flutter/services.dart';

/// The platform permission state required to read the current Wi-Fi SSID.
enum WifiSsidPermission { granted, denied, permanentlyDenied }

class WifiSsidManager {
  WifiSsidManager._();

  static final WifiSsidManager instance = WifiSsidManager._();

  static const _channel = MethodChannel('wifi_ssid');
  static const _ssidChangesChannel = EventChannel('wifi_ssid/ssid_changes');
  static const _getSsidMethod = 'getSsid';
  static const _checkPermissionMethod = 'checkPermission';
  static const _requestPermissionMethod = 'requestPermission';

  /// Emits the SSID whenever the platform notices an association change.
  ///
  /// Platforms without a native watcher leave the stream with a missing
  /// plugin error; callers fall back to reading [getSsid] on their own.
  Stream<String?> get ssidChanges => _ssidChangesChannel
      .receiveBroadcastStream()
      .map((event) => event as String?);

  /// Returns the current WiFi SSID, or null if not connected to WiFi.
  Future<String?> getSsid() {
    return _channel.invokeMethod<String>(_getSsidMethod);
  }

  Future<WifiSsidPermission> checkPermission() async {
    final result = await _channel.invokeMethod<int>(_checkPermissionMethod);
    return _decodePermission(result);
  }

  Future<WifiSsidPermission> requestPermission() async {
    final result = await _channel.invokeMethod<int>(_requestPermissionMethod);
    return _decodePermission(result);
  }

  WifiSsidPermission _decodePermission(int? value) {
    return switch (value) {
      0 => WifiSsidPermission.granted,
      2 => WifiSsidPermission.permanentlyDenied,
      null || 1 => WifiSsidPermission.denied,
      _ => throw PlatformException(
        code: 'INVALID_PERMISSION_STATE',
        message: 'Native wifi_ssid returned an invalid permission state.',
        details: value,
      ),
    };
  }
}

final wifiSsidManager = WifiSsidManager.instance;
