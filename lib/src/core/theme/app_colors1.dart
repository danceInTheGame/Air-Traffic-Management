import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color scaffoldBackground = Color(0xFF0B1221);
  static const Color panelBackground = Color(0xFF162032);
  static const Color sidebarBackground = Color(0xFF131B2B);

  // Status Colors
  static const Color activeFlights = Color(0xFF005698);
  static const Color activeFlightsText = Color(0xFFE3F2FD);
  
  static const Color delayed = Color(0xFFD66D00);
  static const Color delayedText = Color(0xFFFFF3E0);
  
  static const Color onGround = Color(0xFF263238);
  static const Color onGroundText = Color(0xFFECEFF1);
  
  static const Color alert = Color(0xFFB71C1C);
  static const Color alertText = Color(0xFFFFEBEE);

  // Flight Status Badges (Brighter versions for badges)
  static const Color statusInFlight = Color(0xFF2E7D32); // Greenish
  static const Color statusDelayed = Color(0xFFEF6C00); // Orange
  static const Color statusEnRoute = Color(0xFF1565C0); // Blue
  static const Color statusBoarding = Color(0xFFF9A825); // Yellow
  static const Color statusLanded = Color(0xFFC62828); // Red-ish 
  static const Color statusScheduled = Color(0xFF00695C); // Teal

  // Text
  static const Color textPrimary = Color(0xFFECEFF1);
  static const Color textSecondary = Color(0xFFB0BEC5);

  // Map
  static const Color mapGrid = Color(0x33FFFFFF);
  static const Color trajectoryPath = Color(0xFFFFC107); // Amber/Yellow
  static const Color trajectoryPathSecondary = Color(0xFF0288D1); // Light Blue

  // UI Elements
  static const Color divider = Color(0xFF37474F);
}
