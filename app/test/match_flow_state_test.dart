import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/match_flow_state.dart';

void main() {
  group('MatchFlowState', () {
    test('parses API payload and polls until completed', () {
      final state = MatchFlowState.fromJson({
        'applies': true,
        'phase': 'live',
        'is_owner': false,
        'is_representative': true,
        'representatives': [1, 2],
        'all_ready': true,
        'ready_players': [
          {'user_id': 1, 'name': 'Host', 'is_ready': true, 'is_representative': true},
          {'user_id': 2, 'name': 'Guest', 'is_ready': true, 'is_representative': true},
        ],
        'ready_count': 2,
        'total_players': 2,
        'max_players': 2,
        'timer_expired': false,
        'seconds_remaining': 1200,
      });

      expect(state.applies, isTrue);
      expect(state.phase, MatchFlowState.phaseLive);
      expect(state.shouldPoll, isTrue);
      expect(state.readyPlayers, hasLength(2));
    });

    test('stops polling when completed', () {
      const state = MatchFlowState(applies: true, phase: MatchFlowState.phaseCompleted);
      expect(state.shouldPoll, isFalse);
    });

    test('vote conflict maps to proof review phase constant', () {
      expect(MatchFlowState.phaseProofReview, 'proof_review');
    });
  });
}
