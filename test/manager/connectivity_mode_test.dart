import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/connectivity_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rust_api/rust_api.dart' show NetworkState;

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

const _wifi = NetworkState(wifi: true, vpn: false);
const _offWifi = NetworkState(wifi: false, vpn: false);

void main() {
  late ProviderContainer container;
  late StreamController<NetworkState> connectivity;
  late _MockCoreHandlerInterface core;

  setUpAll(() {
    registerFallbackValue(
      const UpdateParams(
        tun: Tun(),
        mixedPort: 7890,
        allowLan: false,
        findProcessMode: FindProcessMode.strict,
        mode: Mode.rule,
        logLevel: LogLevel.info,
        ipv6: false,
        tcpConcurrent: false,
        externalController: ExternalControllerStatus.close,
        unifiedDelay: false,
        options: CoreOptions(testUrl: ''),
      ),
    );
  });

  setUp(() {
    core = _MockCoreHandlerInterface();
    when(() => core.updateConfig(any())).thenAnswer((_) async => '');
    when(() => core.closeConnections()).thenAnswer((_) async => true);
    container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWithValue(null),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    container.listen(configProvider, (_, _) {});
    globalState.container = container;
    connectivity = StreamController<NetworkState>.broadcast();
  });

  tearDown(() async {
    await connectivity.close();
    container.dispose();
  });

  Future<void> pumpManager(
    WidgetTester tester, {
    required SsidReader readSsid,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ConnectivityManager(
          connectivityStream: connectivity.stream,
          readSsid: readSsid,
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> enableModeRules(WidgetTester tester) async {
    container
        .read(wifiModeSettingProvider.notifier)
        .value = const WifiModeSettings(
      enabled: true,
      rules: {'Home': Mode.direct, 'Office': Mode.global},
      fallback: Mode.rule,
    );
    await tester.pump();
  }

  Mode currentMode() => container.read(patchClashConfigProvider).mode;

  /// Lets the pending read finish and then disposes the manager, because the
  /// poll timer never goes idle while automation is enabled.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('switches the mode by SSID without an excluded network', (
    tester,
  ) async {
    var ssid = 'Home';
    await pumpManager(tester, readSsid: () async => ssid);
    await enableModeRules(tester);

    connectivity.add(_wifi);
    await tester.pump();
    await tester.pump();
    expect(currentMode(), Mode.direct);
    expect(container.read(suspendProvider), isFalse);

    ssid = 'Office';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(currentMode(), Mode.global);

    ssid = 'home';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(currentMode(), Mode.rule, reason: 'SSID matching is case sensitive');

    await finish(tester);
  });

  testWidgets('uses the fallback when Wi-Fi drops or the SSID is unreadable', (
    tester,
  ) async {
    String? ssid = 'Home';
    await pumpManager(tester, readSsid: () async => ssid);
    await enableModeRules(tester);

    connectivity.add(_wifi);
    await tester.pump();
    await tester.pump();
    expect(currentMode(), Mode.direct);

    ssid = null;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(currentMode(), Mode.rule);

    ssid = 'Home';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(currentMode(), Mode.direct);

    connectivity.add(_offWifi);
    await tester.pump();
    await tester.pump();
    expect(currentMode(), Mode.rule);

    await finish(tester);
  });

  testWidgets('restores the SSID rule after a manual mode change', (
    tester,
  ) async {
    await pumpManager(tester, readSsid: () async => 'Home');
    await enableModeRules(tester);

    connectivity.add(_wifi);
    await tester.pump();
    await tester.pump();
    expect(currentMode(), Mode.direct);

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: Mode.rule));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(currentMode(), Mode.direct);

    await finish(tester);
  });

  testWidgets('disabling automation stops the scheduled mode changes', (
    tester,
  ) async {
    await pumpManager(tester, readSsid: () async => 'Home');
    await enableModeRules(tester);

    connectivity.add(_wifi);
    await tester.pump();
    await tester.pump();
    expect(currentMode(), Mode.direct);

    container
        .read(wifiModeSettingProvider.notifier)
        .value = const WifiModeSettings(
      enabled: false,
      rules: {'Home': Mode.global},
      fallback: Mode.direct,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(currentMode(), Mode.direct);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('drops live connections when the SSID changes', (tester) async {
    var ssid = 'Home';
    await pumpManager(tester, readSsid: () async => ssid);
    await enableModeRules(tester);

    connectivity.add(_wifi);
    await tester.pump();
    await tester.pump();
    clearInteractions(core);

    ssid = 'Office';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    verify(() => core.closeConnections()).called(1);
    await finish(tester);
  });
}
