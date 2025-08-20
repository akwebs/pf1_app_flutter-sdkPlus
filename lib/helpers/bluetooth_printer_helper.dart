import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';
import 'package:image/image.dart' as img;

class BluetoothPrinterHelper {
  static Future<void> checkAndPrint(
      BuildContext context, List<dynamic> printData) async {
    if (!await _checkPermissions()) {
      ToastHelper.nativeToastErr(msg: 'Bluetooth permissions are required.');
      return;
    }

    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      _showDeviceSelectionSheet(context, printData);
    } else {
      _printData(printData);
    }
  }

  static Future<bool> _checkPermissions() async {
    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      return true;
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  }

  static Future<void> _printData(List<dynamic> printData) async {
    try {
      // Initialize printer
      await PrintBluetoothThermal.writeBytes([0x1B, 0x40]); // ESC @ - Initialize printer
      
      // Reset font size to normal
      await PrintBluetoothThermal.writeBytes([0x1D, 0x21, 0x00]); // ESC ! 0 - Normal size
      
      // Center alignment
      await PrintBluetoothThermal.writeBytes([0x1B, 0x61, 0x01]); // ESC a 1 - Center alignment
      
      // Add feed before printing
      // await PrintBluetoothThermal.writeBytes([0x1B, 0x64, 0x02]); // Feed 2 lines
      
      for (var item in printData) {
        if (item is PrintTextSize) {
          await PrintBluetoothThermal.writeString(printText: item);
        } else if (item is Uint8List) {
          List<int> bytes = await _convertImageToEscPos(item);
          await PrintBluetoothThermal.writeBytes(bytes);
        }
      }
      
      // Add feed after content
      // await PrintBluetoothThermal.writeBytes([0x1B, 0x64, 0x02]); // Feed 2 lines
      
      // Cut paper
      await PrintBluetoothThermal.writeBytes([0x1D, 0x56, 0x41]); // GS V A - Full cut
      
      // Reset alignment to left
      await PrintBluetoothThermal.writeBytes([0x1B, 0x61, 0x00]); // ESC a 0 - Left alignment
      
      // Reset font size to normal
      await PrintBluetoothThermal.writeBytes([0x1D, 0x21, 0x00]); // ESC ! 0 - Normal size
    } catch (e) {
      print('Printing error: $e');
    }
  }

  static Future<List<int>> _convertImageToEscPos(Uint8List imageData) async {
    img.Image? image = img.decodeImage(imageData);
    if (image == null) return [];

    image = img.copyResize(image, width: 250);
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    return generator.image(image);
  }

  static void _showDeviceSelectionSheet(
      BuildContext context, List<dynamic> printData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
              width: double.infinity,
              child: DeviceSelectionSheet(printData: printData)),
        );
      },
    );
  }
}

class DeviceSelectionSheet extends StatefulWidget {
  final List<dynamic> printData;
  const DeviceSelectionSheet({Key? key, required this.printData})
      : super(key: key);

  @override
  _DeviceSelectionSheetState createState() => _DeviceSelectionSheetState();
}

class _DeviceSelectionSheetState extends State<DeviceSelectionSheet> {
  List<BluetoothInfo> _devices = [];
  String? _selectedDevice;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndScan();
  }

  Future<void> _checkPermissionsAndScan() async {
    if (await BluetoothPrinterHelper._checkPermissions()) {
      _scanDevices();
    } else {
      ToastHelper.nativeToastErr(msg: 'Bluetooth permissions are required.');
    }
  }

  Future<void> _scanDevices() async {
    final List<BluetoothInfo> devices =
        await PrintBluetoothThermal.pairedBluetooths;
    setState(() {
      _devices = devices;
    });
  }

  Future<void> _connectAndPrint() async {
    if (_selectedDevice == null) return;
    setState(() => _loading = true);

    final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: _selectedDevice!);
    setState(() => _loading = false);

    if (result) {
      Navigator.pop(context);
      BluetoothPrinterHelper.checkAndPrint(context, widget.printData);
    } else {
      if (mounted) {
        ToastHelper.nativeToastErr(msg: 'Failed to connect to device');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select a Bluetooth Printer', style: TextStyle(fontSize: 18)),
          SizedBox(height: 10),
          DropdownButton<String>(
            hint: Text('Select Device'),
            value: _selectedDevice,
            items: _devices.map((device) {
              return DropdownMenuItem<String>(
                value: device.macAdress,
                child: Text(device.name),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() => _selectedDevice = value);
            },
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loading ? null : _connectAndPrint,
            child: _loading
                ? CircularProgressIndicator()
                : Text('Connect & Print'),
          ),
        ],
      ),
    );
  }
}
