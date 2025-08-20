import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kota_pf1_app/providers/helmet_provider.dart';
import 'package:kota_pf1_app/providers/vehicle_type_provider.dart';

class HelmetSection extends StatelessWidget {
  const HelmetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final Map selectedVehicleType = context.watch<VehicleTypeProvider>().selectedVehicleType;
    final bool hasHelmet = context.watch<HelmetProvider>().hasHelmet;

    // Only show helmet section for two-wheelers
    if (!selectedVehicleType['vehicle_type'].toString().toLowerCase().contains('two wheeler')) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Helmet',
            style: TextStyle(
              color: const Color(0xFF747373),
              fontSize: 12,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.read<HelmetProvider>().setHelmetStatus(true);
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasHelmet ? Color(0xFFA1F7A9) : Color(0xFFF5F5F5),
                      border: Border.all(
                        color: hasHelmet ? Color(0xFF04560C) : Color(0xFFF5F5F5),
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        'Yes',
                        style: TextStyle(
                          color: hasHelmet ? Color(0xFF04560C) : Color(0xFF747373),
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.read<HelmetProvider>().setHelmetStatus(false);
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: !hasHelmet ? Color(0xFFA1F7A9) : Color(0xFFF5F5F5),
                      border: Border.all(
                        color: !hasHelmet ? Color(0xFF04560C) : Color(0xFFF5F5F5),
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        'No',
                        style: TextStyle(
                          color: !hasHelmet ? Color(0xFF04560C) : Color(0xFF747373),
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 