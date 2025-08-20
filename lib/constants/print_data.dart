import 'package:kota_pf1_app/helpers/pref_helper.dart';

class PrintData {
  static const String envPrefKey = 'env';
  static String _env = 'ggc';

  static const Map<String, Map<String, String>> _datasets = {
    'ggc': {
      'baseUrl': 'https://ggc.akwebs.in/',
      'appName': 'GGC Parking',
      'appLogo': 'assets/images/ggc-logo.png',
      'appLogoWhite': 'assets/images/ggc-logo_w.png',
      'vehicleNo': 'RJ25',
      'orgName': 'R S Construction',
      'parkingName': 'GGC Station Parking',
      'gstNo': '08BQCPM3088F1ZR',
      'railwayHelpLine': 'Railway Help Line: 900 108 1777',
      'checkIn': 'Check-In',
      'checkOut': 'Check-Out',
      'vehicleType': 'Vehicle Type',
      'tokenNo': 'Token No',
      'helmet': 'Helmet',
      'totalAmount': 'Total Amount',
      'receiptLost': 'Receipt Lost Rs-150 Charge Extra\nNo Responsibility Of Lossing The Parts & Article & Goods Etc..',
      'thankYou': 'Thank You!',
      'parkingRates': 'Parking Rates:',
    },
    'sogariya': {
      'baseUrl': 'https://park.akwebs.in/',
      'appName': 'Sogariya Parking',
      'appLogo': 'assets/images/sog-logo.png',
      'appLogoWhite': 'assets/images/sog-logo_w.png',
      'vehicleNo': 'RJ20',
      'orgName': 'SHREE RADHARANI ENTERPRISES',
      'parkingName': 'Sogariya Station Parking',
      'gstNo': '08BRJPP4424Q2Z1',
      'railwayHelpLine': 'Railway Help Line: 900 108 1777',
      'checkIn': 'Check-In',
      'checkOut': 'Check-Out',
      'vehicleType': 'Vehicle Type',
      'tokenNo': 'Token No',
      'helmet': 'Helmet',
      'totalAmount': 'Total Amount',
      'receiptLost': 'Receipt Lost Rs-150 Charge Extra\nNo Responsibility Of Lossing The Parts & Article & Goods Etc..',
      'thankYou': 'Thank You!',
      'parkingRates': 'Parking Rates:',
    },
    'pf1': {
      'baseUrl': 'https://kota.akwebs.in/',
      'appName': 'Kota PF1 Parking',
      'appLogo': 'assets/images/pf1-logo.png',
      'appLogoWhite': 'assets/images/pf1-logo_w.png',
      'vehicleNo': 'RJ20',
      'orgName': 'ANANT CARRIER',
      'parkingName': 'Kota PF1 Station Parking',
      'gstNo': '08AHTPK3181E273',
      'railwayHelpLine': 'Railway Help Line: 900 108 1777',
      'checkIn': 'Check-In',
      'checkOut': 'Check-Out',
      'vehicleType': 'Vehicle Type',
      'tokenNo': 'Token No',
      'helmet': 'Helmet',
      'totalAmount': 'Total Amount',
      'receiptLost': 'Receipt Lost Rs-150 Charge Extra\nNo Responsibility Of Lossing The Parts & Article & Goods Etc..',
      'thankYou': 'Thank You!',
      'parkingRates': 'Parking Rates:',
    },
    'pf4': {
      'baseUrl': 'https://kota.akwebs.in/',
      'appName': 'Kota PF4 Parking',
      'appLogo': 'assets/images/pf4-logo.png',
      'appLogoWhite': 'assets/images/pf4-logo_w.png',
      'vehicleNo': 'RJ20',
      'orgName': 'ANANT MARKETING & CARGO (PF4)',
      'parkingName': 'Kota PF4 Station Parking',
      'gstNo': '08AMIPK7206Q2ZG',
      'railwayHelpLine': 'Railway Help Line: 900 108 1777',
      'checkIn': 'Check-In',
      'checkOut': 'Check-Out',
      'vehicleType': 'Vehicle Type',
      'tokenNo': 'Token No',
      'helmet': 'Helmet',
      'totalAmount': 'Total Amount',
      'receiptLost': 'Receipt Lost Rs-150 Charge Extra\nNo Responsibility Of Lossing The Parts & Article & Goods Etc..',
      'thankYou': 'Thank You!',
      'parkingRates': 'Parking Rates:',
    },
  };

  static Future<void> init() async {
    final savedEnv = await PrefHelper.getString(envPrefKey);
    if (savedEnv.isNotEmpty && _datasets.containsKey(savedEnv)) {
      _env = savedEnv;
    }
  }

  static Future<void> setEnv(String env) async {
    if (_datasets.containsKey(env)) {
      _env = env;
      await PrefHelper.setString(envPrefKey, env);
    }
  }

  static String get currentEnv => _env;
  static List<String> get availableEnvs => _datasets.keys.toList(growable: false);

  static String _v(String key) => _datasets[_env]![key] ?? '';

  static String get baseUrl => _v('baseUrl');
  static String get appName => _v('appName');
  static String get appLogo => _v('appLogo');
  static String get appLogoWhite => _v('appLogoWhite');
  static String get vehicleNo => _v('vehicleNo');
  static String get orgName => _v('orgName');
  static String get parkingName => _v('parkingName');
  static String get gstNo => _v('gstNo');
  static String get railwayHelpLine => _v('railwayHelpLine');
  static String get checkIn => _v('checkIn');
  static String get checkOut => _v('checkOut');
  static String get vehicleType => _v('vehicleType');
  static String get tokenNo => _v('tokenNo');
  static String get helmet => _v('helmet');
  static String get totalAmount => _v('totalAmount');
  static String get receiptLost => _v('receiptLost');
  static String get thankYou => _v('thankYou');
  static String get parkingRates => _v('parkingRates');
}