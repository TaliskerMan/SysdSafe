import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../scanner.dart';
import '../state.dart';

class DashboardScreen extends StatefulWidget {
  final List<SystemdService> services;

  const DashboardScreen({super.key, required this.services});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int get unsafeCount =>
      widget.services.where((s) => s.exposureLevel == 'UNSAFE').length;
  int get exposedCount =>
      widget.services.where((s) => s.exposureLevel == 'EXPOSED').length;
  int get mediumCount =>
      widget.services.where((s) => s.exposureLevel == 'MEDIUM').length;
  int get okCount =>
      widget.services.where((s) => s.exposureLevel == 'OK').length;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Security Overview',
            style: TextStyle(
              fontSize: appState.fontSizeBase + 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Total Services',
                          style: TextStyle(fontSize: appState.fontSizeBase + 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.services.length}',
                          style: TextStyle(
                            fontSize: appState.fontSizeBase + 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Overall Status',
                          style: TextStyle(fontSize: appState.fontSizeBase + 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          unsafeCount > 10 ? 'VULNERABLE' : 'FAIR',
                          style: TextStyle(
                            fontSize: appState.fontSizeBase + 20,
                            fontWeight: FontWeight.w900,
                            color: unsafeCount > 10
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: widget.services.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 60,
                            sections: [
                              PieChartSectionData(
                                color: Colors.redAccent,
                                value: unsafeCount.toDouble(),
                                title: 'Unsafe',
                                radius: 50,
                                titleStyle: TextStyle(
                                  fontSize: appState.fontSizeBase,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                color: Colors.orangeAccent,
                                value: exposedCount.toDouble(),
                                title: 'Exposed',
                                radius: 50,
                                titleStyle: TextStyle(
                                  fontSize: appState.fontSizeBase,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                color: Colors.yellow[700],
                                value: mediumCount.toDouble(),
                                title: 'Medium',
                                radius: 50,
                                titleStyle: TextStyle(
                                  fontSize: appState.fontSizeBase,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                color: Colors.greenAccent,
                                value: okCount.toDouble(),
                                title: 'OK',
                                radius: 50,
                                titleStyle: TextStyle(
                                  fontSize: appState.fontSizeBase,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegend(
                              'UNSAFE',
                              Colors.redAccent,
                              unsafeCount,
                              appState.fontSizeBase,
                            ),
                            _buildLegend(
                              'EXPOSED',
                              Colors.orangeAccent,
                              exposedCount,
                              appState.fontSizeBase,
                            ),
                            _buildLegend(
                              'MEDIUM',
                              Colors.yellow[700]!,
                              mediumCount,
                              appState.fontSizeBase,
                            ),
                            _buildLegend(
                              'OK',
                              Colors.greenAccent,
                              okCount,
                              appState.fontSizeBase,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(
    String label,
    Color color,
    int count,
    double baseFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: baseFontSize + 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
