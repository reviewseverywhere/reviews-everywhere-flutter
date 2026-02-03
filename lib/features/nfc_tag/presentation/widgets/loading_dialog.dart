import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

const blue = Color(0xFF0066CC);
const orange = Color(0xFFFF6600);

class LoadingDialog {
  const LoadingDialog();

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.white,
      barrierDismissible: false,
      
      builder: (BuildContext context) {
        return Container(
          width: 100,
          height: 100,
          color: Colors.white,
          child: Center(
            child: LoadingAnimationWidget.discreteCircle(
                secondRingColor: blue,
                thirdRingColor: orange,
                color: Colors.black,
                size: 60),
          ),
        );
      },
    );
  }

  void terminateLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}
