import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/patient/app_colors.dart';
import '../screens/patient/ui_kit.dart';

/// What the resident answered: 1-5 stars and an optional comment, or a skip
/// (rating null).
typedef RatingAnswer = ({int? rating, String? comment});

/// "How was the response to your SOS?" with 5 stars. Returns null when the
/// dialog was closed without an answer (asked again next time).
Future<RatingAnswer?> showRatingDialog(
  BuildContext context, {
  required String title,
  required String? gobikerName,
  required IconData icon,
}) {
  return showDialog<RatingAnswer>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _RatingDialog(title: title, gobikerName: gobikerName, icon: icon),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({
    required this.title,
    required this.gobikerName,
    required this.icon,
  });

  final String title;
  final String? gobikerName;
  final IconData icon;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  static const _labels = ['Poor', 'Fair', 'Good', 'Very good', 'Excellent'];
  static const _star = Color(0xFFF5A524);

  int _rating = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.gobikerName;
    return AlertDialog(
      icon: Icon(widget.icon, color: AppColors.orangeText, size: 36),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name == null
                  ? 'Rate the GoBiker who helped you.'
                  : 'Rate $name, the GoBiker who helped you.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  Semantics(
                    button: true,
                    selected: _rating == i,
                    label: '$i star${i == 1 ? '' : 's'}',
                    child: IconButton(
                      iconSize: 38,
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _rating = i);
                      },
                      icon: Icon(
                        i <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i <= _rating ? _star : AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 22,
              child: Text(
                _rating == 0 ? 'Tap a star' : _labels[_rating - 1],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Add a comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: 'Submit',
              onPressed: _rating == 0
                  ? null
                  : () => Navigator.pop<RatingAnswer>(context, (
                      rating: _rating,
                      comment: _comment.text.trim().isEmpty
                          ? null
                          : _comment.text.trim(),
                    )),
            ),
            QuietButton(
              label: 'Skip',
              onPressed: () => Navigator.pop<RatingAnswer>(context, (
                rating: null,
                comment: null,
              )),
            ),
          ],
        ),
      ],
    );
  }
}
