import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CarMonitorApp());
}

class CarMonitorApp extends StatelessWidget {
  const CarMonitorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Safety Monitor',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C63FF),
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        cardTheme: CardThemeData(
          elevation: 8,
          color: const Color(0xFF1A1F3A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E27),
          elevation: 0,
        ),
      ),
      home: const CarDashboard(),
    );
  }
}

class CarDashboard extends StatefulWidget {
  const CarDashboard({Key? key}) : super(key: key);

  @override
  State<CarDashboard> createState() => _CarDashboardState();
}

class _CarDashboardState extends State<CarDashboard> with TickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, CarData> carsData = {};
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    _database.child('Car1').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          carsData['Car1'] = CarData.fromMap(
            Map<String, dynamic>.from(event.snapshot.value as Map),
          );
        });
      }
    });

    _database.child('Car2').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          carsData['Car2'] = CarData.fromMap(
            Map<String, dynamic>.from(event.snapshot.value as Map),
          );
        });
      }
    });
  }

  Future<void> _openInGoogleMaps(double latitude, double longitude) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildOverviewTab()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final flippedCount = carsData.values.where((car) => car.flipped).length;
    final hasAlert = flippedCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasAlert
              ? [const Color(0xFFFF416C), const Color(0xFFFF4B2B)]
              : [const Color(0xFF6C63FF), const Color(0xFF5A52D5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: (hasAlert ? Colors.red : const Color(0xFF6C63FF)).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Monitor',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Real-time Safety Tracking',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              if (hasAlert)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.2),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Color(0xFFFF416C),
                          size: 28,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildQuickStat(
                'Active',
                carsData.length.toString(),
                Icons.directions_car_rounded,
              ),
              const SizedBox(width: 16),
              _buildQuickStat(
                'Alerts',
                flippedCount.toString(),
                Icons.error_rounded,
              ),
              const SizedBox(width: 16),
              _buildQuickStat(
                'Warning',
                carsData.values.where((car) => car.flipRisk > 40 && !car.flipped).length.toString(),
                Icons.warning_amber_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (carsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 20),
            Text(
              'Connecting to vehicles...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      color: const Color(0xFF6C63FF),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (carsData.containsKey('Car1'))
            ModernCarCard(
              title: 'VEHICLE ALPHA',
              data: carsData['Car1']!,
              gradientColors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
              onOpenMaps: () => _openInGoogleMaps(
                carsData['Car1']!.latitude,
                carsData['Car1']!.longitude,
              ),
            ),
          const SizedBox(height: 16),
          if (carsData.containsKey('Car2'))
            ModernCarCard(
              title: 'VEHICLE BETA',
              data: carsData['Car2']!,
              gradientColors: const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
              onOpenMaps: () => _openInGoogleMaps(
                carsData['Car2']!.latitude,
                carsData['Car2']!.longitude,
              ),
            ),
        ],
      ),
    );
  }
}

class CarData {
  final double distance;
  final bool flipped;
  final double pitch;
  final double roll;
  final String timestamp;
  final double latitude;
  final double longitude;

  CarData({
    required this.distance,
    required this.flipped,
    required this.pitch,
    required this.roll,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  factory CarData.fromMap(Map<String, dynamic> map) {
    return CarData(
      distance: (map['distance'] ?? 0).toDouble(),
      flipped: map['flipped'] ?? false,
      pitch: (map['pitch'] ?? 0).toDouble(),
      roll: (map['roll'] ?? 0).toDouble(),
      timestamp: map['timestamp']?.toString() ?? '0',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
    );
  }

  double get flipRisk {
    double absRoll = roll.abs();
    if (absRoll < 30) return 0;
    if (absRoll >= 90) return 100;
    return ((absRoll - 30) / 60) * 100;
  }

  Color get riskColor {
    if (flipped) return const Color(0xFFFF416C);
    if (flipRisk > 70) return const Color(0xFFFF6B6B);
    if (flipRisk > 40) return const Color(0xFFFFA726);
    return const Color(0xFF4CAF50);
  }

  String get riskLevel {
    if (flipped) return 'CRITICAL';
    if (flipRisk > 70) return 'HIGH RISK';
    if (flipRisk > 40) return 'CAUTION';
    return 'OPTIMAL';
  }

  String get locationDisplay {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}

class ModernCarCard extends StatelessWidget {
  final String title;
  final CarData data;
  final List<Color> gradientColors;
  final VoidCallback onOpenMaps;

  const ModernCarCard({
    Key? key,
    required this.title,
    required this.data,
    required this.gradientColors,
    required this.onOpenMaps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: data.flipped
            ? const LinearGradient(
          colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [
            Color(0xFF1A1F3A),
            Color(0xFF1A1F3A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (data.flipped ? const Color(0xFFFF416C) : gradientColors[0])
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(20),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: data.flipped
                    ? [Colors.white, Colors.white]
                    : gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (data.flipped ? Colors.white : gradientColors[0])
                      .withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.directions_car_rounded,
              color: data.flipped ? const Color(0xFFFF416C) : Colors.white,
              size: 28,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: data.riskColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: data.riskColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        data.flipped ? Icons.error_rounded : Icons.shield_rounded,
                        size: 14,
                        color: data.riskColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data.riskLevel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: data.riskColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0E27),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interactive Location Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.2),
                          const Color(0xFF2E7D32).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CURRENT LOCATION',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data.locationDisplay,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Coordinate Details
                        Row(
                          children: [
                            Expanded(
                              child: _buildCoordinateBox(
                                'Latitude',
                                data.latitude.toStringAsFixed(6),
                                Icons.south,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCoordinateBox(
                                'Longitude',
                                data.longitude.toStringAsFixed(6),
                                Icons.east,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Open in Google Maps Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onOpenMaps,
                            icon: const Icon(Icons.map, size: 20),
                            label: const Text(
                              'OPEN IN GOOGLE MAPS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 8,
                              shadowColor: const Color(0xFF4CAF50).withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Risk Gauge
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          data.riskColor.withOpacity(0.2),
                          data.riskColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: data.riskColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'RISK LEVEL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${data.flipRisk.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: data.riskColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: data.flipRisk / 100,
                            minHeight: 12,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(data.riskColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Angle Visualization
                  const Text(
                    'ORIENTATION METRICS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        minY: -100,
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: data.pitch,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                ),
                                width: 50,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: data.roll,
                                gradient: LinearGradient(
                                  colors: data.flipped
                                      ? [const Color(0xFFFF416C), const Color(0xFFFF4B2B)]
                                      : [const Color(0xFFFFA726), const Color(0xFFFF6B6B)],
                                ),
                                width: 50,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ],
                          ),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final style = TextStyle(
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                );
                                switch (value.toInt()) {
                                  case 0:
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text('PITCH', style: style),
                                    );
                                  case 1:
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text('ROLL', style: style),
                                    );
                                  default:
                                    return const Text('');
                                }
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}°',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[800],
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Distance',
                          '${data.distance.toStringAsFixed(1)}m',
                          Icons.straighten,
                          const Color(0xFF667EEA),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Pitch',
                          '${data.pitch.toStringAsFixed(1)}°',
                          Icons.rotate_90_degrees_ccw,
                          const Color(0xFF764BA2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Roll',
                          '${data.roll.toStringAsFixed(1)}°',
                          Icons.rotate_left,
                          data.riskColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Status',
                          data.flipped ? 'FLIPPED' : 'NORMAL',
                          data.flipped ? Icons.warning : Icons.check_circle,
                          data.riskColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}