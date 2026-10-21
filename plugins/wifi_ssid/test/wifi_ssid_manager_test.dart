import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('wifi_ssid');
  final manager = WifiSsidManager.instance;

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getSsid returns the native value', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return 'Office Wi-Fi';
        });

    expect(await manager.getSsid(), 'Office Wi-Fi');
    expect(receivedCall?.method, 'getSsid');
  });

  test('getSsid preserves a null native value', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    expect(await manager.getSsid(), isNull);
  });

  test('checkPermission maps every native permission state', () async {
    var nativeState = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'checkPermission');
          return nativeState;
        });

    expect(await manager.checkPermission(), WifiSsidPermission.granted);
    nativeState = 1;
    expect(await manager.checkPermission(), WifiSsidPermission.denied);
    nativeState = 2;
    expect(
      await manager.checkPermission(),
      WifiSsidPermission.permanentlyDenied,
    );
  });

  test('requestPermission treats a null native value as denied', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestPermission');
          return null;
        });

    expect(await manager.requestPermission(), WifiSsidPermission.denied);
  });

  test('invalid native permission state produces a platform error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 99);

    await expectLater(
      manager.checkPermission(),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'INVALID_PERMISSION_STATE')
            .having((error) => error.details, 'details', 99),
      ),
    );
  });

  test('ssidChanges forwards native association changes', () async {
    const eventsChannel = EventChannel('wifi_ssid/ssid_changes');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? sink;
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(onListen: (arguments, events) => sink = events),
    );
    addTearDown(() => messenger.setMockStreamHandler(eventsChannel, null));

    final received = <String?>[];
    final subscription = manager.ssidChanges.listen(received.add);
    await Future<void>.delayed(Duration.zero);
    sink!.success('Office Wi-Fi');
    sink!.success(null);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(received, ['Office Wi-Fi', null]);
  });
}
