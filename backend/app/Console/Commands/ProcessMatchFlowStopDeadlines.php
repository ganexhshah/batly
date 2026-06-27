<?php

namespace App\Console\Commands;

use App\Services\BattlyCache;
use App\Services\MatchFlowService;
use Illuminate\Console\Command;

class ProcessMatchFlowStopDeadlines extends Command
{
    protected $signature = 'match-flow:process-stop-deadlines';

    protected $description = 'Auto-payout when one-sided stop review deadlines expire';

    public function handle(MatchFlowService $flow): int
    {
        $count = $flow->processExpiredStopReviews();
        if ($count > 0) {
            BattlyCache::flushTournaments();
            $this->info("Processed {$count} expired stop review(s).");
        }

        return self::SUCCESS;
    }
}
