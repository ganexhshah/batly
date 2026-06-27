'use client';

import React, { useState, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { AdminPageHeader } from '@/components/admin/AdminPageHeader';
import { DataTableSkeleton } from '@/components/admin/DataTableSkeleton';
import { ProofGallery } from '@/components/admin/ProofGallery';
import {
  usePendingResults,
  useApproveResults,
  useRejectResults,
  useAdminMatches,
  useVerifyMatch,
  useRejectMatch,
} from '@/lib/admin-queries';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import {
  Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetFooter,
} from '@/components/ui/sheet';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  CheckCircle, XCircle, Eye, Loader2, Trophy, ShieldCheck,
  Gamepad, Users, DollarSign, Search, FileText, ClipboardCheck, History
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { RequireRole } from '@/components/require-role';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { canApproveResults } from '@/lib/role-permissions';

// Form validation schema for match verification
const verifySchema = z.object({
  rank: z.number().min(1).max(100),
  kills: z.number().min(0).max(100),
  points: z.number().min(0).max(500),
  notes: z.string().optional(),
  prize_amount: z.number().min(0).optional(),
});

type VerifyValues = z.infer<typeof verifySchema>;

interface LeaderboardRow {
  user_id: number;
  name: string;
  rank: string | number | null;
  kills: string | number | null;
  points: number | null;
  prize_amount: number;
}

interface PendingTournament {
  id: number;
  title: string;
  status: string;
  current_players: number;
  max_players: number;
  prize_pool: string;
  submitted_at: string | null;
  host: string | null;
  leaderboard: LeaderboardRow[];
}

interface AdminMatch {
  id: string;
  tournament: string;
  teamA: string;
  teamB: string;
  game: string;
  status: string;
  score?: string;
  kills?: string | number;
  points?: number;
  rank?: string | number;
  proofImages?: string[];
  notes?: string;
  prizeAmount?: number;
  roundName?: string;
  mapName?: string;
  roundTime?: string;
}

export default function ResultsApprovalPage() {
  const { theme } = useAppStore();
  
  // Queries & Mutations
  const { data: tournaments = [], isLoading: isTournamentsLoading, isError: tournamentsError, error: tournamentsErr, refetch: refetchTournaments } = usePendingResults();
  const { data: matches = [], isLoading: isMatchesLoading, isError: matchesError, error: matchesErr, refetch: refetchMatches } = useAdminMatches();
  
  const approveTournament = useApproveResults();
  const rejectTournament = useRejectResults();
  
  const verifyMatchMutation = useVerifyMatch();
  const rejectMatchMutation = useRejectMatch();

  // Active View Tab State
  const [activeTab, setActiveTab] = useState('leaderboards');

  // Selection states
  const [selectedTournament, setSelectedTournament] = useState<PendingTournament | null>(null);
  const [selectedMatch, setSelectedMatch] = useState<AdminMatch | null>(null);
  const [verifyingMatch, setVerifyingMatch] = useState<AdminMatch | null>(null);
  
  // Text input states
  const [rejectReason, setRejectReason] = useState('');
  const [matchRejectReason, setMatchRejectReason] = useState('');

  // Filtering states for scorecards
  const [matchSearch, setMatchSearch] = useState('');
  const [matchGameFilter, setMatchGameFilter] = useState('all');

  // React Hook Form for Match verification
  const verifyForm = useForm<VerifyValues>({
    resolver: zodResolver(verifySchema),
    defaultValues: { rank: 1, kills: 0, points: 0, notes: '', prize_amount: 0 },
  });

  // Action handlers
  const handleApproveTournament = async (t: PendingTournament) => {
    try {
      await approveTournament.mutateAsync(t.id);
      toast.success('Tournament results approved and prizes credited!');
      setSelectedTournament(null);
    } catch (err: unknown) {
      toast.error('Tournament approval failed', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const handleRejectTournament = async () => {
    if (!selectedTournament) return;
    try {
      await rejectTournament.mutateAsync({
        tournamentId: selectedTournament.id,
        reason: rejectReason || undefined
      });
      toast.success('Tournament results rejected — Host notified to resubmit');
      setSelectedTournament(null);
      setRejectReason('');
    } catch (err: unknown) {
      toast.error('Rejection failed', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const openVerifyMatch = (m: AdminMatch) => {
    const rankNum = m.rank ? parseInt(String(m.rank).replace(/\D/g, ''), 10) : 1;
    verifyForm.reset({
      rank: rankNum || 1,
      kills: Number(m.kills) || 0,
      points: m.points ?? 0,
      notes: m.notes ?? '',
      prize_amount: m.prizeAmount ?? 0,
    });
    setVerifyingMatch(m);
  };

  const handleVerifyMatchSubmit = async (values: VerifyValues) => {
    if (!verifyingMatch) return;
    try {
      const rawId = verifyingMatch.id.replace('M-', '');
      await verifyMatchMutation.mutateAsync({
        id: rawId,
        payload: {
          rank: values.rank,
          kills: values.kills,
          points: values.points,
          notes: values.notes,
          prize_amount: values.prize_amount,
        },
      });
      toast.success('Match scorecard verified successfully!');
      setVerifyingMatch(null);
    } catch (err: unknown) {
      toast.error('Failed to verify match', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const handleRejectMatch = async () => {
    if (!verifyingMatch) return;
    try {
      const rawId = verifyingMatch.id.replace('M-', '');
      await rejectMatchMutation.mutateAsync({
        id: rawId,
        reason: matchRejectReason || 'Proof details did not match claims.',
      });
      toast.success('Match results rejected');
      setVerifyingMatch(null);
      setMatchRejectReason('');
    } catch (err: unknown) {
      toast.error('Failed to reject match', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  // Calculations for stats badges
  const stats = useMemo(() => {
    const pendingTournamentsCount = tournaments.length;
    const pendingScorecardsCount = (matches as AdminMatch[]).filter(
      (m) => m.status === 'Pending Verification'
    ).length;
    const verifiedCount = (matches as AdminMatch[]).filter(
      (m) => m.status === 'Verified'
    ).length;
    const totalWinningsAwarded = (matches as AdminMatch[])
      .filter((m) => m.status === 'Verified')
      .reduce((sum, m) => sum + (m.prizeAmount ?? 0), 0);

    return {
      pendingTournamentsCount,
      pendingScorecardsCount,
      verifiedCount,
      totalWinningsAwarded,
    };
  }, [tournaments, matches]);

  // Filters logic
  const filteredScorecards = useMemo(() => {
    return (matches as AdminMatch[]).filter((m) => {
      // Exclude Scheduled matches from verification queue
      if (m.status === 'Scheduled') return false;
      
      // Filter out history (which goes to tab 3)
      if (m.status === 'Verified' || m.status === 'Rejected') return false;

      const matchesSearch =
        m.tournament.toLowerCase().includes(matchSearch.toLowerCase()) ||
        m.teamA.toLowerCase().includes(matchSearch.toLowerCase()) ||
        m.id.toLowerCase().includes(matchSearch.toLowerCase());

      const matchesGame =
        matchGameFilter === 'all' ||
        m.game.toLowerCase() === matchGameFilter.toLowerCase();

      return matchesSearch && matchesGame;
    });
  }, [matches, matchSearch, matchGameFilter]);

  const historyRecords = useMemo(() => {
    return (matches as AdminMatch[]).filter((m) => {
      return m.status === 'Verified' || m.status === 'Rejected';
    });
  }, [matches]);

  const matchStatusBadge = (status: string) => {
    const lookup = String(status).toLowerCase();
    if (lookup === 'verified') {
      return 'bg-emerald-50 text-emerald-700 border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900';
    }
    if (lookup === 'pending verification' || lookup === 'pending_verification') {
      return 'bg-amber-50 text-amber-700 border-amber-100 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900';
    }
    if (lookup === 'rejected') {
      return 'bg-rose-50 text-rose-700 border-rose-100 dark:bg-rose-950/20 dark:text-rose-400 dark:border-rose-900';
    }
    return 'bg-zinc-100 text-zinc-650 border-zinc-200 dark:bg-zinc-800/40 dark:text-zinc-400 dark:border-zinc-800';
  };

  const handleRefreshAll = () => {
    refetchTournaments();
    refetchMatches();
    toast.success('Results data synchronized.');
  };

  return (
    <div className="p-6 md:p-8 space-y-6 bg-zinc-50/50 min-h-screen dark:bg-[#07080A]">
      <AdminPageHeader
        title="Results Verification Console"
        description="Verify match scorecards, screenshots, and authorize prize disbursements"
        action={
          <Button variant="outline" size="sm" onClick={handleRefreshAll} className="text-xs h-9 rounded-xl shadow-sm bg-white border-zinc-200">
            Refresh Lists
          </Button>
        }
      />

      {(tournamentsError || matchesError) && (
        <QueryErrorBanner
          error={tournamentsErr ?? matchesErr}
          onRetry={() => {
            if (tournamentsError) refetchTournaments();
            if (matchesError) refetchMatches();
          }}
          title="Failed to load results data"
        />
      )}

      {/* Analytics widgets row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Pending Tournaments</span>
              <span className="text-2xl font-black text-zinc-900 block dark:text-white">{stats.pendingTournamentsCount}</span>
              <span className="text-[9px] text-zinc-400 font-semibold block">Host submissions</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-orange-50 dark:bg-orange-950/25 flex items-center justify-center border border-orange-100 dark:border-orange-900/50 shrink-0">
              <Trophy className="w-5 h-5 text-[#FF6B00]" />
            </div>
          </CardContent>
        </Card>

        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Pending Scorecards</span>
              <span className="text-2xl font-black text-zinc-900 block dark:text-white">{stats.pendingScorecardsCount}</span>
              <span className="text-[9px] text-zinc-400 font-semibold block">Player submissions</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-blue-50 dark:bg-blue-950/25 flex items-center justify-center border border-blue-100 dark:border-blue-900/50 shrink-0">
              <ShieldCheck className="w-5 h-5 text-blue-500" />
            </div>
          </CardContent>
        </Card>

        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Verified Matches</span>
              <span className="text-2xl font-black text-zinc-900 block dark:text-white">{stats.verifiedCount}</span>
              <span className="text-[9px] text-zinc-500 font-bold block text-emerald-500">Payouts final</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-emerald-50 dark:bg-emerald-950/25 flex items-center justify-center border border-emerald-100 dark:border-emerald-900/50 shrink-0">
              <CheckCircle className="w-5 h-5 text-emerald-500" />
            </div>
          </CardContent>
        </Card>

        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Disbursed</span>
              <span className="text-xl font-black text-emerald-600 block dark:text-emerald-400">
                NPR {stats.totalWinningsAwarded.toLocaleString()}
              </span>
              <span className="text-[9px] text-zinc-400 font-semibold block">Verified payouts</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-purple-50 dark:bg-purple-950/25 flex items-center justify-center border border-purple-100 dark:border-purple-900/50 shrink-0">
              <DollarSign className="w-5 h-5 text-purple-500" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Tabs Workspace */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
        <TabsList className="bg-zinc-100 dark:bg-zinc-800 p-1 rounded-xl h-10 w-fit">
          <TabsTrigger value="leaderboards" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <Trophy className="w-3.5 h-3.5" />
            Tournament Leaderboards ({tournaments.length})
          </TabsTrigger>
          <TabsTrigger value="scorecards" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <ShieldCheck className="w-3.5 h-3.5" />
            Player Scorecards ({filteredScorecards.length})
          </TabsTrigger>
          <TabsTrigger value="history" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <History className="w-3.5 h-3.5" />
            Verification Log
          </TabsTrigger>
        </TabsList>

        {/* Tab 1: Tournament Leaderboards (Host reviews) */}
        <TabsContent value="leaderboards" className="space-y-4 outline-none">
          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 dark:bg-[#0E1015] dark:border-zinc-800">
            <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
              <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Awaiting Host Leaderboard Approval</CardTitle>
              <CardDescription className="text-xs dark:text-zinc-400">
                These custom room matches require approving the compiled leaderboard matrix to credit all players.
              </CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              <Table>
                <TableHeader className="border-zinc-100 bg-zinc-50/50 dark:bg-zinc-900/50 dark:border-zinc-800">
                  <TableRow className="border-zinc-100 dark:border-zinc-800 hover:bg-transparent">
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Tournament</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Host</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Players</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Prize Pool</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Submitted At</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isTournamentsLoading ? (
                    <TableRow>
                      <TableCell colSpan={6} className="py-10 text-center">
                        <Loader2 className="w-6 h-6 animate-spin mx-auto text-[#FF6B00]" />
                        <span className="text-xs text-zinc-500 block mt-2 font-semibold">Loading leaderboards...</span>
                      </TableCell>
                    </TableRow>
                  ) : tournaments.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center py-12 text-zinc-400 text-xs font-semibold">
                        No tournament leaderboards pending review.
                      </TableCell>
                    </TableRow>
                  ) : (
                    (tournaments as PendingTournament[]).map((t) => (
                      <TableRow key={t.id} className="border-b border-zinc-50 dark:border-zinc-800 hover:bg-zinc-50/20">
                        <TableCell className="font-extrabold text-xs text-zinc-800 dark:text-white py-3.5">{t.title}</TableCell>
                        <TableCell className="text-xs text-zinc-500 font-medium py-3.5">{t.host ?? '—'}</TableCell>
                        <TableCell className="text-xs font-bold text-zinc-700 dark:text-zinc-300 py-3.5">
                          {t.current_players} / {t.max_players}
                        </TableCell>
                        <TableCell className="text-xs font-black text-[#FF6B00] py-3.5">{t.prize_pool}</TableCell>
                        <TableCell className="text-xs text-zinc-500 font-semibold py-3.5">
                          {t.submitted_at ? new Date(t.submitted_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—'}
                        </TableCell>
                        <TableCell className="text-right py-3.5">
                          <div className="flex justify-end gap-2">
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => setSelectedTournament(t)}
                              className="h-8 text-xs font-bold rounded-lg border-zinc-200 bg-white hover:bg-zinc-50 dark:bg-zinc-900 dark:border-zinc-800 text-zinc-700 dark:text-zinc-300"
                            >
                              <Eye className="w-3.5 h-3.5 mr-1" /> Review Matrix
                            </Button>
                            <RequireRole allow={canApproveResults}>
                              <Button
                                size="sm"
                                disabled={approveTournament.isPending}
                                onClick={() => handleApproveTournament(t)}
                                className="h-8 text-xs font-bold rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white flex items-center gap-1"
                              >
                                {approveTournament.isPending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle className="w-3.5 h-3.5" />}
                                Approve
                              </Button>
                            </RequireRole>
                          </div>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Tab 2: Player Scorecards (Individual Match Reviews) */}
        <TabsContent value="scorecards" className="space-y-4 outline-none">
          {/* Filters controls */}
          <div className="flex flex-col sm:flex-row justify-between gap-4">
            <div className="flex items-center gap-3 flex-1 max-w-sm">
              <div className="relative w-full">
                <Search className="w-4 h-4 text-zinc-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  placeholder="Search scorecards (Match ID, Player)..."
                  value={matchSearch}
                  onChange={(e) => setMatchSearch(e.target.value)}
                  className="bg-white border-zinc-200 pl-9 pr-4 text-xs h-9 rounded-xl dark:bg-[#0E1015] dark:border-zinc-800"
                />
              </div>
            </div>

            <div className="flex items-center gap-2 relative">
              <select
                value={matchGameFilter}
                onChange={(e) => setMatchGameFilter(e.target.value)}
                className="bg-white border border-zinc-200 rounded-xl px-3 py-1.5 text-xs font-semibold text-zinc-700 outline-none pr-8 appearance-none cursor-pointer dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white"
              >
                <option value="all">All Games</option>
                <option value="BGMI">BGMI</option>
                <option value="Valorant">Valorant</option>
                <option value="Free Fire">Free Fire</option>
                <option value="COD Mobile">COD Mobile</option>
              </select>
              <Gamepad className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          </div>

          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 dark:bg-[#0E1015] dark:border-zinc-800">
            <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
              <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Player Scorecard Submissions</CardTitle>
              <CardDescription className="text-xs dark:text-zinc-400">
                Individual player scorecard claims. Cross-verify screenshot uploads before authorizing payout credits.
              </CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              <Table>
                <TableHeader className="border-zinc-100 bg-zinc-50/50 dark:bg-zinc-900/50 dark:border-zinc-800">
                  <TableRow className="border-zinc-100 dark:border-zinc-800 hover:bg-transparent">
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Match ID</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Tournament</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Player</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Game</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Claimed Rank</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Status</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isMatchesLoading ? (
                    <TableRow>
                      <TableCell colSpan={7} className="py-10 text-center">
                        <Loader2 className="w-6 h-6 animate-spin mx-auto text-[#FF6B00]" />
                        <span className="text-xs text-zinc-500 block mt-2 font-semibold">Loading match list...</span>
                      </TableCell>
                    </TableRow>
                  ) : filteredScorecards.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={7} className="text-center py-12 text-zinc-400 text-xs font-semibold">
                        No scorecards pending verification.
                      </TableCell>
                    </TableRow>
                  ) : (
                    filteredScorecards.map((m) => (
                      <TableRow key={m.id} className="border-b border-zinc-50 dark:border-zinc-800 hover:bg-zinc-50/20">
                        <TableCell className="font-bold text-xs text-zinc-500 py-3.5">{m.id}</TableCell>
                        <TableCell className="text-xs font-semibold text-zinc-850 dark:text-white py-3.5">{m.tournament}</TableCell>
                        <TableCell className="text-xs font-bold text-zinc-700 dark:text-zinc-300 py-3.5">
                          {m.teamA} <span className="text-[10px] text-zinc-400 font-medium">({m.teamB})</span>
                        </TableCell>
                        <TableCell className="text-xs font-semibold text-zinc-500 py-3.5">{m.game}</TableCell>
                        <TableCell className="text-xs font-black text-[#FF6B00] py-3.5">{m.score ?? m.rank ?? '—'}</TableCell>
                        <TableCell className="py-3.5">
                          <Badge className={cn('border text-[9px] font-bold px-2 py-0.5 rounded-md hover:bg-transparent', matchStatusBadge(m.status))}>
                            {m.status}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right py-3.5">
                          <div className="flex justify-end gap-2">
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => setSelectedMatch(m)}
                              className="h-8 text-xs font-bold rounded-lg border-zinc-200 bg-white hover:bg-zinc-50 dark:bg-zinc-900 dark:border-zinc-800 text-zinc-700 dark:text-zinc-300"
                            >
                              <Eye className="w-3.5 h-3.5 mr-1" /> View proof
                            </Button>
                            {m.status === 'Pending Verification' && (
                              <RequireRole allow={canApproveResults}>
                                <Button
                                  size="sm"
                                  onClick={() => openVerifyMatch(m)}
                                  className="h-8 text-xs font-bold rounded-lg bg-zinc-900 dark:bg-[#FF6B00] hover:bg-zinc-800 dark:hover:bg-[#FF6B00]/90 text-white"
                                >
                                  <ClipboardCheck className="w-3.5 h-3.5 mr-1" /> Verify
                                </Button>
                              </RequireRole>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Tab 3: History log of verified/rejected match results */}
        <TabsContent value="history" className="space-y-4 outline-none">
          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 dark:bg-[#0E1015] dark:border-zinc-800">
            <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
              <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Results Archive Log</CardTitle>
              <CardDescription className="text-xs dark:text-zinc-400">
                Auditing log of historically verified scorecards and tournament payout approvals.
              </CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              <Table>
                <TableHeader className="border-zinc-100 bg-zinc-50/50 dark:bg-zinc-900/50 dark:border-zinc-800">
                  <TableRow className="border-zinc-100 dark:border-zinc-800 hover:bg-transparent">
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Match ID</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Tournament</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Player</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Game</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Rank</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Payout</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Status</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 text-right">Details</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isMatchesLoading ? (
                    <TableRow>
                      <TableCell colSpan={8} className="py-10 text-center">
                        <Loader2 className="w-6 h-6 animate-spin mx-auto text-[#FF6B00]" />
                        <span className="text-xs text-zinc-500 block mt-2 font-semibold">Loading log...</span>
                      </TableCell>
                    </TableRow>
                  ) : historyRecords.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={8} className="text-center py-12 text-zinc-400 text-xs font-semibold">
                        No closed logs available.
                      </TableCell>
                    </TableRow>
                  ) : (
                    historyRecords.map((m) => (
                      <TableRow key={m.id} className="border-b border-zinc-50 dark:border-zinc-800 hover:bg-zinc-50/20">
                        <TableCell className="font-bold text-xs text-zinc-500 py-3.5">{m.id}</TableCell>
                        <TableCell className="text-xs font-semibold text-zinc-800 dark:text-white py-3.5">{m.tournament}</TableCell>
                        <TableCell className="text-xs font-bold text-zinc-700 dark:text-zinc-300 py-3.5">
                          {m.teamA} <span className="text-[10px] text-zinc-400 font-medium">({m.teamB})</span>
                        </TableCell>
                        <TableCell className="text-xs font-semibold text-zinc-500 py-3.5">{m.game}</TableCell>
                        <TableCell className="text-xs font-bold text-zinc-700 dark:text-zinc-300 py-3.5">{m.score ?? m.rank ?? '—'}</TableCell>
                        <TableCell className="text-xs font-black text-emerald-600 dark:text-emerald-400 py-3.5">
                          NPR {(m.prizeAmount ?? 0).toLocaleString()}
                        </TableCell>
                        <TableCell className="py-3.5">
                          <Badge className={cn('border text-[9px] font-bold px-2 py-0.5 rounded-md hover:bg-transparent', matchStatusBadge(m.status))}>
                            {m.status}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right py-3.5">
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => setSelectedMatch(m)}
                            className="h-8 text-xs font-bold rounded-lg border-zinc-200 bg-white hover:bg-zinc-50 dark:bg-zinc-900 dark:border-zinc-800 text-zinc-700 dark:text-zinc-300"
                          >
                            <Eye className="w-3.5 h-3.5" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Sheet Modal 1: Review Tournament Leaderboard (Tab 1 Drawer) */}
      <Sheet open={!!selectedTournament} onOpenChange={(open) => !open && setSelectedTournament(null)}>
        <SheetContent className={cn('sm:max-w-xl overflow-y-auto bg-white border-l border-zinc-200 shadow-xl dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white')}>
          <SheetHeader className="pb-4 border-b border-zinc-50 dark:border-zinc-800">
            <SheetTitle className="text-base font-extrabold text-zinc-900 dark:text-white">{selectedTournament?.title}</SheetTitle>
            <SheetDescription className="text-xs text-zinc-400 font-semibold mt-1">
              Host: {selectedTournament?.host} · Roster: {selectedTournament?.leaderboard.length} registrants
            </SheetDescription>
          </SheetHeader>
          
          {selectedTournament && (
            <div className="space-y-6 py-5">
              <div className="rounded-xl border border-zinc-200 dark:border-zinc-800 overflow-hidden bg-white dark:bg-[#08090C]">
                <Table>
                  <TableHeader className="bg-zinc-50/50 dark:bg-zinc-900/50">
                    <TableRow className="border-b border-zinc-100 dark:border-zinc-800">
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-400">Rank</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-400">Player</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-400 text-center">Kills</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-400 text-center">Points</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-400 text-right">Prize Share</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {selectedTournament.leaderboard.map((row) => (
                      <TableRow key={row.user_id} className="border-b border-zinc-50 dark:border-zinc-800/50 hover:bg-zinc-50/30">
                        <TableCell className="text-xs font-black text-zinc-800 dark:text-white py-2.5">
                          {row.rank ? `#${row.rank}` : '—'}
                        </TableCell>
                        <TableCell className="text-xs font-bold text-zinc-700 dark:text-zinc-300 py-2.5">{row.name}</TableCell>
                        <TableCell className="text-xs font-semibold text-center text-zinc-500 py-2.5">{row.kills ?? '—'}</TableCell>
                        <TableCell className="text-xs font-semibold text-center text-zinc-500 py-2.5">{row.points ?? '—'}</TableCell>
                        <TableCell className="text-xs font-extrabold text-right text-emerald-600 dark:text-emerald-400 py-2.5">
                          NPR {row.prize_amount.toLocaleString()}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-bold text-zinc-700 dark:text-zinc-350">Rejection Reason</Label>
                <Input
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder="Optional notes to notify host in case of rejection..."
                  className="text-xs h-10 bg-white border-zinc-200 dark:bg-[#08090C] dark:border-zinc-800"
                />
              </div>

              <SheetFooter className="flex flex-col sm:flex-row gap-2.5 pt-2">
                <RequireRole allow={canApproveResults}>
                  <div className="flex flex-col sm:flex-row gap-2.5 w-full">
                    <Button
                      className="w-full h-10 text-xs font-bold bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white rounded-xl"
                      disabled={rejectTournament.isPending || approveTournament.isPending}
                      onClick={handleRejectTournament}
                      variant="outline"
                    >
                      {rejectTournament.isPending ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <XCircle className="w-4 h-4 mr-2" />}
                      Reject Leaderboard
                    </Button>
                    <Button
                      className="w-full h-10 text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl"
                      disabled={approveTournament.isPending || rejectTournament.isPending}
                      onClick={() => handleApproveTournament(selectedTournament)}
                    >
                      {approveTournament.isPending ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <CheckCircle className="w-4 h-4 mr-2" />}
                      Approve & Pay Prizes
                    </Button>
                  </div>
                </RequireRole>
              </SheetFooter>
            </div>
          )}
        </SheetContent>
      </Sheet>

      {/* Sheet Modal 2: Match Verification Form (Tab 2 Drawer) */}
      <Sheet open={!!verifyingMatch} onOpenChange={(open) => !open && setVerifyingMatch(null)}>
        <SheetContent className={cn('sm:max-w-md overflow-y-auto bg-white border-l border-zinc-200 shadow-xl dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white')}>
          <SheetHeader className="pb-4 border-b border-zinc-50 dark:border-zinc-800">
            <SheetTitle className="text-base font-extrabold text-zinc-900 dark:text-white flex items-center gap-1.5">
              <ShieldCheck className="w-4.5 h-4.5 text-emerald-500" />
              Verify Match Scorecard
            </SheetTitle>
            <SheetDescription className="text-xs text-zinc-400 font-semibold mt-1">
              Match ID: {verifyingMatch?.id} · Player: {verifyingMatch?.teamA} ({verifyingMatch?.teamB})
            </SheetDescription>
          </SheetHeader>

          {verifyingMatch && (
            <div className="space-y-6 py-5">
              <div>
                <Label className="text-xs font-bold text-zinc-500 block mb-2">Screenshot Evidence</Label>
                <ProofGallery images={verifyingMatch.proofImages ?? []} />
              </div>

              <form onSubmit={verifyForm.handleSubmit(handleVerifyMatchSubmit)} className="space-y-4">
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <Label className="text-[10px] font-bold text-zinc-500 uppercase">Rank</Label>
                    <Input type="number" {...verifyForm.register('rank', { valueAsNumber: true })} className="h-9 text-xs" />
                  </div>
                  <div>
                    <Label className="text-[10px] font-bold text-zinc-500 uppercase">Kills</Label>
                    <Input type="number" {...verifyForm.register('kills', { valueAsNumber: true })} className="h-9 text-xs" />
                  </div>
                  <div>
                    <Label className="text-[10px] font-bold text-zinc-500 uppercase">Points</Label>
                    <Input type="number" {...verifyForm.register('points', { valueAsNumber: true })} className="h-9 text-xs" />
                  </div>
                </div>

                <div>
                  <Label className="text-xs font-bold text-zinc-700 dark:text-zinc-350">Prize Payout override (NPR)</Label>
                  <Input type="number" {...verifyForm.register('prize_amount', { valueAsNumber: true })} className="h-9 text-xs mt-1" />
                  <p className="text-[9px] text-zinc-400 font-medium mt-1">
                    Leave at 0 or empty to allow the system to auto-calculate payout based on rank distribution.
                  </p>
                </div>

                <div>
                  <Label className="text-xs font-bold text-zinc-700 dark:text-zinc-350">Admin Notes / Feedback</Label>
                  <Input {...verifyForm.register('notes')} placeholder="Notes visible to audit ledger..." className="h-9 text-xs mt-1" />
                </div>

                <div className="border-t border-zinc-100 dark:border-zinc-800 pt-4 space-y-4">
                  <div className="space-y-1">
                    <Label className="text-xs font-bold text-zinc-700 dark:text-zinc-350">Rejection Feedback</Label>
                    <Input
                      value={matchRejectReason}
                      onChange={(e) => setMatchRejectReason(e.target.value)}
                      placeholder="Specify reasons for rejecting..."
                      className="h-9 text-xs bg-white border-zinc-200"
                    />
                  </div>

                  <SheetFooter className="flex flex-col sm:flex-row gap-2.5 pt-2">
                    <RequireRole allow={canApproveResults}>
                      <div className="flex flex-col sm:flex-row gap-2.5 w-full">
                        <Button
                          type="button"
                          variant="outline"
                          onClick={handleRejectMatch}
                          disabled={rejectMatchMutation.isPending || verifyMatchMutation.isPending}
                          className="w-full h-10 text-xs font-bold text-rose-600 border-rose-200 hover:bg-rose-50 rounded-xl"
                        >
                          {rejectMatchMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <XCircle className="w-4 h-4 mr-2" />}
                          Reject Claim
                        </Button>
                        <Button
                          type="submit"
                          disabled={verifyMatchMutation.isPending || rejectMatchMutation.isPending}
                          className="w-full h-10 text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl"
                        >
                          {verifyMatchMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : <CheckCircle className="w-4 h-4 mr-2" />}
                          Approve & Credit Winnings
                        </Button>
                      </div>
                    </RequireRole>
                  </SheetFooter>
                </div>
              </form>
            </div>
          )}
        </SheetContent>
      </Sheet>

      {/* Dialog Modal 3: View Details (Any Tab Details View) */}
      <Dialog open={!!selectedMatch} onOpenChange={(open) => !open && setSelectedMatch(null)}>
        <DialogContent className={cn('sm:max-w-md bg-white border border-zinc-200 shadow-xl rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white')}>
          <DialogHeader className="pb-3 border-b border-zinc-50 dark:border-zinc-800">
            <DialogTitle className="text-sm font-extrabold text-zinc-900 dark:text-white">Match Details: {selectedMatch?.id}</DialogTitle>
            <DialogDescription className="text-xs text-zinc-400 font-semibold mt-1">
              {selectedMatch?.tournament} · {selectedMatch?.game}
            </DialogDescription>
          </DialogHeader>

          {selectedMatch && (
            <div className="space-y-4 text-xs font-medium py-3 text-zinc-700 dark:text-zinc-300">
              <div className="grid grid-cols-2 gap-4">
                <div className="p-3 rounded-xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80">
                  <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Player / Team</span>
                  <span className="font-extrabold text-zinc-800 dark:text-white text-xs mt-0.5 block">{selectedMatch.teamA}</span>
                </div>
                <div className="p-3 rounded-xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80">
                  <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">In-Game Name</span>
                  <span className="font-semibold text-[#FF6B00] text-xs mt-0.5 block">{selectedMatch.teamB || '—'}</span>
                </div>
                <div className="p-3 rounded-xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80">
                  <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Claimed / Final Rank</span>
                  <span className="font-bold text-zinc-800 dark:text-white text-xs mt-0.5 block">{selectedMatch.score ?? selectedMatch.rank ?? '—'}</span>
                </div>
                <div className="p-3 rounded-xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80">
                  <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider font-extrabold">Payout Winnings</span>
                  <span className="font-extrabold text-emerald-600 dark:text-emerald-400 text-xs mt-0.5 block">
                    NPR {(selectedMatch.prizeAmount ?? 0).toLocaleString()}
                  </span>
                </div>
                {selectedMatch.roundName && (
                  <div className="p-3 rounded-xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80 col-span-2">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Session Details</span>
                    <span className="font-semibold text-zinc-800 dark:text-white text-xs mt-0.5 block">
                      {selectedMatch.roundName} · {selectedMatch.mapName || 'Bermuda'} · {selectedMatch.roundTime || '—'}
                    </span>
                  </div>
                )}
              </div>

              {selectedMatch.notes && (
                <div className="p-3 rounded-xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80">
                  <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Verification Notes</span>
                  <p className="text-zinc-600 dark:text-zinc-400 text-xs mt-1 leading-relaxed">{selectedMatch.notes}</p>
                </div>
              )}

              <div>
                <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider mb-2">Screenshot Evidence</span>
                <ProofGallery images={selectedMatch.proofImages ?? []} />
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
