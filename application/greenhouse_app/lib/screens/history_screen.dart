import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/sensor_reading.dart';
import '../services/api_exception.dart';
import '../services/fake_sensor_service.dart';
import '../services/greenhouse_api_service.dart';

/// Sensor types available in the History chart view.
enum HistorySensor {
  temperature(
    label: 'Temperature',
    unit: '°C',
    icon: Icons.thermostat,
    color: Colors.orange,
    decimals: 1,
  ),
  airHumidity(
    label: 'Air Humidity',
    unit: '%',
    icon: Icons.water_drop,
    color: Colors.blue,
    decimals: 0,
  ),
  soilMoisture(
    label: 'Soil Moisture',
    unit: '%',
    icon: Icons.grass,
    color: Colors.green,
    decimals: 0,
  ),
  lightLevel(
    label: 'Light Level',
    unit: 'lux',
    icon: Icons.wb_sunny,
    color: Colors.amber,
    decimals: 0,
  );

  const HistorySensor({
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.decimals,
  });

  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final int decimals;

  double valueOf(SensorReading reading) {
    return switch (this) {
      HistorySensor.temperature => reading.temperature,
      HistorySensor.airHumidity => reading.airHumidity,
      HistorySensor.soilMoisture => reading.soilMoisture,
      HistorySensor.lightLevel => reading.lightLevel,
    };
  }

  String formatValue(double value) => value.toStringAsFixed(decimals);
}

/// Time periods available in the History chart view.
enum HistoryPeriod {
  hours24(
    label: 'Last 24 hours',
    pointCount: 13,
    interval: Duration(hours: 2),
    lookback: Duration(hours: 24),
  ),
  days7(
    label: 'Last 7 days',
    pointCount: 7,
    interval: Duration(days: 1),
    lookback: Duration(days: 7),
  ),
  days30(
    label: 'Last 30 days',
    pointCount: 15,
    interval: Duration(days: 2),
    lookback: Duration(days: 30),
  );

  const HistoryPeriod({
    required this.label,
    required this.pointCount,
    required this.interval,
    required this.lookback,
  });

  final String label;
  final int pointCount;
  final Duration interval;
  final Duration lookback;
}

/// Displays simulated or live historical sensor trends and summary statistics.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.readingsLoader,
    this.apiService,
    this.device,
    this.initialSnapshot,
  });

  /// Optional loader override for testing empty or custom datasets.
  final List<SensorReading> Function(HistoryPeriod period)? readingsLoader;

  /// Optional API service for fetching real measurements from the backend.
  final GreenhouseApiService? apiService;

  /// Target device when displaying live backend measurements.
  final Device? device;

  /// Optional pre-loaded snapshot from [DashboardScreen].
  final GreenhouseSnapshot? initialSnapshot;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _scaffoldBg = Color(0xFFF5F7F2);

  HistorySensor _selectedSensor = HistorySensor.temperature;
  HistoryPeriod _selectedPeriod = HistoryPeriod.hours24;
  List<SensorReading> _readings = const [];
  GreenhouseSnapshot? _snapshot;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isLiveMode =>
      widget.readingsLoader == null && widget.apiService != null;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    _loadReadings();
  }

  void _loadReadings({bool forceRefresh = false}) {
    if (widget.readingsLoader != null) {
      _readings = widget.readingsLoader!(_selectedPeriod);
      return;
    }

    if (widget.apiService != null) {
      if (widget.device == null) {
        _readings = const [];
        return;
      }
      if (!forceRefresh && _snapshot != null) {
        _readings = _snapshot!.historyForLookback(_selectedPeriod.lookback);
        return;
      }
      _fetchLiveSnapshot();
      return;
    }

    _readings = FakeSensorService.getFakeHistory(
      count: _selectedPeriod.pointCount,
      interval: _selectedPeriod.interval,
    );
  }

  Future<void> _fetchLiveSnapshot() async {
    final api = widget.apiService;
    final device = widget.device;
    if (api == null || device == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await api.fetchDeviceSnapshot(device);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _readings = snapshot.historyForLookback(_selectedPeriod.lookback);
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load history: $error';
      });
    }
  }

  void _selectSensor(HistorySensor sensor) {
    if (_selectedSensor == sensor) return;
    setState(() {
      _selectedSensor = sensor;
    });
  }

  void _selectPeriod(HistoryPeriod period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
      _loadReadings();
    });
  }

  _SensorSummary? _computeSummary() {
    if (_readings.isEmpty) return null;

    var minValue = _selectedSensor.valueOf(_readings.first);
    var maxValue = minValue;
    for (final reading in _readings.skip(1)) {
      final value = _selectedSensor.valueOf(reading);
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
    }

    return _SensorSummary(
      latest: _selectedSensor.valueOf(_readings.last),
      min: minValue,
      max: maxValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _computeSummary();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _scaffoldBg,
        title: const Text(
          'Sensor History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLiveMode && widget.device != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _loadReadings(forceRefresh: true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeBanner(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(_errorMessage!),
            ],
            const SizedBox(height: 18),
            const Text(
              'Sensor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildSensorSelector(),
            const SizedBox(height: 18),
            const Text(
              'Period',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            _buildChartCard(),
            const SizedBox(height: 20),
            _buildSummarySection(summary),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBanner() {
    final text = _isLiveMode
        ? (widget.device != null
            ? 'Live backend history — ${widget.device!.name}'
            : 'Live mode — select or register an ESP32 device.')
        : 'Simulated demo data — historical trends are illustrative only.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            _isLiveMode ? Icons.cloud_done_outlined : Icons.info_outline,
            color: _primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _primaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
            onPressed: () => _loadReadings(forceRefresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HistorySensor.values.map((sensor) {
        final isSelected = sensor == _selectedSensor;
        return ChoiceChip(
          avatar: Icon(
            sensor.icon,
            size: 18,
            color: isSelected ? Colors.white : sensor.color,
          ),
          label: Text(sensor.label),
          selected: isSelected,
          selectedColor: _primaryGreen,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? _primaryGreen : Colors.grey.shade300,
          ),
          onSelected: (_) => _selectSensor(sensor),
        );
      }).toList(),
    );
  }

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HistoryPeriod.values.map((period) {
        final isSelected = period == _selectedPeriod;
        return ChoiceChip(
          label: Text(period.label),
          selected: isSelected,
          selectedColor: _primaryGreen,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? _primaryGreen : Colors.grey.shade300,
          ),
          onSelected: (_) => _selectPeriod(period),
        );
      }).toList(),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selectedSensor.icon,
                color: _selectedSensor.color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_selectedSensor.label} (${_selectedSensor.unit})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _selectedPeriod.label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 230,
            width: double.infinity,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryGreen),
                  )
                : (_readings.isEmpty
                    ? _buildEmptyChartState()
                    : _buildLineChart()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            'No historical data available for this period.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = List<FlSpot>.generate(
      _readings.length,
      (index) =>
          FlSpot(index.toDouble(), _selectedSensor.valueOf(_readings[index])),
    );

    final values = spots.map((s) => s.y).toList();
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final span = rawMax - rawMin;
    final padding = span == 0 ? (rawMax.abs() * 0.1 + 1) : span * 0.2;
    final minY = rawMin - padding;
    final maxY = rawMax + padding;
    final yInterval = math.max((maxY - minY) / 4, 0.5);

    final lastIndex = _readings.length - 1;
    final xInterval = _readings.length <= 7
        ? 1.0
        : (_readings.length / 4).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(lastIndex.toDouble(), 1),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey.shade300),
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _selectedSensor.formatValue(value),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= _readings.length) {
                  return const SizedBox.shrink();
                }
                if ((value - index).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    _formatAxisTimestamp(_readings[index].measuredAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex.clamp(0, _readings.length - 1);
                final timestamp = _formatTooltipTimestamp(
                  _readings[idx].measuredAt,
                );
                final formatted =
                    '${_selectedSensor.formatValue(spot.y)} ${_selectedSensor.unit}';
                return LineTooltipItem(
                  '$formatted\n$timestamp',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _selectedSensor.color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: _readings.length <= 15),
            belowBarData: BarAreaData(
              show: true,
              color: _selectedSensor.color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(_SensorSummary? summary) {
    final unit = _selectedSensor.unit;
    final latestText = summary == null
        ? '--'
        : '${_selectedSensor.formatValue(summary.latest)} $unit';
    final minText = summary == null
        ? '--'
        : '${_selectedSensor.formatValue(summary.min)} $unit';
    final maxText = summary == null
        ? '--'
        : '${_selectedSensor.formatValue(summary.max)} $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.9,
          children: [
            _SummaryTile(label: 'Latest', value: latestText),
            _SummaryTile(label: 'Period', value: _selectedPeriod.label),
            _SummaryTile(label: 'Minimum', value: minText),
            _SummaryTile(label: 'Maximum', value: maxText),
          ],
        ),
      ],
    );
  }

  String _formatAxisTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    if (_selectedPeriod == HistoryPeriod.hours24) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatTooltipTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _SensorSummary {
  const _SensorSummary({
    required this.latest,
    required this.min,
    required this.max,
  });

  final double latest;
  final double min;
  final double max;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
