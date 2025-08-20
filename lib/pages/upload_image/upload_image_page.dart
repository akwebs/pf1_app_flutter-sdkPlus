import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/controllers/loader_controller.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/bluetooth_printer_helper.dart';
import 'package:kota_pf1_app/helpers/image_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/doc_btn.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/pass_btn.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/vehicle_type_chip.dart';
import 'package:kota_pf1_app/providers/checkin_provider.dart';
import 'package:kota_pf1_app/providers/pass_type_provider.dart';
import 'package:kota_pf1_app/providers/slot_provider.dart';
import 'package:kota_pf1_app/providers/vehicle_type_provider.dart';
import 'package:kota_pf1_app/widgets/back_btn.dart';

class UploadImagePage extends StatefulWidget {
  final Map item;
  const UploadImagePage({super.key, required this.item});

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  @override
  void initState() {
    Future.delayed(Duration.zero, () {
      if (mounted) {
        resetAll();
      }
    });
    super.initState();
  }

  final apiClient = ApiClient.create();
  final CancelToken _cancelToken = CancelToken();
  final loaderController = LoaderController(loading: false);

  resetAll() {
    context.read<CheckInProvider>().resetImages();
  }

  handleSubmitClick() async {
    final vehicleImage = context.read<CheckInProvider>().vehicleImage;
    final licenseImage = context.read<CheckInProvider>().licenseImage;

    String vehicleImageName = "";
    String licenseImageName = "";

    if (mounted) {
      setState(() {
        loaderController.showLoading();
      });
    }

    if (vehicleImage.isNotEmpty) {
      final vehicleImageData = context.read<CheckInProvider>().vehicleImageData;
      try {
        vehicleImageName = await ImageHelper.uploadImage(vehicleImageData);
      } catch (err) {
        ToastHelper.nativeToastErr(msg: 'Unable to upload vehicle image');
        debugPrint(err.toString());
      }
    }

    if (licenseImage.isNotEmpty) {
      final licenseImageData = context.read<CheckInProvider>().licenseImageData;

      try {
        licenseImageName = await ImageHelper.uploadImage(licenseImageData);
      } catch (err) {
        ToastHelper.nativeToastErr(msg: 'Unable to upload license image');
        debugPrint(err.toString());
      }
    }

    try {
      final res = await apiClient.post(
          path: 'update_images',
          data: {
            "vehicle_image": vehicleImageName,
            "license_image": licenseImageName,
            "id": widget.item['id'].toString()
          },
          cancelToken: _cancelToken);

      if (mounted) {
        if (res.data['status'].toString() == '200') {
          resetAll();
          setState(() {
            loaderController.hideLoading();
          });
          ToastHelper.nativeToastSuccess(msg: 'Updated successfully');
          Navigator.pop(context);
        } else {
          ToastHelper.openErrorToast(context, 'Error, ${res.data['msg']}');
        }
      }
    } on DioException catch (err) {
      if (mounted) {
        ToastHelper.openErrorToast(context, err.response?.data['message']);
      }
    } on Exception catch (err) {
      debugPrint(err.toString());
      if (mounted) {
        ToastHelper.openErrorToast(context, StrConstants.connectionError);
      }
    }
    if (mounted) {
      setState(() {
        loaderController.hideLoading();
      });
    }
  }

  @override
  void dispose() {
    _cancelToken.cancel(StrConstants.dioDisposal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          HeaderLayout(
            children: [
              Row(
                children: [BackBtn(), PageTitle()],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: ListItem(item: widget.item),
          ),
          DocSection(),
          SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              if (!loaderController.loading) {
                handleSubmitClick();
              }
            },
            child: CheckInBtn(
              isLoading: loaderController.loading,
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
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
      'Upload Photo',
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
      padding: EdgeInsets.only(left: 22, right: 22, top: 40, bottom: 20),
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

class CheckInBtn extends StatelessWidget {
  final bool isLoading;
  const CheckInBtn({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5),
        width: double.infinity,
        height: 55,
        decoration: ShapeDecoration(
          color: const Color(0xFF34C47C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          shadows: [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 4),
              spreadRadius: 0,
            )
          ],
        ),
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage("assets/images/check_icon.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  )
                ],
              ),
      ),
    );
  }
}

class DocSection extends StatefulWidget {
  DocSection({
    super.key,
  });

  @override
  State<DocSection> createState() => _DocSectionState();
}

class _DocSectionState extends State<DocSection> {
  @override
  Widget build(BuildContext context) {
    String licenseImagePath = context.watch<CheckInProvider>().licenseImage;
    String vehicleImagePath = context.watch<CheckInProvider>().vehicleImage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: DocBtn(
              imagePath: 'assets/images/doc_icon.png',
              selectedImg: licenseImagePath,
              text: 'License Photo',
              onPressed: () async {
                final imageData = await ImageHelper.capturePhoto();
                if (imageData != null) {
                  setState(() {
                    licenseImagePath = imageData["path"].toString();
                  });
                  context.read<CheckInProvider>().setLicenseImage(
                      imageData["path"].toString(), imageData['formData']);
                }
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: DocBtn(
              imagePath: 'assets/images/vehicle_icon.png',
              selectedImg: vehicleImagePath,
              text: 'Vehicle Photo',
              onPressed: () async {
                final imageData = await ImageHelper.capturePhoto();
                if (imageData != null) {
                  setState(() {
                    vehicleImagePath = imageData["path"].toString();
                  });
                  context.read<CheckInProvider>().setVehicleImage(
                      imageData["path"].toString(), imageData['formData']);
                }
              },
            ),
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
