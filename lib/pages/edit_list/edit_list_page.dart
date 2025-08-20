import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/helpers/bluetooth_printer_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/route_helper.dart';
import 'package:kota_pf1_app/pages/upload_image/upload_image_page.dart';
import 'package:kota_pf1_app/providers/check_price_provider.dart';
import 'package:kota_pf1_app/providers/reprint_provider.dart';
import 'package:kota_pf1_app/widgets/back_btn.dart';
import 'package:kota_pf1_app/widgets/reprint_btn.dart';
import 'package:kota_pf1_app/widgets/search_btn.dart';
import 'package:kota_pf1_app/widgets/vehicle_search_input.dart';

class EditListPage extends StatefulWidget {
  const EditListPage({super.key});

  @override
  State<EditListPage> createState() => _ReprintState();
}

class _ReprintState extends State<EditListPage> {
  @override
  void initState() {
    Future.delayed(Duration.zero, () {
      if (mounted) {
        context.read<ReprintProvider>().loadCheckInHistory(context, "");
      }
    });
    super.initState();
  }

  TextEditingController vehicleNumberController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.watch<ReprintProvider>().isLoading;
    final List history = context.watch<ReprintProvider>().historyCheckIn;

    return Scaffold(
      body: Column(
        children: [
          HeaderLayout(
            children: [
              Row(
                children: [BackBtn(), PageTitle()],
              ),
              SizedBox(height: 12),
              VehicleSearchInput(
                controller: vehicleNumberController,
                hintText: 'Enter Vehicle Number',
              ),
              SizedBox(height: 14),
              SearchBtn(
                text: 'Search',
                onPressed: () {
                  context.read<ReprintProvider>().loadCheckInHistory(
                      context, vehicleNumberController.text);
                },
              ),
            ],
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
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 22),
                  itemCount: history.length,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () {
                        RouteHelper.push(
                            context, () => UploadImagePage(item: history[i]));
                      },
                      child: ListItem(
                        item: history[i],
                      ),
                    );
                  }),
            )
        ],
      ),
    );
  }
}

class ListItem extends StatelessWidget {
  final Map item;
  const ListItem({super.key, required this.item});

  Future<Uint8List> generateQrCode(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
    );

    final picData = await qrPainter.toImageData(200);
    return picData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      width: double.infinity,
      padding: EdgeInsets.all(11),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        shadows: [
          BoxShadow(
            color: Color(0x338F9FB8),
            blurRadius: 15,
            offset: Offset(0, 2),
            spreadRadius: 0,
          )
        ],
      ),
      child: Row(
        children: [
          CarIcon(),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoText(
                    label: 'Vehicle No', value: item['vehicle_no'].toString()),
                InfoText(label: 'Slot No', value: item['slot_number'])
              ],
            ),
          ),
        ],
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
  const CarIcon({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 41,
      height: 41,
      padding: EdgeInsets.all(8),
      decoration: ShapeDecoration(
        color: const Color(0xFFFA7763),
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
      'Vehicles',
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
