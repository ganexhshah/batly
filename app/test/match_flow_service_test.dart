import 'package:app/models/match_flow_state.dart';
import 'package:app/services/match_flow_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stopPolling on inactive tournament is a no-op', () {
    final service = MatchFlowService.instance;

    service.startPolling(
      tournamentId: 10,
      onUpdate: (_) {},
      initial: const MatchFlowState(applies: false),
    );

    expect(() => service.stopPolling(tournamentId: 99), returnsNormally);

    service.stopPolling(tournamentId: 10);
  });

  test('same tournament supports multiple subscribers', () {
    final service = MatchFlowService.instance;
    var updates = 0;

    service.startPolling(
      tournamentId: 20,
      onUpdate: (_) => updates++,
      initial: const MatchFlowState(applies: false),
    );

    service.startPolling(
      tournamentId: 20,
      onUpdate: (_) => updates++,
      initial: const MatchFlowState(applies: false),
    );

    service.stopPolling(tournamentId: 20);
    service.startPolling(
      tournamentId: 20,
      onUpdate: (_) => updates++,
      initial: const MatchFlowState(applies: false),
    );
    service.stopPolling(tournamentId: 20);

    expect(updates, greaterThanOrEqualTo(3));
  });
}
