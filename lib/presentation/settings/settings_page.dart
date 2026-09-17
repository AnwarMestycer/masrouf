import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/data/sync/sync_status.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:masrouf/presentation/auth/controllers/auth_controller.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/digest_providers.dart';
import 'package:masrouf/presentation/settings/export_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Confirms sign-out, and says what it costs when the outbox is not empty.
  ///
  /// Signing out wipes every local row including the outbox, so a user who has
  /// been offline loses those writes for good. The count is already known — this
  /// is the one place it has to be spent rather than merely displayed. The tile
  /// also sits directly under the account row, which makes a mis-tap cheap
  /// without this.
  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    SyncStatus status,
  ) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final action = await showDialog<_SignOutChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.authSignOutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (status.hasPending)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Text(
                  l10n.authSignOutPending(status.pending),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            Text(l10n.authSignOutBody),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_SignOutChoice.cancel),
            child: Text(l10n.actionCancel),
          ),
          if (status.hasPending)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_SignOutChoice.sync),
              child: Text(l10n.authSignOutSyncFirst),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_SignOutChoice.signOut),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.authSignOut),
          ),
        ],
      ),
    );

    switch (action) {
      case _SignOutChoice.sync:
        ref.read(syncEngineProvider).requestSync();
      case _SignOutChoice.signOut:
        await ref.read(authControllerProvider.notifier).signOut();
      case _SignOutChoice.cancel:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          _SyncTile(status: sync),
          const Divider(),

          _SectionHeader(title: l10n.settingsAccount),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user?.email ?? ''),
            subtitle: Text(l10n.settingsAccount),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.authSignOut),
            onTap: () => _confirmSignOut(context, ref, sync),
          ),
          const Divider(),

          _SectionHeader(title: l10n.appTitle),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l10n.accountsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.accounts),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.categoriesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.categories),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(l10n.budgetsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.budgets),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l10n.calendarTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.calendar),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.goalsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.goals),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.plannedTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.planned),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(l10n.recurringTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.recurring),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange_outlined),
            title: Text(l10n.settingsExchangeRates),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.exchangeRates),
          ),
          const Divider(),

          _SectionHeader(title: l10n.settingsTitle),
          const _DigestToggle(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            trailing: DropdownButton<String>(
              value: settings.locale,
              underline: const SizedBox.shrink(),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'fr', child: Text('Français')),
                DropdownMenuItem<String>(value: 'ar', child: Text('العربية')),
                DropdownMenuItem<String>(value: 'en', child: Text('English')),
              ],
              onChanged: (locale) {
                if (locale == null) return;
                ref
                    .read(settingsRepositoryProvider)
                    .save(settings.copyWith(locale: locale));
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settingsTheme),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<ThemeMode>>[
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.system,
                  child: Text(l10n.settingsThemeSystem),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.light,
                  child: Text(l10n.settingsThemeLight),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.dark,
                  child: Text(l10n.settingsThemeDark),
                ),
              ],
              onChanged: (mode) {
                if (mode == null) return;
                ref
                    .read(settingsRepositoryProvider)
                    .save(settings.copyWith(themeMode: mode));
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(l10n.settingsBaseCurrency),
            trailing: DropdownButton<String>(
              value: settings.baseCurrency.code,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<String>>[
                for (final currency in Currency.known)
                  DropdownMenuItem<String>(
                    value: currency.code,
                    child: Text(currency.code),
                  ),
              ],
              onChanged: (code) {
                if (code == null) return;
                // Changing this rewrites every stored aggregate, which the
                // repository handles by rebuilding them from the ledger.
                ref.read(settingsRepositoryProvider).save(
                      settings.copyWith(
                        baseCurrency: Currency.fromCode(code),
                      ),
                    );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: Text(l10n.settingsPayday),
            subtitle: Text(l10n.settingsPaydayDay(settings.paydayDayOfMonth)),
            onTap: () async {
              final day = await showDialog<int>(
                context: context,
                builder: (context) => _PaydayPicker(
                  initial: settings.paydayDayOfMonth,
                  title: l10n.settingsPayday,
                ),
              );
              if (day == null) return;
              await ref
                  .read(settingsRepositoryProvider)
                  .save(settings.copyWith(paydayDayOfMonth: day));
            },
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.settingsExportCsv),
            onTap: () => exportTransactionsCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l10n.settingsSyncStatus),
            subtitle: Text(l10n.syncSyncing),
            onTap: () => ref.read(syncEngineProvider).requestSync(),
          ),
        ],
      ),
    );
  }
}

/// Current sync state, plus how many local changes have not reached the server.
///
/// Shown prominently because the app is deliberately usable offline: the user
/// needs a way to tell "saved on this phone" from "saved everywhere".
class _SyncTile extends ConsumerWidget {
  const _SyncTile({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final (icon, label, color) = switch (status.state) {
      SyncState.syncing => (
          Icons.sync,
          l10n.syncSyncing,
          theme.colorScheme.primary,
        ),
      SyncState.offline => (
          Icons.cloud_off_outlined,
          l10n.syncOffline,
          theme.colorScheme.onSurfaceVariant,
        ),
      SyncState.failed => (
          Icons.sync_problem,
          l10n.syncFailed,
          theme.colorScheme.error,
        ),
      SyncState.idle => (
          Icons.cloud_done_outlined,
          l10n.syncIdle,
          theme.colorScheme.primary,
        ),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle:
          status.hasPending ? Text(l10n.syncPending(status.pending)) : null,
      trailing: TextButton(
        onPressed: () => ref.read(syncEngineProvider).requestSync(),
        child: Text(l10n.actionRetry),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xs),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _PaydayPicker extends StatelessWidget {
  const _PaydayPicker({required this.initial, required this.title});

  final int initial;
  final String title;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              return InkWell(
                onTap: () => Navigator.of(context).pop(day),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: day == initial ? FontWeight.bold : null,
                      color: day == initial
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

/// What the sign-out dialog came back with. Named rather than a `bool?` so the
/// "sync first" branch cannot be confused with a plain cancel.
enum _SignOutChoice { cancel, sync, signOut }

/// The weekly summary switch.
///
/// Asks for the notification permission at the moment the user turns it on,
/// rather than at launch: a permission prompt makes sense when it is attached
/// to something the user just asked for, and is refused out of hand when it is
/// not. If they decline, the switch goes back off and says why — silently
/// staying on while nothing ever arrives would be worse.
class _DigestToggle extends ConsumerWidget {
  const _DigestToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(digestEnabledProvider).value ?? false;

    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: Text(l10n.digestEnable),
      subtitle: Text(l10n.digestHint),
      value: enabled,
      onChanged: (next) async {
        final controller = ref.read(digestControllerProvider);
        if (!next) {
          await controller.setEnabled(enabled: false);
          return;
        }
        final granted =
            await ref.read(digestSchedulerProvider).requestPermission();
        if (!context.mounted) return;
        if (!granted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(l10n.digestPermission)),
            );
          return;
        }
        await controller.setEnabled(enabled: true);
      },
    );
  }
}
