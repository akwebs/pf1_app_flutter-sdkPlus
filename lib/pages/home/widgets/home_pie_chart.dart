import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HomePieChart extends StatelessWidget {
  final int availableParking;
  final int occupiedParking;

  const HomePieChart({
    Key? key,
    required this.availableParking,
    required this.occupiedParking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 28, // Increased for a thinner look
          sections: _buildPieChartSections(occupiedParking, availableParking),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      int occupied, int available) {
    return [
      PieChartSectionData(
        color: Color(0xFF0E67B7),
        value: occupied.toDouble(),
        title: '', // Removed title
        radius: 10, // Reduced thickness
      ),
      PieChartSectionData(
        color: const Color(0xFFFE595C),
        value: available.toDouble(),
        title: '', // Removed title
        radius: 10, // Reduced thickness
      ),
    ];
  }
}
