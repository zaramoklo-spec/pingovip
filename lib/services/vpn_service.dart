import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vpn_service/flutter_vpn_service.dart';
import 'dart:async';
import 'dart:math';

class VpnService extends ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _currentConfig;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  String _duration = "00:00:00";
  Timer? _connectionTimer;
  Timer? _speedTimer;
  DateTime? _connectionStartTime;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get currentConfig => _currentConfig;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  String get duration => _duration;

  VpnService() {
    _initializeVPN();
    _loadSavedConfig();
  }

  Future<void> _initializeVPN() async {
    try {
      // Listen to VPN status changes
      FlutterVpnService.vpnStatusStream.listen((status) {
        _handleStatusChange(status);
      });
    } catch (e) {
      debugPrint('Error initializing VPN: $e');
    }
  }

  void _handleStatusChange(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        _isConnected = true;
        _isConnecting = false;
        _connectionStartTime = DateTime.now();
        _startConnectionTimer();
        _startSpeedSimulation();
        break;
      case VpnStatus.disconnected:
        _isConnected = false;
        _isConnecting = false;
        _uploadSpeed = 0;
        _downloadSpeed = 0;
        _duration = "00:00:00";
        _connectionTimer?.cancel();
        _speedTimer?.cancel();
        _connectionStartTime = null;
        break;
      case VpnStatus.connecting:
        _isConnecting = true;
        _isConnected = false;
        break;
    }
    notifyListeners();
  }

  Future<void> _loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentConfig = prefs.getString('vpn_config');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading config: $e');
    }
  }

  Future<void> _saveConfig(String config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vpn_config', config);
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  bool _isValidConfig(String config) {
    return config.startsWith('vmess://') || 
           config.startsWith('vless://') || 
           config.startsWith('ss://') ||
           config.startsWith('trojan://') ||
           config.contains('server') ||
           config.contains('port');
  }

  Future<bool> connect(String config) async {
    if (_isConnecting || _isConnected) return false;

    if (!_isValidConfig(config)) {
      return false;
    }

    try {
      _isConnecting = true;
      _currentConfig = config;
      await _saveConfig(config);
      notifyListeners();

      // Request VPN permission
      bool hasPermission = await FlutterVpnService.requestPermission();
      if (!hasPermission) {
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      // Parse config and create VPN configuration
      VpnConfig vpnConfig = _parseConfig(config);

      // Start VPN
      await FlutterVpnService.startVpn(vpnConfig);
      
      return true;
    } catch (e) {
      debugPrint('Error connecting to VPN: $e');
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  VpnConfig _parseConfig(String config) {
    // Simple config parsing - in real app you'd parse vmess/vless properly
    return VpnConfig(
      serverAddress: "127.0.0.1", // Placeholder
      serverPort: 1080,
      username: "pingo",
      password: "vpn",
      protocol: VpnProtocol.shadowsocks,
    );
  }

  Future<void> disconnect() async {
    try {
      await FlutterVpnService.stopVpn();
      _isConnected = false;
      _isConnecting = false;
      _uploadSpeed = 0;
      _downloadSpeed = 0;
      _duration = "00:00:00";
      _connectionTimer?.cancel();
      _speedTimer?.cancel();
      _connectionStartTime = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting VPN: $e');
    }
  }

  void _startConnectionTimer() {
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_connectionStartTime != null && _isConnected) {
        final elapsed = DateTime.now().difference(_connectionStartTime!);
        _duration = _formatDuration(elapsed);
        notifyListeners();
      }
    });
  }

  void _startSpeedSimulation() {
    final random = Random();
    _speedTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isConnected) {
        // Simulate realistic speeds (bytes/s)
        _downloadSpeed = 50000 + random.nextInt(100000); // 50-150 KB/s
        _uploadSpeed = 20000 + random.nextInt(50000);    // 20-70 KB/s
        notifyListeners();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _speedTimer?.cancel();
    disconnect();
    super.dispose();
  }
}