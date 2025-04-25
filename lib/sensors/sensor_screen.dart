import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  double _temperature = 0;
  double _humidity = 0;
  String _lastUpdate = "00:00:00";
  late DatabaseReference _sensorRef;
  List<FlSpot> _tempSpots = [];
  List<FlSpot> _humiditySpots = [];
  final int _maxDataPoints = 30;
  final double _timeCounter = 0;
  DateTime? _firstTimestamp;

  @override
  void initState() {
    super.initState();
    _setupFirebase();
    // Initialize with empty data
    _tempSpots = [];
    _humiditySpots = [];
  }

  void _setupFirebase() {
    _sensorRef = FirebaseDatabase.instance.ref('sensors/esp32_001/current');
    _sensorRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          (data['timestamp'] as int) * 1000,
          isUtc: true,
        );

        setState(() {
          // Initialize first timestamp if null
          _firstTimestamp ??= timestamp;

          // Calculate seconds since first reading
          final secondsSinceStart = timestamp.difference(_firstTimestamp!).inSeconds.toDouble();

          // Update current values
          _temperature = data['temp']?.toDouble() ?? 0.0;
          _humidity = data['hum']?.toDouble() ?? 0.0;
          _lastUpdate = DateFormat('HH:mm:ss').format(timestamp.toLocal());

          // Update graph data
          _tempSpots.add(FlSpot(secondsSinceStart, _temperature));
          _humiditySpots.add(FlSpot(secondsSinceStart, _humidity));

          // Trim old data points
          if (_tempSpots.length > _maxDataPoints) {
            _tempSpots.removeAt(0);
            _humiditySpots.removeAt(0);
          }
        });
      }
    });
  }

  Widget _buildTemperatureChart() {
    return AspectRatio(
      aspectRatio: 2,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 50, // Adjust for expected temperature range
          minX: _tempSpots.isNotEmpty ? _tempSpots.first.x : 0,
          maxX: _tempSpots.isNotEmpty ? _tempSpots.last.x : 10,
          lineTouchData: const LineTouchData(enabled: true),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}s',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}°C',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _tempSpots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              belowBarData: BarAreaData(show: false),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHumidityChart() {
    return AspectRatio(
      aspectRatio: 2,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100, // Humidity percentage range
          minX: _humiditySpots.isNotEmpty ? _humiditySpots.first.x : 0,
          maxX: _humiditySpots.isNotEmpty ? _humiditySpots.last.x : 10,
          lineTouchData: const LineTouchData(enabled: true),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}s',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _humiditySpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              belowBarData: BarAreaData(show: false),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Environmental Monitor'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Current Readings Cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildValueCard('Temperature', '°C', _temperature, Colors.orange),
                  _buildValueCard('Humidity', '%', _humidity, Colors.blue),
                ],
              ),
            ),

            // Temperature Graph
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const Text('Temperature Over Time'),
                      _buildTemperatureChart(),
                    ],
                  ),
                ),
              ),
            ),

            // Humidity Graph
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const Text('Humidity Over Time'),
                      _buildHumidityChart(),
                    ],
                  ),
                ),
              ),
            ),

            // Last Updated
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Last updated: $_lastUpdate',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueCard(String title, String unit, double value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}