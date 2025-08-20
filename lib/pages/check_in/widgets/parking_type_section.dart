import 'package:flutter/material.dart';
import 'package:kota_pf1_app/providers/vehicle_type_provider.dart';
import 'package:provider/provider.dart';
import 'package:kota_pf1_app/providers/parking_type_provider.dart';

class ParkingTypeChip extends StatelessWidget {
  final bool isSelected;
  final String text;

  const ParkingTypeChip({
    super.key,
    required this.isSelected,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: ShapeDecoration(
        color: isSelected ? const Color(0xFFEDF7EE) : const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 0.50,
            color:
                isSelected ? const Color(0xFFC3DFCE) : const Color(0xFFE3E3E3),
          ),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? const Color(0xFF3A9869) : const Color(0xFF616161),
          fontSize: 14,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ParkingTypeSection extends StatelessWidget {
  const ParkingTypeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final String selectedParkingType =
        context.watch<ParkingTypeProvider>().selectedParkingType;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Parking Type',
                style: TextStyle(
                  color: const Color(0xFF747373),
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Text(
              //   ' *',
              //   style: TextStyle(
              //     color: Colors.red,
              //     fontSize: 12,
              //     fontFamily: 'Poppins',
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
            ],
          ),
          SizedBox(height: 5),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  context.read<ParkingTypeProvider>().setParkingType('1');
                },
                child: ParkingTypeChip(
                  isSelected: selectedParkingType == '1',
                  text: 'General Parking',
                ),
              ),
              // GestureDetector(
              //   onTap: () {
              //     final vehicleTypes = context.read<VehicleTypeProvider>().vehicleTypes;
              //     final fourWheeler = vehicleTypes.firstWhere(
              //       (type) => type['vehicle_type'].toString().toLowerCase().contains('four wheeler'),
              //       orElse: () => vehicleTypes.first,
              //     );
              //     context.read<ParkingTypeProvider>().setParkingType('2');
              //     context.read<VehicleTypeProvider>().setVehicleType(fourWheeler);
              //     // disable all vehicle types
              //   },
              //   child: ParkingTypeChip(
              //     isSelected: selectedParkingType == '2',
              //     text: 'Premium Parking',
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}
