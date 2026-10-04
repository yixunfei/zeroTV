import 'package:flutter/material.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/l10n/generated/app_localizations.dart';

/// Bottom sheet listing past EPG programmes for catchup playback.
///
/// Returns the picked programme, or null when dismissed.
Future<EpgProgram?> showCatchupSheet(
  BuildContext context,
  List<EpgProgram> programmes,
) {
  // Show latest first.
  final sorted = [...programmes]..sort((a, b) => b.start.compareTo(a.start));
  return showModalBottomSheet<EpgProgram>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.catchupTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final p = sorted[i];
                    return ListTile(
                      title: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_formatRange(context, p)),
                      onTap: () => Navigator.of(context).pop(p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatRange(BuildContext context, EpgProgram p) {
  final start = TimeOfDay.fromDateTime(p.start.toLocal());
  final stop = TimeOfDay.fromDateTime(p.stop.toLocal());
  final date = MaterialLocalizations.of(
    context,
  ).formatShortDate(p.start.toLocal());
  return '$date  ${start.format(context)} – ${stop.format(context)}';
}
