import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/backup_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Backup, share and restore.
///
/// Restore lists the backups already on this device rather than opening a system
/// file picker: picking an arbitrary file would need a new dependency, and the
/// case it buys — a file moved here from another phone — is better served by the
/// account sync that is already the primary path. Share exists so a copy can
/// leave the device; getting one back is a v2 problem.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref.read(backupControllerProvider).backupNow();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(file == null ? l10n.backupEmpty : l10n.backupDone),
          ),
        );
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final file = await ref.read(backupServiceProvider).latest();
    if (file == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupNever)));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: <String>[p.basename(file.path)],
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final files = await ref.read(backupServiceProvider).list();

    if (!context.mounted) return;
    if (files.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupNever)));
      return;
    }

    final chosen = await showModalBottomSheet<File>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Text(
                l10n.backupRestore,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final file in files)
              ListTile(
                leading: const Icon(Icons.restore_page_outlined),
                title: Text(_labelFor(context, file)),
                subtitle: Text(_sizeLabel(file)),
                onTap: () => Navigator.of(context).pop(file),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreTitle),
        content: Text(l10n.backupRestoreBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.backupRestoreConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await ref.read(backupControllerProvider).restore(chosen);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.backupRestoreDone(count))),
        );
    } on FormatException {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupRestoreInvalid)));
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.errorUnknown)));
    }
  }

  /// The timestamp encoded in the filename, read back in the user's locale.
  static String _labelFor(BuildContext context, File file) {
    final name = p.basenameWithoutExtension(file.path);
    final stamp = name.replaceFirst('masrouf-backup-', '');
    // `2026-10-05T14-32-07` — the colons were swapped out to keep the name legal
    // on every filesystem, so they go back before parsing.
    final parts = stamp.split('T');
    final parsed = parts.length == 2
        ? DateTime.tryParse('${parts[0]}T${parts[1].replaceAll('-', ':')}Z')
        : null;
    if (parsed == null) return name;
    return DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .add_Hm()
        .format(parsed.toLocal());
  }

  static String _sizeLabel(File file) {
    final kb = (file.lengthSync() / 1024).ceil();
    return '$kb KB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final last = ref.watch(lastBackupAtProvider).value;
    final auto = ref.watch(autoBackupEnabledProvider).value ?? false;
    final formatter = ref.watch(localeCodeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SwitchListTile(
          secondary: const Icon(Icons.backup_outlined),
          title: Text(l10n.backupAuto),
          subtitle: Text(l10n.backupAutoHint),
          value: auto,
          onChanged: (next) => ref
              .read(backupControllerProvider)
              .setAutoEnabled(enabled: next),
        ),
        ListTile(
          leading: const Icon(Icons.save_outlined),
          title: Text(l10n.backupNow),
          subtitle: Text(
            last == null
                ? l10n.backupNever
                : l10n.backupLastAt(
                    DateFormat.yMMMd(formatter).add_Hm().format(last.toLocal()),
                  ),
          ),
          onTap: () => _backupNow(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: Text(l10n.backupShare),
          onTap: () => _share(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore),
          title: Text(l10n.backupRestore),
          onTap: () => _restore(context, ref),
        ),
      ],
    );
  }
}
