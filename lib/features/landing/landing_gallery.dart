import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/responsive.dart';
import 'landing_model.dart';

class LandingGallerySection extends StatelessWidget {
  final List<LandingGalleryItem> gallery;
  final AppStrings strings;

  const LandingGallerySection({super.key, required this.gallery, required this.strings});

  @override
  Widget build(BuildContext context) {
    if (gallery.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final columns = Responsive.columns(context, max: 4);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pagePadding(context),
        vertical: 72,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.gallery,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(strings.galleryTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 26),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gallery.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) => _GalleryTile(
              item: gallery[i],
              onTap: () => _openViewer(context, gallery, i),
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<LandingGalleryItem> items, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => _GalleryViewer(items: items, initialIndex: index),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final LandingGalleryItem item;
  final VoidCallback onTap;
  const _GalleryTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Hero(
          tag: 'gallery_${item.id}',
          child: Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            cacheWidth: 600,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  final List<LandingGalleryItem> items;
  final int initialIndex;
  const _GalleryViewer({required this.items, required this.initialIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, i) {
            final item = widget.items[i];
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: Hero(
                  tag: 'gallery_${item.id}',
                  child: Image.network(item.imageUrl, fit: BoxFit.contain),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Text('${_currentIndex + 1} / ${widget.items.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}