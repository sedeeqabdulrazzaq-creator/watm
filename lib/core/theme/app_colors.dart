import 'package:flutter/material.dart';

abstract final class AppColors {
  // Official WATM palette from Figma Foundations.
  static const sea = Color(0xFF5FA9D3);
  static const nature = Color(0xFFD7DB62);
  static const sky = Color(0xFFA8AD32);
  static const earth = Color(0xFF75644A);
  static const universe = Color(0xFF101820);
  static const warmBackground = Color(0xFFFBFAF6);

  static const white = Color(0xFFFFFFFF);
  static const seaSoft = Color(0xFFEAF4FA);
  static const natureSoft = Color(0xFFF3F4D5);
  static const border = Color(0xFFE5E0D7);
  static const muted = Color(0xFFF1EEE8);

  // Previously duplicated as raw hex literals across several presentation
  // files; centralized here so every screen shares one definition.
  static const seaAccent = Color(0xFF3E7FA8);
  static const errorSoft = Color(0xFFFFF2F0);
  static const errorBorder = Color(0xFFE7A39B);
  static const errorText = Color(0xFF7D2C24);
}
