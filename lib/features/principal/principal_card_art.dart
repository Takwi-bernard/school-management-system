import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'principal_models.dart';

/// Draws the student ID card (front and back) with a canvas: a soft
/// watercolor wash in the school's two colours, bilingual labels that
/// follow the school's language mode, and a decorative barcode.
///
/// The PNG it produces (CR80 at 300 dpi) is used both for the on-screen
/// flip preview and, unchanged, inside the printable PDF, so what the
/// principal sees is exactly what gets printed.

const double pnCardW = 1011;
const double pnCardH = 638;

Color pnHex(String hex, Color fallback) {
  var v = hex.replaceAll('#', '').trim();
  if (v.length == 6) v = 'FF$v';
  final n = int.tryParse(v, radix: 16);
  return n == null ? fallback : Color(n);
}

/// School-wide data decoded once and reused for every card of a batch.
class PnCardSchool {
  final String name;
  final String motto;
  final String address;
  final String phone;
  final String email;
  final String academicYear;
  final String languageMode; // english | french | bilingual
  final Color primary;
  final Color secondary;
  final ui.Image? logo;
  final ui.Image? stamp;
  final int seed;

  const PnCardSchool({
    required this.name,
    required this.motto,
    required this.address,
    required this.phone,
    required this.email,
    required this.academicYear,
    required this.languageMode,
    required this.primary,
    required this.secondary,
    required this.logo,
    required this.stamp,
    required this.seed,
  });

  String label(String en, String fr) {
    switch (languageMode) {
      case 'french':
        return fr;
      case 'english':
        return en;
      default:
        return '$en / $fr';
    }
  }

  static Future<ui.Image?> fetchImage(String? url, {int? maxWidth}) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(res.bodyBytes, targetWidth: maxWidth);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}

class PnCardPhotoCache {
  /// Turns a stored photo value into a link that can be downloaded (the
  /// photos are in a private bucket, so they must be signed first).
  final Future<String?> Function(String stored)? resolve;
  PnCardPhotoCache({this.resolve});

  final Map<String, ui.Image?> _cache = {};

  Future<ui.Image?> get(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    if (_cache.containsKey(stored)) return _cache[stored];
    String? url = stored;
    if (resolve != null) url = await resolve!(stored);
    final img = await PnCardSchool.fetchImage(url, maxWidth: 480);
    // A failed download is not remembered, so a retry can succeed.
    if (img != null) _cache[stored] = img;
    return img;
  }
}

Future<Uint8List> pnRenderCard({
  required PnCardSchool school,
  required IdCardStudentData student,
  required ui.Image? photo,
  required bool front,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, const Rect.fromLTWH(0, 0, pnCardW, pnCardH));
  final painter = _CardPainter(canvas, school);
  painter.paint(student, photo, front);
  final picture = recorder.endRecording();
  final image = await picture.toImage(pnCardW.toInt(), pnCardH.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class _CardPainter {
  final Canvas c;
  final PnCardSchool s;
  _CardPainter(this.c, this.s);

  static const ink = Color(0xFF1B2230);
  static const soft = Color(0xFF5B6475);

  Color get p => s.primary;
  Color get q => s.secondary;

  void paint(IdCardStudentData st, ui.Image? photo, bool front) {
    final bounds = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, pnCardW, pnCardH), const Radius.circular(40));
    c.save();
    c.clipRRect(bounds);
    c.drawRect(const Rect.fromLTWH(0, 0, pnCardW, pnCardH), Paint()..color = const Color(0xFFFDFCF9));
    _watercolor(front);
    _watermark();
    if (front) {
      _front(st, photo);
    } else {
      _back(st);
    }
    c.restore();
    c.drawRRect(bounds.deflate(1), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x22000000));
  }

  // ------------------------------------------------------------ watercolor

  void _blob(Offset o, double r, Color color, double alpha, double sigma) {
    c.drawCircle(o, r, Paint()..color = color.withValues(alpha: alpha)..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma));
  }

  void _watercolor(bool front) {
    final rnd = math.Random(s.seed + (front ? 1 : 7));
    final w = pnCardW;
    final h = pnCardH;
    // big soft washes
    if (front) {
      _blob(Offset(w * 0.90, h * 0.30), 250, p, 0.18, 70);
      _blob(Offset(w * 0.06, h * 0.92), 270, q, 0.17, 75);
      _blob(Offset(w * 0.55, h * 1.00), 210, p, 0.13, 65);
      _blob(Offset(w * 0.02, h * 0.38), 170, q, 0.13, 60);
      _blob(Offset(w * 0.98, h * 0.95), 190, q, 0.16, 60);
    } else {
      _blob(Offset(w * 0.10, h * 0.20), 260, q, 0.17, 75);
      _blob(Offset(w * 0.92, h * 0.88), 280, p, 0.17, 80);
      _blob(Offset(w * 0.50, h * 0.05), 200, p, 0.12, 65);
      _blob(Offset(w * 0.95, h * 0.30), 150, q, 0.13, 55);
    }
    // layered, irregular patches so the wash looks painted, not a gradient
    for (var i = 0; i < 9; i++) {
      final col = i.isEven ? p : q;
      final o = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      _blob(o, 40 + rnd.nextDouble() * 80, col, 0.05 + rnd.nextDouble() * 0.07, 22 + rnd.nextDouble() * 18);
    }
    // fine splatter
    for (var i = 0; i < 16; i++) {
      final col = i % 3 == 0 ? q : p;
      final o = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      _blob(o, 3 + rnd.nextDouble() * 9, col, 0.10 + rnd.nextDouble() * 0.10, 2.5);
    }
  }

  void _watermark() {
    final logo = s.logo;
    if (logo == null) return;
    const size = 400.0;
    final dst = Rect.fromCenter(center: Offset(pnCardW * 0.62, pnCardH * 0.58), width: size, height: size);
    _drawContain(logo, dst, opacity: 0.07);
  }

  // ------------------------------------------------------------ front

  void _front(IdCardStudentData st, ui.Image? photo) {
    // header with a curved lower edge and a thin accent line beneath it
    final accent = Path()
      ..moveTo(0, 0)
      ..lineTo(pnCardW, 0)
      ..lineTo(pnCardW, 118)
      ..quadraticBezierTo(pnCardW * 0.64, 172, pnCardW * 0.36, 128)
      ..quadraticBezierTo(pnCardW * 0.16, 96, 0, 128)
      ..close();
    c.drawPath(accent, Paint()..color = q);
    final head = Path()
      ..moveTo(0, 0)
      ..lineTo(pnCardW, 0)
      ..lineTo(pnCardW, 104)
      ..quadraticBezierTo(pnCardW * 0.64, 158, pnCardW * 0.36, 114)
      ..quadraticBezierTo(pnCardW * 0.16, 82, 0, 114)
      ..close();
    c.drawPath(
      head,
      Paint()..shader = ui.Gradient.linear(const Offset(0, 0), Offset(pnCardW, 120), [p, Color.lerp(p, const Color(0xFF000000), 0.28)!]),
    );

    // logo medallion
    const lc = Offset(88, 64);
    c.drawCircle(lc, 50, Paint()..color = const Color(0xFFFFFFFF));
    c.drawCircle(lc, 50, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = q);
    if (s.logo != null) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: lc, radius: 42)));
      _drawContain(s.logo!, Rect.fromCircle(center: lc, radius: 42));
      c.restore();
    } else {
      _text(_initials(s.name), Offset(lc.dx - 40, lc.dy - 22), size: 38, color: p, weight: FontWeight.w900, maxW: 80, align: TextAlign.center);
    }

    // school name (auto-fit) and motto
    // the flag sits at the right end of the header, so the name stops before it
    final nameMax = pnCardW - 168 - 44 - _flagW - 24;
    final fit = _fitSize(s.name.toUpperCase(), nameMax, 40, 24, FontWeight.w900, spacing: 1);
    _text(s.name.toUpperCase(), Offset(160, 30), size: fit, color: const Color(0xFFFFFFFF), weight: FontWeight.w900, maxW: nameMax, spacing: 1);
    if (s.motto.isNotEmpty) {
      _text(s.motto, Offset(160, 30 + fit + 8), size: 21, color: const Color(0xDDFFFFFF), maxW: nameMax, italic: true);
    }

    _flag(const Rect.fromLTWH(pnCardW - 44 - _flagW, 24, _flagW, _flagH));

    // card title
    _text(s.label('STUDENT ID CARD', 'CARTE D’ÉLÈVE').toUpperCase(), Offset(330, 148), size: 19, color: p, weight: FontWeight.w800, maxW: pnCardW - 330 - 44, spacing: 3);

    // photo frame
    const pr = Rect.fromLTWH(44, 172, 232, 294);
    final prr = RRect.fromRectAndRadius(pr, const Radius.circular(26));
    c.drawRRect(prr.shift(const Offset(0, 8)), Paint()..color = const Color(0x33000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    c.drawRRect(prr.inflate(7), Paint()..color = const Color(0xFFFFFFFF));
    c.drawRRect(prr.inflate(7), Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = p);
    c.save();
    c.clipRRect(prr);
    if (photo != null) {
      _drawCover(photo, pr);
    } else {
      c.drawRect(pr, Paint()..color = p.withValues(alpha: 0.10));
      final pc = Paint()..color = p.withValues(alpha: 0.35);
      c.drawCircle(Offset(pr.center.dx, pr.top + 112), 52, pc);
      c.drawOval(Rect.fromCenter(center: Offset(pr.center.dx, pr.bottom - 10), width: 190, height: 170), pc);
    }
    c.restore();

    // admission number pill under the photo
    final pill = RRect.fromRectAndRadius(const Rect.fromLTWH(34, 494, 252, 52), const Radius.circular(26));
    c.drawRRect(pill, Paint()..color = p);
    _text(st.admissionNumber, Offset(34, 505), size: 27, color: const Color(0xFFFFFFFF), weight: FontWeight.w800, maxW: 252, align: TextAlign.center, spacing: 1.5);

    // details
    const x = 318.0;
    final maxW = pnCardW - x - 44;
    var y = 196.0;
    final fit2 = _fitSize(st.fullName.toUpperCase(), maxW, 44, 28, FontWeight.w900);
    final nameH = _text(st.fullName.toUpperCase(), Offset(x, y), size: fit2, color: ink, weight: FontWeight.w900, maxW: maxW, maxLines: 2);
    y += nameH + 10;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 90, 6), const Radius.circular(3)), Paint()..color = q);
    y += 26;

    y = _field(x, y, maxW, s.label('Class', 'Classe'), st.className);
    y = _field(x, y, maxW, s.label('Date of birth', 'Date de naissance'), st.dateOfBirth == null ? '—' : _date(st.dateOfBirth!));
    y = _field(x, y, maxW, s.label('Academic year', 'Année scolaire'), s.academicYear.isEmpty ? '—' : s.academicYear);

    // barcode and stripe
    _barcode(st.admissionNumber, Rect.fromLTWH(pnCardW - 44 - 280, 540, 280, 46));
    _stripe();
  }

  double _field(double x, double y, double maxW, String label, String value) {
    final lh = _text(label.toUpperCase(), Offset(x, y), size: 15.5, color: soft, weight: FontWeight.w700, maxW: maxW, spacing: 1.4);
    final vh = _text(value, Offset(x, y + lh + 2), size: 28, color: ink, weight: FontWeight.w700, maxW: maxW);
    return y + lh + vh + 20;
  }

  // ------------------------------------------------------------ back

  void _back(IdCardStudentData st) {
    final band = Path()
      ..moveTo(0, 0)
      ..lineTo(pnCardW, 0)
      ..lineTo(pnCardW, 40)
      ..quadraticBezierTo(pnCardW * 0.7, 78, pnCardW * 0.42, 44)
      ..quadraticBezierTo(pnCardW * 0.2, 20, 0, 52)
      ..close();
    c.drawPath(band, Paint()..shader = ui.Gradient.linear(const Offset(0, 0), Offset(pnCardW, 60), [p, Color.lerp(p, const Color(0xFF000000), 0.25)!]));
    c.drawPath(
      Path()
        ..moveTo(0, 52)
        ..quadraticBezierTo(pnCardW * 0.2, 20, pnCardW * 0.42, 44)
        ..quadraticBezierTo(pnCardW * 0.7, 78, pnCardW, 40)
        ..lineTo(pnCardW, 50)
        ..quadraticBezierTo(pnCardW * 0.7, 90, pnCardW * 0.42, 54)
        ..quadraticBezierTo(pnCardW * 0.2, 30, 0, 62)
        ..close(),
      Paint()..color = q,
    );

    // identity strip
    _text(s.name.toUpperCase(), Offset(48, 92), size: 27, color: p, weight: FontWeight.w900, maxW: pnCardW - 96 - _flagW - 24, spacing: 1.2);
    _text(st.fullName, Offset(48, 128), size: 22, color: soft, weight: FontWeight.w600, maxW: pnCardW - 96 - _flagW - 24);
    _flag(const Rect.fromLTWH(pnCardW - 48 - _flagW, 84, _flagW, _flagH));

    const x = 48.0;
    const colW = 420.0;
    var y = 178.0;
    y = _field(x, y, colW, s.label('Guardian', 'Tuteur'), (st.guardianName ?? '').isEmpty ? '—' : st.guardianName!);
    y = _field(x, y, colW, s.label('Guardian phone', 'Téléphone du tuteur'), (st.guardianPhone ?? '').isEmpty ? '—' : st.guardianPhone!);
    y = _field(x, y, colW, s.label('Admitted on', 'Admis le'), st.admissionDate == null ? '—' : _date(st.admissionDate!));

    // return notice
    final notice = s.languageMode == 'french'
        ? 'En cas de perte, prière de retourner cette carte à ${s.name}.'
        : s.languageMode == 'english'
            ? 'If found, please return this card to ${s.name}.'
            : 'If found, please return this card to ${s.name}.\nEn cas de perte, prière de la retourner à ${s.name}.';
    _text(notice, Offset(x, 490), size: 17.5, color: soft, maxW: 560, italic: true, maxLines: 3);

    // contact lines
    var cy = 556.0;
    for (final line in [s.address, s.phone, s.email]) {
      if (line.trim().isEmpty) continue;
      c.drawCircle(Offset(x + 6, cy + 11), 5, Paint()..color = q);
      _text(line, Offset(x + 22, cy), size: 17, color: ink, maxW: 560);
      cy += 24;
      if (cy > pnCardH - 30) break;
    }

    // stamp and signature
    const sx = 700.0;
    if (s.stamp != null) {
      _drawContain(s.stamp!, const Rect.fromLTWH(sx + 40, 300, 200, 150));
    }
    c.drawLine(const Offset(sx, 470), const Offset(sx + 280, 470), Paint()..color = ink.withValues(alpha: 0.55)..strokeWidth = 2);
    _text(s.label('The Principal', 'Le Chef d’Établissement'), const Offset(sx, 478), size: 16, color: soft, weight: FontWeight.w700, maxW: 280, align: TextAlign.center);

    _barcode(st.admissionNumber, Rect.fromLTWH(pnCardW - 48 - 280, 188, 280, 56));
    _stripe();
  }

  // ------------------------------------------------------------ flag

  static const double _flagW = 104;
  static const double _flagH = 70;

  /// The flag of Cameroon: green, red and yellow vertical bands with a
  /// yellow star on the red one. Drawn in code so it is crisp at any
  /// size and needs no image file.
  void _flag(Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
    c.drawRRect(rr.shift(const Offset(0, 4)), Paint()..color = const Color(0x33000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.save();
    c.clipRRect(rr);
    final bw = r.width / 3;
    c.drawRect(Rect.fromLTWH(r.left, r.top, bw, r.height), Paint()..color = const Color(0xFF007A5E));
    c.drawRect(Rect.fromLTWH(r.left + bw, r.top, bw, r.height), Paint()..color = const Color(0xFFCE1126));
    c.drawRect(Rect.fromLTWH(r.left + 2 * bw, r.top, bw + 1, r.height), Paint()..color = const Color(0xFFFCD116));
    // five-point star centred on the red band
    final centre = Offset(r.left + bw * 1.5, r.center.dy);
    final outer = r.height * 0.27;
    final inner = outer * 0.382;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(centre.dx + rad * math.cos(a), centre.dy + rad * math.sin(a));
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    c.drawPath(star, Paint()..color = const Color(0xFFFCD116));
    c.restore();
    c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFFFFFFFF));
  }

  // ------------------------------------------------------------ shared bits

  void _stripe() {
    final w = pnCardW;
    final h = pnCardH;
    c.drawPath(
      Path()
        ..moveTo(0, h - 30)
        ..quadraticBezierTo(w * 0.25, h - 58, w * 0.5, h - 30)
        ..quadraticBezierTo(w * 0.75, h - 4, w, h - 34)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = q,
    );
    c.drawPath(
      Path()
        ..moveTo(0, h - 12)
        ..quadraticBezierTo(w * 0.25, h - 38, w * 0.5, h - 12)
        ..quadraticBezierTo(w * 0.75, h + 12, w, h - 16)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = p,
    );
  }

  void _barcode(String code, Rect r) {
    final bars = <bool>[];
    for (final u in '*${code.toUpperCase()}*'.codeUnits) {
      for (var b = 6; b >= 0; b--) {
        bars.add(((u >> b) & 1) == 1);
      }
      bars.add(false);
    }
    final unit = r.width / bars.length;
    final paint = Paint()..color = ink.withValues(alpha: 0.78);
    for (var i = 0; i < bars.length; i++) {
      if (bars[i]) c.drawRect(Rect.fromLTWH(r.left + i * unit, r.top, unit * 0.82, r.height), paint);
    }
  }

  void _drawCover(ui.Image img, Rect dst) {
    final ia = img.width / img.height;
    final da = dst.width / dst.height;
    Rect src;
    if (ia > da) {
      final w = img.height * da;
      src = Rect.fromLTWH((img.width - w) / 2, 0, w, img.height.toDouble());
    } else {
      final h = img.width / da;
      // faces sit in the upper part of a portrait, so crop from the top third
      src = Rect.fromLTWH(0, (img.height - h) * 0.25, img.width.toDouble(), h);
    }
    c.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);
  }

  void _drawContain(ui.Image img, Rect dst, {double opacity = 1}) {
    final ia = img.width / img.height;
    final da = dst.width / dst.height;
    late Rect out;
    if (ia > da) {
      final h = dst.width / ia;
      out = Rect.fromLTWH(dst.left, dst.center.dy - h / 2, dst.width, h);
    } else {
      final w = dst.height * ia;
      out = Rect.fromLTWH(dst.center.dx - w / 2, dst.top, w, dst.height);
    }
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      out,
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  double _fitSize(String text, double maxW, double start, double min, FontWeight w, {double spacing = 0}) {
    var size = start;
    while (size > min) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: w, letterSpacing: spacing)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (tp.width <= maxW) break;
      size -= 1;
    }
    return size;
  }

  /// Paints text and returns its height.
  double _text(
    String text,
    Offset o, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    required double maxW,
    bool italic = false,
    double spacing = 0,
    int maxLines = 1,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight, fontStyle: italic ? FontStyle.italic : FontStyle.normal, letterSpacing: spacing, height: 1.18),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(minWidth: align == TextAlign.left ? 0 : maxW, maxWidth: maxW);
    tp.paint(c, o);
    return tp.height;
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}