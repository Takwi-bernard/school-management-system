import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn, animated charts for the Proprietor module. They use only
/// Flutter's own canvas (no chart package), so they cannot break on a
/// package upgrade, animate in on first paint and again whenever the
/// data changes, and show a tooltip on hover (desktop) or touch/drag
/// (phone and tablet).

// ============================================================ shared

class PrTipRow {
  final String label;
  final String value;
  final Color color;
  const PrTipRow({required this.label, required this.value, required this.color});
}

class PrTip {
  final String title;
  final List<PrTipRow> rows;
  const PrTip({required this.title, required this.rows});
}

class PrSlice {
  final String label;
  final double value;
  final Color color;
  const PrSlice({required this.label, required this.value, required this.color});
}

class _CT {
  final Color grid;
  final Color zero;
  final Color tipBg;
  final TextStyle axis;
  final TextStyle tipTitle;
  final TextStyle tipText;
  final TextStyle tipValue;
  const _CT({
    required this.grid,
    required this.zero,
    required this.tipBg,
    required this.axis,
    required this.tipTitle,
    required this.tipText,
    required this.tipValue,
  });

  factory _CT.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _CT(
      grid: cs.onSurface.withValues(alpha: 0.08),
      zero: cs.onSurface.withValues(alpha: 0.35),
      tipBg: cs.inverseSurface.withValues(alpha: 0.96),
      axis: TextStyle(color: cs.outline, fontSize: 11, fontWeight: FontWeight.w500),
      tipTitle: TextStyle(color: cs.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w800),
      tipText: TextStyle(color: cs.onInverseSurface.withValues(alpha: 0.75), fontSize: 11.5),
      tipValue: TextStyle(color: cs.onInverseSurface, fontSize: 11.5, fontWeight: FontWeight.w800),
    );
  }
}

TextPainter _tp(String text, TextStyle style, {double? maxWidth}) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  );
  p.layout(maxWidth: maxWidth ?? double.infinity);
  return p;
}

double _niceCeil(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / exp;
  final nf = f <= 1 ? 1.0 : (f <= 2 ? 2.0 : (f <= 5 ? 5.0 : 10.0));
  return nf * exp;
}

String _sig(Iterable<double> values) => Object.hashAll(values.map((v) => v.round())).toString();

void _drawTip(Canvas canvas, Size size, Offset anchor, PrTip tip, _CT ct) {
  final titleP = _tp(tip.title, ct.tipTitle);
  final labels = <TextPainter>[];
  final values = <TextPainter>[];
  var rowW = 0.0;
  for (final r in tip.rows) {
    final l = _tp(r.label, ct.tipText);
    final v = _tp(r.value, ct.tipValue);
    labels.add(l);
    values.add(v);
    rowW = math.max(rowW, 14 + l.width + 14 + v.width);
  }
  const pad = 11.0;
  final w = math.max(titleP.width, rowW) + pad * 2;
  final h = pad * 2 + titleP.height + (tip.rows.isEmpty ? 0 : 6 + tip.rows.length * 18.0);

  var x = anchor.dx + 14;
  if (x + w > size.width) x = anchor.dx - 14 - w;
  x = x.clamp(0.0, math.max(0.0, size.width - w)).toDouble();
  final y = (anchor.dy - h / 2).clamp(0.0, math.max(0.0, size.height - h)).toDouble();
  final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(12));

  canvas.drawRRect(rect.shift(const Offset(0, 3)), Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  canvas.drawRRect(rect, Paint()..color = ct.tipBg);

  titleP.paint(canvas, Offset(x + pad, y + pad));
  var ry = y + pad + titleP.height + 6;
  for (var i = 0; i < tip.rows.length; i++) {
    canvas.drawCircle(Offset(x + pad + 4, ry + 9), 4, Paint()..color = tip.rows[i].color);
    labels[i].paint(canvas, Offset(x + pad + 14, ry + 9 - labels[i].height / 2));
    values[i].paint(canvas, Offset(x + w - pad - values[i].width, ry + 9 - values[i].height / 2));
    ry += 18;
  }
}

mixin _Replay<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..forward();

  double get progress => Curves.easeOutCubic.transform(anim.value);

  void replay() => anim.forward(from: 0);

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }
}

// ============================================================ bar chart

class PrBarSeries {
  final String name;
  final Color color;
  final List<double> values;

  /// Optional per-bar colours (used by the diverging net-result chart).
  final List<Color>? valueColors;
  const PrBarSeries({required this.name, required this.color, required this.values, this.valueColors});
}

/// Grouped bars; supports negative values (bars grow below the zero line).
class PrBarChart extends StatefulWidget {
  final List<String> labels;
  final List<PrBarSeries> series;
  final String Function(double) axisFormat;
  final PrTip Function(int index) tipFor;
  final double height;

  const PrBarChart({
    super.key,
    required this.labels,
    required this.series,
    required this.axisFormat,
    required this.tipFor,
    this.height = 260,
  });

  @override
  State<PrBarChart> createState() => _PrBarChartState();
}

class _PrBarChartState extends State<PrBarChart> with SingleTickerProviderStateMixin, _Replay<PrBarChart> {
  int? _hover;
  static const double _left = 48, _right = 8;

  @override
  void didUpdateWidget(covariant PrBarChart old) {
    super.didUpdateWidget(old);
    if (_sig(old.series.expand((s) => s.values)) != _sig(widget.series.expand((s) => s.values))) replay();
  }

  int? _indexAt(double dx, double w) {
    final n = widget.labels.length;
    if (n == 0) return null;
    final gw = (w - _left - _right) / n;
    final i = ((dx - _left) / gw).floor();
    return (i < 0 || i >= n) ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final ct = _CT.of(context);
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      void set(Offset p) {
        final i = _indexAt(p.dx, w);
        if (i != _hover) setState(() => _hover = i);
      }

      return MouseRegion(
        onHover: (e) => set(e.localPosition),
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final i = _indexAt(d.localPosition.dx, w);
            setState(() => _hover = (i == _hover) ? null : i);
          },
          onHorizontalDragUpdate: (d) => set(d.localPosition),
          child: SizedBox(
            width: w,
            height: widget.height,
            child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) => CustomPaint(
                painter: _BarPainter(
                  labels: widget.labels,
                  series: widget.series,
                  axisFormat: widget.axisFormat,
                  hover: _hover,
                  tip: _hover == null ? null : widget.tipFor(_hover!),
                  progress: progress,
                  ct: ct,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _BarPainter extends CustomPainter {
  final List<String> labels;
  final List<PrBarSeries> series;
  final String Function(double) axisFormat;
  final int? hover;
  final PrTip? tip;
  final double progress;
  final _CT ct;

  _BarPainter({
    required this.labels,
    required this.series,
    required this.axisFormat,
    required this.hover,
    required this.tip,
    required this.progress,
    required this.ct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0, right = 8.0, top = 10.0, bottom = 26.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    var maxV = 0.0, minV = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        maxV = math.max(maxV, v);
        minV = math.min(minV, v);
      }
    }
    double topV, bottomV, step;
    if (minV >= 0) {
      topV = _niceCeil(maxV);
      bottomV = 0;
      step = topV / 4;
    } else {
      final absMax = math.max(maxV, -minV);
      step = _niceCeil(absMax / 2);
      topV = (maxV / step).ceil() * step;
      bottomV = (minV / step).floor() * step;
      if (topV <= bottomV) topV = bottomV + step;
    }
    final range = topV - bottomV;
    double yOf(double v) => plot.top + (topV - v) / range * plot.height;

    // grid + y axis labels
    var v = bottomV;
    var guard = 0;
    while (v <= topV + step * 0.001 && guard++ < 20) {
      final y = yOf(v);
      final isZero = v.abs() < step * 0.001;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), Paint()..color = (isZero ? ct.zero : ct.grid)..strokeWidth = (isZero ? 1.2 : 1.0));
      final p = _tp(axisFormat(v), ct.axis, maxWidth: left - 8);
      p.paint(canvas, Offset(left - 8 - p.width, y - p.height / 2));
      v += step;
    }

    final n = labels.length;
    if (n == 0) return;
    final gw = plot.width / n;

    // hover band
    if (hover != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(plot.left + hover! * gw + 2, plot.top, gw - 4, plot.height), const Radius.circular(8)),
        Paint()..color = ct.zero.withValues(alpha: 0.10),
      );
    }

    // x labels (thinned when crowded)
    var maxLabelW = 0.0;
    final labelPs = <TextPainter>[];
    for (final l in labels) {
      final p = _tp(l, ct.axis, maxWidth: gw * 1.6);
      labelPs.add(p);
      maxLabelW = math.max(maxLabelW, p.width);
    }
    final every = math.max(1, ((maxLabelW + 6) / gw).ceil());
    for (var i = 0; i < n; i++) {
      if (i % every != 0) continue;
      final p = labelPs[i];
      p.paint(canvas, Offset(plot.left + gw * i + gw / 2 - p.width / 2, plot.bottom + 7));
    }

    // bars
    final sc = series.length;
    final barW = math.min(22.0, gw * 0.72 / sc);
    final groupW = barW * sc + (sc - 1) * 3;
    final zeroY = yOf(0);
    for (var i = 0; i < n; i++) {
      final gx = plot.left + gw * i + (gw - groupW) / 2;
      for (var s = 0; s < sc; s++) {
        final val = i < series[s].values.length ? series[s].values[i] : 0.0;
        if (val == 0) continue;
        final x = gx + s * (barW + 3);
        final yv = zeroY + (yOf(val) - zeroY) * progress;
        final rect = val >= 0 ? Rect.fromLTRB(x, yv, x + barW, zeroY) : Rect.fromLTRB(x, zeroY, x + barW, yv);
        final color = (series[s].valueColors != null && i < series[s].valueColors!.length) ? series[s].valueColors![i] : series[s].color;
        final dim = hover != null && hover != i;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: val >= 0 ? const Radius.circular(6) : Radius.zero,
            topRight: val >= 0 ? const Radius.circular(6) : Radius.zero,
            bottomLeft: val < 0 ? const Radius.circular(6) : Radius.zero,
            bottomRight: val < 0 ? const Radius.circular(6) : Radius.zero,
          ),
          Paint()..color = color.withValues(alpha: dim ? 0.45 : 1),
        );
      }
    }

    if (tip != null && hover != null) {
      _drawTip(canvas, size, Offset(plot.left + gw * hover! + gw / 2, plot.top + plot.height / 2), tip!, ct);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.progress != progress || old.hover != hover || old.series != series || old.labels != labels || old.ct.grid != ct.grid;
}

// ============================================================ line / area chart

class PrLineSeries {
  final String name;
  final Color color;
  final List<double> values;
  const PrLineSeries({required this.name, required this.color, required this.values});
}

class PrLineChart extends StatefulWidget {
  final List<String> labels;
  final List<PrLineSeries> series;
  final String Function(double) axisFormat;
  final PrTip Function(int index) tipFor;
  final double height;

  const PrLineChart({
    super.key,
    required this.labels,
    required this.series,
    required this.axisFormat,
    required this.tipFor,
    this.height = 240,
  });

  @override
  State<PrLineChart> createState() => _PrLineChartState();
}

class _PrLineChartState extends State<PrLineChart> with SingleTickerProviderStateMixin, _Replay<PrLineChart> {
  int? _hover;
  static const double _left = 48, _right = 14;

  @override
  void didUpdateWidget(covariant PrLineChart old) {
    super.didUpdateWidget(old);
    if (_sig(old.series.expand((s) => s.values)) != _sig(widget.series.expand((s) => s.values))) replay();
  }

  int? _indexAt(double dx, double w) {
    final n = widget.labels.length;
    if (n == 0) return null;
    if (n == 1) return 0;
    final t = ((dx - _left) / (w - _left - _right)).clamp(0.0, 1.0);
    return (t * (n - 1)).round();
  }

  @override
  Widget build(BuildContext context) {
    final ct = _CT.of(context);
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      void set(Offset p) {
        final i = _indexAt(p.dx, w);
        if (i != _hover) setState(() => _hover = i);
      }

      return MouseRegion(
        onHover: (e) => set(e.localPosition),
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => set(d.localPosition),
          onHorizontalDragUpdate: (d) => set(d.localPosition),
          child: SizedBox(
            width: w,
            height: widget.height,
            child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) => CustomPaint(
                painter: _LinePainter(
                  labels: widget.labels,
                  series: widget.series,
                  axisFormat: widget.axisFormat,
                  hover: _hover,
                  tip: _hover == null ? null : widget.tipFor(_hover!),
                  progress: progress,
                  ct: ct,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _LinePainter extends CustomPainter {
  final List<String> labels;
  final List<PrLineSeries> series;
  final String Function(double) axisFormat;
  final int? hover;
  final PrTip? tip;
  final double progress;
  final _CT ct;

  _LinePainter({
    required this.labels,
    required this.series,
    required this.axisFormat,
    required this.hover,
    required this.tip,
    required this.progress,
    required this.ct,
  });

  Path _smooth(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final mx = (a.dx + b.dx) / 2;
      p.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0, right = 14.0, top = 10.0, bottom = 26.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (plot.width <= 0 || plot.height <= 0) return;
    final n = labels.length;
    if (n == 0) return;

    var maxV = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        maxV = math.max(maxV, v);
      }
    }
    final topV = _niceCeil(maxV);
    double yOf(double v) => plot.bottom - (v / topV) * plot.height;
    double xOf(int i) => n == 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);

    for (var k = 0; k <= 4; k++) {
      final v = topV * k / 4;
      final y = yOf(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), Paint()..color = (k == 0 ? ct.zero : ct.grid)..strokeWidth = (k == 0 ? 1.2 : 1.0));
      final p = _tp(axisFormat(v), ct.axis, maxWidth: left - 8);
      p.paint(canvas, Offset(left - 8 - p.width, y - p.height / 2));
    }

    // x labels, thinned
    final labelPs = labels.map((l) => _tp(l, ct.axis)).toList();
    final maxLabelW = labelPs.fold<double>(0, (m, p) => math.max(m, p.width));
    final slot = n <= 1 ? plot.width : plot.width / (n - 1);
    final every = math.max(1, ((maxLabelW + 10) / slot).ceil());
    for (var i = 0; i < n; i += every) {
      final p = labelPs[i];
      final x = (xOf(i) - p.width / 2).clamp(0.0, size.width - p.width).toDouble();
      p.paint(canvas, Offset(x, plot.bottom + 7));
    }

    // series, revealed left to right
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plot.left + plot.width * progress + 2, size.height));
    for (final s in series) {
      if (s.values.isEmpty) continue;
      final pts = [for (var i = 0; i < n && i < s.values.length; i++) Offset(xOf(i), yOf(s.values[i]))];
      if (pts.isEmpty) continue;
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, 3.5, Paint()..color = s.color);
        continue;
      }
      final line = _smooth(pts);
      final fill = Path.from(line)
        ..lineTo(pts.last.dx, plot.bottom)
        ..lineTo(pts.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.color.withValues(alpha: 0.20), s.color.withValues(alpha: 0.0)],
          ).createShader(plot),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();

    if (hover != null && hover! < n) {
      final x = xOf(hover!);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), Paint()..color = ct.zero.withValues(alpha: 0.5)..strokeWidth = 1);
      for (final s in series) {
        if (hover! >= s.values.length) continue;
        final c = Offset(x, yOf(s.values[hover!]));
        canvas.drawCircle(c, 6, Paint()..color = Colors.white);
        canvas.drawCircle(c, 4.2, Paint()..color = s.color);
      }
      if (tip != null) _drawTip(canvas, size, Offset(x, plot.top + plot.height / 2), tip!, ct);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.progress != progress || old.hover != hover || old.series != series || old.labels != labels || old.ct.grid != ct.grid;
}

// ============================================================ donut

class PrDonut extends StatefulWidget {
  final List<PrSlice> slices;
  final double size;
  final double thickness;

  /// Centre content; receives the hovered slice index (or null).
  final Widget Function(int? hovered) center;

  const PrDonut({super.key, required this.slices, required this.center, this.size = 190, this.thickness = 22});

  @override
  State<PrDonut> createState() => _PrDonutState();
}

class _PrDonutState extends State<PrDonut> with SingleTickerProviderStateMixin, _Replay<PrDonut> {
  int? _hover;

  @override
  void didUpdateWidget(covariant PrDonut old) {
    super.didUpdateWidget(old);
    if (_sig(old.slices.map((s) => s.value)) != _sig(widget.slices.map((s) => s.value))) replay();
  }

  int? _sliceAt(Offset p) {
    final total = widget.slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return null;
    final c = Offset(widget.size / 2, widget.size / 2);
    final d = p - c;
    final r = d.distance;
    final outer = widget.size / 2;
    if (r > outer + 4 || r < outer - widget.thickness - 14) return null;
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    while (a < 0) {
      a += 2 * math.pi;
    }
    a = a % (2 * math.pi);
    var acc = 0.0;
    for (var i = 0; i < widget.slices.length; i++) {
      acc += widget.slices[i].value / total * 2 * math.pi;
      if (a <= acc) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onHover: (e) {
        final i = _sliceAt(e.localPosition);
        if (i != _hover) setState(() => _hover = i);
      },
      onExit: (_) => setState(() => _hover = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final i = _sliceAt(d.localPosition);
          setState(() => _hover = i == _hover ? null : i);
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) => CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutPainter(
                  slices: widget.slices,
                  thickness: widget.thickness,
                  hover: _hover,
                  progress: progress,
                  track: cs.onSurface.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(widget.thickness + 14),
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 160), child: KeyedSubtree(key: ValueKey(_hover), child: widget.center(_hover))),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<PrSlice> slices;
  final double thickness;
  final int? hover;
  final double progress;
  final Color track;

  _DonutPainter({required this.slices, required this.thickness, required this.hover, required this.progress, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - thickness / 2 - 4);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = thickness);
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    final gap = slices.where((s) => s.value > 0).length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final s = slices[i];
      if (s.value <= 0) continue;
      final full = s.value / total * math.pi * 2;
      final sweep = math.max(0.0, full - gap) * progress;
      final dim = hover != null && hover != i;
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep,
        false,
        Paint()
          ..color = s.color.withValues(alpha: dim ? 0.4 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = hover == i ? thickness + 6 : thickness
          ..strokeCap = StrokeCap.butt,
      );
      start += full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.progress != progress || old.hover != hover || old.slices != slices;
}

// ============================================================ gauge

class PrGauge extends StatelessWidget {
  /// 0..1
  final double value;
  final double size;
  final Color color;
  final Widget child;
  const PrGauge({super.key, required this.value, required this.color, required this.child, this.size = 150});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size(size, size), painter: _GaugePainter(value: v, color: color, track: cs.onSurface.withValues(alpha: 0.08))),
          child,
        ]),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  _GaugePainter({required this.value, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - stroke / 2 - 2);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    canvas.drawArc(rect, start, sweep, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
    if (value > 0) {
      canvas.drawArc(rect, start, sweep * value, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.color != color;
}

// ============================================================ sparkline

class PrSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  const PrSparkline({super.key, required this.values, required this.color, this.height = 34});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(size: Size.infinite, painter: _SparkPainter(values: values, color: color, progress: t)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double progress;
  _SparkPainter({required this.values, required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(size.width * i / (values.length - 1), size.height - 3 - (values[i] - minV) / range * (size.height - 6)),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final mx = (pts[i].dx + pts[i + 1].dx) / 2;
      line.cubicTo(mx, pts[i].dy, mx, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)])
            .createShader(Offset.zero & size),
    );
    canvas.drawPath(line, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.progress != progress || old.values != values || old.color != color;
}