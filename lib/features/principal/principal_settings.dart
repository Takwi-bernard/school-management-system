import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../proprietor/proprietor_format.dart';
import '../proprietor/proprietor_ui.dart';
import 'principal_core.dart';
import 'principal_hub_models.dart';
import 'principal_hub_providers.dart';

/// School rules the principal controls: pass mark, borderline margin,
/// the amount above which the proprietor is alerted, class balancing.
class PrincipalSettingsPage extends ConsumerStatefulWidget {
  final String schoolId;
  final AppStrings strings;
  const PrincipalSettingsPage({super.key, required this.schoolId, required this.strings});

  @override
  ConsumerState<PrincipalSettingsPage> createState() => _PrincipalSettingsPageState();
}

class _PrincipalSettingsPageState extends ConsumerState<PrincipalSettingsPage> {
  final _pass = TextEditingController();
  final _margin = TextEditingController();
  final _threshold = TextEditingController();
  bool _balance = true;
  bool _seeded = false;
  bool _saving = false;

  AppStrings get _s => widget.strings;

  @override
  void dispose() {
    _pass.dispose();
    _margin.dispose();
    _threshold.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.').replaceAll(' ', ''));

  void _seed(PnSettings v) {
    if (_seeded) return;
    _seeded = true;
    String f(double d) => d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
    _pass.text = f(v.passMark);
    _margin.text = f(v.margin);
    _threshold.text = f(v.threshold);
    _balance = v.balance;
  }

  Future<void> _save() async {
    final s = _s;
    final pass = _num(_pass);
    final margin = _num(_margin);
    final threshold = _num(_threshold);
    if (pass == null || pass <= 0 || pass > 20) {
      prSnack(context, s.pn('The pass mark must be between 1 and 20.', 'La barre de passage doit être comprise entre 1 et 20.'));
      return;
    }
    if (margin == null || margin < 0 || margin > 5) {
      prSnack(context, s.pn('The borderline margin must be between 0 and 5.', 'La marge limite doit être comprise entre 0 et 5.'));
      return;
    }
    if (threshold == null || threshold < 0) {
      prSnack(context, s.pn('Enter a valid approval amount (0 or more).', 'Saisissez un montant d\'alerte valide (0 ou plus).'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(principalHubRepositoryProvider).saveSettings(
            widget.schoolId,
            PnSettings(passMark: pass, margin: margin, threshold: threshold, balance: _balance),
          );
      ref.invalidate(pnSettingsProvider(widget.schoolId));
      ref.invalidate(pnOverviewProvider);
      ref.invalidate(pnBoardProvider);
      if (mounted) prSnack(context, s.pn('Settings saved.', 'Paramètres enregistrés.'));
    } catch (e) {
      if (mounted) prSnack(context, pnErr(s, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final theme = Theme.of(context);
    final async = ref.watch(pnSettingsProvider(widget.schoolId));

    return async.when(
      loading: () => const PrPageSkeleton(),
      error: (e, _) => PrError(error: e, strings: s, onRetry: () => ref.invalidate(pnSettingsProvider(widget.schoolId))),
      data: (v) {
        _seed(v);
        return PrPage(
          maxWidth: 860,
          children: [
            PrHeader(
              title: s.pn('School rules', 'Règles de l\'école'),
              subtitle: s.pn('These values are used for report cards, promotion and teacher payments.', 'Ces valeurs servent aux bulletins, à la promotion et aux paiements des enseignants.'),
            ),
            PrReveal(
              child: PnPanel(
                title: s.pn('Academic results', 'Résultats scolaires'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: _pass,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: pnDeco(s.pn('Pass mark (out of 20)', 'Barre de passage (sur 20)'), hint: '10', icon: Icons.flag_outlined),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.pn('Schools differ: 9, 10 or 11. A student whose annual average reaches this mark is promoted.', 'Les écoles diffèrent : 9, 10 ou 11. Un élève dont la moyenne annuelle atteint cette barre est promu.'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _margin,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: pnDeco(s.pn('Borderline margin', 'Marge limite'), hint: '1', icon: Icons.balance_rounded),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.pn('Students below the pass mark by no more than this are flagged "borderline" so the council can review them before they repeat.', 'Les élèves sous la barre de cette marge au plus sont signalés « limite » pour que le conseil les réexamine avant tout redoublement.'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _balance,
                    onChanged: (x) => setState(() => _balance = x),
                    title: Text(s.pn('Spread students evenly across classes', 'Répartir équitablement les élèves entre les classes')),
                    subtitle: Text(s.pn('When promoting, if 1A → 2A is full or missing, use the other classes of the level by free seats.', 'À la promotion, si 1A → 2A est pleine ou absente, utiliser les autres classes du niveau selon les places libres.')),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            PrReveal(
              index: 1,
              child: PnPanel(
                title: s.pn('Money', 'Argent'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: _threshold,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: pnDeco(s.pn('Alert the proprietor from', 'Alerter le promoteur à partir de'), hint: '200000', icon: Icons.notifications_active_outlined, suffix: 'FCFA'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.pn('Any teacher payment or expense of this amount or more is recorded, then flagged on the proprietor\'s dashboard for review. Currently ${pMoney(v.threshold)}.', 'Tout paiement d\'enseignant ou dépense de ce montant ou plus est enregistré, puis signalé sur le tableau de bord du promoteur. Actuellement ${pMoney(v.threshold)}.'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.4),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)) : const Icon(Icons.check_rounded),
                label: Text(s.pn('Save settings', 'Enregistrer')),
              ),
            ),
          ],
        );
      },
    );
  }
}
