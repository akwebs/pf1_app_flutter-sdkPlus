import 'package:flutter/material.dart';

class SearchBtn extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;
  final bool isLoading;

  const SearchBtn(
      {Key? key,
      required this.text,
      required this.onPressed,
      this.color = Colors.white,
      this.textColor = Colors.black,
      this.isLoading = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 42,
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        shadows: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 4),
            spreadRadius: 0,
          )
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: () {
          if (!isLoading) {
            onPressed();
          }
        },
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFA7966),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: const Color(0xFFFA7966),
                  fontSize: 15,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
