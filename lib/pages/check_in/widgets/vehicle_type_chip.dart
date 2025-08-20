import 'package:flutter/material.dart';

class VehicleTypeChip extends StatelessWidget {
  final String text;
  final Color color;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final VoidCallback? onPressed;
  final bool isSelected;

  const VehicleTypeChip({
    Key? key,
    required this.text,
    this.color = const Color(0xFFFA7763),
    this.height = 36.0,
    this.fontSize = 14.0,
    this.fontWeight = FontWeight.w500,
    this.onPressed,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        margin: EdgeInsets.only(right: 5),
        decoration: ShapeDecoration(
          color: !isSelected ? Colors.white : color,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: color),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: !isSelected ? color : Colors.white,
              fontSize: fontSize,
              fontFamily: 'Poppins',
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }
}
