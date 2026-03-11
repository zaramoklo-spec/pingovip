import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2ray_flutter/v2ray_flutter.dart';
import 'dart:async';

class VpnService extends ChangeNotifier {
  final V2rayFlutter _v2ray = V2rayFlutter();
  
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _currentConfig;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  String _duration = "00:00:00";
  Timer? _connectionTimer;
  DateTime? _connectionStartTime;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get currentConfig => _currentConfig;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  String get duration => _duration;

  VpnService() {
    _initializeV2Ray();
    _loadSavedConfig();
  }

  Future<void> _initializeV2Ray() async {
    try {
      // Listen to V2Ray status changes
      _v2ray.statusStream?.listen((status) {
        _handleStatusChange(status);
      });
    } catch (e) {
      debugPrint('Error initializing V2Ray: $e');
    }
  }

  void _handleStatusChange(V2rayStatus status) {
    switch (status.state) {
      case V2rayState.connected:
        _isConnected = true;
        _isConnecting = false;
        _connectionStartTime = DateTime.now();
        _startConnectionTimer();
        break;
      case V2rayState.disconnected:
        _isConnected = false;
        _isConnecting = false;
        _uploadSpeed = 0;
        _downloadSpeed = 0;
        _duration = "00:00:00";
        _connectionTimer?.cancel();
        _connectionStartTime = null;
        break;
      case V2rayState.connecting:
        _isConnecting = true;
        _isConnected = false;
        break;
    }
    
    // Update speeds if available
    if (status.uploadSpeed != null) {
      _uploadSpeed = status.uploadSpeed!.toInt();
    }
    if (status.downloadSpeed != null) {
      _downloadSpeed = status.downloadSpeed!.toInt();
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
           config.startsWith('trojan://');
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
      bool hasPermission = await _v2ray.requestPermission();
      if (!hasPermission) {
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      // Start V2Ray
      await _v2ray.startV2ray(
        remark: "Pingo VPN",
        config: config,
      );
      
      return true;
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
      await _v2ray.stopV2ray();
      _isConnected = false;
      _isConnecting = false;
      _uploadSpeed = 0;
      _downloadSpeed = 0;
      _duration = "00:00:00";
      _connectionTimer?.cancel();
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
    disconnect();
    super.dispose();
  }
}