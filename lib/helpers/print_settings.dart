import 'package:kota_pf1_app/helpers/pref_helper.dart';

class PrintSettings {
  final bool includeOrgName;
  final bool includeGstOnCheckout;
  final bool includeCheckInTime;
  final bool includeCheckoutTime;
  final bool includeVehicleNo;
  final bool includeParkingType;
  final bool includeVehicleType;
  final bool includeTokenNo;
  final bool includeHelmet;
  final bool includeParkingRates;
  final bool includeReceiptLost;
  final bool includeThankYou;
  final bool includeRailwayHelpLine;
  final bool includeQrOnCheckIn;
  final int extraFeedCheckIn; // number of extra newlines after print

  const PrintSettings({
    required this.includeOrgName,
    required this.includeGstOnCheckout,
    required this.includeCheckInTime,
    required this.includeCheckoutTime,
    required this.includeVehicleNo,
    required this.includeParkingType,
    required this.includeVehicleType,
    required this.includeTokenNo,
    required this.includeHelmet,
    required this.includeParkingRates,
    required this.includeReceiptLost,
    required this.includeThankYou,
    required this.includeRailwayHelpLine,
    required this.includeQrOnCheckIn,
    required this.extraFeedCheckIn,
  });

  static const _kPrefix = 'print_';

  static Future<PrintSettings> load() async {
    final hasSaved = await PrefHelper.getBool('${_kPrefix}sav');
    if (!hasSaved) {
      // Defaults (print everything)
      return const PrintSettings(
        includeOrgName: true,
        includeGstOnCheckout: true,
        includeCheckInTime: true,
        includeCheckoutTime: true,
        includeVehicleNo: true,
        includeParkingType: true,
        includeVehicleType: true,
        includeTokenNo: true,
        includeHelmet: true,
        includeParkingRates: true,
        includeReceiptLost: true,
        includeThankYou: true,
        includeRailwayHelpLine: true,
        includeQrOnCheckIn: true,
        extraFeedCheckIn: 3,
      );
    }

    final includeOrgName = await PrefHelper.getBool('${_kPrefix}includeOrgName');
    final includeGstOnCheckout = await PrefHelper.getBool('${_kPrefix}includeGstOnCheckout');
    final includeCheckInTime = await PrefHelper.getBool('${_kPrefix}includeCheckInTime');
    final includeCheckoutTime = await PrefHelper.getBool('${_kPrefix}includeCheckoutTime');
    final includeVehicleNo = await PrefHelper.getBool('${_kPrefix}includeVehicleNo');
    final includeParkingType = await PrefHelper.getBool('${_kPrefix}includeParkingType');
    final includeVehicleType = await PrefHelper.getBool('${_kPrefix}includeVehicleType');
    final includeTokenNo = await PrefHelper.getBool('${_kPrefix}includeTokenNo');
    final includeHelmet = await PrefHelper.getBool('${_kPrefix}includeHelmet');
    final includeParkingRates = await PrefHelper.getBool('${_kPrefix}includeParkingRates');
    final includeReceiptLost = await PrefHelper.getBool('${_kPrefix}includeReceiptLost');
    final includeThankYou = await PrefHelper.getBool('${_kPrefix}includeThankYou');
    final includeRailwayHelpLine = await PrefHelper.getBool('${_kPrefix}includeRailwayHelpLine');
    final includeQrOnCheckIn = await PrefHelper.getBool('${_kPrefix}includeQrOnCheckIn');
    final extraFeedCheckIn = await PrefHelper.getInt('${_kPrefix}extraFeedCheckIn');

    return PrintSettings(
      includeOrgName: includeOrgName,
      includeGstOnCheckout: includeGstOnCheckout,
      includeCheckInTime: includeCheckInTime,
      includeCheckoutTime: includeCheckoutTime,
      includeVehicleNo: includeVehicleNo,
      includeParkingType: includeParkingType,
      includeVehicleType: includeVehicleType,
      includeTokenNo: includeTokenNo,
      includeHelmet: includeHelmet,
      includeParkingRates: includeParkingRates,
      includeReceiptLost: includeReceiptLost,
      includeThankYou: includeThankYou,
      includeRailwayHelpLine: includeRailwayHelpLine,
      includeQrOnCheckIn: includeQrOnCheckIn,
      extraFeedCheckIn: extraFeedCheckIn == 0 ? 3 : extraFeedCheckIn,
    );
  }

  Future<void> save() async {
    await PrefHelper.setBool('${_kPrefix}includeOrgName', includeOrgName);
    await PrefHelper.setBool('${_kPrefix}includeGstOnCheckout', includeGstOnCheckout);
    await PrefHelper.setBool('${_kPrefix}includeCheckInTime', includeCheckInTime);
    await PrefHelper.setBool('${_kPrefix}includeCheckoutTime', includeCheckoutTime);
    await PrefHelper.setBool('${_kPrefix}includeVehicleNo', includeVehicleNo);
    await PrefHelper.setBool('${_kPrefix}includeParkingType', includeParkingType);
    await PrefHelper.setBool('${_kPrefix}includeVehicleType', includeVehicleType);
    await PrefHelper.setBool('${_kPrefix}includeTokenNo', includeTokenNo);
    await PrefHelper.setBool('${_kPrefix}includeHelmet', includeHelmet);
    await PrefHelper.setBool('${_kPrefix}includeParkingRates', includeParkingRates);
    await PrefHelper.setBool('${_kPrefix}includeReceiptLost', includeReceiptLost);
    await PrefHelper.setBool('${_kPrefix}includeThankYou', includeThankYou);
    await PrefHelper.setBool('${_kPrefix}includeRailwayHelpLine', includeRailwayHelpLine);
    await PrefHelper.setBool('${_kPrefix}includeQrOnCheckIn', includeQrOnCheckIn);
    await PrefHelper.setInt('${_kPrefix}extraFeedCheckIn', extraFeedCheckIn);
    // mark saved
    await PrefHelper.setBool('${_kPrefix}sav', true);
  }

  PrintSettings copyWith({
    bool? includeOrgName,
    bool? includeGstOnCheckout,
    bool? includeCheckInTime,
    bool? includeCheckoutTime,
    bool? includeVehicleNo,
    bool? includeParkingType,
    bool? includeVehicleType,
    bool? includeTokenNo,
    bool? includeHelmet,
    bool? includeParkingRates,
    bool? includeReceiptLost,
    bool? includeThankYou,
    bool? includeRailwayHelpLine,
    bool? includeQrOnCheckIn,
    int? extraFeedCheckIn,
  }) {
    return PrintSettings(
      includeOrgName: includeOrgName ?? this.includeOrgName,
      includeGstOnCheckout: includeGstOnCheckout ?? this.includeGstOnCheckout,
      includeCheckInTime: includeCheckInTime ?? this.includeCheckInTime,
      includeCheckoutTime: includeCheckoutTime ?? this.includeCheckoutTime,
      includeVehicleNo: includeVehicleNo ?? this.includeVehicleNo,
      includeParkingType: includeParkingType ?? this.includeParkingType,
      includeVehicleType: includeVehicleType ?? this.includeVehicleType,
      includeTokenNo: includeTokenNo ?? this.includeTokenNo,
      includeHelmet: includeHelmet ?? this.includeHelmet,
      includeParkingRates: includeParkingRates ?? this.includeParkingRates,
      includeReceiptLost: includeReceiptLost ?? this.includeReceiptLost,
      includeThankYou: includeThankYou ?? this.includeThankYou,
      includeRailwayHelpLine: includeRailwayHelpLine ?? this.includeRailwayHelpLine,
      includeQrOnCheckIn: includeQrOnCheckIn ?? this.includeQrOnCheckIn,
      extraFeedCheckIn: extraFeedCheckIn ?? this.extraFeedCheckIn,
    );
  }
} 