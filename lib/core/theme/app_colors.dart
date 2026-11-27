import 'dart:ui';

/// All colors of the app. Light and dark palettes are kept apart.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFF2662C);
  static const Color primaryDark = Color(0xFFD94E16);
  static const Color accent = Color(0xFF3BB273);

  // Light palette
  static const Color backgroundLight = Color(0xFFFFFAF4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF2B2118);
  static const Color textSecondaryLight = Color(0xFF7A6B5D);
  static const Color dividerLight = Color(0xFFEFE4D8);

  // Dark palette
  static const Color backgroundDark = Color(0xFF1B1511);
  static const Color surfaceDark = Color(0xFF2A211B);
  static const Color textPrimaryDark = Color(0xFFFFF3E6);
  static const Color textSecondaryDark = Color(0xFFC5B3A0);
  static const Color dividerDark = Color(0xFF3B2F27);

  // Status
  static const Color veg = Color(0xFF2E9E4F);
  static const Color nonVeg = Color(0xFFC62828);
  static const Color danger = Color(0xFFD32F2F);

  // HUD over the 3D view
  static const Color hudGlass = Color(0xCC1B1511);
  static const Color hudText = Color(0xFFFFFFFF);

  // 3D world (hex ints for three_js): warm wood + modern black accents
  static const int skyColor = 0xBCD7EC;
  static const int groundOutside = 0x6E9C62;
  static const int plaza = 0xB5AEA2;
  static const int aisleRunner = 0x8F8A82;
  static const int wall = 0xE3D6C3; // warm plaster
  static const int wallAccent = 0xF2662C;
  static const int skirting = 0x2B2E33;
  static const int ceiling = 0x2B2E33; // dark modern ceiling
  static const int charcoal = 0x2B2E33;
  static const int metalBlack = 0x23262A;
  static const int brass = 0xC9A24A;
  static const int lampWarm = 0xFFD9A0;
  static const int wood = 0xBD8E58; // light oak
  static const int woodLight = 0xD2A672;
  static const int woodDark = 0x5A3D27; // walnut
  static const int walnutBack = 0x7A5434;
  static const int shelfFrame = 0xBD8E58;
  static const int shelfBase = 0x4E3623;
  static const int tagPaper = 0xFFFFFF;
  static const int doorSilver = 0xCDD2D8;
  static const int doorFrame = 0x23262A;
  static const int glass = 0xB7DCEB;
  static const int fridgeBody = 0x2B2E33;
  static const int skin = 0xE8B796;
  static const int skinShade = 0xD9A27E;
  static const int sleeve = 0x3A3F47;
  static const int cuff = 0xF4F4F2;
  static const int basketRed = 0xC9302C;
  static const int basketDark = 0x8E1F1C;
  static const int terracotta = 0xB9623F;
  static const int trunk = 0x6B4B2E;
  static const int leaves = 0x3E7D3F;
}
