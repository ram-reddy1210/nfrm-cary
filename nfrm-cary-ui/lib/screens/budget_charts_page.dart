import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class BudgetChartsPage extends StatefulWidget {
  const BudgetChartsPage({super.key});

  @override
  State<BudgetChartsPage> createState() => _BudgetChartsPageState();
}

class _BudgetChartsPageState extends State<BudgetChartsPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.grey[50],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BUDGET',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CASH FLOW',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 5000,
                          barGroups: List.generate(
                            12,
                            (i) => BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: 2000 + (i * 200).toDouble(),
                                  color: Colors.cyan,
                                  width: 15,
                                ),
                              ],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                  return Text(months[value.toInt() % 12]);
                                },
                              ),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BUDGET VS ACTUAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Category  {index + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const Row(
                                    children: [
                                      Text('Planned: \$5,000  '),
                                      Text('Actual: \$4,200'),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: 0.84,
                                    child: Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.cyan,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPENSE BREAKDOWN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: 35,
                                    color: Colors.blue,
                                    title: '35%',
                                    radius: 60,
                                  ),
                                  PieChartSectionData(
                                    value: 25,
                                    color: Colors.green,
                                    title: '25%',
                                    radius: 60,
                                  ),
                                  PieChartSectionData(
                                    value: 20,
                                    color: Colors.orange,
                                    title: '20%',
                                    radius: 60,
                                  ),
                                  PieChartSectionData(
                                    value: 20,
                                    color: Colors.red,
                                    title: '20%',
                                    radius: 60,
                                  ),
                                ],
                                sectionsSpace: 2,
                                centerSpaceRadius: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BUDGET HEALTH',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: Stack(
                              children: [
                                Center(
                                  child: CustomPaint(
                                    size: const Size(160, 160),
                                    painter: GaugePainter(value: 0.75),
                                  ),
                                ),
                                const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '75%',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        'Good',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double value;
  GaugePainter({required this.value});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );
    final valuePaint = Paint()
      ..color = value < 0.3
          ? Colors.red
          : value < 0.7
              ? Colors.orange
              : Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      value * pi,
      false,
      valuePaint,
    );
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
