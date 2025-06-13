import 'package:flutter/material.dart';
import 'dart:io';

import 'package:mapbox_fyp/screens/detection.dart';

class DashcamConnectionPage extends StatefulWidget {
  const DashcamConnectionPage({super.key});

  @override
  State<DashcamConnectionPage> createState() => _DashcamConnectionPageState();
}

class _DashcamConnectionPageState extends State<DashcamConnectionPage> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  List<Map<String, dynamic>> _availableDevices = [];
  late TabController _tabController;
  bool _isConnecting = false;
  String? _connectingDeviceName;
  bool _isConnected = false;
  Map<String, dynamic> _selectedDevice = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startScanning();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _availableDevices = [];
      // TODO: Implement actual device scanning
      // This is a placeholder for demonstration
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _availableDevices = [
              {'name': 'Dashcam-001', 'type': 'wifi', 'signal': 'Strong', 'battery': '85%'},
              {'name': 'Dashcam-002', 'type': 'wifi', 'signal': 'Medium', 'battery': '92%'},
            ];
            _isScanning = false;
          });
        }
      });
    });
  }

  Future<void> _connectToDevice(Map<String, dynamic> device) async {
    setState(() {
      _isConnecting = true;
      _connectingDeviceName = device['name'];
      _selectedDevice = device;
    });

    try {
      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Implement actual connection logic here
      // For now, we'll just simulate a successful connection

      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to device!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to the AI Vision Assistant (Detection Page)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Dashcam Connected Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connected to: ${device['name']}'),
                const SizedBox(height: 8),
                Text('Signal: ${device['signal']}'),
                Text('Battery: ${device['battery']}'),
                const SizedBox(height: 16),
                const Text('Ready to start AI-powered object detection and lane analysis.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const DrivingAssistantPage(
                        title: 'AI Vision Assistant - Live Detection',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Detection'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Vision Assistant Setup',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                letterSpacing: 0.5,
              ),
              tabs: [
                _buildTab(Icons.wifi, 'WiFi'),
                _buildTab(Icons.bluetooth, 'Bluetooth'),
                _buildTab(Icons.usb, 'USB'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildDeviceList('wifi'),
                _buildDeviceList('bluetooth'),
                _buildDeviceList('usb'),
              ],
            ),
            if (_isConnecting)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to $_connectingDeviceName...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  // Navigate directly to detection page for testing
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Test AI Vision Assistant'),
                      content: const Text('This will open the AI Vision Assistant in test mode without connecting to a real dashcam. You can test object detection and lane analysis features.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const DrivingAssistantPage(
                                  title: 'AI Vision Assistant - Test Mode',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Start Test'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.smart_toy),
                label: const Text('Test AI Vision'),
                backgroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(String connectionType) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Available ${connectionType.toUpperCase()} Devices',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isScanning ? Icons.hourglass_empty : Icons.refresh,
                    key: ValueKey<bool>(_isScanning),
                  ),
                ),
                onPressed: _isScanning ? null : _startScanning,
                tooltip: 'Scan for devices',
              ),
            ],
          ),
        ),
        if (_isScanning)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Scanning for devices...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_availableDevices.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No devices found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _startScanning,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _availableDevices.length,
              itemBuilder: (context, index) {
                final device = _availableDevices[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(
                        _getConnectionTypeIcon(connectionType),
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    title: Text(
                      device['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Signal: ${device['signal']}'),
                        Text('Battery: ${device['battery']}'),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: _isConnecting ? null : () => _connectToDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Connect'),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _getConnectionTypeIcon(String type) {
    switch (type) {
      case 'wifi':
        return Icons.wifi;
      case 'bluetooth':
        return Icons.bluetooth;
      case 'usb':
        return Icons.usb;
      default:
        return Icons.devices;
    }
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      height: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: Colors.white,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 