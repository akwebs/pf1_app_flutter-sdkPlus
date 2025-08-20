import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:kota_pf1_app/controllers/loader_controller.dart';
import 'package:kota_pf1_app/helpers/date_time_helper.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/bluetooth_printer_helper.dart';
import 'package:kota_pf1_app/helpers/image_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';
import 'package:kota_pf1_app/helpers/route_helper.dart';
import 'package:kota_pf1_app/pages/login/login_page.dart';
import 'package:kota_pf1_app/helpers/alpr_detection_controller.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/doc_btn.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/parking_type_section.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/pass_btn.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/vehicle_type_chip.dart';
import 'package:kota_pf1_app/providers/checkin_provider.dart';
import 'package:kota_pf1_app/providers/parking_type_provider.dart';
import 'package:kota_pf1_app/providers/pass_type_provider.dart';
import 'package:kota_pf1_app/providers/slot_provider.dart';
import 'package:kota_pf1_app/providers/vehicle_type_provider.dart';
import 'package:flutter/services.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/helmet_section.dart';
import 'package:kota_pf1_app/providers/helmet_provider.dart';
import 'package:alprsdk_plugin/alprsdk_plugin.dart';
import 'package:alprsdk_plugin/alprdetection_interface.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/rendering.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/helpers/print_templates.dart';
import 'package:kota_pf1_app/helpers/connectivity_helper.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> implements AlprDetectionInterface {
  CameraController? _cameraController;
  bool _cameraLoading = false;
  final FocusNode _pageFocusNode = FocusNode();
  final FocusNode _vehicleInputFocusNode = FocusNode();
  final FocusNode _parkingTypeFocusNode = FocusNode();
  final FocusNode _vehicleTypeFocusNode = FocusNode();
  final FocusNode _helmetFocusNode = FocusNode();
  final FocusNode _checkInBtnFocusNode = FocusNode();
  final AlprsdkPlugin _alprsdkPlugin = AlprsdkPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _alprpluginState = -1;
  bool _isInitializing = false;
  bool _isRecognizing = false;
  DateTime? _lastRecognitionTime;
  String? _lastRecognizedPlate;
  bool _isStreamPaused = false;
  dynamic _detectedPlates;
  LocalAlprDetectionViewController? _alprViewController;

  @override
  void initState() {
    super.initState();
    _initializeAlprSdk();
    _initializeAudioPlayer();
    Future.delayed(Duration.zero, () {
      if (mounted) {
        resetAll();
      }
    });
  }

  final apiClient = ApiClient.create();
  final CancelToken _cancelToken = CancelToken();
  final loaderController = LoaderController(loading: false);
  final TextEditingController vehicleController = TextEditingController();

  resetAll() {
    context.read<SlotProvider>().resetSlot();
    context.read<VehicleTypeProvider>().resetSelectedVehicleType();
    context.read<PassTypeProvider>().resetSelectedPassType();
    context.read<ParkingTypeProvider>().resetSelectedParkingType();
    context.read<CheckInProvider>().resetImages();
    context.read<HelmetProvider>().resetHelmetStatus();
    vehicleController.text = PrintData.vehicleNo;
    context.read<VehicleTypeProvider>().loadVehicleTypes(context);
    setState(() {
      _cameraLoading = false;
      _cameraController?.dispose();
      _cameraController = null;
    });
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

  Future<bool> _showPrintPreviewDialog(BuildContext context, Map<String, dynamic> data, String customerType) async {
    return await PrintTemplates.showPreviewDialog(context, data, isCheckIn: true);
  }

  handleCheckInClick() async {
    if (_isStreamPaused) {
      // Resume stream after check-in is complete
      setState(() {
        _isStreamPaused = false;
      });
    }
    final Map slot = context.read<SlotProvider>().slot;
    final Map vehicleType =
        context.read<VehicleTypeProvider>().selectedVehicleType;
    final String passType = context.read<PassTypeProvider>().selectedPassType;
    final String parkingType =
        context.read<ParkingTypeProvider>().selectedParkingType;
    final bool hasHelmet = context.read<HelmetProvider>().hasHelmet;
    final vehicleImage = context.read<CheckInProvider>().vehicleImage;
    final licenseImage = context.read<CheckInProvider>().licenseImage;

    String vehicleImageName = "";
    String licenseImageName = "";

    if (vehicleController.text.isEmpty) {
      ToastHelper.openErrorToast(context, 'Please enter vehicle number');
    } else if (parkingType.isEmpty) {
      ToastHelper.openErrorToast(context, 'Please select parking type');
    } else if (vehicleType.isEmpty) {
      ToastHelper.openErrorToast(context, 'Please select vehicle type');
    } else if (vehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler') && hasHelmet == null) {
      ToastHelper.openErrorToast(context, 'Please confirm if rider has helmet');
    } else {
      if (mounted) {
        setState(() {
          loaderController.showLoading();
        });
      }

      if (vehicleImage.isNotEmpty) {
        final vehicleImageData =
            context.read<CheckInProvider>().vehicleImageData;
        try {
          vehicleImageName = await ImageHelper.uploadImage(vehicleImageData);
        } catch (err) {
          ToastHelper.nativeToastErr(msg: 'Unable to upload vehicle image');
          debugPrint(err.toString());
        }
      }

      if (licenseImage.isNotEmpty) {
        final licenseImageData =
            context.read<CheckInProvider>().licenseImageData;

        try {
          licenseImageName = await ImageHelper.uploadImage(licenseImageData);
        } catch (err) {
          ToastHelper.nativeToastErr(msg: 'Unable to upload license image');
          debugPrint(err.toString());
        }
      }

      try {
        final payload = {
          "admin_id": await PrefHelper.getUserData('admin_id'),
          "user_id": await PrefHelper.getUserData('id'),
          "vehicle_no": vehicleController.text.toUpperCase(),
          "slot_number": slot['slot'].toString(),
          "slot_id": slot['slot_id'].toString(),
          "vehicle_type": vehicleType['id'].toString(),
          "type": passType.isEmpty ? '3' : passType,
          "parking_type": parkingType.isEmpty ? '1' : parkingType,
          "smart_code": '',
          "vehicle_image": vehicleImageName,
          "license_image": licenseImageName,
          "has_helmet": vehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler') 
              ? (hasHelmet ? "1" : "0") 
              : "0",
        };

        final online = await ConnectivityHelper.isOnline();
        dynamic res;
        if (online) {
          res = await apiClient.post(path: 'save', data: payload, cancelToken: _cancelToken);
        } else {
          // Queue offline: create temp pass_no and local record
          final tempPassNo = 'OFF-${DateTime.now().millisecondsSinceEpoch}';
          final nowStr = DateTime.now().toIso8601String();
          await LocalDb.addHistory({
            'vehicle_no': payload['vehicle_no'],
            'checked_in': nowStr,
            'status': 1,
            'slot_number': payload['slot_number'],
            'vehicle_type': vehicleType['vehicle_type'] ?? '',
            'parking_type_text': '',
            'pass_no': tempPassNo,
            'has_helmet': payload['has_helmet'],
            'type': payload['type'],
          });
          await LocalDb.enqueuePendingOp({
            'id': tempPassNo,
            'type': 'checkin',
            'payload': payload,
          });
          res = { 'data': { 'status': '200', ...payload, 'pass_no': tempPassNo, 'checked_in': nowStr, 'parking_type_text': context.read<ParkingTypeProvider>().parkingTypeTextMap[payload['parking_type']] ?? '' } };
        }

        if (mounted) {
          if (res.data['status'].toString() == '200') {
            resetAll();
            setState(() {
              loaderController.hideLoading();
            });
            ToastHelper.nativeToastSuccess(msg: 'Check in successful');
            final gst = await PrefHelper.getUserData('gst');
            String customerType = "-";

            if (res.data['type'].toString() == '1') {
              customerType = 'VIP';
            } else if (res.data['type'].toString() == '2') {
              customerType = 'Employee';
            } else if (res.data['type'].toString() == '3') {
              customerType = 'Customer';
            }

            if (mounted) {
              // Show print preview dialog and print simultaneously
              _showPrintPreviewDialog(context, res.data, customerType);
              
              final printData = await PrintTemplates.buildPrintData(res.data, isCheckIn: true);
              await BluetoothPrinterHelper.checkAndPrint(context, printData);

              // Save local check-in history with token and rates for reprint
              try {
                await LocalDb.addHistory({
                  'vehicle_no': res.data['vehicle_no']?.toString().toUpperCase() ?? '',
                  'checked_in': res.data['checked_in'] ?? '',
                  'status': 1,
                  'slot_number': res.data['slot_number'] ?? '',
                  'vehicle_type': res.data['vehicle_type'] ?? '',
                  'parking_type_text': res.data['parking_type_text'] ?? '',
                  'pass_no': res.data['pass_no']?.toString() ?? '',
                  'parking_rates': res.data['parking_rates'] ?? [],
                  'two_column_rates': res.data['two_column_rates'] ?? [],
                  'has_helmet': res.data['has_helmet']?.toString() ?? '0',
                  'type': res.data['type']?.toString() ?? '3',
                });
              } catch (_) {}
            }
          } else {
            final msg = (res.data['msg'] ?? '').toString();
            if (msg.toLowerCase().contains('suspended')) {
              await PrefHelper.clearAll();
              if (mounted) RouteHelper.replace(context, () => const LoginPage());
              return;
            }
            ToastHelper.openErrorToast(context, 'Error, ${res.data['msg']}');
          }
        }
      } on DioException catch (err) {
        if (mounted) {
          final msg = err.response?.data['message']?.toString() ?? '';
          if (msg.toLowerCase().contains('suspended')) {
            await PrefHelper.clearAll();
            RouteHelper.replace(context, () => const LoginPage());
          } else {
          ToastHelper.openErrorToast(context, err.response?.data['message']);
          }
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
  }

  @override
  Future<void> onAlprDetected(plates) async {
    if (!mounted || _isStreamPaused) return;

    try {
      setState(() {
        _detectedPlates = plates;
      });

      if (plates != null && plates.isNotEmpty) {
        final plate = plates[0];
        if (plate != null && plate is Map) {
          final plateNumber = plate['number']?.toString().toUpperCase() ?? '';
          
          // Check if plate matches either format: AB12AB1234 or 11AB1234A
          bool isValidFormat = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(plateNumber) || 
                             RegExp(r'^\d{2}[A-Z]{2}\d{4}[A-Z]$').hasMatch(plateNumber);
          
          if (isValidFormat && plateNumber != _lastRecognizedPlate) {
            if (mounted) {
              setState(() {
                vehicleController.text = plateNumber;
                _lastRecognizedPlate = plateNumber;
                _isStreamPaused = true;
              });
              await _playBeepSound();
              ToastHelper.nativeToastSuccess(msg: 'Plate recognized: $plateNumber');
              
              // Stop the camera stream
              await _alprViewController?.stopCamera();
            }
          }
        }
      }
    } catch (e) {
      print("Error in ALPR detection: $e");
      if (mounted) {
        ToastHelper.openErrorToast(context, 'Error processing plate detection. Please try again.');
      }
    }
  }

  Future<void> _initializeAlprSdk() async {
    if (_isInitializing) return;
    _isInitializing = true;
    
    try {
      setState(() {
        _cameraLoading = true;
      });

      // Activate SDK with license key
      final activationResult = await _alprsdkPlugin.setActivation(
        "ewAyoIlsDIN24AW/1Ugr9rGv+qkGjsnzV2EPW5OPBySzdKkWhRScPdeCjS4oGynZPI2EgPjA6ump"
        "An5iKnCHBXXjHux1yaBau6M8fSjavrdUr/GKgiJ7w7x05B6P9eQk6BJjjdtA59jjgPzR0EkaWpM6"
        "AFoSoi4V86e1MmCne3dc3lPzMelD7tx+xpdqHdDf0zc6O3xSxEQiu7uU8Aj499FyGu1B+M22kAtU"
        "2klrker81f3DJD+LxRLjSXAE1NDSc6erJwwwVMyJyBoCalTGHpI4ZDND6r/lVpRyJP/ghtwI6sqv"
        "NykLwz+wdj3T2vFnZ9Z/X/9yt6SfZIPVjK0hUA==");
      
      if (!mounted) return;

      setState(() {
        _alprpluginState = activationResult ?? -1;
      });

      if (_alprpluginState != 0) {
        print("ALPR SDK activation failed with state: $_alprpluginState");
        if (mounted) {
          ToastHelper.openErrorToast(context, 'ALPR SDK activation failed. Please restart the app.');
        }
        return;
      }

      // Initialize SDK after successful activation
      final initResult = await _alprsdkPlugin.init();
      if (!mounted) return;

      setState(() {
        _alprpluginState = initResult ?? -1;
      });

      if (_alprpluginState != 0) {
        print("ALPR SDK initialization failed with state: $_alprpluginState");
        if (mounted) {
          ToastHelper.openErrorToast(context, 'ALPR SDK initialization failed. Please restart the app.');
        }
        return;
      }

      // Create new camera view after successful initialization
      if (mounted) {
        _onPlatformViewCreated(DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      print("ALPR SDK initialization error: $e");
      if (mounted) {
        ToastHelper.openErrorToast(context, 'ALPR SDK initialization error. Please restart the app.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _cameraLoading = false;
        });
      }
    }
  }

  Future<void> _resetAndReinitializePage() async {
    if (_isInitializing) return;
    
    try {
      setState(() {
        _cameraLoading = true;
        _isInitializing = true;
      });

      // Stop and dispose current camera
      await _alprViewController?.stopCamera();
      _alprViewController = null;
      
      // Reset all states and providers
      context.read<SlotProvider>().resetSlot();
      context.read<VehicleTypeProvider>().resetSelectedVehicleType();
      context.read<PassTypeProvider>().resetSelectedPassType();
      context.read<ParkingTypeProvider>().resetSelectedParkingType();
      context.read<CheckInProvider>().resetImages();
      context.read<HelmetProvider>().resetHelmetStatus();
      
      // Reset vehicle controller
      vehicleController.text = "RJ20";
      
      // Reset ALPR states
      _lastRecognizedPlate = null;
      _isStreamPaused = false;
      _detectedPlates = null;
      
      // Reload vehicle types
      await context.read<VehicleTypeProvider>().loadVehicleTypes(context);
      
      // Wait for reset to complete
      await Future.delayed(Duration(milliseconds: 500));
      
      // Reinitialize ALPR SDK
      await _initializeAlprSdk();
      
    } catch (e) {
      print("Error during page reset: $e");
      if (mounted) {
        ToastHelper.openErrorToast(context, 'Failed to reset page. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _cameraLoading = false;
          _isInitializing = false;
        });
      }
    }
  }

  void _onPlatformViewCreated(int id) async {
    try {
      _alprViewController = LocalAlprDetectionViewController(id, this);
      await _alprViewController?.initHandler();
      await _alprViewController?.startCamera(0); // 0 for back camera
    } catch (e) {
      print("Error in platform view creation: $e");
      if (mounted) {
        ToastHelper.openErrorToast(context, 'Failed to initialize camera view. Please try again.');
      }
    }
  }

  Future<void> _initializeAudioPlayer() async {
    await _audioPlayer.setSource(AssetSource('sounds/beep.mp3'));
  }

  Future<void> _playBeepSound() async {
    try {
      await _audioPlayer.resume();
    } catch (e) {
      print("Error playing beep sound: $e");
    }
  }

  @override
  void dispose() {
    _alprViewController?.stopCamera();
    _audioPlayer.dispose();
    _cancelToken.cancel(StrConstants.dioDisposal);
    _pageFocusNode.dispose();
    _vehicleInputFocusNode.dispose();
    _parkingTypeFocusNode.dispose();
    _vehicleTypeFocusNode.dispose();
    _helmetFocusNode.dispose();
    _checkInBtnFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyNavigation(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Function key shortcuts
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _initializeAlprSdk();
      } else if (event.logicalKey == LogicalKeyboardKey.f2) {
        _vehicleInputFocusNode.requestFocus();
      } else if (event.logicalKey == LogicalKeyboardKey.f3) {
        _parkingTypeFocusNode.requestFocus();
      } else if (event.logicalKey == LogicalKeyboardKey.f4) {
        _vehicleTypeFocusNode.requestFocus();
      } else if (event.logicalKey == LogicalKeyboardKey.f5) {
        // Only focus helmet if vehicle type is two wheeler
        final vehicleType = context.read<VehicleTypeProvider>().selectedVehicleType;
        if (vehicleType.isNotEmpty && 
            vehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler')) {
          _helmetFocusNode.requestFocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.f6) {
        _checkInBtnFocusNode.requestFocus();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (FocusScope.of(context).focusedChild == _vehicleInputFocusNode) {
          if (vehicleController.text.isNotEmpty && !loaderController.loading) {
            handleCheckInClick();
          }
        } else if (FocusScope.of(context).focusedChild == _parkingTypeFocusNode) {
          final pt = context.read<ParkingTypeProvider>();
          final available = pt.availableParkingTypes;
          if (available.length <= 1) {
            if (available.isNotEmpty && pt.selectedParkingType != available.first) {
              pt.setParkingType(available.first);
            }
          } else {
            final currentType = pt.selectedParkingType;
            pt.setParkingType(currentType == '1' ? '2' : '1');
          }
        } else if (FocusScope.of(context).focusedChild == _vehicleTypeFocusNode) {
          final vehicleTypes = context.read<VehicleTypeProvider>().vehicleTypes;
          final currentType = context.read<VehicleTypeProvider>().selectedVehicleType;
          final currentIndex = vehicleTypes.indexWhere((type) => type['id'] == currentType['id']);
          final nextIndex = (currentIndex + 1) % vehicleTypes.length;
          final nextVehicleType = vehicleTypes[nextIndex];
          
          // Reset helmet status if changing from two wheeler to other vehicle type
          final isCurrentTwoWheeler = currentType.isNotEmpty && 
              currentType['vehicle_type'].toString().toLowerCase().contains('two wheeler');
          final isNextTwoWheeler = nextVehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler');
          
          if (isCurrentTwoWheeler && !isNextTwoWheeler) {
            context.read<HelmetProvider>().resetHelmetStatus();
          }
          
          context.read<VehicleTypeProvider>().setVehicleType(nextVehicleType);
          context.read<SlotProvider>().loadSlots(context, nextVehicleType['id'].toString());
        } else if (FocusScope.of(context).focusedChild == _helmetFocusNode) {
          final currentStatus = context.read<HelmetProvider>().hasHelmet;
          context.read<HelmetProvider>().setHelmetStatus(!currentStatus);
        } else if (FocusScope.of(context).focusedChild == _checkInBtnFocusNode) {
          if (!loaderController.loading) {
            handleCheckInClick();
          }
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft || 
                 event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (FocusScope.of(context).focusedChild == _parkingTypeFocusNode) {
          final pt = context.read<ParkingTypeProvider>();
          final available = pt.availableParkingTypes;
          if (available.length <= 1) {
            if (available.isNotEmpty && pt.selectedParkingType != available.first) {
              pt.setParkingType(available.first);
            }
          } else {
            final currentType = pt.selectedParkingType;
            pt.setParkingType(currentType == '1' ? '2' : '1');
          }
        } else if (FocusScope.of(context).focusedChild == _vehicleTypeFocusNode) {
          final vehicleTypes = context.read<VehicleTypeProvider>().vehicleTypes;
          final currentType = context.read<VehicleTypeProvider>().selectedVehicleType;
          final currentIndex = vehicleTypes.indexWhere((type) => type['id'] == currentType['id']);
          final nextIndex = event.logicalKey == LogicalKeyboardKey.arrowRight 
              ? (currentIndex + 1) % vehicleTypes.length 
              : (currentIndex - 1 + vehicleTypes.length) % vehicleTypes.length;
          final nextVehicleType = vehicleTypes[nextIndex];
          
          // Reset helmet status if changing from two wheeler to other vehicle type
          final isCurrentTwoWheeler = currentType.isNotEmpty && 
              currentType['vehicle_type'].toString().toLowerCase().contains('two wheeler');
          final isNextTwoWheeler = nextVehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler');
          
          if (isCurrentTwoWheeler && !isNextTwoWheeler) {
            context.read<HelmetProvider>().resetHelmetStatus();
          }
          
          context.read<VehicleTypeProvider>().setVehicleType(nextVehicleType);
          context.read<SlotProvider>().loadSlots(context, nextVehicleType['id'].toString());
        } else if (FocusScope.of(context).focusedChild == _helmetFocusNode) {
          final currentStatus = context.read<HelmetProvider>().hasHelmet;
          context.read<HelmetProvider>().setHelmetStatus(!currentStatus);
        }
      }
    }
  }

  // Add this method to show keyboard shortcuts help
  void _showKeyboardShortcutsHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Keyboard Shortcuts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('F1: Open Camera'),
            Text('F2: Vehicle Input'),
            Text('F3: Parking Type'),
            Text('F4: Vehicle Type'),
            Text('F5: Helmet Status (Two Wheeler only)'),
            Text('F6: Check-in Button'),
            Text('Enter: Select/Confirm'),
            Text('Left/Right Arrow: Switch Options'),
            Text('F12: Show this help'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Add this method to build the plate overlay
  Widget _buildPlateOverlay() {
    if (_detectedPlates == null) return Container();

    return CustomPaint(
      painter: PlatePainter(plates: _detectedPlates),
      child: Container(),
    );
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
          Container(
            width: 200,
            height: 40,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(PrintData.appLogoWhite),
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
          const Spacer(),
          _buildHeaderButton(
            Icons.help_outline,
            () => _showKeyboardShortcutsHelp(),
          ),
          const SizedBox(width: 12),
          _buildHeaderButton(
            Icons.refresh,
            () {
              if (!loaderController.loading) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckInPage(),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: ConstColors.themeColor, size: 20),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2E2C49),
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt, color: ConstColors.themeColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  'License Plate Scanner',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2C49),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                if (_cameraLoading) {
                  return Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(ConstColors.themeColor),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Initializing Camera...',
                            style: TextStyle(
                              color: const Color(0xFF2E2C49),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      child: AspectRatio(
                        aspectRatio: 4/2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              if (defaultTargetPlatform == TargetPlatform.android)
                                AndroidView(
                                  viewType: 'facedetectionview',
                                  onPlatformViewCreated: _onPlatformViewCreated,
                                )
                              else
                                UiKitView(
                                  viewType: 'facedetectionview',
                                  onPlatformViewCreated: _onPlatformViewCreated,
                                ),
                              _buildPlateOverlay(),
                              // Scan area overlay
                              Center(
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.8,
                                  height: MediaQuery.of(context).size.width * 0.4,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Corner markers
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(color: Colors.white, width: 3),
                                              left: BorderSide(color: Colors.white, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(color: Colors.white, width: 3),
                                              right: BorderSide(color: Colors.white, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Colors.white, width: 3),
                                              left: BorderSide(color: Colors.white, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Colors.white, width: 3),
                                              right: BorderSide(color: Colors.white, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInputCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, color: ConstColors.themeColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Vehicle Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2C49),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            VehicleNumberInput(
              vehicleController: vehicleController,
              showCameraPreview: _cameraLoading,
              onCameraPress: _initializeAlprSdk,
              onCheckIn: () {
                if (!loaderController.loading) {
                  handleCheckInClick();
                }
              },
              focusNode: _vehicleInputFocusNode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingConfigCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: ConstColors.themeColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Configuration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2C49),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
                         Consumer<ParkingTypeProvider>(
               builder: (context, pt, _) {
                 final hasSingle = pt.availableParkingTypes.length == 1;
                 if (hasSingle) {
                   if (pt.selectedParkingType.isEmpty || pt.selectedParkingType != pt.availableParkingTypes.first) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       context.read<ParkingTypeProvider>().setParkingType(pt.availableParkingTypes.first);
                     });
                   }
                   return SizedBox.shrink();
                 }
                 // When multiple types are available, default select the first if nothing is selected yet
                 if (pt.selectedParkingType.isEmpty && pt.availableParkingTypes.isNotEmpty) {
                   WidgetsBinding.instance.addPostFrameCallback((_) {
                     context.read<ParkingTypeProvider>().setParkingType(pt.availableParkingTypes.first);
                   });
                 }
                 return ParkingTypeSection(focusNode: _parkingTypeFocusNode);
               },
             ),
             const SizedBox(height: 8),
                         Consumer<VehicleTypeProvider>(
               builder: (context, vt, _) {
                 if (vt.vehicleTypes.length == 1) {
                   final only = vt.vehicleTypes.first;
                   if (vt.selectedVehicleType.isEmpty || vt.selectedVehicleType['id'] != only['id']) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       context.read<VehicleTypeProvider>().setVehicleType(only);
                       context.read<SlotProvider>().loadSlots(context, only['id'].toString());
                     });
                   }
                   return SizedBox.shrink();
                 }
                 // When multiple vehicle types are available, default select the first if nothing is selected yet
                 if (vt.selectedVehicleType.isEmpty && vt.vehicleTypes.isNotEmpty) {
                   WidgetsBinding.instance.addPostFrameCallback((_) {
                     final first = vt.vehicleTypes.first;
                     context.read<VehicleTypeProvider>().setVehicleType(first);
                     context.read<SlotProvider>().loadSlots(context, first['id'].toString());
                   });
                 }
                 return VehicleTypeSection(focusNode: _vehicleTypeFocusNode);
               },
             ),
            Consumer<VehicleTypeProvider>(
              builder: (context, vehicleTypeProvider, child) {
                final selectedVehicleType = vehicleTypeProvider.selectedVehicleType;
                final isTwoWheeler = selectedVehicleType.isNotEmpty && 
                    selectedVehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler');
                
                if (isTwoWheeler) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      HelmetSection(focusNode: _helmetFocusNode),
                    ],
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingSlotCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_parking, color: ConstColors.themeColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Available Slot',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2C49),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ParkingSlotSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPassTypeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_membership, color: ConstColors.themeColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Pass Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2C49),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PassSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              focusNode: _checkInBtnFocusNode,
              onKey: (node, event) {
                if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  if (!loaderController.loading) {
                    handleCheckInClick();
                  }
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    if (!loaderController.loading) {
                      handleCheckInClick();
                      _resetAndReinitializePage();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (loaderController.loading)
                          CircularProgressIndicator(
                            color: ConstColors.themeColor,
                            strokeWidth: 2,
                          )
                        else ...[
                          Icon(
                            Icons.print,
                            color: ConstColors.themeColor,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Check-In & Print (F6)',
                            style: TextStyle(
                              color: ConstColors.themeColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                if (!loaderController.loading) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckInPage(),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Center(
                  child: Icon(
                    Icons.refresh,
                    color: ConstColors.themeColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _pageFocusNode,
      onKey: (event) {
        if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.f12) {
          _showKeyboardShortcutsHelp();
        } else {
          _handleKeyNavigation(event);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildHeader(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Camera Section
                      _buildCameraSection(),
                      const SizedBox(height: 5),
                      
                      // Vehicle Information Section
                      // _buildSectionTitle('Vehicle Information'),
                      _buildVehicleInputCard(),
                      const SizedBox(height: 5),
                      
                      // Parking Configuration Section
                      // _buildSectionTitle('Parking Configuration'),
                      _buildParkingConfigCard(),
                      const SizedBox(height: 5),
                      
                      // Parking Slot Section
                      // _buildSectionTitle('Parking Slot'),
                      _buildParkingSlotCard(),
                      const SizedBox(height: 5),
                      
                      // Pass Type Section
                      // _buildSectionTitle('Pass Type'),
                      // _buildPassTypeCard(),
                      // const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
            // Action Buttons Section
            _buildActionButtonsSection(),
          ],
        ),
      ),
    ),
    );
  }
}

class CheckInBtn extends StatelessWidget {
  final bool isLoading;
  final FocusNode? focusNode;
  
  const CheckInBtn({
    super.key, 
    required this.isLoading,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode != null && FocusScope.of(context).focusedChild == focusNode;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5),
        width: double.infinity,
        height: 55,
        decoration: ShapeDecoration(
          color: const Color(0xFF34C47C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
              color: isFocused ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
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
                        image: AssetImage("assets/images/print_icon.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Check-In & Print (F6)',
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

class PassSection extends StatelessWidget {
  const PassSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String selectedPassType =
        context.watch<PassTypeProvider>().selectedPassType;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: PassBtn(
              backgroundColor: selectedPassType == '2'
                  ? Color(0xFFA1F7A9)
                  : Color(0xFFF5F5F5),
              borderColor: selectedPassType == '2'
                  ? Color(0xFF04560C)
                  : Color(0xFFF5F5F5),
              imagePath: 'assets/images/prepaid_card_icon.png',
              text: 'Prepaid Card',
              onPressed: () {
                // if selected on click not select
                if (selectedPassType == '2') {
                  context.read<PassTypeProvider>().setPassType('');
                } else {
                  context.read<PassTypeProvider>().setPassType('2');
                }
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: PassBtn(
              backgroundColor: selectedPassType == '1'
                  ? Color(0xFFA1F7A9)
                  : Color(0xFFF5F5F5),
              borderColor: selectedPassType == '1'
                  ? Color(0xFF04560C)
                  : Color(0xFFF5F5F5),
              imagePath: 'assets/images/vip_card_icon.png',
              text: 'VIP Pass',
              onPressed: () {
                // if selected on click not select
                if (selectedPassType == '1') {
                  context.read<PassTypeProvider>().setPassType('');
                } else {
                  context.read<PassTypeProvider>().setPassType('1');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DocSection extends StatefulWidget {
  const DocSection({
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

class ParkingSlotSection extends StatelessWidget {
  const ParkingSlotSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Map slot = context.watch<SlotProvider>().slot;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: ShapeDecoration(
          color: const Color(0xFFEDF7EE),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 0.50,
              color: const Color(0xFFC3DFCE),
            ),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot.isNotEmpty ? slot['slot'].toString() : 'No Slot Selected',              
              style: TextStyle(
                color: const Color(0xFF3A9869),
                fontSize: 20,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
            
          ],
        ),
      ),
    );
  }
}

class VehicleTypeSection extends StatelessWidget {
  final FocusNode focusNode;

  const VehicleTypeSection({
    super.key,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = FocusScope.of(context).focusedChild == focusNode;
    
    return Focus(
      focusNode: focusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Vehicle Type (F4)',
                  style: TextStyle(
                    color: const Color(0xFF747373),
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Consumer<VehicleTypeProvider>(
              builder: (context, vehicleTypeProvider, child) {
                if (vehicleTypeProvider.vehicleTypes.length <= 1) {
                  return SizedBox.shrink();
                }
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isFocused ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: vehicleTypeProvider.vehicleTypes.length,
                      itemBuilder: (context, i) {
                        final vehicleType = vehicleTypeProvider.vehicleTypes[i];
                        final isSelected = vehicleType['id'].toString() ==
                            vehicleTypeProvider.selectedVehicleType['id'].toString();
                        
                        return GestureDetector(
                          onTap: () {
                            // Reset helmet status if changing from two wheeler to other vehicle type
                            final currentVehicleType = vehicleTypeProvider.selectedVehicleType;
                            final isCurrentTwoWheeler = currentVehicleType.isNotEmpty && 
                                currentVehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler');
                            final isNewTwoWheeler = vehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler');
                            
                            if (isCurrentTwoWheeler && !isNewTwoWheeler) {
                              context.read<HelmetProvider>().resetHelmetStatus();
                            }
                            
                            vehicleTypeProvider.setVehicleType(vehicleType);
                            context.read<SlotProvider>().loadSlots(
                                context,
                                vehicleType['id'].toString());
                          },
                          child: VehicleTypeChip(
                            isSelected: isSelected,
                            text: vehicleType['vehicle_type'].toString(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
           ],
        ),
      ),
    );
  }
}

class VehicleNumberInput extends StatefulWidget {
  final TextEditingController vehicleController;
  final bool showCameraPreview;
  final Function() onCameraPress;
  final Function() onCheckIn;
  final FocusNode focusNode;

  const VehicleNumberInput({
    super.key,
    required this.vehicleController,
    required this.showCameraPreview,
    required this.onCameraPress,
    required this.onCheckIn,
    required this.focusNode,
  });

  @override
  State<VehicleNumberInput> createState() => _VehicleNumberInputState();
}

class _VehicleNumberInputState extends State<VehicleNumberInput> {
  @override
  void initState() {
    super.initState();
    widget.vehicleController.text = '';
    widget.vehicleController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.vehicleController.text;

    // Check if input is complete (either XXBH1234A or RJ20AB1234 format)
    bool isComplete = (text.length == 9 &&
            RegExp(r'^\d{2}[A-Z]{2}\d{4}[A-Z]$').hasMatch(text)) ||
        (text.length == 10 &&
            RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(text));

    if (isComplete) {
             // Auto select parking type if only one available, else default to '1'
       final pt = context.read<ParkingTypeProvider>();
       if (pt.availableParkingTypes.length == 1) {
         pt.setParkingType(pt.availableParkingTypes.first);
       } else {
         pt.setParkingType('1');
       }

      // Auto select Two Wheeler (vehicle type)
      final vehicleTypes = context.read<VehicleTypeProvider>().vehicleTypes;
      if (vehicleTypes.isEmpty) {
        return;
      }
      final List<Map<String, dynamic>> vtList =
          vehicleTypes.cast<Map<String, dynamic>>();
      final twoWheeler = vtList.firstWhere(
        (type) => type['vehicle_type']
            .toString()
            .toLowerCase()
            .contains('two wheeler'),
        orElse: () => vtList.first,
      );
      
      // Reset helmet status when auto-selecting two wheeler
      context.read<HelmetProvider>().resetHelmetStatus();
      
      context.read<VehicleTypeProvider>().setVehicleType(twoWheeler);

      // Load slots for the selected vehicle type
      context
          .read<SlotProvider>()
          .loadSlots(context, twoWheeler['id'].toString());
    }

    // For XXBH1234A format
    if (RegExp(r'^\d{2}').hasMatch(text)) {
      if (text.length <= 2) {
        // First 2 digits - numeric keyboard
        SystemChannels.textInput
            .invokeMethod('TextInput.setKeyboardType', {'type': 'number'});
      } else if (text.length <= 4) {
        // Next 2 letters - text keyboard
        SystemChannels.textInput
            .invokeMethod('TextInput.setKeyboardType', {'type': 'text'});
      } else if (text.length <= 8) {
        // Next 4 numbers - numeric keyboard
        SystemChannels.textInput
            .invokeMethod('TextInput.setKeyboardType', {'type': 'number'});
      } else {
        // Last letter - text keyboard
        SystemChannels.textInput
            .invokeMethod('TextInput.setKeyboardType', {'type': 'text'});
      }
    } else {
      // For RJ20AB1234 format
      if (text.length <= 6) {
        SystemChannels.textInput
            .invokeMethod('TextInput.setKeyboardType', {'type': 'text'});
      } else {
        SystemChannels.textInput
            .invokeMethod('TextInput.setKeyboardType', {'type': 'number'});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = FocusScope.of(context).focusedChild == widget.focusNode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13),
        width: double.infinity,
        height: 70,
        decoration: ShapeDecoration(
          color: const Color(0xFFEBEBEB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
              color: isFocused ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          shadows: [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 3,
              offset: Offset(0, 3),
              spreadRadius: 0,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  'Vehicle Number (F2)',
                  style: TextStyle(
                    color: const Color(0xFF747373),
                    fontSize: 10,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    focusNode: widget.focusNode,
                    controller: widget.vehicleController,
                    textCapitalization: TextCapitalization.characters,
                    onFieldSubmitted: (_) {
                      // Move focus to the next field or trigger check-in
                      if (widget.vehicleController.text.isNotEmpty) {
                        widget.onCheckIn();
                      }
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(10),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        try {
                          // For XXBH1234A format
                          if (RegExp(r'^\d{2}').hasMatch(newValue.text)) {
                            if (newValue.text.length <= 2) {
                              // First 2 digits
                              return TextEditingValue(
                                text: newValue.text.replaceAll(RegExp(r'[^0-9]'), ''),
                                selection: TextSelection.collapsed(offset: newValue.text.length),
                              );
                            } else if (newValue.text.length <= 4) {
                              // Next 2 letters
                              final prefix = newValue.text.substring(0, 2);
                              final letters = newValue.text.substring(2).replaceAll(RegExp(r'[^A-Za-z]'), '');
                              return TextEditingValue(
                                text: prefix + letters,
                                selection: TextSelection.collapsed(offset: (prefix + letters).length),
                              );
                            } else if (newValue.text.length <= 8) {
                              // Next 4 numbers
                              final prefix = newValue.text.substring(0, 4);
                              final numbers = newValue.text.substring(4).replaceAll(RegExp(r'[^0-9]'), '');
                              return TextEditingValue(
                                text: prefix + numbers,
                                selection: TextSelection.collapsed(offset: (prefix + numbers).length),
                              );
                            } else {
                              // Last letter
                              final prefix = newValue.text.substring(0, 8);
                              final suffix = newValue.text.substring(8).replaceAll(RegExp(r'[^A-Za-z]'), '');
                              return TextEditingValue(
                                text: prefix + suffix,
                                selection: TextSelection.collapsed(offset: (prefix + suffix).length),
                              );
                            }
                          }

                          // For RJ20AB1234 format
                          if (newValue.text.length <= 6) {
                            return newValue;
                          }
                          final prefix = newValue.text.substring(0, 6);
                          final suffix = newValue.text.substring(6).replaceAll(RegExp(r'[^0-9]'), '');
                          return TextEditingValue(
                            text: prefix + suffix,
                            selection: TextSelection.collapsed(offset: prefix.length + suffix.length),
                          );
                        } catch (e) {
                          debugPrint('Error in vehicle number formatting: $e');
                          return oldValue;
                        }
                      }),
                    ],
                    style: TextStyle(
                      fontSize: 28,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      isDense: false,
                      hintText: '22BH1234A or RJ20AB1234',
                      hintStyle: TextStyle(
                        color: const Color(0xFF616161),
                        fontSize: 28,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                      enabledBorder: InputBorder.none,
                      border: InputBorder.none,
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

class LogoSection extends StatelessWidget {
  const LogoSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 207,
          height: 36,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/logo-1.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class OcrSection extends StatelessWidget {
  const OcrSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20),
          width: double.infinity,
          height: 236,
          decoration: BoxDecoration(color: const Color(0xFF700E0F)),
        ),
        Positioned(
          bottom: 18,
          right: 20,
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/camera_icon.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ParkingTypeSection extends StatelessWidget {
  final FocusNode focusNode;

  const ParkingTypeSection({
    super.key,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final String selectedParkingType = context.watch<ParkingTypeProvider>().selectedParkingType;
    final isFocused = FocusScope.of(context).focusedChild == focusNode;

    return Focus(
      focusNode: focusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Parking Type (F3)',
                  style: TextStyle(
                    color: const Color(0xFF747373),
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            if (context.watch<ParkingTypeProvider>().availableParkingTypes.length > 1)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isFocused ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: context.watch<ParkingTypeProvider>().availableParkingTypes.map<Widget>((typeId) {
                      final selected = selectedParkingType == typeId.toString();
                      String label;
                      // Prefer labels cached from rates if available
                      final map = context.watch<ParkingTypeProvider>().parkingTypeTextMap;
                      if (map.containsKey(typeId.toString())) {
                        label = map[typeId.toString()]!;
                      } else {
                        final env = PrintData.currentEnv;
                        if (env == 'sogariya') {
                          if (typeId.toString() == '1') {
                            label = 'Drop & Go';
                          } else if (typeId.toString() == '2') {
                            label = 'Long Parking';
                          } else {
                            label = 'Type ' + typeId.toString();
                          }
                        } else {
                          if (typeId.toString() == '1') {
                            label = 'General Parking';
                          } else if (typeId.toString() == '2') {
                            label = 'Premium Parking';
                          } else {
                            label = 'Type ' + typeId.toString();
                          }
                        }
                      }
                      return GestureDetector(
                        onTap: () {
                          context.read<ParkingTypeProvider>().setParkingType(typeId.toString());
                        },
                        child: ParkingTypeChip(
                          isSelected: selected,
                          text: label,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HelmetSection extends StatelessWidget {
  final FocusNode focusNode;

  const HelmetSection({
    super.key,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasHelmet = context.watch<HelmetProvider>().hasHelmet;
    final isFocused = FocusScope.of(context).focusedChild == focusNode;

    return Focus(
      focusNode: focusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Helmet (F5)',
                  style: TextStyle(
                    color: const Color(0xFF747373),
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFocused ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        context.read<HelmetProvider>().setHelmetStatus(true);
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: hasHelmet ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Text(
                            'Yes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        context.read<HelmetProvider>().setHelmetStatus(false);
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: hasHelmet ? Colors.grey : Colors.red,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Text(
                            'No',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlatePainter extends CustomPainter {
  final dynamic plates;
  
  PlatePainter({required this.plates});

  @override
  void paint(Canvas canvas, Size size) {
    if (plates == null) return;

    var paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (var plate in plates) {
      // Original frame size from camera
      final frameWidth = plate['frameWidth']?.toDouble() ?? size.width;
      final frameHeight = plate['frameHeight']?.toDouble() ?? size.height;

      // Scale to fit height
      final scale = size.height / frameHeight;

      final scaledFrameWidth = frameWidth * scale;
      final offsetX = (size.width - scaledFrameWidth) / 2;
      final offsetY = 0.0;

      // Plate coordinates
      final x1 = plate['x1']?.toDouble() ?? 0;
      final y1 = plate['y1']?.toDouble() ?? 0;
      final x2 = plate['x2']?.toDouble() ?? 0;
      final y2 = plate['y2']?.toDouble() ?? 0;

      // Apply scale and offset
      final drawX1 = x1 * scale + offsetX;
      final drawY1 = y1 * scale + offsetY;
      final drawX2 = x2 * scale + offsetX;
      final drawY2 = y2 * scale + offsetY;

      final title = plate['number']?.toString() ?? '';

      // Draw label
      final span = TextSpan(
        style: TextStyle(color: Colors.green, fontSize: 20),
        text: title
      );
      final tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr
      );
      tp.layout();
      tp.paint(canvas, Offset(drawX1 + 10, drawY1 - 30));

      // Draw rectangle
      final rect = Rect.fromPoints(
        Offset(drawX1, drawY1),
        Offset(drawX2, drawY2)
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _BuildPlateOverlay extends StatefulWidget {
  final dynamic plates;

  const _BuildPlateOverlay({Key? key, required this.plates}) : super(key: key);

  @override
  State<_BuildPlateOverlay> createState() => _BuildPlateOverlayState();
}

class _BuildPlateOverlayState extends State<_BuildPlateOverlay> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PlatePainter(plates: widget.plates),
      child: Container(),
    );
  }
}
