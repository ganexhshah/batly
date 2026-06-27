import 'dart:async';

import '../models/match_flow_state.dart';
import 'api_service.dart';

class MatchFlowService {
  MatchFlowService._();
  static final MatchFlowService instance = MatchFlowService._();

  static const pollInterval = Duration(seconds: 4);

  Timer? _pollTimer;
  int? _tournamentId;
  int _subscriberCount = 0;
  void Function(MatchFlowState state)? _onUpdate;
  void Function(Object error)? _onError;

  bool get isPolling => _pollTimer != null;

  Future<MatchFlowState> fetch(int tournamentId) =>
      ApiService.getMatchFlow(tournamentId);

  void startPolling({
    required int tournamentId,
    required void Function(MatchFlowState state) onUpdate,
    void Function(Object error)? onError,
    MatchFlowState? initial,
  }) {
    if (_tournamentId == tournamentId && _pollTimer != null) {
      _subscriberCount++;
      _onUpdate = onUpdate;
      _onError = onError;
      if (initial != null) {
        onUpdate(initial);
      }
      return;
    }

    _stopInternal();
    _tournamentId = tournamentId;
    _subscriberCount = 1;
    _onUpdate = onUpdate;
    _onError = onError;

    if (initial != null) {
      onUpdate(initial);
      if (initial.shouldPoll) {
        _pollOnce();
      }
      return;
    }

    _pollOnce();
  }

  /// Stops polling for [tournamentId]. Other tournaments are unaffected.
  void stopPolling({required int tournamentId}) {
    if (_tournamentId != tournamentId) return;
    _subscriberCount--;
    if (_subscriberCount <= 0) {
      _stopInternal();
    }
  }

  void _stopInternal() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _tournamentId = null;
    _subscriberCount = 0;
    _onUpdate = null;
    _onError = null;
  }

  Future<void> _pollOnce() async {
    final id = _tournamentId;
    final onUpdate = _onUpdate;
    if (id == null || onUpdate == null) return;

    try {
      final state = await fetch(id);
      onUpdate(state);
      _scheduleNext(state);
    } catch (e) {
      _onError?.call(e);
      _pollTimer = Timer(pollInterval, _pollOnce);
    }
  }

  void _scheduleNext(MatchFlowState state) {
    _pollTimer?.cancel();
    if (!state.shouldPoll) {
      _stopInternal();
      return;
    }
    _pollTimer = Timer(pollInterval, _pollOnce);
  }
}
