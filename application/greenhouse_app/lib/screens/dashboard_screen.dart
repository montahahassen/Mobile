import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';
import '../services/api_exception.dart';
import '../services/fake_sensor_service.dart';
import '../services/greenhouse_api_service.dart';
import '../widgets/sensor_card.dart';
import 'history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.nowProvider,
    this.session,
    this.apiService,
    this.onLogout,
  });

  /// Optional timestamp source for deterministic testing (defaults to `DateTime.now`).
  final DateTime Function()? nowProvider;

  /// Authenticated session when running in Live API mode; `null` in Demo Mode.
  final AuthSession? session;

  /// API service used in Live mode; when `null`, Demo Mode uses [FakeSensorService].
  final GreenhouseApiService? apiService;

  /// Called when the user signs out, exits Demo Mode, or hits HTTP 401.
  final ValueChanged<String?>? onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Duration _demoRefreshInterval = Duration(seconds: 5);
  static const Duration _liveRefreshInterval = Duration(seconds: 30);

  SensorReading? _reading;
  Timer? _liveTimer;
  int _liveTick = 0;

  List<Device> _devices = const [];
  Device? _selectedDevice;
  GreenhouseSnapshot? _snapshot;
  bool _isLoadingLive = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  bool get _isLiveMode => widget.apiService != null;

  @override
  void initState() {
    super.initState();
    if (_isLiveMode) {
      _isLoadingLive = true;
      _loadLiveData(initialLoad: true, forceReloadMetadata: true);
      _liveTimer = Timer.periodic(_liveRefreshInterval, (_) {
        _loadLiveData();
      });
    } else {
      _reading = FakeSensorService.getFakeReading(measuredAt: _now());
      _liveTimer = Timer.periodic(_demoRefreshInterval, (_) {
        if (!mounted) return;
        setState(() {
          _liveTick++;
          _reading = FakeSensorService.getNextLiveReading(
            _liveTick,
            measuredAt: _now(),
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  Future<void> _loadLiveData({
    bool initialLoad = false,
    bool forceReloadMetadata = false,
  }) async {
    final api = widget.apiService;
    if (api == null || _isRefreshing) return;

    _isRefreshing = true;
    if (initialLoad && mounted) {
      setState(() {
        _isLoadingLive = true;
        _errorMessage = null;
      });
    }

    try {
      List<Device> devices = _devices;
      Device? activeDevice = _selectedDevice;
      GreenhouseSnapshot? snapshot;

      final hasCachedSensors =
          !forceReloadMetadata &&
          activeDevice != null &&
          _snapshot != null &&
          _snapshot!.sensors.isNotEmpty;

      if (hasCachedSensors) {
        snapshot = await api.fetchMeasurementsSnapshot(
          activeDevice,
          _snapshot!.sensors,
        );
      } else {
        devices = await api.fetchUserDevices();
        if (activeDevice != null) {
          final match = devices.where((d) => d.id == activeDevice!.id).toList();
          activeDevice = match.isNotEmpty ? match.first : null;
        }
        activeDevice ??= devices.isNotEmpty ? devices.first : null;

        if (activeDevice != null) {
          snapshot = await api.fetchDeviceSnapshot(activeDevice);
        }
      }

      if (!mounted) return;
      setState(() {
        _devices = devices;
        _selectedDevice = activeDevice;
        _snapshot = snapshot;
        _reading = snapshot?.latestReading;
        _isLoadingLive = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized && widget.onLogout != null) {
        widget.onLogout!('Session expired. Please sign in again.');
        return;
      }
      setState(() {
        _isLoadingLive = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingLive = false;
        _errorMessage = 'Failed to load greenhouse data: $error';
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _selectDevice(Device device) async {
    setState(() {
      _selectedDevice = device;
      _snapshot = null;
      _isLoadingLive = true;
      _errorMessage = null;
    });
    await _loadLiveData(initialLoad: true, forceReloadMetadata: true);
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    final formattedTimestamp = reading != null
        ? _formatTimestamp(reading.measuredAt)
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7F2),
        title: const Row(
          children: [
            Icon(Icons.eco, color: Color(0xFF2E7D32)),
            SizedBox(width: 10),
            Text('GreenHouse', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_isLiveMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () =>
                  _loadLiveData(initialLoad: true, forceReloadMetadata: true),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => HistoryScreen(
                    apiService: widget.apiService,
                    device: _selectedDevice,
                    initialSnapshot: _snapshot,
                  ),
                ),
              );
            },
          ),
          if (widget.onLogout != null)
            IconButton(
              icon: Icon(_isLiveMode ? Icons.logout : Icons.login),
              tooltip: _isLiveMode ? 'Sign Out' : 'Sign In',
              onPressed: () => widget.onLogout!(null),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.session != null
                  ? 'Welcome back, ${widget.session!.displayName}!'
                  : 'Welcome back!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Monitor your greenhouse environment.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 22),

            if (_isLiveMode && _devices.length > 1) ...[
              _buildDeviceSelector(),
              const SizedBox(height: 14),
            ],

            _buildConnectionBanner(),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _buildErrorBanner(_errorMessage!),
            ],

            const SizedBox(height: 25),
            const Text(
              'Sensor Readings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            if (_isLiveMode && _isLoadingLive && reading == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                ),
              )
            else if (_isLiveMode && _selectedDevice == null)
              _buildEmptyStateCard(
                icon: Icons.sensors_off,
                message: 'No ESP32 device registered for this account yet.',
              )
            else if (_isLiveMode && reading == null)
              _buildEmptyStateCard(
                icon: Icons.hourglass_empty,
                message:
                    'Connected to ${_selectedDevice!.name}, waiting for sensor measurements.',
              )
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  SensorCard(
                    title: 'Temperature',
                    value: reading!.temperature.toStringAsFixed(1),
                    unit: '°C',
                    icon: Icons.thermostat,
                    color: Colors.orange,
                  ),
                  SensorCard(
                    title: 'Air Humidity',
                    value: reading.airHumidity.toStringAsFixed(0),
                    unit: '%',
                    icon: Icons.water_drop,
                    color: Colors.blue,
                  ),
                  SensorCard(
                    title: 'Soil Moisture',
                    value: reading.soilMoisture.toStringAsFixed(0),
                    unit: '%',
                    icon: Icons.grass,
                    color: Colors.green,
                  ),
                  SensorCard(
                    title: 'Light Level',
                    value: reading.lightLevel.toStringAsFixed(0),
                    unit: 'lux',
                    icon: Icons.wb_sunny,
                    color: Colors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                _isLiveMode
                    ? 'Last update: Live · $formattedTimestamp'
                    : 'Last update: Simulated live · $formattedTimestamp',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedDevice?.id,
          isExpanded: true,
          items: _devices.map((device) {
            final suffix = device.location != null && device.location!.isNotEmpty
                ? ' (${device.location})'
                : '';
            return DropdownMenuItem<int>(
              value: device.id,
              child: Text('${device.name}$suffix'),
            );
          }).toList(),
          onChanged: (deviceId) {
            if (deviceId == null) return;
            final chosen = _devices.firstWhere((d) => d.id == deviceId);
            _selectDevice(chosen);
          },
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    if (!_isLiveMode) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.white, size: 32),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESP32 Device',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Demo mode - Simulated live (Not connected)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.circle, color: Colors.orangeAccent, size: 12),
            SizedBox(width: 5),
            Text(
              'Demo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final device = _selectedDevice;
    final isActive = device?.isActive ?? false;
    final title = device?.name ?? 'ESP32 Device';
    final subtitle = device == null
        ? 'Connected to backend (no device found)'
        : device.location != null && device.location!.isNotEmpty
            ? '${device.location} · Live API'
            : 'Connected via GreenHouse API';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            Icons.circle,
            color: device == null
                ? Colors.orangeAccent
                : (isActive ? Colors.lightGreenAccent : Colors.redAccent),
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            device == null ? 'None' : (isActive ? 'Online' : 'Offline'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () =>
                _loadLiveData(initialLoad: true, forceReloadMetadata: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }
}
