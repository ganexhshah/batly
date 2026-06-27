'use client';

import React, { useState, useMemo, useEffect } from 'react';
import { useParams, useRouter, useSearchParams } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { apiGet, apiDelete, apiPost, apiPut } from '@/lib/api';
import { 
  useAdminDisputes, 
  useResolveDispute, 
  useResolveReport,
  adminKeys
} from '@/lib/admin-queries';
import { RequireRole } from '@/components/require-role';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { canResolveDisputes } from '@/lib/role-permissions';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { 
  ChevronLeft, Gamepad, Trophy, Calendar, Play, CheckCircle, 
  MoreVertical, Edit, ShieldAlert, Trash, Users, FileText, 
  DollarSign, AlertTriangle, ArrowLeft, Loader2, UserX
} from 'lucide-react';
import { cn } from '@/lib/utils';

// Helper to parse numeric values from strings (e.g. "NPR 5,000" -> 5000)
function parsePoolAmount(prize: string): number {
  return Number(String(prize).replace(/[^0-9.]/g, '')) || 0;
}

// Helper to preview prize shares
function buildPrizePreview(prize: string, matchFormat: string) {
  const pool = parsePoolAmount(prize);
  if (matchFormat === 'classic') {
    return [
      { label: '1st Place', share: '50%', amount: pool * 0.5 },
      { label: '2nd Place', share: '30%', amount: pool * 0.3 },
      { label: '3rd Place', share: '20%', amount: pool * 0.2 },
    ];
  }
  return [{ label: 'Match Winner', share: '100%', amount: pool }];
}

export default function TournamentHubPage() {
  const { id } = useParams() as { id: string };
  const router = useRouter();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const { theme } = useAppStore();

  const tabFromUrl = searchParams.get('tab') || 'overview';
  const [activeTab, setActiveTab] = useState(tabFromUrl);

  useEffect(() => {
    setActiveTab(tabFromUrl);
  }, [tabFromUrl]);

  const handleTabChange = (value: string) => {
    setActiveTab(value);
    const params = new URLSearchParams(searchParams.toString());
    if (value === 'overview') {
      params.delete('tab');
    } else {
      params.set('tab', value);
    }
    const qs = params.toString();
    router.replace(qs ? `/tournaments/${id}?${qs}` : `/tournaments/${id}`, { scroll: false });
  };

  // Fetch single tournament details
  const { data: detailData, isLoading: detailsLoading, isError: detailsError, error: detailsErr, refetch: refetchDetails } = useQuery({
    queryKey: ['admin', 'tournament-details', id],
    queryFn: async () => {
      const data = await apiGet(`/tournaments/${id}`);
      return data;
    },
    enabled: !!id,
  });

  const { data: disputesData, isLoading: disputesLoading, isError: disputesError, error: disputesErr, refetch: refetchDisputes } = useAdminDisputes();
  const resolveDispute = useResolveDispute();
  const resolveReport = useResolveReport();

  const tournament = detailData?.tournament;
  const participants = detailData?.participants ?? [];

  // Parse start date safely
  const startDate = useMemo(() => {
    if (!tournament?.starts_at) return new Date();
    return new Date(tournament.starts_at);
  }, [tournament?.starts_at]);

  // Map backend status to user badge text
  const statusBadge = (s: string) => {
    const colors: Record<string, string> = {
      open: 'bg-amber-50 text-amber-700 border-amber-100 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900',
      under_review: 'bg-blue-50 text-blue-700 border-blue-100 dark:bg-blue-950/20 dark:text-blue-400 dark:border-blue-900',
      resolved: 'bg-emerald-50 text-emerald-700 border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900',
      dismissed: 'bg-zinc-100 text-zinc-600 border-zinc-200 dark:bg-zinc-800/40 dark:text-zinc-400 dark:border-zinc-800',
      live: 'bg-emerald-50 text-emerald-600 border border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900',
      ongoing: 'bg-emerald-50 text-emerald-600 border border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900',
      upcoming: 'bg-blue-50 text-blue-600 border border-blue-100 dark:bg-blue-950/20 dark:text-blue-400 dark:border-blue-900',
      completed: 'bg-purple-50 text-purple-600 border border-purple-100 dark:bg-purple-950/20 dark:text-purple-400 dark:border-purple-900',
      cancelled: 'bg-rose-50 text-rose-600 border border-rose-100 dark:bg-rose-950/20 dark:text-rose-400 dark:border-rose-900',
    };
    const lookup = String(s || '').toLowerCase();
    return (
      <Badge className={cn(colors[lookup] ?? colors.open, 'border font-extrabold text-[10px] px-2 py-0.5 rounded-md')}>
        {lookup.toUpperCase()}
      </Badge>
    );
  };

  // Kicking participant mutation
  const removeParticipantMutation = useMutation({
    mutationFn: (userId: number) => apiDelete(`/tournaments/${id}/participants/${userId}`),
    onSuccess: () => {
      toast.success('Participant removed and entry fee refunded.');
      refetchDetails();
      queryClient.invalidateQueries({ queryKey: adminKeys.overview });
    },
    onError: (err: any) => {
      toast.error('Failed to kick participant', { description: err.message });
    }
  });

  const handleKickParticipant = (userId: number, userName: string) => {
    if (confirm(`Are you sure you want to kick ${userName}? This will refund their entry fee.`)) {
      removeParticipantMutation.mutate(userId);
    }
  };

  // Filter disputes and reports linked to this tournament
  const activeDisputes = useMemo(() => {
    if (!tournament?.title || !disputesData?.disputes) return [];
    return disputesData.disputes.filter(
      (d: any) => String(d.tournament_title).toLowerCase() === String(tournament.title).toLowerCase()
    );
  }, [tournament?.title, disputesData?.disputes]);

  const activeReports = useMemo(() => {
    if (!tournament?.title || !disputesData?.reports) return [];
    return disputesData.reports.filter(
      (r: any) => String(r.tournament_title).toLowerCase() === String(tournament.title).toLowerCase()
    );
  }, [tournament?.title, disputesData?.reports]);

  const handleResolveDispute = async (disputeId: number, status: string) => {
    try {
      await resolveDispute.mutateAsync({ id: disputeId, status });
      toast.success(`Dispute updated to ${status}`);
    } catch (err: any) {
      toast.error('Failed to resolve dispute', { description: err.message });
    }
  };

  const handleResolveReport = async (reportId: number, status: string) => {
    try {
      await resolveReport.mutateAsync({ id: reportId, status });
      toast.success(`Report updated to ${status}`);
    } catch (err: any) {
      toast.error('Failed to resolve report', { description: err.message });
    }
  };

  if (detailsLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-3">
        <Loader2 className="w-8 h-8 animate-spin text-[#FF6B00]" />
        <span className="text-sm font-semibold text-zinc-400">Loading tournament console...</span>
      </div>
    );
  }

  if (!tournament) {
    return (
      <div className="p-8 text-center space-y-4">
        <AlertTriangle className="w-12 h-12 text-amber-500 mx-auto" />
        <h3 className="text-lg font-bold text-zinc-800">Tournament Not Found</h3>
        <Button onClick={() => router.push('/tournaments')} className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white">
          <ChevronLeft className="w-4 h-4 mr-2" /> Back to Catalog
        </Button>
      </div>
    );
  }

  // Financial Logs calculation
  const entryFeeAmount = parsePoolAmount(tournament.entry_fee || '0');
  const prizePoolAmount = parsePoolAmount(tournament.prize_pool || '0');
  const totalRevenue = participants.length * entryFeeAmount;
  const netBalance = totalRevenue - prizePoolAmount;

  return (
    <div className="p-6 md:p-8 space-y-6 bg-zinc-50/50 min-h-screen dark:bg-[#07080A]">
      {/* Header section with back navigation */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-zinc-150 pb-5">
        <div className="flex items-center gap-3">
          <Button 
            variant="outline" 
            size="icon" 
            onClick={() => router.push('/tournaments')}
            className="w-9 h-9 rounded-xl border-zinc-200 text-zinc-500 hover:text-zinc-950 bg-white"
          >
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-black text-zinc-900 tracking-tight dark:text-white">{tournament.title}</h2>
              {statusBadge(tournament.statusText || 'UPCOMING')}
            </div>
            <p className="text-xs text-zinc-400 font-semibold mt-1">
              Esports Hub • {tournament.game} • {tournament.stage}
            </p>
          </div>
        </div>
      </div>

      {(detailsError || disputesError) && (
        <QueryErrorBanner
          error={detailsErr ?? disputesErr}
          onRetry={() => {
            if (detailsError) refetchDetails();
            if (disputesError) refetchDisputes();
          }}
          title="Failed to load tournament data"
        />
      )}

      {/* Main Tabs Container */}
      <Tabs value={activeTab} onValueChange={handleTabChange} className="space-y-6">
        <TabsList className={cn('bg-zinc-100 dark:bg-zinc-800 p-1 rounded-xl h-10 w-fit')}>
          <TabsTrigger value="overview" className="text-xs font-semibold rounded-lg px-4">
            <Gamepad className="w-3.5 h-3.5 mr-2" /> Overview
          </TabsTrigger>
          <TabsTrigger value="participants" className="text-xs font-semibold rounded-lg px-4">
            <Users className="w-3.5 h-3.5 mr-2" /> Participants ({participants.length})
          </TabsTrigger>
          <TabsTrigger value="disputes" className="text-xs font-semibold rounded-lg px-4">
            <ShieldAlert className="w-3.5 h-3.5 mr-2" /> Disputes ({activeDisputes.length + activeReports.length})
          </TabsTrigger>
          <TabsTrigger value="report" className="text-xs font-semibold rounded-lg px-4">
            <FileText className="w-3.5 h-3.5 mr-2" /> Financial Logs
          </TabsTrigger>
        </TabsList>

        {/* Tab 1: Overview and details */}
        <TabsContent value="overview">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Card Left: Settings properties */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl lg:col-span-2">
              <CardHeader className="border-b border-zinc-50 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800">Tournament Configurations</CardTitle>
              </CardHeader>
              <CardContent className="p-6">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-medium text-zinc-700">
                  <div className="p-3.5 rounded-xl border border-zinc-100 bg-zinc-50/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Game Title</span>
                    <span className="font-extrabold text-zinc-850 text-sm mt-0.5 block">{tournament.game}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 bg-zinc-50/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Stage / Title</span>
                    <span className="font-semibold text-zinc-800 text-sm mt-0.5 block">{tournament.stage}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 bg-zinc-50/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Match Mode</span>
                    <span className="font-semibold text-zinc-800 text-sm mt-0.5 block">{tournament.mode}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 bg-zinc-50/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Match Format</span>
                    <span className="font-semibold text-[#FF6B00] text-sm mt-0.5 block capitalize">
                      {tournament.customSettings?.team_size || 'classic'}
                    </span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 bg-zinc-50/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Prize Pool committed</span>
                    <span className="font-black text-emerald-600 text-sm mt-0.5 block">{tournament.prize_pool || 'Free'}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 bg-zinc-50/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Entry Fee</span>
                    <span className="font-bold text-zinc-800 text-sm mt-0.5 block">{tournament.entry_fee || 'Free'}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 bg-zinc-50/50 sm:col-span-2">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Schedule Time</span>
                    <span className="font-semibold text-zinc-800 text-sm mt-0.5 block">
                      {startDate.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' })} at{' '}
                      {startDate.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>
                </div>

                {/* Progress slots */}
                <div className="space-y-2 mt-6">
                  <div className="flex justify-between text-xs font-bold text-zinc-700">
                    <span>Joined Teams slots</span>
                    <span>{participants.length} / {tournament.max_players}</span>
                  </div>
                  <div className="w-full bg-zinc-100 h-2.5 rounded-full overflow-hidden">
                    <div 
                      className="bg-[#FF6B00] h-full rounded-full transition-all duration-300"
                      style={{ width: `${Math.min(100, (participants.length / tournament.max_players) * 100)}%` }}
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Card Right: Prize breakdown share */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl">
              <CardHeader className="border-b border-zinc-50 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-805">Prize Share Distribution</CardTitle>
              </CardHeader>
              <CardContent className="p-6 space-y-4">
                <div className="rounded-xl border border-orange-100 bg-orange-50/40 p-4 space-y-3">
                  <p className="text-[10px] font-bold text-[#FF6B00] uppercase tracking-wider">
                    {tournament.customSettings?.prize_distribution === 'winner_takes_all'
                      ? 'Winner Takes All distribution'
                      : 'Classic Top 3 Distribution'}
                  </p>
                  
                  {buildPrizePreview(tournament.prize_pool, tournament.customSettings?.prize_distribution === 'winner_takes_all' ? '1v1' : 'classic').map((row) => (
                    <div key={row.label} className="flex items-center justify-between text-xs font-semibold">
                      <span className="text-zinc-650">{row.label} ({row.share})</span>
                      <span className="font-extrabold text-emerald-600">NPR {Math.round(row.amount).toLocaleString()}</span>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Tab 2: Roster list */}
        <TabsContent value="participants">
          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0">
            <CardContent className="p-0">
              <Table>
                <TableHeader className="border-zinc-100 bg-zinc-50/50">
                  <TableRow className="border-zinc-100 hover:bg-transparent">
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Player Name</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">In-Game Name (IGN)</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Game UID</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Fee Paid</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Roster Status</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 text-right">Roster Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {participants.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center py-10 text-zinc-400 text-xs font-semibold">
                        No registered participants joined yet.
                      </TableCell>
                    </TableRow>
                  ) : (
                    participants.map((p: any) => (
                      <TableRow key={p.id} className="border-b border-zinc-50 hover:bg-zinc-50/30">
                        <TableCell className="py-3.5">
                          <div className="flex items-center gap-2.5">
                            {p.avatar_url ? (
                              <img src={p.avatar_url} className="w-8 h-8 rounded-full object-cover shrink-0 border border-zinc-100" />
                            ) : (
                              <div className="w-8 h-8 rounded-full bg-zinc-100 text-zinc-400 flex items-center justify-center shrink-0">
                                <Users className="w-4 h-4" />
                              </div>
                            )}
                            <span className="text-xs font-bold text-zinc-800">{p.name}</span>
                          </div>
                        </TableCell>
                        <TableCell className="text-xs font-bold text-[#FF6B00] py-3.5">{p.ign || '—'}</TableCell>
                        <TableCell className="text-xs font-medium text-zinc-500 py-3.5">{p.game_uid || '—'}</TableCell>
                        <TableCell className="text-xs font-bold text-emerald-600 py-3.5">
                          NPR {Number(p.entry_fee_paid).toLocaleString()}
                        </TableCell>
                        <TableCell className="py-3.5">
                          {p.is_ready ? (
                            <Badge className="bg-emerald-50 text-emerald-700 border-emerald-100 border hover:bg-transparent font-extrabold text-[9px] px-2 py-0.5 rounded-md">
                              READY
                            </Badge>
                          ) : (
                            <Badge className="bg-zinc-50 text-zinc-650 border-zinc-200 border hover:bg-transparent font-extrabold text-[9px] px-2 py-0.5 rounded-md">
                              PENDING
                            </Badge>
                          )}
                        </TableCell>
                        <TableCell className="py-3.5 text-right">
                          <Button
                            variant="ghost"
                            size="sm"
                            disabled={removeParticipantMutation.isPending}
                            onClick={() => handleKickParticipant(p.id, p.name)}
                            className="h-7 text-[10px] rounded-lg font-bold text-rose-500 hover:text-rose-700 hover:bg-rose-50 flex items-center gap-1.5 ml-auto"
                          >
                            <UserX className="w-3.5 h-3.5" />
                            Kick Player
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

        {/* Tab 3: Disputes anti-cheat */}
        <TabsContent value="disputes">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Left disputes */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl">
              <CardHeader className="border-b border-zinc-50 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800">Match Result Disputes ({activeDisputes.length})</CardTitle>
              </CardHeader>
              <CardContent className="p-6 space-y-4">
                {activeDisputes.length === 0 ? (
                  <p className="text-xs text-zinc-400 font-semibold py-8 text-center border border-zinc-100 border-dashed rounded-xl bg-zinc-50/20">
                    No result disputes filed for this tournament.
                  </p>
                ) : (
                  activeDisputes.map((d: any) => (
                    <div key={d.id} className="p-4 rounded-xl border border-zinc-150 bg-white space-y-3 text-xs shadow-sm">
                      <div className="flex justify-between items-start">
                        <div>
                          <p className="font-bold text-zinc-800">Filer: <span className="font-medium text-zinc-500">{d.filer || '—'}</span></p>
                          <p className="text-[10px] text-zinc-400 font-semibold mt-0.5">Type: {d.type?.replace('_', ' ').toUpperCase()}</p>
                        </div>
                        {statusBadge(d.status)}
                      </div>
                      <p className="text-zinc-650 bg-zinc-50 p-2.5 rounded-lg font-medium leading-relaxed border border-zinc-100">{d.reason}</p>
                      
                      {d.status === 'open' && (
                        <RequireRole allow={canResolveDisputes}>
                          <div className="flex gap-2 justify-end pt-1">
                            <Button 
                              size="sm" 
                              variant="outline" 
                              onClick={() => handleResolveDispute(d.id, 'dismissed')} 
                              className="h-7 text-[10px] rounded-lg font-bold border-zinc-200 text-zinc-500 hover:bg-zinc-50"
                            >
                              Dismiss dispute
                            </Button>
                            <Button 
                              size="sm" 
                              onClick={() => handleResolveDispute(d.id, 'resolved')} 
                              className="h-7 text-[10px] rounded-lg font-bold bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white"
                            >
                              Resolve Dispute
                            </Button>
                          </div>
                        </RequireRole>
                      )}
                    </div>
                  ))
                )}
              </CardContent>
            </Card>

            {/* Right reports */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl">
              <CardHeader className="border-b border-zinc-50 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800">Anti-Cheat Player Reports ({activeReports.length})</CardTitle>
              </CardHeader>
              <CardContent className="p-6 space-y-4">
                {activeReports.length === 0 ? (
                  <p className="text-xs text-zinc-400 font-semibold py-8 text-center border border-zinc-100 border-dashed rounded-xl bg-zinc-50/20">
                    No anti-cheat player reports filed.
                  </p>
                ) : (
                  activeReports.map((r: any) => (
                    <div key={r.id} className="p-4 rounded-xl border border-zinc-150 bg-white space-y-3 text-xs shadow-sm">
                      <div className="flex justify-between items-start">
                        <div>
                          <p className="font-bold text-zinc-800">
                            Reported: <span className="font-extrabold text-rose-600">{r.reported_user}</span>
                          </p>
                          <p className="text-[10px] text-zinc-400 font-semibold mt-0.5">Reporter: {r.reporter}</p>
                        </div>
                        {statusBadge(r.status)}
                      </div>
                      <p className="text-zinc-650 bg-zinc-50 p-2.5 rounded-lg font-medium leading-relaxed border border-zinc-100">{r.reason}</p>
                      
                      {r.status === 'open' && (
                        <RequireRole allow={canResolveDisputes}>
                          <div className="flex gap-2 justify-end pt-1">
                            <Button 
                              size="sm" 
                              variant="outline" 
                              onClick={() => handleResolveReport(r.id, 'dismissed')} 
                              className="h-7 text-[10px] rounded-lg font-bold border-zinc-200 text-zinc-500 hover:bg-zinc-50"
                            >
                              Dismiss Report
                            </Button>
                            <Button 
                              size="sm" 
                              onClick={() => handleResolveReport(r.id, 'resolved')} 
                              className="h-7 text-[10px] rounded-lg font-bold bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white"
                            >
                              Resolve / Ban
                            </Button>
                          </div>
                        </RequireRole>
                      )}
                    </div>
                  ))
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Tab 4: Financial reports log */}
        <TabsContent value="report">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Financial Card Summary stats */}
            <div className="lg:col-span-2 space-y-6">
              <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl">
                <CardHeader className="border-b border-zinc-50 pb-4">
                  <CardTitle className="text-sm font-bold text-zinc-800 font-semibold flex items-center gap-1.5">
                    <DollarSign className="w-5 h-5 text-emerald-500" />
                    Gross revenue & Balance sheet
                  </CardTitle>
                </CardHeader>
                <CardContent className="p-6">
                  <div className="rounded-xl border border-zinc-150 p-4 bg-zinc-50/50 space-y-3.5 text-xs font-semibold">
                    <p className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider">Tournament Accounting Summary</p>
                    
                    <div className="flex justify-between items-center">
                      <span className="text-zinc-600 font-medium">Joined Participants</span>
                      <span className="font-extrabold text-zinc-800">{participants.length} Teams</span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-zinc-600 font-medium">Fee per Slot / Team</span>
                      <span className="font-bold text-zinc-800">NPR {entryFeeAmount.toLocaleString()}</span>
                    </div>

                    <div className="flex justify-between items-center border-t border-zinc-200/60 pt-2.5">
                      <span className="text-zinc-650 font-bold">Total Entry Revenue Collected</span>
                      <span className="font-black text-emerald-600 text-sm">NPR {totalRevenue.toLocaleString()}</span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-zinc-600 font-medium">Committed Prize Pool</span>
                      <span className="font-bold text-rose-500">- NPR {prizePoolAmount.toLocaleString()}</span>
                    </div>

                    <hr className="border-zinc-200" />
                    
                    <div className="flex justify-between items-center text-sm font-black pt-1">
                      <span className="text-zinc-800">Net Profit margin / Commission</span>
                      <span className={cn(netBalance >= 0 ? 'text-emerald-600' : 'text-rose-600')}>
                        NPR {netBalance.toLocaleString()}
                      </span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Side-by-side ledger instructions card */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl">
              <CardHeader className="border-b border-zinc-50 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800 flex items-center gap-2">
                  <FileText className="w-4 h-4 text-zinc-400" />
                  Accounting Info
                </CardTitle>
              </CardHeader>
              <CardContent className="p-6 text-xs text-zinc-400 font-medium leading-relaxed space-y-3">
                <p>Gross revenues are calculated live based on current active registrants and their entry fee amount settings.</p>
                <p>If a player is kicked from the roster tab, their transaction refund log is immediately processed, and this ledger is updated in real time.</p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
