import 'package:flutter/material.dart';

abstract class AppColors {
  // Backgrounds
  // Deep dark blue background for the main scaffold
  static const Color background = Color(0xFF0B1221); 
  // Slightly lighter for cards/containers
  static const Color cardBackground = Color(0xFF161D2F);
  
  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8F9BB3);

  // Status & Accents
  static const Color primaryBlue = Color(0xFF0075FF); // "Active Flights" blue
  static const Color warningOrange = Color(0xFFE07C00); // "Delayed" orange
  static const Color alertRed = Color(0xFFD32F2F); // "Alerts" red
  static const Color successGreen = Color(0xFF28A745);
  
  // Specific UI Elements
  static const Color tableHeader = Color(0xFF1E2838);
  static const Color divider = Color(0xFF2B3648);
}
