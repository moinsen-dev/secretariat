// F200-F201: Color definitions for Secretariat app
//
// Features:
// - F200: Create lib/theme/colors.dart with Color constants
// - F201: Define primaryColor, secondaryColor, accentColor

import 'package:flutter/material.dart';

/// F200-F201: Color constants for the Secretariat app
///
/// Professional color scheme using blues and grays for a secure,
/// trustworthy appearance suitable for a secrets management application.

// Primary Colors - Deep Blue (trust, security)
const Color primaryColor = Color(0xFF1976D2); // Material Blue 700
const Color primaryColorLight = Color(0xFF63A4FF); // Light variant
const Color primaryColorDark = Color(0xFF004BA0); // Dark variant

// Secondary Colors - Slate Gray (professional, neutral)
const Color secondaryColor = Color(0xFF455A64); // Blue Grey 700
const Color secondaryColorLight = Color(0xFF718792); // Light variant
const Color secondaryColorDark = Color(0xFF1C313A); // Dark variant

// Accent Colors - Teal (action, highlight)
const Color accentColor = Color(0xFF00ACC1); // Cyan 600
const Color accentColorLight = Color(0xFF5DDEF4); // Light variant
const Color accentColorDark = Color(0xFF007C91); // Dark variant

// Semantic Colors
const Color successColor = Color(0xFF4CAF50); // Green 500
const Color warningColor = Color(0xFFFFA726); // Orange 400
const Color errorColor = Color(0xFFF44336); // Red 500
const Color infoColor = Color(0xFF2196F3); // Blue 500

// Background Colors - Light Theme
const Color backgroundLight = Color(0xFFFAFAFA); // Gray 50
const Color surfaceLight = Color(0xFFFFFFFF); // White
const Color surfaceVariantLight = Color(0xFFF5F5F5); // Gray 100

// Background Colors - Dark Theme
const Color backgroundDark = Color(0xFF121212); // Material Dark background
const Color surfaceDark = Color(0xFF1E1E1E); // Dark surface
const Color surfaceVariantDark = Color(0xFF2C2C2C); // Dark surface variant

// Text Colors - Light Theme
const Color textPrimaryLight = Color(0xFF212121); // Gray 900
const Color textSecondaryLight = Color(0xFF757575); // Gray 600
const Color textHintLight = Color(0xFF9E9E9E); // Gray 500

// Text Colors - Dark Theme
const Color textPrimaryDark = Color(0xFFFFFFFF); // White
const Color textSecondaryDark = Color(0xFFB0B0B0); // Light gray
const Color textHintDark = Color(0xFF757575); // Gray 600

// Border Colors
const Color borderLight = Color(0xFFE0E0E0); // Gray 300
const Color borderDark = Color(0xFF424242); // Gray 800

// Special Colors
const Color lockedColor = Color(0xFFF44336); // Red - vault locked
const Color unlockedColor = Color(0xFF4CAF50); // Green - vault unlocked
const Color secretColor = Color(0xFF9C27B0); // Purple - secrets
const Color applicationColor = Color(0xFF00BCD4); // Cyan - applications
