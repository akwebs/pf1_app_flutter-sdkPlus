import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/controllers/loader_controller.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/route_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';
import 'package:kota_pf1_app/pages/home/home_page.dart';
import 'package:kota_pf1_app/widgets/custom_textbox.dart';
import 'package:kota_pf1_app/widgets/submit_button.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kota_pf1_app/helpers/sync_service.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  TextEditingController mobileController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _appVersion = '';
  final FocusNode _mobileFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  int _secretTapCount = 0;
  DateTime? _lastSecretTapAt;
  late final AnimationController _bgAnimController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat(reverse: true);
  late final Animation<double> _bgAnim = CurvedAnimation(
    parent: _bgAnimController,
    curve: Curves.easeInOut,
  );
  double _syncProgress = 0.0;
  String _syncMessage = '';
  late final AnimationController _syncAnim;
  late final Animation<double> _syncPulse;

  final apiClient = ApiClient.create();
  final CancelToken _cancelToken = CancelToken();
  final loaderController = LoaderController(loading: false);

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _bgAnimController.addListener(() {
      if (mounted) setState(() {});
    });
    _syncAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _syncPulse = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _syncAnim, curve: Curves.easeInOut));
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
      });
    } catch (_) {
      // ignore version errors silently
    }
  }

  handleLoginClick() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (mobileController.text.isEmpty) {
      ToastHelper.openErrorToast(context, 'Please enter mobile number');
    } else if (passwordController.text.isEmpty) {
      ToastHelper.openErrorToast(context, 'Please enter password');
    } else {
      if (mounted) {
        setState(() {
          loaderController.showLoading();
          _syncProgress = 0.0;
          _syncMessage = '';
        });
      }

      try {
        final res = await apiClient.post(
            path: 'login',
            data: {
              "mobile": mobileController.text,
              "pass": passwordController.text,
            },
            cancelToken: _cancelToken);

        if (mounted) {
          if (res.data['status'].toString() == '200') {
            PrefHelper.setUserId(res.data['id'].toString());
            PrefHelper.setUserData(res.data);
            // Sync lookup tables locally before routing to home with progress
            try {
              _syncAnim.repeat(reverse: true);
              await SyncService().syncLookupData(onProgress: (p, msg) {
                if (!mounted) return;
                setState(() {
                  _syncProgress = p;
                  _syncMessage = msg;
                });
              });
            } catch (_) {}
            RouteHelper.replace(context, () => HomePage());
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
      } finally {
        if (mounted) {
          setState(() {
            loaderController.hideLoading();
            _syncAnim.stop();
            _syncAnim.reset();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _cancelToken.cancel(StrConstants.dioDisposal);
    mobileController.dispose();
    passwordController.dispose();
    _mobileFocus.dispose();
    _passwordFocus.dispose();
    _bgAnimController.dispose();
    _syncAnim.dispose();
    super.dispose();
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

  Future<void> _showEnvSwitcher() async {
    final Map<String, String> labels = {
      'ggc': 'GGC',
      'sogariya': 'Sogariya',
      'pf1': 'Kota PF1',
      'pf4': 'Kota PF4',
    };
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(height: 4, width: 44, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              const Text('Select Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final env in PrintData.availableEnvs)
                ListTile(
                  title: Text(labels[env] ?? env),
                  trailing: PrintData.currentEnv == env ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await PrintData.setEnv(env);
                    if (!mounted) return;
                    ToastHelper.openToast(context, 'Switched to ${labels[env] ?? env}');
                    RouteHelper.replace(context, () => const LoginPage());
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _handleSecretTap() {
    final now = DateTime.now();
    if (_lastSecretTapAt == null || now.difference(_lastSecretTapAt!) > const Duration(seconds: 2)) {
      _secretTapCount = 0;
    }
    _lastSecretTapAt = now;
    _secretTapCount++;
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showEnvSwitcher();
    }
  }

  // handleTestPrint() async {
  //   setState(() {
  //     loaderController.showLoading();
  //   });
  //   Uint8List qrCodeBytes = await generateQrCode('MH1234');
  //   if (mounted) {
  //     await BluetoothPrinterHelper.checkAndPrint(
  //       context,
  //       [
  //         PrintTextSize(text: 'PF4 Parking\n', size: 2),
  //         PrintTextSize(text: 'GST: gstin464644554655\n', size: 1),
  //         PrintTextSize(text: 'Check-In: test\n', size: 1),
  //         PrintTextSize(text: 'Vehicle No: test\n', size: 1),
  //         PrintTextSize(text: 'Token No: test\n', size: 1),
  //         PrintTextSize(text: 'Parking Slot: test\n', size: 1),
  //         PrintTextSize(text: 'Vehicle Type: test\n', size: 1),
  //         PrintTextSize(text: 'Customer Type: test\n', size: 1),
  //         qrCodeBytes,
  //         PrintTextSize(text: '\n', size: 1),
  //         PrintTextSize(text: '\n', size: 1),
  //         PrintTextSize(text: '\n', size: 1),
  //         PrintTextSize(text: '\n', size: 1),
  //         // PrintTextSize(text: 'Thank You!', size: 2),
  //       ],
  //     );
  //   }
  //   setState(() {
  //     loaderController.hideLoading();
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ConstColors.themeColor,
              ConstColors.themeColor.withOpacity(0.8),
              ConstColors.themeColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  // Animated background blobs
                  Positioned(
                    top: height * (0.05 + 0.02 * math.sin(_bgAnim.value * math.pi * 2)),
                    left: width * (0.65 + 0.04 * math.cos(_bgAnim.value * math.pi * 2)),
                    child: _AnimatedBlob(
                      size: width * 0.35,
                      color: Colors.white.withOpacity(0.08),
                      animation: _bgAnim,
                    ),
                  ),
                  Positioned(
                    bottom: height * (0.02 + 0.03 * math.cos(_bgAnim.value * math.pi * 2)),
                    right: width * (0.55 + 0.04 * math.sin(_bgAnim.value * math.pi)),
                    child: _AnimatedBlob(
                      size: width * 0.28,
                      color: Colors.white.withOpacity(0.06),
                      animation: _bgAnim,
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 480,
                          minHeight: height * 0.8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo
                            Align(
                              alignment: Alignment.center,
                              child: Image.asset(PrintData.appLogoWhite, height: 88),
                            ),
                            // Glass form
                            _GlassLoginForm(
                              formKey: _formKey,
                              mobileController: mobileController,
                              passwordController: passwordController,
                              mobileFocus: _mobileFocus,
                              passwordFocus: _passwordFocus,
                              obscurePassword: _obscurePassword,
                              toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                              loading: loaderController.loading,
                              onSubmit: handleLoginClick,
                            ),
                            // Footer
                            Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onLongPress: _showEnvSwitcher,
                                  onDoubleTap: _showEnvSwitcher,
                                  onTap: _handleSecretTap,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      Text(
                                        'Version ${_appVersion.isEmpty ? '...' : _appVersion}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Powered by AK Webs, contact 8503810897',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Sync progress overlay at bottom
                  if (_syncProgress > 0 && _syncProgress < 1.0)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: Center(
                          child: ScaleTransition(
                            scale: _syncPulse,
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: _syncProgress.clamp(0.0, 1.0),
                                          strokeWidth: 8,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(ConstColors.themeColor),
                                        ),
                                        Text('${(_syncProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _syncMessage.isEmpty ? 'Syncing in progress...' : _syncMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  final double size;
  final Color color;
  final Animation<double> animation;

  const _AnimatedBlob({required this.size, required this.color, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final transform = Matrix4.identity()
          ..translate(
            size * math.cos(animation.value * math.pi * 2),
            size * math.sin(animation.value * math.pi * 2),
          )
          ..rotateZ(animation.value * math.pi * 2);
        return Transform(
          transform: transform,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _GlassLoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController mobileController;
  final TextEditingController passwordController;
  final FocusNode mobileFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final VoidCallback toggleObscure;
  final bool loading;
  final VoidCallback onSubmit;

  const _GlassLoginForm({
    required this.formKey,
    required this.mobileController,
    required this.passwordController,
    required this.mobileFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.toggleObscure,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.14),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    PrintData.appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Let\'s sign you in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mobile Number Field
                  TextFormField(
                    controller: mobileController,
                    focusNode: mobileFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(passwordFocus),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    maxLength: 10,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      hintText: 'Enter your mobile number',
                      prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                      counterText: '',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white, width: 1.4),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your mobile number';
                      }
                      if (value.length != 10) {
                        return 'Enter 10 digit mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password Field
                  TextFormField(
                    controller: passwordController,
                    focusNode: passwordFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => onSubmit(),
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: toggleObscure,
                      ),
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white, width: 1.4),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ConstColors.themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
