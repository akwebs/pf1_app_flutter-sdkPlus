import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kota_pf1_app/providers/check_price_provider.dart';
import 'package:kota_pf1_app/widgets/back_btn.dart';
import 'package:kota_pf1_app/widgets/reprint_btn.dart';
import 'package:kota_pf1_app/widgets/search_btn.dart';
import 'package:kota_pf1_app/widgets/vehicle_search_input.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/constants/print_data.dart';

class CheckPricePage extends StatefulWidget {
  const CheckPricePage({super.key});

  @override
  State<CheckPricePage> createState() => _CheckPricePageState();
}

class _CheckPricePageState extends State<CheckPricePage> {
  @override
  void initState() {
    Future.delayed(Duration.zero, () {
      if (mounted) {
        context.read<CheckPriceProvider>().resetVehicleDetail();
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
            'Vehicles',
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
    final bool isLoading = context.watch<CheckPriceProvider>().isLoading;
    final Map vehicleDetail = context.watch<CheckPriceProvider>().vehicleDetail;

    return Scaffold(
      body: SafeArea(
        child: ListView(
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
                    isLoading: isLoading,
                    text: 'Search',
                    onPressed: () {
                      context.read<CheckPriceProvider>().loadVehicleDetails(
                          context, vehicleNumberController.text);
                    },
                  ),
                ],
              ),
            ),
            if (vehicleDetail['pass_no'] == null) NoDataFound(),
            if (vehicleDetail['pass_no'] != null)
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFD6D5D9),
                              width: 0.50,
                            ),
                          ),
                          image: DecorationImage(
                              image:
                                  AssetImage('assets/images/car_card_pattern.png'),
                              alignment: Alignment.topRight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CarIcon(),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InfoText(
                                  label: 'Token No',
                                  value: vehicleDetail['pass_no'].toString(),
                                ),
                                SizedBox(height: 5),
                                InfoText(
                                  label: 'Vehicle No',
                                  value: vehicleDetail['vehicle_no'].toString(),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      InfoText(
                        label: 'Vehicle Type',
                        value: vehicleDetail['vehicle_type'].toString(),
                      ),
                      SizedBox(height: 5),
                      InfoText(
                        label: 'Slot No',
                        value: vehicleDetail['slot_number'].toString(),
                      ),
                      SizedBox(height: 5),
                      InfoText(
                        label: 'Check in Time',
                        value: vehicleDetail['checked_in'].toString(),
                      ),
                      SizedBox(height: 5),
                      InfoText(
                        label: 'Checkout Time :',
                        value: vehicleDetail['checkout_time'].toString(),
                      ),
                      SizedBox(height: 5),
                      InfoText(
                        label: 'Parking Type : ',
                        value: vehicleDetail['parking_type_text'].toString(),
                      ),
                      SizedBox(height: 5),
                      InfoText(
                        label: 'Amount',
                        value: vehicleDetail['extra_amount'].toString(),
                      ),
                    ],
                  ),
                ),
              )
          ],
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
    return Column(
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
        Text(
          'Search By Vehicle Number',
          style: TextStyle(
            color: const Color(0xFFD6CECE),
            fontSize: 18,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
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
              fontSize: 15,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontFamily: 'Public Sans',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
