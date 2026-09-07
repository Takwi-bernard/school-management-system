import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Parses a school's stored hex color (schools.primary_color /
/// secondary_color) into a Flutter Color.
///
/// Deliberately falls back to a neutral GRAY, not a plausible-looking
/// brand color. The previous pattern (several files each had their
/// own copy of this, all falling back to 0xFF1A73E8 - a real blue)
/// was actively dangerous: a parsing failure looked exactly like a
/// legitimate, intentional blue theme instead of an obvious "this is
/// broken" signal. Also logs to the console on failure so it's never
/// silent - check the browser devtools console if you ever see gray
/// where a school's color should be.
Color parseSchoolColor(String? hex, {required String debugLabel}) {
  const fallback = Color(0xFF9E9E9E);

  if (hex == null || hex.trim().isEmpty) {
    debugPrint('[school_color] $debugLabel: color is empty/null - falling back to gray. Check the schools table.');
    return fallback;
  }

  var value = hex.trim().replaceAll('#', '');
  if (value.length == 3) {
    // Shorthand #RGB -> #RRGGBB
    value = value.split('').map((c) => '$c$c').join();
  }
  if (value.length == 6) value = 'FF$value';

  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    debugPrint('[school_color] $debugLabel: could not parse "$hex" as a hex color - falling back to gray.');
    return fallback;
  }
  return Color(parsed);
}