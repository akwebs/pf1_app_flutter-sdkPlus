import 'package:kota_pf1_app/constants/print_data.dart';
class ApiConstants {
  static String get baseUrl => PrintData.baseUrl;
  static String get apiBaseUrl => "${baseUrl}api/";
  static const apiKey = "d29985af97d29a80e40cd81016d939af";
  static const String parkingCostListEndpoint =
      "parking_cost_list"; // Added endpoint
}
