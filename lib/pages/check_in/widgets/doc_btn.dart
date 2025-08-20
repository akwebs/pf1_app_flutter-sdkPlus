import 'dart:io';

import 'package:flutter/material.dart';

class DocBtn extends StatelessWidget {
  final String imagePath;
  final String selectedImg;
  final String text;
  final VoidCallback? onPressed;

  const DocBtn({
    Key? key,
    required this.imagePath,
    required this.selectedImg,
    required this.text,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 138,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: ShapeDecoration(
          color: const Color(0xFFEDF7EE),
          shape: RoundedRectangleBorder(
            side: const BorderSide(
              width: 0.50,
              color: Color(0xFFC3DFCE),
            ),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: selectedImg.isNotEmpty
                      ? FileImage(File(selectedImg))
                      : AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF5C665D),
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
