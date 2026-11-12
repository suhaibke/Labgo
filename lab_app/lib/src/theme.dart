import 'package:flutter/material.dart';

/// Colour tokens copied 1:1 from the design's CSS variables
/// (`:root` for light and `[data-theme="dark"]` for dark).
class Palette {
  final Color pageBg;
  final Color appBg;
  final Color card;
  final Color cardBorder;
  final Color accent;
  final Color ink;
  final Color muted;
  final Color muted2;
  final Color line;
  final Color segmented;
  final Color inputBg;
  final Color navBg;
  final Color navBorder;
  final Color chipBg;
  final Color track;
  final Color peach;
  final Color activeCircle;
  final Color activeIcon;
  final Color toastBg;
  final Color toastText;
  final Color avatarBg;
  final Color placeholder;
  final Color searchBg;
  final bool dark;

  /// `bg-white` utility (dark mode turns it into #1C1C1E).
  Color get white => dark ? const Color(0xFF1C1C1E) : Colors.white;

  /// `bg-[#FFF0E6]` (soft accent surface).
  Color get softAccent =>
      dark ? const Color(0xFF3A2A1E) : const Color(0xFFFFF0E6);

  /// `bg-[#E6F7ED]` / `text-[#0E7A3E]`.
  Color get softGreen =>
      dark ? const Color(0xFF1E3A2A) : const Color(0xFFE6F7ED);
  Color get greenText =>
      dark ? const Color(0xFF4CD964) : const Color(0xFF0E7A3E);

  const Palette({
    required this.pageBg,
    required this.appBg,
    required this.card,
    required this.cardBorder,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.muted2,
    required this.line,
    required this.segmented,
    required this.inputBg,
    required this.navBg,
    required this.navBorder,
    required this.chipBg,
    required this.track,
    required this.peach,
    required this.activeCircle,
    required this.activeIcon,
    required this.toastBg,
    required this.toastText,
    required this.avatarBg,
    required this.placeholder,
    required this.searchBg,
    required this.dark,
  });

  factory Palette.light(Color accent) => Palette(
    pageBg: const Color(0xFFE8E9EB),
    appBg: const Color(0xFFEDEDED),
    card: const Color(0xFFF7F7F7),
    cardBorder: const Color(0xFFFFFFFF),
    accent: accent,
    ink: const Color(0xFF111111),
    muted: const Color(0xFF8A8A8E),
    muted2: const Color(0xFF6E6E73),
    line: const Color(0xFFE7E7E9),
    segmented: const Color(0xFFE7E7E7),
    inputBg: const Color(0xFFFFFFFF),
    navBg: const Color.fromRGBO(255, 255, 255, 0.7),
    navBorder: const Color(0xFFFFFFFF),
    chipBg: const Color(0xFFFFFFFF),
    track: const Color(0xFFE7E7E9),
    peach: const Color(0xFFFFC4A8),
    activeCircle: const Color(0xFFFFFFFF),
    activeIcon: const Color(0xFF111111),
    toastBg: const Color(0xFF111111),
    toastText: const Color(0xFFFFFFFF),
    avatarBg: const Color(0xFFC9C9CE),
    placeholder: const Color(0xFF8A8A8E),
    searchBg: const Color(0xFFF2F2F7),
    dark: false,
  );

  factory Palette.dark(Color accent) => Palette(
    pageBg: const Color(0xFF000000),
    appBg: const Color(0xFF0B0B0D),
    card: const Color(0xFF1C1C1E),
    cardBorder: const Color(0xFF2C2C2E),
    accent: accent,
    ink: const Color(0xFFFFFFFF),
    muted: const Color(0xFFA1A1AA),
    muted2: const Color(0xFFA1A1AA),
    line: const Color(0xFF2C2C2E),
    segmented: const Color(0xFF2C2C2E),
    // Dark mode forces inputs to #1C1C1E (see design CSS overrides).
    inputBg: const Color(0xFF1C1C1E),
    navBg: const Color.fromRGBO(28, 28, 30, 0.85),
    navBorder: const Color(0xFF2C2C2E),
    chipBg: const Color(0xFF2C2C2E),
    track: const Color(0xFF3A3A3C),
    peach: const Color(0xFFFF8A4A),
    activeCircle: const Color(0xFF3A3A3C),
    activeIcon: const Color(0xFFFFFFFF),
    toastBg: const Color(0xFF2C2C2E),
    toastText: const Color(0xFFFFFFFF),
    avatarBg: const Color(0xFF3A3A3C),
    placeholder: const Color(0xFF8E8E93),
    searchBg: const Color(0xFF1C1C1E),
    dark: true,
  );
}

/// Accent colour choices from the design ("Change Color").
class AccentOption {
  final String key;
  final String label;
  final Color hex;
  final Color darkHex;
  const AccentOption(this.key, this.label, this.hex, this.darkHex);
}

const kAccents = <AccentOption>[
  AccentOption('orange', 'Orange', Color(0xFFFF5A00), Color(0xFFFF7A33)),
  AccentOption('blue', 'Blue', Color(0xFF007AFF), Color(0xFF3395FF)),
  AccentOption('green', 'Green', Color(0xFF34C759), Color(0xFF4CD964)),
  AccentOption('purple', 'Purple', Color(0xFFAF52DE), Color(0xFFBF5AF2)),
  AccentOption('red', 'Red', Color(0xFFFF3B30), Color(0xFFFF6961)),
  AccentOption('teal', 'Teal', Color(0xFF00C7BE), Color(0xFF40D9D1)),
];

/// Fixed colours used directly in the design.
class Fixed {
  static const orange = Color(0xFFFF5A00);
  static const orangeLight = Color(0xFFFF8A3D);
  static const sendA = Color(0xFFFF6B00);
  static const sendB = Color(0xFFFF8A00);
  static const red = Color(0xFFFF3B30);
  static const green = Color(0xFF34C759);
  static const blue = Color(0xFF007AFF);

  /// linear-gradient(135deg,#FF5A00,#FF8A3D)
  static const loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange, orangeLight],
  );

  /// linear-gradient(135deg,#FF6B00,#FF8A00)
  static const sendGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sendA, sendB],
  );
}

/// Tailwind shadows used by the design.
class Shadows {
  static const sm = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];
  static const md = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];
  static const lg = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -4,
    ),
  ];
  static const xl = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 10,
      spreadRadius: -6,
    ),
  ];
  static const xxl = [
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 25),
      blurRadius: 50,
      spreadRadius: -12,
    ),
  ];
  static const logo = [
    BoxShadow(
      color: Color.fromRGBO(17, 17, 17, .14),
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
    BoxShadow(
      color: Color.fromRGBO(17, 17, 17, .08),
      offset: Offset(0, 3),
      blurRadius: 8,
    ),
  ];
}
