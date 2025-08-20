import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/pages/home/home_page.dart';
import 'package:kota_pf1_app/pages/login/login_page.dart';
import 'package:kota_pf1_app/providers/check_price_provider.dart';
import 'package:kota_pf1_app/providers/checkin_provider.dart';
import 'package:kota_pf1_app/providers/helmet_provider.dart';
import 'package:kota_pf1_app/providers/home_provider.dart';
import 'package:kota_pf1_app/providers/parking_rates_provider.dart';
import 'package:kota_pf1_app/providers/parking_type_provider.dart';
import 'package:kota_pf1_app/providers/pass_type_provider.dart';
import 'package:kota_pf1_app/providers/reprint_provider.dart';
import 'package:kota_pf1_app/providers/slot_provider.dart';
import 'package:kota_pf1_app/providers/vehicle_type_provider.dart';
import 'constants/const_colors.dart';
import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/helpers/sync_service.dart';
import 'package:kota_pf1_app/pages/splash/splash_page.dart';
import 'package:kota_pf1_app/helpers/sync_settings.dart';
import 'package:background_fetch/background_fetch.dart';

class RouteObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.settings.name == '/home') {
      final context = route.navigator?.context;
      if (context != null) {
        context.read<HomeProvider>().loadData(context);
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register headless background task (Android)
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  // Set status bar color for Android 14+ compatibility
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: ConstColors.themeColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  await PrintData.init();
  await LocalDb.init();

  // Configure background fetch based on user setting
  try {
    await SyncService.configureBackgroundFetch();
  } catch (_) {}

  // On cold start, perform a background sync to refresh local lookup data
  try {
    await SyncService().syncLookupData();
  } catch (_) {}

  String userId = await PrefHelper.getUserId();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => HomeProvider()),
      ChangeNotifierProvider(create: (_) => VehicleTypeProvider()),
      ChangeNotifierProvider(create: (_) => SlotProvider()),
      ChangeNotifierProvider(create: (_) => PassTypeProvider()),
      ChangeNotifierProvider(create: (_) => ParkingTypeProvider()),
      ChangeNotifierProvider(create: (_) => CheckInProvider()),
      ChangeNotifierProvider(create: (_) => CheckPriceProvider()),
      ChangeNotifierProvider(create: (_) => ReprintProvider()),
      ChangeNotifierProvider(create: (_) => ParkingRatesProvider()),
      ChangeNotifierProvider(create: (_) => HelmetProvider()),
    ],
    child: ParkingApp(
      isLoggedIn: userId.isNotEmpty ? true : false,
    ),
  ));
}

class ParkingApp extends StatelessWidget {
  final bool isLoggedIn;
  const ParkingApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        color: Colors.transparent,
        debugShowCheckedModeBanner: false,
        navigatorObservers: [RouteObserver()],
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          brightness: Brightness.light,
          textTheme:
              GoogleFonts.poppinsTextTheme(), // Change to your desired font
        ),
        home: SplashPage(isLoggedIn: isLoggedIn));
  }
}
