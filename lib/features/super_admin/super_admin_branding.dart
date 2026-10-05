import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'super_admin_models.dart';
import 'super_admin_providers.dart';

Widget _darkField(TextEditingController controller, String label, {int maxLines = 1}) => TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );

class BrandingPage extends StatefulWidget {
  final SchoolSummary school;
  const BrandingPage({super.key, required this.school});

  @override
  State<BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends State<BrandingPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text('${widget.school.schoolName} · Branding', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [Tab(text: 'Assets'), Tab(text: 'Content'), Tab(text: 'Gallery'), Tab(text: 'Achievements'), Tab(text: 'Events')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _AssetsTab(schoolId: widget.school.id),
        _ContentTab(schoolId: widget.school.id, languageMode: widget.school.languageMode),
        _GalleryTab(schoolId: widget.school.id),
        _AchievementsTab(schoolId: widget.school.id, languageMode: widget.school.languageMode),
        _EventsTab(schoolId: widget.school.id),
      ]),
    );
  }
}

// ============================================================
// ASSETS
// ============================================================

class _AssetsTab extends ConsumerStatefulWidget {
  final String schoolId;
  const _AssetsTab({required this.schoolId});

  @override
  ConsumerState<_AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends ConsumerState<_AssetsTab> {
  bool _uploading = false;

  Future<void> _upload(String assetType) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final repo = ref.read(superAdminRepositoryProvider);
      final url = await repo.uploadBrandingFile(bytes: bytes, extension: ext, folder: '${widget.schoolId}/$assetType');
      await repo.saveAsset(schoolId: widget.schoolId, assetType: assetType, fileUrl: url, fileName: picked.name, mimeType: 'image/$ext', fileSize: bytes.length);
      ref.invalidate(schoolAssetsProvider(widget.schoolId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(String id) async {
    await ref.read(superAdminRepositoryProvider).deleteAsset(id);
    ref.invalidate(schoolAssetsProvider(widget.schoolId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolAssetsProvider(widget.schoolId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
      data: (assets) {
        Widget assetSlot(String type, String label) {
          final current = assets.where((a) => a.assetType == type && a.isActive).toList();
          final active = current.isNotEmpty ? current.first : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
                child: active != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(active.fileUrl, fit: BoxFit.cover))
                    : const Icon(Icons.image_outlined, color: Colors.white24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              if (active != null) IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _delete(active.id)),
              FilledButton(onPressed: _uploading ? null : () => _upload(type), child: Text(active == null ? 'Upload' : 'Replace')),
            ]),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            assetSlot('logo', 'School Logo'),
            assetSlot('hero_banner', 'Hero Banner (landing page header)'),
            assetSlot('homepage_image', 'Homepage Image'),
            assetSlot('document_background', 'Document Background'),
          ]),
        );
      },
    );
  }
}

// ============================================================
// CONTENT - respects the school's language_mode
// ============================================================

class _ContentTab extends ConsumerWidget {
  final String schoolId;
  final String languageMode;
  const _ContentTab({required this.schoolId, required this.languageMode});

  static const _knownTypes = ['mission', 'vision', 'history', 'about'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolContentProvider(schoolId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('$e', style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
        ),
      ),
      data: (items) {
        final byType = <String, Map<String, SchoolContentItem>>{};
        for (final item in items) {
          byType.putIfAbsent(item.contentType, () => {})[item.language] = item;
        }
        final types = {..._knownTypes, ...byType.keys}.toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: types
              .map((type) => _ContentCard(
                    schoolId: schoolId,
                    contentType: type,
                    languageMode: languageMode,
                    en: byType[type]?['en'],
                    fr: byType[type]?['fr'],
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ContentCard extends ConsumerStatefulWidget {
  final String schoolId;
  final String contentType;
  final String languageMode;
  final SchoolContentItem? en;
  final SchoolContentItem? fr;
  const _ContentCard({required this.schoolId, required this.contentType, required this.languageMode, this.en, this.fr});

  @override
  ConsumerState<_ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends ConsumerState<_ContentCard> {
  TextEditingController? _enTitle;
  TextEditingController? _enBody;
  TextEditingController? _frTitle;
  TextEditingController? _frBody;
  bool _saving = false;

  bool get _showEnglish => widget.languageMode != 'french';
  bool get _showFrench => widget.languageMode != 'english';

  @override
  void initState() {
    super.initState();
    if (_showEnglish) {
      _enTitle = TextEditingController(text: widget.en?.title ?? '');
      _enBody = TextEditingController(text: widget.en?.content ?? '');
    }
    if (_showFrench) {
      _frTitle = TextEditingController(text: widget.fr?.title ?? '');
      _frBody = TextEditingController(text: widget.fr?.content ?? '');
    }
  }

  @override
  void dispose() {
    _enTitle?.dispose();
    _enBody?.dispose();
    _frTitle?.dispose();
    _frBody?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      if (_showEnglish) {
        await repo.saveContent(id: widget.en?.id, schoolId: widget.schoolId, contentType: widget.contentType, language: 'en', title: _enTitle!.text.trim(), content: _enBody!.text.trim());
      }
      if (_showFrench) {
        await repo.saveContent(id: widget.fr?.id, schoolId: widget.schoolId, contentType: widget.contentType, language: 'fr', title: _frTitle!.text.trim(), content: _frBody!.text.trim());
      }
      ref.invalidate(schoolContentProvider(widget.schoolId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.contentType[0].toUpperCase() + widget.contentType.substring(1), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_showEnglish)
            Expanded(
              child: Column(children: [
                Align(alignment: Alignment.centerLeft, child: Text('English', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11))),
                const SizedBox(height: 6),
                _darkField(_enTitle!, 'Title'),
                const SizedBox(height: 8),
                _darkField(_enBody!, 'Content', maxLines: 4),
              ]),
            ),
          if (_showEnglish && _showFrench) const SizedBox(width: 14),
          if (_showFrench)
            Expanded(
              child: Column(children: [
                Align(alignment: Alignment.centerLeft, child: Text('French', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11))),
                const SizedBox(height: 6),
                _darkField(_frTitle!, 'Titre'),
                const SizedBox(height: 8),
                _darkField(_frBody!, 'Contenu', maxLines: 4),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
        ),
      ]),
    );
  }
}

// ============================================================
// GALLERY
// ============================================================

class _GalleryTab extends ConsumerStatefulWidget {
  final String schoolId;
  const _GalleryTab({required this.schoolId});

  @override
  ConsumerState<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends ConsumerState<_GalleryTab> {
  bool _uploading = false;

  Future<void> _addImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final repo = ref.read(superAdminRepositoryProvider);
      final url = await repo.uploadBrandingFile(bytes: bytes, extension: ext, folder: '${widget.schoolId}/gallery');
      await repo.addGalleryItem(schoolId: widget.schoolId, imageUrl: url);
      ref.invalidate(schoolGalleryProvider(widget.schoolId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolGalleryProvider(widget.schoolId));
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _uploading ? null : _addImage,
            icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add Image'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('No gallery images yet.', style: TextStyle(color: Colors.white38)));
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Stack(children: [
                    Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(item.imageUrl, fit: BoxFit.cover))),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                          onPressed: () async {
                            await ref.read(superAdminRepositoryProvider).deleteGalleryItem(item.id);
                            ref.invalidate(schoolGalleryProvider(widget.schoolId));
                          },
                        ),
                      ),
                    ),
                  ]);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// ACHIEVEMENTS - now with real image upload, used on the landing
// page's achievement cards.
// ============================================================

class _AchievementsTab extends ConsumerWidget {
  final String schoolId;
  final String languageMode;
  const _AchievementsTab({required this.schoolId, required this.languageMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolAchievementsProvider(schoolId));
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () async {
              final saved = await showDialog<bool>(context: context, builder: (_) => _AchievementDialog(schoolId: schoolId, languageMode: languageMode));
              if (saved == true) ref.invalidate(schoolAchievementsProvider(schoolId));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Achievement'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('No achievements yet.', style: TextStyle(color: Colors.white38)));
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = items[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
                        child: a.imageUrl != null && a.imageUrl!.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(a.imageUrl!, fit: BoxFit.cover))
                            : const Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 22),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.titleEn ?? a.titleFr ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          if (a.achievedOn != null) Text('${a.achievedOn!.day}/${a.achievedOn!.month}/${a.achievedOn!.year}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                        onPressed: () async {
                          final saved = await showDialog<bool>(context: context, builder: (_) => _AchievementDialog(schoolId: schoolId, languageMode: languageMode, existing: a));
                          if (saved == true) ref.invalidate(schoolAchievementsProvider(schoolId));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        onPressed: () async {
                          await ref.read(superAdminRepositoryProvider).deleteAchievement(a.id);
                          ref.invalidate(schoolAchievementsProvider(schoolId));
                        },
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _AchievementDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String languageMode;
  final AchievementItem? existing;
  const _AchievementDialog({required this.schoolId, required this.languageMode, this.existing});

  @override
  ConsumerState<_AchievementDialog> createState() => _AchievementDialogState();
}

class _AchievementDialogState extends ConsumerState<_AchievementDialog> {
  TextEditingController? _titleEn;
  TextEditingController? _descEn;
  TextEditingController? _titleFr;
  TextEditingController? _descFr;
  DateTime? _achievedOn;
  String? _imageUrl;
  XFile? _pickedImage;
  bool _saving = false;
  bool _uploadingImage = false;

  bool get _showEnglish => widget.languageMode != 'french';
  bool get _showFrench => widget.languageMode != 'english';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (_showEnglish) {
      _titleEn = TextEditingController(text: e?.titleEn ?? '');
      _descEn = TextEditingController(text: e?.descriptionEn ?? '');
    }
    if (_showFrench) {
      _titleFr = TextEditingController(text: e?.titleFr ?? '');
      _descFr = TextEditingController(text: e?.descriptionFr ?? '');
    }
    _achievedOn = e?.achievedOn;
    _imageUrl = e?.imageUrl;
  }

  @override
  void dispose() {
    _titleEn?.dispose();
    _descEn?.dispose();
    _titleFr?.dispose();
    _descFr?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _pickedImage = picked;
      _uploadingImage = true;
    });
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final url = await ref.read(superAdminRepositoryProvider).uploadBrandingFile(bytes: bytes, extension: ext, folder: '${widget.schoolId}/achievements');
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveAchievement(
            id: widget.existing?.id,
            schoolId: widget.schoolId,
            titleEn: _showEnglish ? _titleEn!.text.trim() : null,
            titleFr: _showFrench ? _titleFr!.text.trim() : null,
            descriptionEn: _showEnglish ? _descEn!.text.trim() : null,
            descriptionFr: _showFrench ? _descFr!.text.trim() : null,
            imageUrl: _imageUrl,
            achievedOn: _achievedOn,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.existing == null ? 'Add Achievement' : 'Edit Achievement', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Image upload - this is what the home page's achievement
            // cards actually display. Missing before; required now.
            Center(
              child: GestureDetector(
                onTap: _uploadingImage ? null : _pickImage,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                  child: _uploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : _imageUrl != null && _imageUrl!.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(_imageUrl!, fit: BoxFit.cover))
                          : const Icon(Icons.add_photo_alternate_outlined, color: Colors.white38, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _imageUrl == null || _imageUrl!.isEmpty ? 'Tap to add an achievement image (used on the home page)' : 'Tap to replace',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_showEnglish) ...[
              _darkField(_titleEn!, 'Title (English)'),
              const SizedBox(height: 10),
              _darkField(_descEn!, 'Description (English)', maxLines: 3),
              const SizedBox(height: 10),
            ],
            if (_showFrench) ...[
              _darkField(_titleFr!, 'Titre (Français)'),
              const SizedBox(height: 10),
              _darkField(_descFr!, 'Description (Français)', maxLines: 3),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(context: context, initialDate: _achievedOn ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                if (picked != null) setState(() => _achievedOn = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(_achievedOn == null ? 'Date achieved' : '${_achievedOn!.day}/${_achievedOn!.month}/${_achievedOn!.year}'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || _uploadingImage ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

// ============================================================
// EVENTS - status is now a locked dropdown with the real confirmed
// enum values: draft, published, cancelled.
// ============================================================

class _EventsTab extends ConsumerWidget {
  final String schoolId;
  const _EventsTab({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolEventsProvider(schoolId));
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () async {
              final saved = await showDialog<bool>(context: context, builder: (_) => _EventDialog(schoolId: schoolId));
              if (saved == true) ref.invalidate(schoolEventsProvider(schoolId));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Event'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text('$e', style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('No events yet.', style: TextStyle(color: Colors.white38)));
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = items[i];
                  final statusColor = e.status == 'published' ? Colors.green : e.status == 'cancelled' ? Colors.red : Colors.orange;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(e.title ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                            if (e.status != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                child: Text(e.status!, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                          Text(
                            '${e.eventDate != null ? '${e.eventDate!.day}/${e.eventDate!.month}/${e.eventDate!.year}' : ''}'
                            '${e.eventTime != null ? ' · ${e.eventTime}' : ''}'
                            '${e.location != null && e.location!.isNotEmpty ? ' · ${e.location}' : ''}',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                        onPressed: () async {
                          final saved = await showDialog<bool>(context: context, builder: (_) => _EventDialog(schoolId: schoolId, existing: e));
                          if (saved == true) ref.invalidate(schoolEventsProvider(schoolId));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        onPressed: () async {
                          await ref.read(superAdminRepositoryProvider).deleteEvent(e.id);
                          ref.invalidate(schoolEventsProvider(schoolId));
                        },
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _EventDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final EventItem? existing;
  const _EventDialog({required this.schoolId, this.existing});

  @override
  ConsumerState<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<_EventDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  DateTime? _date;
  TimeOfDay? _time;
  String _status = 'draft';
  bool _saving = false;

  static const _validStatuses = ['draft', 'published', 'cancelled'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _status = _validStatuses.contains(e?.status) ? e!.status! : 'draft';
    _date = e?.eventDate;
    if (e?.eventTime != null) {
      final parts = e!.eventTime!.split(':');
      if (parts.length >= 2) {
        _time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  String? _formattedTime() {
    if (_time == null) return null;
    return '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(superAdminRepositoryProvider).saveEvent(
            id: widget.existing?.id,
            schoolId: widget.schoolId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            eventDate: _date,
            eventTime: _formattedTime(),
            location: _location.text.trim(),
            status: _status,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.existing == null ? 'Add Event' : 'Edit Event', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _darkField(_title, 'Title'),
            const SizedBox(height: 10),
            _darkField(_description, 'Description', maxLines: 3),
            const SizedBox(height: 10),
            _darkField(_location, 'Location'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Status', labelStyle: TextStyle(color: Colors.white38)),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'draft'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(_date == null ? 'Date' : '${_date!.day}/${_date!.month}/${_date!.year}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
                    if (picked != null) setState(() => _time = picked);
                  },
                  icon: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(_time == null ? 'Time' : _time!.format(context)),
                ),
              ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}