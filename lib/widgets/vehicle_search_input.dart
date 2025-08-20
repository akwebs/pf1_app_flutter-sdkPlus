import 'package:flutter/material.dart';

class VehicleSearchInput extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;

  const VehicleSearchInput({
    Key? key,
    this.hintText = '',
    this.controller,
    this.obscureText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 49,
      decoration: ShapeDecoration(
        color: const Color(0xFF9C1905),
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 0.50,
            color: Color(0xFF954135),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x19BABABA),
            blurRadius: 5.80,
            offset: Offset(0, 1),
            spreadRadius: 3,
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        textCapitalization: TextCapitalization.characters,
        // add keyboard uppercase
        keyboardType: TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0xFFFC8888),
            fontSize: 18,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }
}
