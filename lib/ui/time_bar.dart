import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'format.dart';

/// Stellarium-style time controls: step back/forward, pause, jump to now.
class TimeBar extends StatelessWidget {
  final AppState app;
  const TimeBar({super.key, required this.app});

  Future<void> _pickDateTime(BuildContext context) async {
    final now = app.now;
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    app.setTime(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final t = app.now;
    Widget step(String label, Duration d) => InkWell(
          onTap: () => app.shiftTime(d),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _pickDateTime(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(app.isLive ? Icons.circle : Icons.history,
                    size: 10, color: app.isLive ? Colors.greenAccent : Colors.orangeAccent),
                const SizedBox(width: 6),
                Text('${fmtDate(t)}  ${fmtTime(t, seconds: true)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.edit_calendar, size: 16, color: Colors.white54),
              ],
            ),
          ),
          FittedBox(
            child: Row(
              children: [
                step('−1d', const Duration(days: -1)),
                step('−1h', const Duration(hours: -1)),
                step('−10m', const Duration(minutes: -10)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(app.paused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                  onPressed: app.togglePause,
                ),
                TextButton(
                  onPressed: app.isLive ? null : app.resetTime,
                  child: const Text('NOW'),
                ),
                step('+10m', const Duration(minutes: 10)),
                step('+1h', const Duration(hours: 1)),
                step('+1d', const Duration(days: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
