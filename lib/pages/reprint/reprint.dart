import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:kota_pf1_app/helpers/bluetooth_printer_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/date_time_helper.dart';
import 'package:kota_pf1_app/providers/reprint_provider.dart';
import 'package:kota_pf1_app/widgets/back_btn.dart';
import 'package:kota_pf1_app/widgets/search_btn.dart';
import 'package:kota_pf1_app/widgets/vehicle_search_input.dart';
import 'package:kota_pf1_app/helpers/print_templates.dart';

class Reprint extends StatefulWidget {
  const Reprint({super.key});

  @override
  State<Reprint> createState() => _ReprintState();
}

class _ReprintState extends State<Reprint> {
  @override
  void initState() {
    Future.delayed(Duration.zero, () {
      if (mounted) {
        context.read<ReprintProvider>().loadHistory(context, "");
      }
    });
    super.initState();
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ConstColors.themeColor, ConstColors.themeColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ConstColors.themeColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          BackBtn(),
          const SizedBox(width: 8),
          Text(
            'Reprint pass',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            width: 160,
            height: 36,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(PrintData.appLogoWhite),
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextEditingController vehicleNumberController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.watch<ReprintProvider>().isLoading;
    final List history = context.watch<ReprintProvider>().history;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHeader(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  VehicleSearchInput(
                    controller: vehicleNumberController,
                    hintText: 'Enter Vehicle Number',
                  ),
                  const SizedBox(height: 14),
                  SearchBtn(
                    text: 'Search',
                    onPressed: () {
                      context
                          .read<ReprintProvider>()
                          .loadHistory(context, vehicleNumberController.text);
                    },
                  ),
                ],
              ),
            ),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(
                    color: ConstColors.themeColor,
                  ),
                ),
              ),
            if (history.isEmpty && !isLoading) Expanded(child: NoDataFound()),
            if (history.isNotEmpty && !isLoading) ListHeader(),
            if (history.isNotEmpty && !isLoading)
              Expanded(
                child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (context, i) {
                      return ListItem(
                        item: history[i],
                      );
                    }),
              )
          ],
        ),
      ),
    );
  }
}

class ListItem extends StatelessWidget {
  final Map item;
  const ListItem({super.key, required this.item});

  String _formatCheckIn(String input) {
    try {
      if (input.isEmpty) return input;
      final parts = input.split(' ');
      if (parts.length < 2) return input;
      final date = parts[0];
      final time = parts[1];
      final d = date.split('/');
      if (d.length < 3) return input;
      final t = time.split(':');
      if (t.length < 2) return '${d[0]}/${d[1]} $time';
      int hour = int.tryParse(t[0]) ?? 0;
      final String minute = t[1];
      final String suffix = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '${d[0]}/${d[1]} ${hour.toString().padLeft(2, '0')}:$minute $suffix';
    } catch (_) {
      return input;
    }
  }

  Future<Uint8List> generateQrCode(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
    );

    final picData = await qrPainter.toImageData(200);
    return picData!.buffer.asUint8List();
  }

  static Future<bool> _showPrintPreviewDialog(BuildContext context, Map<String, dynamic> data, String customerType, bool isCheckIn) async {
    return await PrintTemplates.showPreviewDialog(context, data, isCheckIn: isCheckIn);
  }

  handleCheckInPrint(context) async {
    final gst = await PrefHelper.getUserData('gst');
    String customerType = "-";

    if (item['type'].toString() == '1') {
      customerType = 'VIP';
    } else if (item['type'].toString() == '2') {
      customerType = 'Employee';
    } else if (item['type'].toString() == '3') {
      customerType = 'Customer';
    }

    // Ensure parking type text is available
    String parkingTypeText = item['parking_type_text'] ?? 'General Parking';

    // Get parking rates
    List<Map<String, dynamic>> parkingRates = [];
    if (item['parking_rates'] != null) {
      parkingRates = List<Map<String, dynamic>>.from(item['parking_rates']);
    }
    List<Map<String, dynamic>> twoColumnRates = [];
    if (item['two_column_rates'] != null) {
      twoColumnRates = List<Map<String, dynamic>>.from(item['two_column_rates']);
    }

    // Show print preview dialog
    final bool shouldPrint = await _showPrintPreviewDialog(context, Map<String, dynamic>.from(item), customerType, true);
    
    if (shouldPrint) {
      final printData = await PrintTemplates.buildPrintData(Map<String, dynamic>.from(item), isCheckIn: true);
      await BluetoothPrinterHelper.checkAndPrint(context, printData);
    }
  }

  handleCheckOutPrint(context) async {
    final gst = await PrefHelper.getUserData('gst');
    String customerType = "-";

    if (item['type'].toString() == '1') {
      customerType = 'VIP';
    } else if (item['type'].toString() == '2') {
      customerType = 'Employee';
    } else if (item['type'].toString() == '3') {
      customerType = 'Customer';
    }

    // Ensure parking type text is available
    String parkingTypeText = item['parking_type_text'] ?? 'General Parking';

    // Get parking rates
    List<Map<String, dynamic>> parkingRates = [];
    if (item['parking_rates'] != null) {
      parkingRates = List<Map<String, dynamic>>.from(item['parking_rates']);
    }
    List<Map<String, dynamic>> twoColumnRates = [];
    if (item['two_column_rates'] != null) {
      twoColumnRates = List<Map<String, dynamic>>.from(item['two_column_rates']);
    }

    // Show print preview dialog
    final bool shouldPrint = await _showPrintPreviewDialog(context, Map<String, dynamic>.from(item), customerType, false);
    
    if (shouldPrint) {
      final printData = await PrintTemplates.buildPrintData(Map<String, dynamic>.from(item), isCheckIn: false);
      await BluetoothPrinterHelper.checkAndPrint(context, printData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
        children: [
          CarIcon(status: item['status']?.toString() ?? ''),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item['vehicle_no'].toString().toUpperCase(),style: TextStyle(
              color: const Color(0xFF0E67B7),
              fontSize: 15,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w800,
            ),),
                    SizedBox(width: 10),
                    Text(_formatCheckIn((item['checked_in'] ?? '').toString().toUpperCase()),style: TextStyle(
              color: const Color(0xFF0E67B7),
              fontSize: 13,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w600,
            ),),
                  ],
                ),
                Row(
                  children: [
                    Text(item['slot_number'],style: TextStyle(
              color: const Color(0xFF0E67B7),
              fontSize: 13,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w600,
            ),),
                    SizedBox(width: 10),
                    Text((item['parking_type_text'] ?? 'Other').toString().toUpperCase(),style: TextStyle(
              color: const Color(0xFF0E67B7),
              fontSize: 13,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w600,
            ),),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (item['status']?.toString() == '1') {
                handleCheckInPrint(context);
              } else if (item['status']?.toString() == '2') {
                handleCheckOutPrint(context);
              }
            },
            child: Container(
              width: 20,
              height: 20,
              margin: EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/print_icon_color.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
        ],
        ),
      ),
    );
  }
}

class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 19, bottom: 0, left: 22, right: 22),
        child: Text(
          'Recent Vehicles',
          style: TextStyle(
            color: const Color(0xFF3F3C65),
            fontSize: 13,
            fontFamily: 'Public Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class CarIcon extends StatelessWidget {
  final String status;
  const CarIcon({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCheckedOut = status == '2';
    final Color bgColor = isCheckedOut ? Colors.red : Colors.green;
    return Container(
      width: 41,
      height: 41,
      padding: EdgeInsets.all(8),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: CircleBorder(),
      ),
      child: Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/car_icon.png"),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class NoDataFound extends StatelessWidget {
  const NoDataFound({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        SizedBox(height: 48),
        Container(
          width: 300,
          height: 226,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/no_vehicle.jpeg'),
              fit: BoxFit.contain,
            ),
          ),
        ),
        Center(
          child: Text(
            'No data found',
            style: TextStyle(
              color: const Color(0xFFD6CECE),
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        )
      ],
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'Reprint pass',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class HeaderLayout extends StatelessWidget {
  final List<Widget> children;
  const HeaderLayout({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: 22, right: 22, top: 56, bottom: 23),
      decoration: ShapeDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/home_pattern.png"),
          alignment: Alignment.topRight,
        ),
        color: const Color(0xFFFA7763),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class InfoText extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const InfoText({
    Key? key,
    required this.label,
    required this.value,
    this.labelColor = const Color(0xFF3F3C65),
    this.valueColor = const Color(0xFF0E67B7),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label : ',
            style: TextStyle(
              color: labelColor,
              fontSize: 13,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
