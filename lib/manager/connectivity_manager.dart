import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/wifi_ssid.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/on_demand.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/rust_api.dart' show NetworkState, networkChanges;

typedef SsidReader = Future<String?> Function();

class ConnectivityManager extends ConsumerStatefulWidget {
  final Function(NetworkState state)? onConnectivityChanged;
  final Stream<NetworkState>? connectivityStream;
  final SsidReader? readSsid;
  final Widget child;

  const ConnectivityManager({
    super.key,
    this.onConnectivityChanged,
    this.connectivityStream,
    this.readSsid,
    required this.child,
  });

  @override
  ConsumerState<ConnectivityManager> createState() =>
      _ConnectivityManagerState();
}

class _ConnectivityManagerState extends ConsumerState<ConnectivityManager>
    with WidgetsBindingObserver {
  static const _activePollInterval = Duration(seconds: 1);
  static const _idlePollInterval = Duration(seconds: 5);
  static const _activePollWindow = Duration(seconds: 30);

  late final StreamSubscription subscription;
  late final SsidReader _readSsid = widget.readSsid ?? wifiSsidManager.getSsid;

  int _ssidRequestId = 0;
  bool _wifiPossible = false;
  Timer? _ssidTimer;
  Timer? _activityTimer;
  bool _recentActivity = false;
  (String?, Mode)? _lastModeDecision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final stream =
        widget.connectivityStream ??
        (system.isAndroid ? app!.networkChanges : networkChanges());
    subscription = stream.listen(_handleResults);
    ref.listenManual(excludeSSIDsProvider.select((state) => state.isNotEmpty), (
      previous,
      next,
    ) {
      if (previous != next) {
        unawaited(_updateSsid());
      }
    });
    ref.listenManual(wifiModeSettingProvider, (previous, next) {
      _lastModeDecision = null;
      unawaited(_updateSsid());
    });
    ref.listenManual(
      locationPermissionsProvider.select(
        (permission) => permission == WifiSsidPermission.granted,
      ),
      (previous, next) {
        if (previous != next) {
          unawaited(_updateSsid());
        }
      },
    );
  }

  bool get _ssidGateOpen =>
      ref.read(excludeSSIDsProvider).isNotEmpty ||
      ref.read(wifiModeSettingProvider).enabled;

  void _handleResults(NetworkState state) {
    // A VPN hides the physical transport, so both count as possibly Wi-Fi and
    // the SSID read decides.
    _wifiPossible = state.wifi || state.vpn;
    _markSsidActivity();
    unawaited(_updateSsid());
    widget.onConnectivityChanged?.call(state);
  }

  void _markSsidActivity() {
    _recentActivity = true;
    _activityTimer?.cancel();
    _activityTimer = Timer(_activePollWindow, () => _recentActivity = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markSsidActivity();
      unawaited(_updateSsid());
    }
  }

  Future<void> _updateSsid() async {
    final requestId = ++_ssidRequestId;
    _ssidTimer?.cancel();
    // The SSID costs a blocking platform call and a location permission on
    // Android, macOS and Windows, and nothing reads it until SSID automation
    // or an excluded network asks for it.
    try {
      if (!_wifiPossible || ref.read(safeModeProvider) || !_ssidGateOpen) {
        _publishSsid(requestId, null);
        return;
      }
      final ssid = await _readSsid().timeout(const Duration(seconds: 4));
      final changed = mounted && ref.read(currentSSIDProvider) != ssid;
      if (_publishSsid(requestId, ssid) && changed) {
        _markSsidActivity();
        commonPrint.log('Wi-fi SSID: $ssid', logLevel: LogLevel.info);
      }
    } catch (error) {
      commonPrint.log(
        'Unable to read the Wi-Fi SSID: $error',
        logLevel: LogLevel.warning,
      );
      _publishSsid(requestId, null);
    } finally {
      if (mounted &&
          requestId == _ssidRequestId &&
          !ref.read(safeModeProvider) &&
          ref.read(wifiModeSettingProvider).enabled) {
        _ssidTimer = Timer(
          _recentActivity ? _activePollInterval : _idlePollInterval,
          _updateSsid,
        );
      }
    }
  }

  bool _publishSsid(int requestId, String? ssid) {
    if (requestId != _ssidRequestId || !mounted) {
      return false;
    }
    final previous = ref.read(currentSSIDProvider);
    ref.read(currentSSIDProvider.notifier).value = ssid;
    final settings = ref.read(wifiModeSettingProvider);
    if (settings.enabled && !ref.read(safeModeProvider)) {
      final mode = settings.rules[ssid] ?? settings.fallback;
      final decision = (ssid, mode);
      final currentMode = ref.read(patchClashConfigProvider).mode;
      if (_lastModeDecision != decision || currentMode != mode) {
        final switched = previous != ssid;
        _lastModeDecision = decision;
        if (switched || currentMode != mode) {
          ref
              .read(setupActionProvider.notifier)
              .changeMode(mode, dropConnections: switched);
        }
      }
    }
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ssidTimer?.cancel();
    _activityTimer?.cancel();
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
