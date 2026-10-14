import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/status_colors.dart';
import '../proprietor/proprietor_ui.dart';

/// Shared building blocks for the Principal module.
///
/// Language: every Principal screen reads its text through
/// `strings.pn('English', 'Français')`. The language is the school's
/// active locale, so the whole module follows it exactly like the
/// Secretary, Parent and Proprietor modules do.
extension PrincipalStrings on AppStrings {
  String pn(String en, String fr) => isFrench ? fr : en;
}

// ============================================================ errors

/// Turns any failure into a sentence the principal can act on. The
/// database raises short codes (for example `class_full:Form 2A:61:60`);
/// those are translated here so nobody ever sees a raw exception.
String pnErr(AppStrings s, Object e) {
  final raw = e is PostgrestException ? '${e.message} ${e.details ?? ''}' : e.toString();
  final m = raw.toLowerCase();

  if (m.contains('class_full')) {
    final match = RegExp(r'class_full:([^:]+):(\d+):(\d+)').firstMatch(raw);
    if (match != null) {
      return s.pn(
        '${match.group(1)} is full (${match.group(2)} of ${match.group(3)} seats). Raise its capacity or choose another class.',
        '${match.group(1)} est pleine (${match.group(2)} places sur ${match.group(3)}). Augmentez sa capacité ou choisissez une autre classe.',
      );
    }
    return s.pn('That class is full.', 'Cette classe est pleine.');
  }
  if (m.contains('run_step0_first')) {
    return s.pn('A database update is missing. Ask your administrator to run the Step 0 script.', 'Une mise à jour de la base de données manque. Demandez à votre administrateur d\'exécuter le script Étape 0.');
  }
  if (m.contains('could not find the function') || m.contains('schema cache')) {
    return s.pn('A database update is missing. Ask your administrator to run the latest migration.', 'Une mise à jour de la base de données manque. Demandez à votre administrateur d\'exécuter la dernière migration.');
  }
  const map = <String, List<String>>{
    'not_allowed': ['You are not allowed to do this.', 'Vous n\'êtes pas autorisé à faire cela.'],
    'year_name_required': ['Enter a name for the academic year.', 'Saisissez un nom pour l\'année scolaire.'],
    'year_dates_invalid': ['The end date must be after the start date.', 'La date de fin doit être postérieure à la date de début.'],
    'duplicate_year': ['An academic year with this name already exists.', 'Une année scolaire portant ce nom existe déjà.'],
    'dates_invalid': ['The end date must be after the start date.', 'La date de fin doit être postérieure à la date de début.'],
    'name_required': ['A name is required.', 'Un nom est requis.'],
    'term_in_use': ['This term already has marks or report cards, so it cannot be deleted.', 'Ce trimestre contient déjà des notes ou des bulletins ; il ne peut pas être supprimé.'],
    'sequence_in_use': ['This sequence already has marks or report cards, so it cannot be deleted.', 'Cette séquence contient déjà des notes ou des bulletins ; elle ne peut pas être supprimée.'],
    'same_year': ['Choose two different academic years.', 'Choisissez deux années scolaires différentes.'],
    'run_in_use': ['Marks were already entered in the new year for these students, so this promotion can no longer be undone.', 'Des notes ont déjà été saisies dans la nouvelle année pour ces élèves ; cette promotion ne peut plus être annulée.'],
    'already_undone': ['This promotion was already undone.', 'Cette promotion a déjà été annulée.'],
    'amount_invalid': ['Enter an amount greater than zero.', 'Saisissez un montant supérieur à zéro.'],
    'method_invalid': ['Choose how the money was paid.', 'Choisissez le mode de paiement.'],
    'kind_invalid': ['Choose the type of payment.', 'Choisissez le type de paiement.'],
    'purpose_required': ['Explain why the money was paid (at least 3 letters).', 'Expliquez pourquoi cet argent a été versé (3 lettres minimum).'],
    'paid_to_required': ['Enter who received the money.', 'Indiquez qui a reçu l\'argent.'],
    'place_required': ['Enter where the money was handed over.', 'Indiquez où l\'argent a été remis.'],
    'reference_required': ['Enter the bank transfer reference.', 'Saisissez la référence du virement bancaire.'],
    'reason_required': ['A reason is required.', 'Un motif est requis.'],
    'note_required': ['Write a short note explaining your decision.', 'Rédigez une courte note expliquant votre décision.'],
    'period_required': ['Choose a sequence first.', 'Choisissez d\'abord une séquence.'],
    'term_required': ['Choose a term first.', 'Choisissez d\'abord un trimestre.'],
    'bad_status': ['That status is not valid.', 'Ce statut n\'est pas valide.'],
    'not_found': ['This record no longer exists. Refresh and try again.', 'Cet enregistrement n\'existe plus. Actualisez et réessayez.'],
  };
  for (final entry in map.entries) {
    if (m.contains(entry.key)) return s.pn(entry.value[0], entry.value[1]);
  }
  if (m.contains('socketexception') || m.contains('failed host lookup') || m.contains('network') || m.contains('xmlhttprequest')) {
    return s.pn('No connection. Check your internet and try again.', 'Pas de connexion. Vérifiez votre internet et réessayez.');
  }
  return s.pn('Something went wrong. Please try again.', 'Une erreur est survenue. Veuillez réessayer.');
}

// ============================================================ dialogs & sheets

Future<bool> pnConfirm(
  BuildContext context,
  AppStrings s, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.pn('Cancel', 'Annuler'))),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error) : null,
          child: Text(confirmLabel ?? s.pn('Confirm', 'Confirmer')),
        ),
      ],
    ),
  );
  return res == true;
}

/// Modal bottom sheet that is centred and width-limited on large
/// screens and keyboard-aware on phones.
Future<T?> pnSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: builder,
  );
}

class PnSheetBody extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  const PnSheetBody({super.key, required this.title, this.subtitle, required this.children, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.4)),
          ],
          const SizedBox(height: 18),
          ...children,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: actions),
          ],
        ]),
      ),
    );
  }
}

InputDecoration pnDeco(String label, {String? hint, IconData? icon, String? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      suffixText: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

Future<DateTime?> pnPickDate(BuildContext context, DateTime? initial, {DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 6),
    lastDate: last ?? DateTime(now.year + 6),
  );
}

/// ISO date (yyyy-MM-dd) for RPC parameters.
String pnIso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String pnAvg(num? v) => v == null ? '–' : v.toStringAsFixed(2);

// ============================================================ widgets

class PnChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  const PnChip({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c))),
      ]),
    );
  }
}

Color pnGood() => kSettled;
Color pnWarn() => kPending;
Color pnBad() => kOverdue;

/// Rank medal: top three get a filled tone, the rest an outline.
class PnRank extends StatelessWidget {
  final int? rank;
  final int? total;
  const PnRank({super.key, required this.rank, this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (rank == null) {
      return Text('–', style: TextStyle(color: cs.outline, fontWeight: FontWeight.w700));
    }
    final top = rank! <= 3;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: top ? cs.primary : Colors.transparent,
          border: Border.all(color: top ? cs.primary : cs.outlineVariant, width: 1.4),
        ),
        child: Text('$rank', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: top ? cs.onPrimary : cs.onSurface)),
      ),
      if (total != null) ...[
        const SizedBox(width: 6),
        Text('/ $total', style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w600)),
      ],
    ]);
  }
}

/// Section card with a title row, used by most Principal pages.
class PnPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PnPanel({super.key, this.title, this.subtitle, this.trailing, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrCard(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title!, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.35)),
                    ),
                ]),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        child,
      ]),
    );
  }
}

/// Info banner (neutral) or warning banner.
class PnNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  const PnNotice({super.key, required this.text, this.icon = Icons.info_outline_rounded, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.22))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(height: 1.45, color: theme.colorScheme.onSurface))),
      ]),
    );
  }
}

/// Search field with debounce handled by the caller.
class PnSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const PnSearch({super.key, required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7))),
      ),
    );
  }
}

/// Busy overlay button label.
class PnBusyLabel extends StatelessWidget {
  final bool busy;
  final String label;
  const PnBusyLabel({super.key, required this.busy, required this.label});

  @override
  Widget build(BuildContext context) {
    if (!busy) return Text(label);
    return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2));
  }
}
