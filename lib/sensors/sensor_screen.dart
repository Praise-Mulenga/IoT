import 'package:environmental_monitor_dashboard/sensors/bulb_control_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'temperature_screen.dart';
import 'humidity_screen.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  double _temperature = 0;
  double _humidity = 0;
  String _lastUpdate = "00:00:00";
  DatabaseReference? _sensorRef;
  final List<FlSpot> _tempSpots = [];
  final List<FlSpot> _humiditySpots = [];
  final int _maxDataPoints = 30;
  DateTime? _firstTimestamp;
  int _currentIndex = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupFirebase();
  }

  void _setupFirebase() {
    try {
      _sensorRef = FirebaseDatabase.instance.ref('sensors/esp32_001/current');
      _sensorRef?.onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            (data['timestamp'] as int) * 1000,
            isUtc: true,
          );

          setState(() {
            _firstTimestamp ??= timestamp;
            final secondsSinceStart = timestamp.difference(_firstTimestamp!).inSeconds.toDouble();

            _temperature = data['temp']?.toDouble() ?? 0.0;
            _humidity = data['hum']?.toDouble() ?? 0.0;
            _lastUpdate = DateFormat('HH:mm:ss').format(timestamp.toLocal());
            _errorMessage = null;

            _tempSpots.add(FlSpot(secondsSinceStart, _temperature));
            _humiditySpots.add(FlSpot(secondsSinceStart, _humidity));

            if (_tempSpots.length > _maxDataPoints) {
              _tempSpots.removeAt(0);
              _humiditySpots.removeAt(0);
            }
          });
        }
      }, onError: (error) {
        setState(() {
          _errorMessage = 'Database error: ${error.message}';
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization error: $e';
      });
    }
  }

  final List<Widget> _screens = [];

  @override
  Widget build(BuildContext context) {
    _screens.clear();
    _screens.addAll([
      TemperatureScreen(
        temperature: _temperature,
        lastUpdate: _lastUpdate,
        tempSpots: _tempSpots,
        errorMessage: _errorMessage,
      ),
      HumidityScreen(
        humidity: _humidity,
        lastUpdate: _lastUpdate,
        humiditySpots: _humiditySpots,
        errorMessage: _errorMessage,
      ),
      const BulbControlScreen(),
    ]);

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Environmental Monitor'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.thermostat),
            label: 'Temperature',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_drop),
            label: 'Humidity',
          ),
          
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'Bulb Control',
          ),
        ],
      ),
    );
  }
}