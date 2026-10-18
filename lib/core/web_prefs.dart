// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Tiny wrapper over the browser's localStorage for light preferences
/// (language choice and the like). Every call is guarded: storage can be
/// blocked (private windows, strict settings), and the app must work
/// without it.
String? webPrefGet(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void webPrefSet(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void webPrefRemove(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}
