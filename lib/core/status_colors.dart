import 'package:flutter/material.dart';

/// Color rule for the whole parent module (and anywhere else this is
/// reused): decoration - stat tiles, icons, section accents - draws
/// ONLY from the school's own theme.colorScheme.primary/secondary, at
/// varying opacity. These three are the one deliberate exception:
/// status meaning that reads the same to everyone regardless of a
/// school's branding, so it should never be swapped for a brand color.
///
/// kPending  - "needs your attention" (payment due, awaiting review)
/// kOverdue  - "declined / late / failed"
/// kSettled  - "done, nothing to do"
const Color kPending = Color(0xFFB07A00); // amber
const Color kOverdue = Color(0xFFC62828); // red
const Color kSettled = Color(0xFF1E8E5A); // green
