<?php

namespace Tests\Unit;

use App\Services\MatchFlowService;
use PHPUnit\Framework\TestCase;

class MatchFlowServiceTest extends TestCase
{
    public function test_initial_state_phase_is_waiting_ready(): void
    {
        $flow = new MatchFlowService;
        $state = $flow->initialState();

        $this->assertSame(MatchFlowService::PHASE_WAITING_READY, $state['phase']);
        $this->assertNull($state['match_started_at']);
        $this->assertSame([], $state['stop_clicked_by']);
    }

    public function test_phase_constants_are_stable(): void
    {
        $this->assertSame('waiting_ready', MatchFlowService::PHASE_WAITING_READY);
        $this->assertSame('sharing_codes', MatchFlowService::PHASE_SHARING_CODES);
        $this->assertSame('waiting_in_game', MatchFlowService::PHASE_WAITING_IN_GAME);
        $this->assertSame('live', MatchFlowService::PHASE_LIVE);
        $this->assertSame('admin_stop_review', MatchFlowService::PHASE_ADMIN_STOP_REVIEW);
        $this->assertSame('result_vote', MatchFlowService::PHASE_RESULT_VOTE);
        $this->assertSame('proof_review', MatchFlowService::PHASE_PROOF_REVIEW);
        $this->assertSame('completed', MatchFlowService::PHASE_COMPLETED);
    }
}
