import 'package:flutter/material.dart';

class PassBtn extends StatelessWidget {
  final String imagePath;
  final String text;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const PassBtn({
    Key? key,
    required this.imagePath,
    required this.text,
    this.onPressed,
    this.width = double.infinity,
    this.height = 91,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.borderColor = const Color(0xFFC3DFCE),
    this.textColor = const Color(0xFF747474),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 0.50,
              color: borderColor,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
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
