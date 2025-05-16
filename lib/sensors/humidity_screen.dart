import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HumidityScreen extends StatelessWidget {
  final double humidity;
  final String lastUpdate;
  final List<FlSpot> humiditySpots;

  const HumidityScreen({
    super.key,
    required this.humidity,
    required this.lastUpdate,
    required this.humiditySpots, String? errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Current Humidity Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildValueCard(
                'Humidity',
                '%',
                humidity,
                Colors.blue,
              ),
            ),

            // Humidity Graph
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
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
                        'Humidity Over Time',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                'Last updated: $lastUpdate',
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

  Widget _buildHumidityChart() {
    return AspectRatio(
      aspectRatio: 1.5,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: humiditySpots.isNotEmpty ? humiditySpots.first.x : 0,
          maxX: humiditySpots.isNotEmpty ? humiditySpots.last.x : 10,
          lineTouchData: const LineTouchData(enabled: true),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${value.toInt()}s',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
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
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade700),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: humiditySpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
              ),
              dotData: const FlDotData(show: false),
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}