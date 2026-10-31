import 'package:flutter/material.dart';

import '../widgets/app_toast.dart';
import '../widgets/rating_dialog.dart';
import 'app_navigator.dart';
import 'auth_service.dart';

/// After a GoBiker resolves the resident's SOS or records their check-up,
/// the resident is asked to rate that GoBiker (1-5 stars). The server says
/// what is waiting (GET /resident/feedback/pending); this shows it.
class FeedbackPrompt {
  FeedbackPrompt._();
  static final FeedbackPrompt instance = FeedbackPrompt._();

  bool _busy = false;

  /// Events closed without an answer this session: not asked again until the
  /// app restarts.
  final Set<String> _postponed = {};

  /// Shows the rating pop-up if a rating is waiting. Safe to call often.
  ///
  /// Only ever asks about one event at a time, so a resident with a few
  /// unrated visits is not met by a stack of dialogs. The next one comes up
  /// the following time the app is opened or a notification arrives.
  Future<void> check() async {
    final user = AuthService.instance.currentUser;
    if (_busy || user == null || !user.isResident) return;
    _busy = true;
    try {
      final res = await AuthService.instance.callAuthed(
        'GET',
        '/resident/feedback/pending',
      );
      final pending = res.body['pending'];
      if (!res.ok || pending is! Map) return;

      final kind = '${pending['kind']}';
      final subjectId = (pending['subject_id'] as num?)?.toInt();
      if (subjectId == null || _postponed.contains('$kind:$subjectId')) return;

      final context = appNavigatorKey.currentState?.overlay?.context;
      if (context == null || !context.mounted) return;

      final gobiker = pending['gobiker'];
      final answer = await showRatingDialog(
        context,
        title: '${pending['title'] ?? 'Rate your GoBiker'}',
        gobikerName: gobiker is Map ? gobiker['name']?.toString() : null,
        icon: kind == 'sos'
            ? Icons.health_and_safety_rounded
            : Icons.medical_services_rounded,
      );
      // Closed without answering: leave it for the next time the app starts.
      if (answer == null) {
        _postponed.add('$kind:$subjectId');
        return;
      }

      final sent = await AuthService.instance.callAuthed(
        'POST',
        '/resident/feedback',
        body: {
          'kind': kind,
          'subject_id': subjectId,
          'rating': ?answer.rating,
          'comment': ?answer.comment,
        },
      );
      final toastContext = appNavigatorKey.currentState?.overlay?.context;
      if (toastContext == null || !toastContext.mounted) return;

      if (!sent.ok) {
        // Don't ask again this session, so a failing server can't nag.
        _postponed.add('$kind:$subjectId');
        AppToast.show(toastContext, sent.message, type: ToastType.error);
      } else if (answer.rating != null) {
        AppToast.show(
          toastContext,
          'Thank you for your feedback!',
          type: ToastType.success,
        );
      }
    } finally {
      _busy = false;
    }
  }

  void reset() => _postponed.clear();
}
