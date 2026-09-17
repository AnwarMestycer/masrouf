import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Writes the ledger to a CSV file and hands it to the system share sheet.
///
/// Goes through the share sheet rather than writing to a public directory: it
/// needs no storage permission on any Android version, and it lets the file land
/// wherever the user actually wants it — Drive, mail, a spreadsheet app.
Future<void> exportTransactionsCsv(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);

  final result = await ref.read(transactionRepositoryProvider).exportCsv();

  final csv = result.valueOrNull;
  if (csv == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorUnknown)));
    return;
  }

  final directory = await getTemporaryDirectory();
  final stamp = DateTime.now().toIso8601String().split('T').first;
  final file = File(p.join(directory.path, 'masrouf-$stamp.csv'));
  await file.writeAsString(csv);

  // Header row does not count as a transaction.
  final rowCount = '\n'.allMatches(csv.trim()).length;

  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'text/csv')],
      fileNameOverrides: <String>['masrouf-$stamp.csv'],
    ),
  );

  messenger.showSnackBar(
    SnackBar(content: Text(l10n.settingsExportDone(rowCount))),
  );
}
