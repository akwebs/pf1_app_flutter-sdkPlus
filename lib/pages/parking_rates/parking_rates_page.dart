import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/providers/parking_rates_provider.dart';
import 'package:kota_pf1_app/widgets/back_btn.dart';
import 'package:kota_pf1_app/constants/print_data.dart';

class ParkingRatesPage extends StatefulWidget {
  const ParkingRatesPage({super.key});

  @override
  State<ParkingRatesPage> createState() => _ParkingRatesPageState();
}

class _ParkingRatesPageState extends State<ParkingRatesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<ParkingRatesProvider>(context, listen: false);
      // Cache-first
      await provider.ensureCachedRates(context);
      // If still empty, fetch from API
      if (provider.parkingRates.isEmpty && !provider.isLoading) {
        await provider.fetchParkingRates();
      }
      if (mounted) setState(() {});
    });
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
            'Parking Rates',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
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
              child: Consumer<ParkingRatesProvider>(
                builder: (context, ratesProvider, child) {
                  if (ratesProvider.isLoading && ratesProvider.parkingRates.isEmpty) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (ratesProvider.errorMessage != null && ratesProvider.parkingRates.isEmpty) {
                    return Center(child: Text('Error: ${ratesProvider.errorMessage}'));
                  }
                  if (ratesProvider.parkingRates.isEmpty) {
                    return Center(child: Text('No parking rates found.'));
                  }

                  // Helper to group rates for display
                  Map<String, List<ParkingRate>> groupRatesByParkingType(
                      List<ParkingRate> rates) {
                    Map<String, List<ParkingRate>> grouped = {};
                    for (var rate in rates) {
                      if (!grouped.containsKey(rate.parkingTypeText)) {
                        grouped[rate.parkingTypeText] = [];
                      }
                      grouped[rate.parkingTypeText]!.add(rate);
                    }
                    return grouped;
                  }

                  Map<String, List<RateCategory>> buildRateCategories(
                      List<ParkingRate> allRates) {
                    Map<String, List<RateCategory>> categoriesByParkingType = {};

                    // Group by parking_type_text (e.g., 'General Parking', 'Premium Parking')
                    var groupedByParkingType = groupRatesByParkingType(allRates);

                    groupedByParkingType.forEach((parkingType, ratesList) {
                      // Further group by vehicle_type_text (e.g., 'Two-Wheeler', 'Four-Wheeler')
                      Map<String, List<RateItem>> ratesByVehicle = {};
                      for (var rate in ratesList) {
                        if (!ratesByVehicle.containsKey(rate.vehicleTypeText)) {
                          ratesByVehicle[rate.vehicleTypeText] = [];
                        }
                        ratesByVehicle[rate.vehicleTypeText]!.add(
                            RateItem(time: rate.durationText, price: rate.price));
                      }

                      List<RateCategory> currentCategories = [];
                      ratesByVehicle.forEach((vehicleType, rateItems) {
                        currentCategories.add(RateCategory(
                          // Determine icon based on vehicleType - use Material Icons
                          icon: vehicleType.toLowerCase().contains('two')
                              ? Icons.motorcycle // Two-Wheeler
                              : Icons.directions_car, // Four-Wheeler/Other
                          title: vehicleType,
                          rates: rateItems,
                        ));
                      });
                      categoriesByParkingType[parkingType] = currentCategories;
                    });

                    return categoriesByParkingType;
                  }

                  final rateCategories =
                      buildRateCategories(ratesProvider.parkingRates);

                  return RefreshIndicator(
                    onRefresh: () async {
                      await ratesProvider.fetchParkingRates();
                    },
                    color: ConstColors.themeColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current parking rates',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 16),
                            ...[
                              for (int i = 0; i < rateCategories.keys.length; i++) ...[
                                RatesCard(
                                  title: '${rateCategories.keys.elementAt(i)} Rates',
                                  isExpanded: i == 0,
                                  rates: rateCategories[rateCategories.keys.elementAt(i)]!,
                                ),
                                if (i < rateCategories.keys.length - 1) SizedBox(height: 16),
                              ],
                            ],
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'All charges are inclusive of GST',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Official vehicles of Hon\'ble Judges, Railway Officers, and Higher Officials of the Central Government are exempted from charges',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RatesCard extends StatefulWidget {
  final String title;
  final bool isExpanded;
  final List<RateCategory> rates;

  const RatesCard({
    super.key,
    required this.title,
    required this.isExpanded,
    required this.rates,
  });

  @override
  State<RatesCard> createState() => _RatesCardState();
}

class _RatesCardState extends State<RatesCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: widget.rates.map((category) {
                  return CategoryRates(category: category);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class CategoryRates extends StatelessWidget {
  final RateCategory category;

  const CategoryRates({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                category.icon, // Use Icon widget with IconData
                size: 24,
                color: Colors.grey[700], // Optional: match icon color
              ),
              SizedBox(width: 8),
              Text(
                category.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...category.rates.map((rate) {
            return Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rate.time,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '₹${rate.price}', // Prepended Rupee symbol
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class RateCategory {
  final IconData icon; // Changed from String to IconData
  final String title;
  final List<RateItem> rates;

  RateCategory({required this.icon, required this.title, required this.rates});
}

class RateItem {
  final String time;
  final String price;

  RateItem({required this.time, required this.price});
}
