import 'package:flutter/material.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';

class HomeActionBtn extends StatelessWidget {
  final String text;
  final String iconPath;
  final VoidCallback onPressed;

  const HomeActionBtn({
    Key? key,
    required this.text,
    this.iconPath = 'assets/images/print_icon.png',
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: ShapeDecoration(
          color: ConstColors.themeColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          shadows: [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconPath,
              width: 17,
              height: 17,
              fit: BoxFit.cover,
            ),
            SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
