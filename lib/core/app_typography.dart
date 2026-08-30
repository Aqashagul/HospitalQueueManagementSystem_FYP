import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle get title =>
      GoogleFonts.playfairDisplay(fontSize: 23, fontWeight: FontWeight.bold, letterSpacing: 0.7);

  static TextStyle get subtitle =>
      TextStyle(fontSize: 14, color: Colors.grey.shade600);

  static TextStyle get Bigcard => GoogleFonts.poppins(
    color: Colors.white,
    fontSize: 15,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w500,
  );

static TextStyle get normaltext => GoogleFonts.inter(
  fontSize: 13,
);

static TextStyle get upperCaseText=> GoogleFonts.inter(
  fontSize: 12,
  color: Colors.grey.shade600,
  fontWeight:FontWeight.w600

);



 
                               

}
