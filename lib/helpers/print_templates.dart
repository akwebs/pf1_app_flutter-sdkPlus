import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:kota_pf1_app/helpers/date_time_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:kota_pf1_app/helpers/print_settings.dart';

class PrintTemplates {
  static Future<Uint8List> _generateQrBytes(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
    );
    final imageData = await painter.toImageData(200);
    return imageData!.buffer.asUint8List();
  }

  static Widget buildPreviewContent(Map<String, dynamic> data, {required bool isCheckIn, required PrintSettings settings}) {
    final String vehicleNo = (data['vehicle_no'] ?? '').toString().toUpperCase();
    final String vehicleType = (data['vehicle_type'] ?? '').toString();
    final String passNo = (data['pass_no'] ?? '').toString();
    final String parkingTypeText = (data['parking_type_text'] ?? '').toString();
    final String checkedIn = DateTimeHelper.toAmPm(data['checked_in']);
    final String checkout = !isCheckIn ? DateTimeHelper.toAmPm(data['checkout_time']) : '';
    final bool isTwoWheeler = vehicleType.toLowerCase().contains('two wheeler');
    final bool hasHelmet = (data['has_helmet'] ?? '0').toString() == '1';

    List<Map<String, dynamic>> twoColumnRates = [];
    if (isCheckIn && data['two_column_rates'] != null && settings.includeParkingRates) {
      twoColumnRates = List<Map<String, dynamic>>.from(data['two_column_rates']);
    }

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (settings.includeOrgName)
            Text(PrintData.orgName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (!isCheckIn && settings.includeGstOnCheckout)
            Text(PrintData.gstNo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Divider(),
          if (settings.includeCheckInTime) Text('${PrintData.checkIn}: $checkedIn'),
          if (!isCheckIn && settings.includeCheckoutTime) Text('${PrintData.checkOut}: $checkout'),
          if (settings.includeVehicleNo) Text('Vehicle No: $vehicleNo'),
          if (settings.includeParkingType) Text('Parking Type: $parkingTypeText'),
          if (settings.includeVehicleType) Text('${PrintData.vehicleType}: $vehicleType'),
          if (settings.includeTokenNo) Text('${PrintData.tokenNo}: $passNo'),
          if (settings.includeHelmet && isTwoWheeler) Text('${PrintData.helmet}: ${hasHelmet ? 'YES' : 'NO'}'),
          Divider(),
          if (!isCheckIn) Text('${PrintData.totalAmount}: ${data['extra_amount'] ?? ''}'),
          if (!isCheckIn) Divider(),
          if (isCheckIn && settings.includeQrOnCheckIn)
            Center(
              child: FutureBuilder<Uint8List>(
                future: _generateQrBytes(vehicleNo),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image.memory(snapshot.data!, width: 100, height: 100);
                  }
                  return CircularProgressIndicator();
                },
              ),
            ),
          if (settings.includeThankYou)
            Text(PrintData.thankYou, textAlign: TextAlign.center),
          if (isCheckIn && settings.includeParkingRates && twoColumnRates.isNotEmpty) ...[
            Divider(),
            Text(PrintData.parkingRates, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ...twoColumnRates.map((rate) => Text('${rate['left_column']} , ${rate['right_column']}', style: TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (settings.includeReceiptLost)
              Text(PrintData.receiptLost, style: TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
          Divider(),
          if (!isCheckIn && settings.includeRailwayHelpLine)
            Text(PrintData.railwayHelpLine, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static Future<bool> showPreviewDialog(BuildContext context, Map<String, dynamic> data, {required bool isCheckIn}) async {
    final settings = await PrintSettings.load();
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildPreviewContent(data, isCheckIn: isCheckIn, settings: settings),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          ),
                          child: Text('Okay', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          ),
                          child: Text('Print', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  static Future<List<dynamic>> buildPrintData(Map<String, dynamic> data, {required bool isCheckIn}) async {
    final List<dynamic> out = [];
    final settings = await PrintSettings.load();
    final String vehicleNo = (data['vehicle_no'] ?? '').toString().toUpperCase();
    final String vehicleType = (data['vehicle_type'] ?? '').toString();
    final String passNo = (data['pass_no'] ?? '').toString();
    final String parkingTypeText = (data['parking_type_text'] ?? '').toString();
    final bool isTwoWheeler = vehicleType.toLowerCase().contains('two wheeler');
    final bool hasHelmet = (data['has_helmet'] ?? '0').toString() == '1';

    if (settings.includeOrgName) {
      out.add(PrintTextSize(text: '${PrintData.orgName}\n', size: 2));
    }
    if (!isCheckIn && settings.includeGstOnCheckout) {
      out.add(PrintTextSize(text: 'GSTIN: ${PrintData.gstNo}\n', size: 1));
    }
    out.add(PrintTextSize(text: '--------------------------------\n', size: 1));
    if (settings.includeCheckInTime) {
      out.add(PrintTextSize(text: '${PrintData.checkIn}: ${DateTimeHelper.toAmPm(data['checked_in'])}\n', size: 2));
    }
    if (!isCheckIn && settings.includeCheckoutTime) {
      out.add(PrintTextSize(text: '${PrintData.checkOut}: ${DateTimeHelper.toAmPm(data['checkout_time'])}\n', size: 2));
    }
    if (settings.includeVehicleNo) out.add(PrintTextSize(text: 'Vehicle No: $vehicleNo\n', size: 2));
    if (settings.includeParkingType) out.add(PrintTextSize(text: 'Parking Type: $parkingTypeText\n', size: 2));
    if (settings.includeVehicleType) out.add(PrintTextSize(text: '${PrintData.vehicleType}: $vehicleType\n', size: 2));
    if (settings.includeTokenNo) out.add(PrintTextSize(text: '${PrintData.tokenNo}: $passNo\n', size: 2));
    if (settings.includeHelmet && isTwoWheeler) {
      out.add(PrintTextSize(text: '${PrintData.helmet}: ${hasHelmet ? 'YES' : 'NO'}\n', size: 2));
    }

    if (isCheckIn) {
      out.add(PrintTextSize(text: '--------------------------------\n', size: 1));
      if (settings.includeQrOnCheckIn) {
        final qr = await _generateQrBytes(vehicleNo);
        out.add(qr);
      }
      out.add(PrintTextSize(text: '--------------------------------\n', size: 1));
      if (settings.includeParkingRates) {
        out.add(PrintTextSize(text: '${PrintData.parkingRates}\n', size: 1));
        if (data['two_column_rates'] != null) {
          final rates = List<Map<String, dynamic>>.from(data['two_column_rates']);
          for (var rate in rates) {
            out.add(PrintTextSize(text: '${rate['left_column']} , ${rate['right_column']}\n', size: 1));
          }
        }
      }
      if (settings.includeReceiptLost) {
        out.add(PrintTextSize(text: '${PrintData.receiptLost}\n', size: 1));
      }
      if (settings.includeThankYou) {
        out.add(PrintTextSize(text: '${PrintData.thankYou}\n', size: 1));
      }
      if (settings.extraFeedCheckIn > 0) {
        out.add(PrintTextSize(text: '\n' * settings.extraFeedCheckIn, size: 1));
      }
    } else {
      out.add(PrintTextSize(text: '--------------------------------\n', size: 1));
      out.add(PrintTextSize(text: '${PrintData.totalAmount}: ${data['extra_amount']}\n', size: 2));
      out.add(PrintTextSize(text: '--------------------------------\n', size: 1));
      if (settings.includeThankYou) out.add(PrintTextSize(text: '${PrintData.thankYou}\n', size: 1));
      if (settings.includeRailwayHelpLine) out.add(PrintTextSize(text: '${PrintData.railwayHelpLine}\n', size: 1));
    }

    return out;
  }
} 