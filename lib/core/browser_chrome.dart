import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Keeps the browser's OWN chrome (Safari's overscroll/bounce area,
/// and the theme-color meta tag some browsers use to tint their UI)
/// in sync with whatever color the app is actively showing.
///
/// index.html's static background can only ever be a guess - it's
/// read before Flutter has fetched the school's data, so it can
/// never actually be "this school's orange." That's fine for the
/// split-second before Flutter mounts, but it's NOT fine for every
/// other moment the bounce area might show (which is most of the
/// time a page scrolls) - for that, the color has to be set here, at
/// runtime, once Flutter actually knows it.
///
/// Call this anywhere a per-school ThemeData is being built (see
/// _TeacherProfileGate in teacher_home.dart and SignInPage for two
/// examples) - right after computing `primary` from
/// landing.primaryColor / school.primaryColor. Safe to call on every
/// build; it's just a DOM style write, idempotent if the color
/// hasn't changed.
void updateBrowserChromeColor(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  final hex = '#${argb.substring(2)}'; // drop the alpha byte -> #RRGGBB

  html.document.body?.style.backgroundColor = hex;
  html.document.documentElement?.style.backgroundColor = hex;

  html.document.querySelector('meta[name="theme-color"]')?.setAttribute('content', hex);
}