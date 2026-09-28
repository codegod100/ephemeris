String two(int n) => n.toString().padLeft(2, '0');

String fmtTime(DateTime? t, {bool seconds = false}) {
  if (t == null) return '—';
  return seconds ? '${two(t.hour)}:${two(t.minute)}:${two(t.second)}' : '${two(t.hour)}:${two(t.minute)}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

String fmtDuration(Duration? d) {
  if (d == null) return '—';
  return '${d.inHours}h ${two(d.inMinutes.remainder(60))}m';
}

String compassPoint(double az) {
  const pts = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  return pts[((az % 360) / 22.5 + 0.5).floor() % 16];
}

String fmtAz(double az) => '${az.toStringAsFixed(1)}° ${compassPoint(az)}';
String fmtAlt(double alt) => '${alt >= 0 ? '+' : ''}${alt.toStringAsFixed(1)}°';

String fmtLatLon(double lat, double lon) =>
    '${lat.abs().toStringAsFixed(4)}°${lat >= 0 ? 'N' : 'S'}, ${lon.abs().toStringAsFixed(4)}°${lon >= 0 ? 'E' : 'W'}';
