import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _loadSavedConfig();
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
           config.contains('port') ||
           config.length > 10; // Basic validation
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

      // Simulate connection process (2-4 seconds)
      await Future.delayed(Duration(seconds: 2 + Random().nextInt(3)));

      // Simulate successful connection (90% success rate)
      if (Random().nextDouble() > 0.1) {
        _isConnected = true;
        _isConnecting = false;
        _connectionStartTime = DateTime.now();
        _startConnectionTimer();
        _startSpeedSimulation();
        notifyListeners();
        return true;
      } else {
        // Simulate connection failure
        _isConnecting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error connecting to VPN: $e');
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
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
        // Simulate realistic VPN speeds (bytes/s)
        _downloadSpeed = 80000 + random.nextInt(120000);  // 80-200 KB/s
        _uploadSpeed = 30000 + random.nextInt(70000);     // 30-100 KB/s
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

  // Method to add real VPN functionality later
  Future<bool> connectToRealVPN(String config) async {
    // TODO: Implement real VPN connection using native Android VPN API
    // This is where you'd integrate with actual VPN libraries
    return connect(config);
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _speedTimer?.cancel();
    disconnect();
    super.dispose();
  }
}