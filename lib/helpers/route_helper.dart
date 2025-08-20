import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

class RouteHelper {
  static push(BuildContext context, Function callback) {
    Navigator.push(
        context,
        PageTransition(
            type: PageTransitionType.fade,
            child: callback(),
            duration: const Duration(milliseconds: 100)));
    // Navigator.push(
    //     context, MaterialPageRoute(builder: (context) => callback()));
  }

  static replace(BuildContext context, Function callback) {
    Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: callback(),
        duration: const Duration(milliseconds: 100),
      ),
    );

    // Navigator.pushReplacement(
    //     context, MaterialPageRoute(builder: (context) => callback()));
  }

  static pushWithCb(
      BuildContext context, Function callback, Function returnCb) {
    Navigator.push(
            context,
            PageTransition(
                type: PageTransitionType.fade,
                child: callback(),
                duration: const Duration(milliseconds: 100)))
        .then((_) {
      returnCb();
    });
    // Navigator.push(
    //     context, MaterialPageRoute(builder: (context) => callback()));
  }
}
