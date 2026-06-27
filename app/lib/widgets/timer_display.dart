import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';

// -----------------------------------------------------------------------------
// TIMER DISPLAY WIDGET
// -----------------------------------------------------------------------------
class TimerDisplay extends StatelessWidget {
  final Duration duration;
  final String statusText;

  const TimerDisplay({
    super.key,
    required this.duration,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final isRegistration = statusText == 'REGISTRATION';

    // Format segments
    String val1 = '';
    String label1 = '';
    String val2 = '';
    String label2 = '';
    String val3 = '';
    String label3 = '';

    if (duration.inDays > 0) {
      val1 = duration.inDays.toString().padLeft(2, '0');
      label1 = duration.inDays == 1 ? 'DAY' : 'DAYS';
      val2 = (duration.inHours % 24).toString().padLeft(2, '0');
      label2 = 'HRS';
      val3 = (duration.inMinutes % 60).toString().padLeft(2, '0');
      label3 = 'MIN';
    } else {
      val1 = duration.inHours.toString().padLeft(2, '0');
      label1 = 'HRS';
      val2 = (duration.inMinutes % 60).toString().padLeft(2, '0');
      label2 = 'MIN';
      val3 = (duration.inSeconds % 60).toString().padLeft(2, '0');
      label3 = 'SEC';
    }

    final numStyle = GoogleFonts.poppins(color: context.battlyOnSurface,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final labelStyle = GoogleFonts.poppins(
      color: context.battlyMuted,
      fontSize: 7,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    );

    final colonStyle = GoogleFonts.poppins(color: context.battlyOnSurface.withValues(alpha: 0.6),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isRegistration ? 'ENDS IN' : 'STARTS IN',
          style: GoogleFonts.poppins(
            color: context.battlyMuted,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(val1, style: numStyle),
                Text(label1, style: labelStyle),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 3.0, right: 3.0),
              child: Text(':', style: colonStyle),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(val2, style: numStyle),
                Text(label2, style: labelStyle),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 3.0, right: 3.0),
              child: Text(':', style: colonStyle),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(val3, style: numStyle),
                Text(label3, style: labelStyle),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
