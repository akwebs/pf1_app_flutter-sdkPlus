import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/controllers/loader_controller.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/bluetooth_printer_helper.dart';
import 'package:kota_pf1_app/helpers/image_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/route_helper.dart';
import 'package:kota_pf1_app/helpers/date_time_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';
import 'package:kota_pf1_app/pages/check_in/widgets/doc_btn.dart';
import 'package:kota_pf1_app/providers/checkin_provider.dart';
import 'package:alprsdk_plugin/alprsdk_plugin.dart';
import 'package:alprsdk_plugin/alprdetection_interface.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/pages/login/login_page.dart';
import 'package:kota_pf1_app/helpers/print_templates.dart';
import 'package:kota_pf1_app/helpers/connectivity_helper.dart';
import 'package:kota_pf1_app/helpers/pricing_calculator.dart';

class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> implements AlprDetectionInterface {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? scanResult;
  QRViewController? controller;
  bool isProcessing = false;
  final TextEditingController vehicleNumberController = TextEditingController();
  final apiClient = ApiClient.create();
  final CancelToken _cancelToken = CancelToken();
  final loaderController = LoaderController(loading: false);
  Map printData = {};
  final AlprsdkPlugin _alprsdkPlugin = AlprsdkPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _alprpluginState = -1;
  bool _isInitializing = false;
  bool _isRecognizing = false;
  DateTime? _lastRecognitionTime;
  String? _lastRecognizedPlate;
  bool _isStreamPaused = false;
  dynamic _detectedPlates;
  AlprDetectionViewController? _alprViewController;
  bool _showAlprView = false;
  bool _cameraLoading = false;

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

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    
    // Disable flash in start
    // controller.toggleFlash();

    // Set scan interval to be more frequent
    controller.scannedDataStream.listen((scanData) {
      if (!mounted || isProcessing) return;
      
      if (scanData.code != null && scanData.code.toString().isNotEmpty) {
      setState(() {
          isProcessing = true;
        scanResult = scanData;
          String scannedValue = scanData.code.toString().toUpperCase();
          vehicleNumberController.text = scannedValue;
        });
        
        // Add haptic feedback
        HapticFeedback.mediumImpact();
        
        // Play beep sound
        _audioPlayer.play(AssetSource('sounds/beep.mp3'));
        
        // Process the scan
        handleScan().then((_) {
          if (mounted) {
            setState(() {
              isProcessing = false;
            });
          }
        });
      }
    });
  }

  Future<void> _initializeAlprSdk() async {
    if (_isInitializing) return;
    _isInitializing = true;
    
    try {
      // Activate SDK with license key
      final activationResult = await _alprsdkPlugin.setActivation(
        "ewAyoIlsDIN24AW/1Ugr9rGv+qkGjsnzV2EPW5OPBySzdKkWhRScPdeCjS4oGynZPI2EgPjA6ump"
        "An5iKnCHBXXjHux1yaBau6M8fSjavrdUr/GKgiJ7w7x05B6P9eQk6BJjjdtA59jjgPzR0EkaWpM6"
        "AFoSoi4V86e1MmCne3dc3lPzMelD7tx+xpdqHdDf0zc6O3xSxEQiu7uU8Aj499FyGu1B+M22kAtU"
        "2klrker81f3DJD+LxRLjSXAE1NDSc6erJwwwVMyJyBoCalTGHpI4ZDND6r/lVpRyJP/ghtwI6sqv"
        "NykLwz+wdj3T2vFnZ9Z/X/9yt6SfZIPVjK0hUA==");
      
      if (mounted) {
        setState(() {
          _alprpluginState = activationResult ?? -1;
        });
      }

      if (_alprpluginState != 0) {
        print("ALPR SDK activation failed with state: $_alprpluginState");
        if (mounted) {
          ToastHelper.openErrorToast(context, 'ALPR SDK activation failed. Please restart the app.');
        }
        return;
      }

      // Initialize SDK after successful activation
      final initResult = await _alprsdkPlugin.init();
      if (mounted) {
        setState(() {
          _alprpluginState = initResult ?? -1;
        });
      }

      if (_alprpluginState != 0) {
        print("ALPR SDK initialization failed with state: $_alprpluginState");
        if (mounted) {
          ToastHelper.openErrorToast(context, 'ALPR SDK initialization failed. Please restart the app.');
        }
      }
    } catch (e) {
      print("ALPR SDK initialization error: $e");
      if (mounted) {
        ToastHelper.openErrorToast(context, 'ALPR SDK initialization error. Please restart the app.');
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _onPlatformViewCreated(int id) async {
    _alprViewController = AlprDetectionViewController(id, this);
    await _alprViewController?.initHandler();
    await _alprViewController?.startCamera(0); // 0 for back camera
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
          
          bool isValidFormat = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(plateNumber) || 
                             RegExp(r'^\d{2}[A-Z]{2}\d{4}[A-Z]$').hasMatch(plateNumber);
          
          if (isValidFormat && plateNumber != _lastRecognizedPlate) {
            if (mounted) {
              setState(() {
                vehicleNumberController.text = plateNumber;
                _lastRecognizedPlate = plateNumber;
                _isStreamPaused = true;
              });
              await _playBeepSound();
              ToastHelper.nativeToastSuccess(msg: 'Plate recognized: $plateNumber');
              
              // Stop the camera stream
              await _alprViewController?.stopCamera();
              setState(() {
                _showAlprView = false;
              });
              
              // Process the scan and handle checkout
              await handleCheckOutClick();
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

  // Add this method to handle vehicle number input changes
  void _onVehicleNumberChanged(String value) {
    if (value.length == 9 || value.length == 10) {
      // Check if the input matches either format
      bool isValidFormat = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(value) || 
                          RegExp(r'^\d{2}[A-Z]{2}\d{4}[A-Z]$').hasMatch(value);
      
      if (isValidFormat) {
        // Trigger checkout process
        handleCheckOutClick();
      }
    }
  }

  // Add this method to build the plate overlay
  Widget _buildPlateOverlay() {
    if (_detectedPlates == null) return Container();

    return CustomPaint(
      painter: PlatePainter(plates: _detectedPlates),
      child: Container(),
    );
  }

  // Header similar to Check-In UI
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
            Icons.refresh,
            () {
              if (!loaderController.loading) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckOutPage(),
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

  // Camera section styled like Check-In UI but uses existing QR/ALPR toggle
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
                  'Scanner',
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
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          if (!_showAlprView)
                            QRView(
                              key: qrKey,
                              onQRViewCreated: _onQRViewCreated,
                              overlay: QrScannerOverlayShape(
                                borderColor: Colors.white,
                                borderRadius: 10,
                                borderLength: 30,
                                borderWidth: 10,
                                cutOutSize: MediaQuery.of(context).size.width * 0.6,
                                overlayColor: Color(0x88000000),
                              ),
                            )
                          else
                            Stack(
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
                                  ),
                                ),
                              ],
                            ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _switchCameraMode,
                                  icon: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    controller?.toggleFlash();
                                    if (mounted) setState(() {});
                                  },
                                  icon: Icon(
                                    Icons.flash_on,
                                    color: Colors.white,
                                    size: 36,
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

  // Vehicle number input card styled like Check-In
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
              vehicleNumberController: vehicleNumberController,
            ),
          ],
        ),
      ),
    );
  }

  // Action buttons styled like Check-In
  Widget _buildActionButtonsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () async {
                  if (!loaderController.loading) {
                    await handleCheckOutClick();
                    await _resetAndReinitializePage();
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
                          'Exit & Print',
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
                      builder: (context) => CheckOutPage(),
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCameraSection(),
                    const SizedBox(height: 5),
                    _buildVehicleInputCard(),
                    const SizedBox(height: 5),
                    // Keep document section styled separately
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insert_drive_file, color: ConstColors.themeColor, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Documents',
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
                            DocSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildActionButtonsSection(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelToken.cancel(StrConstants.dioDisposal);
    controller?.dispose();
    _alprViewController?.stopCamera();
    vehicleNumberController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  resetAll() {
    context.read<CheckInProvider>().resetImages();
    vehicleNumberController.text = PrintData.vehicleNo;
    setState(() {
      vehicleNumberController.text = PrintData.vehicleNo;
      isProcessing = false;
      controller?.resumeCamera();
    });
  }

  handleScan() async {
    if (vehicleNumberController.text.isEmpty) {
      ToastHelper.openErrorToast(context, 'Please enter vehicle number');
      return;
    }

    if (!mounted) return;
    setState(() {
      loaderController.showLoading();
    });

    try {
      final all = LocalDb.getHistory();
      final q = vehicleNumberController.text.trim().toUpperCase();
      final match = all.firstWhere(
        (e) => (e['vehicle_no'] ?? '').toString().toUpperCase() == q && (e['status']?.toString() ?? '1') == '1',
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        setState(() {
          vehicleNumberController.text = q;
        });
        ToastHelper.nativeToastSuccess(msg: 'Vehicle found');
        await handleCheckOutClick();
      } else {
        // Fallback to API scan if local not found
        try {
          final res = await apiClient.post(
              path: 'scan',
              data: {
                "admin_id": await PrefHelper.getUserData('admin_id'),
                "pass_no": q,
              },
              cancelToken: _cancelToken);
          if (res.data['status'].toString() == '200') {
            setState(() {
              vehicleNumberController.text = res.data['vehicle_no'].toString().toUpperCase();
            });
            ToastHelper.nativeToastSuccess(msg: 'Vehicle found (server)');
            await handleCheckOutClick();
          } else {
            setState(() {
              vehicleNumberController.text = "";
            });
            ToastHelper.openErrorToast(context, 'Not found or already checked out');
          }
        } catch (_) {
          setState(() {
            vehicleNumberController.text = "";
          });
          ToastHelper.openErrorToast(context, 'Not found or already checked out');
        }
      }
    } catch (err) {
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

  Future<bool> _showPrintPreviewDialog(BuildContext context, Map<String, dynamic> data, String customerType) async {
    return await PrintTemplates.showPreviewDialog(context, data, isCheckIn: false);
  }

  handlePrinting() async {
    if (!mounted) return;
    final gst = await PrefHelper.getUserData('gst');
    String customerType = "-";

    if (printData['type'].toString() == '1') {
      customerType = 'VIP';
    } else if (printData['type'].toString() == '2') {
      customerType = 'Employee';
    } else if (printData['type'].toString() == '3') {
      customerType = 'General';
    }

    if (!mounted) return;
    final built = await PrintTemplates.buildPrintData(Map<String, dynamic>.from(printData), isCheckIn: false);
    await BluetoothPrinterHelper.checkAndPrint(context, built);
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
      context.read<CheckInProvider>().resetImages();
      setState(() {
        vehicleNumberController.clear();
        isProcessing = false;
        _lastRecognizedPlate = null;
        _isStreamPaused = false;
        _detectedPlates = null;
      });
      
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

  handleCheckOutClick() async {
    if (vehicleNumberController.text.isEmpty) {
      ToastHelper.openErrorToast(context, 'Please enter vehicle number');
      return;
    }

    if (!mounted) return;
    setState(() {
      loaderController.showLoading();
    });

    final vehicleImage = context.read<CheckInProvider>().vehicleImage;
    final licenseImage = context.read<CheckInProvider>().licenseImage;
    final vehicleNumber = vehicleNumberController.text.trim().toUpperCase();

    String vehicleImageName = "";
    String licenseImageName = "";

    if (vehicleImage.isNotEmpty) {
      final vehicleImageData = context.read<CheckInProvider>().vehicleImageData;
      try {
        vehicleImageName = await ImageHelper.uploadImage(vehicleImageData);
      } catch (err) {
        if (mounted) {
          ToastHelper.nativeToastErr(msg: 'Unable to upload vehicle image');
        }
        debugPrint(err.toString());
      }
    }

    if (licenseImage.isNotEmpty) {
      final licenseImageData = context.read<CheckInProvider>().licenseImageData;
      try {
        licenseImageName = await ImageHelper.uploadImage(licenseImageData);
      } catch (err) {
        if (mounted) {
          ToastHelper.nativeToastErr(msg: 'Unable to upload license image');
        }
        debugPrint(err.toString());
      }
    }

          try {
      print("Making checkout request with vehicle number: $vehicleNumber");
      final payload = {
        "admin_id": await PrefHelper.getUserData('admin_id'),
        "user_id": await PrefHelper.getUserData('id'),
        "pass_no": vehicleNumber,
        "vehicle_image": vehicleImageName,
        "license_image": licenseImageName,
      };
      final online = await ConnectivityHelper.isOnline();
      dynamic res;
      if (online) {
        res = await apiClient.post(path: 'chekout', data: payload, cancelToken: _cancelToken);
      } else {
        // compute local extra amount
        final localMatch = LocalDb.getHistory().firstWhere(
          (e) => (e['vehicle_no'] ?? '').toString().toUpperCase() == vehicleNumber.toUpperCase() && (e['status']?.toString() ?? '1') == '1',
          orElse: () => {},
        );
        if (localMatch.isEmpty) {
          throw Exception('Vehicle not found locally for offline checkout');
        }
        final checkinIso = localMatch['checked_in']?.toString() ?? DateTime.now().toIso8601String();
        final checkinDt = DateTime.tryParse(checkinIso) ?? DateTime.now();
        final vehicleTypeText = (localMatch['vehicle_type'] ?? '').toString();
        final parkingTypeId = int.tryParse((localMatch['parking_type'] ?? '1').toString()) ?? 1;
        final pr = PricingCalculator.calculate(
          checkinTime: checkinDt,
          vehicleTypeText: vehicleTypeText,
          parkingType: parkingTypeId,
        );
        final checkoutStr = DateTimeHelper.toAmPm(DateTime.now().toIso8601String());
        // enqueue op
        final opId = 'OFF-OUT-${DateTime.now().millisecondsSinceEpoch}';
        await LocalDb.enqueuePendingOp({ 'id': opId, 'type': 'checkout', 'payload': payload });
        // update local history
        await LocalDb.updateHistoryOnCheckout(vehicleNumber, {
          'checked_out': checkoutStr,
          'status': 2,
          'extra_amount': pr.extraAmountString,
        });
        res = { 'data': {
          'status': '200',
          'vehicle_no': vehicleNumber,
          'checkout_time': checkoutStr,
          'extra_amount': pr.extraAmountString,
          'type': localMatch['type']?.toString() ?? '3',
        }};
      }

      if (!mounted) return;
      
      setState(() {
        loaderController.hideLoading();
      });

      if (res.data['status'].toString() == '200') {
        setState(() {
          printData = res.data;
        });
        
        ToastHelper.nativeToastSuccess(msg: 'Check out successful');

        // Update local history for this vehicle
        try {
          await LocalDb.updateHistoryOnCheckout(
            res.data['vehicle_no']?.toString() ?? vehicleNumber,
            {
              'checked_out': res.data['checkout_time'] ?? '',
              'status': 2,
              'extra_amount': res.data['extra_amount'] ?? '',
            },
          );
        } catch (_) {}
        
        final gst = await PrefHelper.getUserData('gst');
        String customerType = "-";

        if (res.data['type'].toString() == '1') {
          customerType = 'VIP';
        } else if (res.data['type'].toString() == '2') {
          customerType = 'Employee';
        } else if (res.data['type'].toString() == '3') {
          customerType = 'General';
        }

        if (!mounted) return;

        // Ensure we're not in a loading state before showing dialog
        if (loaderController.loading) {
          setState(() {
            loaderController.hideLoading();
          });
        }
        
        // Show preview first
        final shouldPrint = await _showPrintPreviewDialog(context, res.data, customerType);
        
        // Only proceed with printing if preview was closed with Okay button
        if (shouldPrint && mounted) {
          try {
            // Print after preview is completely closed
            final printData = await PrintTemplates.buildPrintData(res.data, isCheckIn: false);
            await BluetoothPrinterHelper.checkAndPrint(context, printData);
            
            // Reset everything after printing is complete
            if (mounted) {
              await _resetAndReinitializePage();
            }
          } catch (e) {
            print("Error during printing: $e");
            if (mounted) {
              ToastHelper.openErrorToast(context, 'Error during printing. Please try again.');
              await _resetAndReinitializePage();
            }
          }
        } else {
          // If user didn't want to print, still reset the page
          if (mounted) {
            await _resetAndReinitializePage();
          }
        }
      } else {
        final msg = (res.data['msg'] ?? '').toString();
        if (msg.toLowerCase().contains('suspended')) {
          await PrefHelper.clearAll();
          if (mounted) RouteHelper.replace(context, () => const LoginPage());
      } else {
        ToastHelper.openErrorToast(context, 'Error, ${res.data['msg']}');
        }
      }
    } on DioException catch (err) {
      if (mounted) {
        setState(() {
          loaderController.hideLoading();
        });
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
        setState(() {
          loaderController.hideLoading();
        });
        ToastHelper.openErrorToast(context, StrConstants.connectionError);
      }
    }
  }

  Future<void> _switchCameraMode() async {
    try {
      setState(() {
        _showAlprView = !_showAlprView;
      });

      if (_showAlprView) {
        // Switching to ALPR mode
        await controller?.pauseCamera();
        if (_alprpluginState != 0) {
          await _initializeAlprSdk();
        }
      } else {
        // Switching to QR mode
        await _alprViewController?.stopCamera();
        await controller?.resumeCamera();
      }
    } catch (e) {
      print("Error switching camera mode: $e");
      if (mounted) {
        ToastHelper.openErrorToast(context, 'Error switching camera mode. Please try again.');
        // Revert the state if there's an error
                  setState(() {
          _showAlprView = !_showAlprView;
                  });
                }
    }
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
              image: AssetImage(PrintData.appLogo),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class CheckOutBtn extends StatelessWidget {
  final bool isLoading;
  final String text;
  const CheckOutBtn({super.key, required this.isLoading, required this.text});

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
                    text,
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

class VehicleNumberInput extends StatefulWidget {
  final TextEditingController vehicleNumberController;
  // final Function() onCheckOut;
  const VehicleNumberInput({
    super.key, 
    required this.vehicleNumberController,
    // required this.onCheckOut,
  });

  @override
  State<VehicleNumberInput> createState() => _VehicleNumberInputState();
}

class _VehicleNumberInputState extends State<VehicleNumberInput> {
  @override
  void initState() {
    super.initState();
    widget.vehicleNumberController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.vehicleNumberController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.vehicleNumberController.text;
    if (text.length == 9 || text.length == 10) {
      // Check if the input matches either format
      bool isValidFormat = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(text) || 
                          RegExp(r'^\d{2}[A-Z]{2}\d{4}[A-Z]$').hasMatch(text);
      
      if (isValidFormat) {
        // Trigger checkout process
        // widget.onCheckOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13),
        width: double.infinity,
        height: 70,
        decoration: ShapeDecoration(
          color: const Color(0xFFEBEBEB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
                  'Vehicle Number',
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
                    controller: widget.vehicleNumberController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (value) {
                      if (value.length == 9 || value.length == 10) {
                        // Check if the input matches either format
                        bool isValidFormat = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(value) || 
                                          RegExp(r'^\d{2}[A-Z]{2}\d{4}[A-Z]$').hasMatch(value);
                        
                        if (isValidFormat) {
                          // Trigger checkout process
                          // widget.onCheckOut();
                        }
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

// class QrSection extends StatelessWidget {
//   const QrSection({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 20),
//       width: double.infinity,
//       height: 236,
//       decoration: BoxDecoration(color: Colors.black),
//     );
//   }
// }

