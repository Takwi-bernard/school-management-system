import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import 'landing_content.dart' show SectionHeading;
import 'landing_model.dart';
import 'landing_text.dart';

class LandingGallerySection extends StatelessWidget {
  final List<LandingGalleryItem> gallery;
  final AppStrings strings;

  const LandingGallerySection({super.key, required this.gallery, required this.strings});

  @override
  Widget build(BuildContext context) {
    if (gallery.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    final columns = Responsive.columns(context, max: 4);

    return RevealOnScroll(
      child: Container(
        width: double.infinity,
        color: cs.surface,
        padding: EdgeInsets.symmetric(horizontal: Responsive.pagePadding(context), vertical: isMobile ? 56 : 88),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(overline: strings.gallery, title: strings.galleryTitle),
          const SizedBox(height: 30),
          LayoutBuilder(builder: (context, box) {
            const gap = 12.0;
            final cols = columns < 2 ? 2 : columns;
            final tile = ((box.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
            // With enough photos the first one is shown double size.
            final feature = cols >= 3 && gallery.length >= 5;
            final bigSize = tile * 2 + gap;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (var i = 0; i < gallery.length; i++)
                SizedBox(
                  width: (feature && i == 0) ? bigSize : tile,
                  height: (feature && i == 0) ? bigSize : tile,
                  child: _GalleryTile(item: gallery[i], onTap: () => _openViewer(context, gallery, i)),
                ),
            ]);
          }),
        ]),
      ),
    );
  }

  void _openViewer(BuildContext context, List<LandingGalleryItem> items, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (_) => _GalleryViewer(items: items, initialIndex: index, text: LandingText(strings.isFrench)),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final LandingGalleryItem item;
  final VoidCallback onTap;
  const _GalleryTile({required this.item, required this.onTap});

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final caption = widget.item.caption;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            AnimatedScale(
              scale: _hover ? 1.07 : 1.0,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              child: Image.network(
                widget.item.imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 900,
                frameBuilder: (context, child, frame, sync) => AnimatedOpacity(opacity: (frame == null && !sync) ? 0 : 1, duration: const Duration(milliseconds: 350), child: child),
                errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.image_not_supported_outlined)),
              ),
            ),
            if (caption != null && caption.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 28, 14, 12),
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)])),
                    child: Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  final List<LandingGalleryItem> items;
  final int initialIndex;
  final LandingText text;
  const _GalleryViewer({required this.items, required this.initialIndex, required this.text});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.items.length) return;
    _controller.animateToPage(next, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.items[_index].caption;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
        },
        child: Focus(
          autofocus: true,
          child: Stack(children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 80 : 12, 64, wide ? 80 : 12, 84),
                  child: Center(child: Image.network(widget.items[i].imageUrl, fit: BoxFit.contain)),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(child: IconButton.filledTonal(tooltip: widget.text.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))),
            ),
            if (wide && _index > 0)
              Positioned(left: 16, top: 0, bottom: 0, child: Center(child: IconButton.filledTonal(onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left_rounded)))),
            if (wide && _index < widget.items.length - 1)
              Positioned(right: 16, top: 0, bottom: 0, child: Center(child: IconButton.filledTonal(onPressed: () => _go(1), icon: const Icon(Icons.chevron_right_rounded)))),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (caption != null && caption.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                    Text('${_index + 1} / ${widget.items.length}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
