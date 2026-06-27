'use client';

import React, { useState, useMemo } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { apiGet, apiPatch } from '@/lib/api';
import {
  usePlayer,
  useInvalidatePlayers,
  useAdminMatches,
  useAdminDisputes,
  useAdjustWallet,
  adminKeys
} from '@/lib/admin-queries';
import { canAdjustWallet, canManagePlayers, getStoredRole } from '@/lib/role-permissions';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  ArrowLeft, Gamepad2, Coins, Calendar, Loader2, UserX,
  PlusCircle, MinusCircle, FileText, History, ShieldAlert, AlertTriangle, CheckCircle
} from 'lucide-react';
import { cn } from '@/lib/utils';

export default function PlayerHubPage() {
  const { id } = useParams() as { id: string };
  const router = useRouter();
  const queryClient = useQueryClient();
  const { theme } = useAppStore();

  const [activeTab, setActiveTab] = useState('overview');

  // Wallet adjustment form state
  const [adjustAmount, setAdjustAmount] = useState('');
  const [adjustReason, setAdjustReason] = useState('');
  const [isIncrement, setIsIncrement] = useState(true);

  // Revoke state
  const [isRevoking, setIsRevoking] = useState(false);

  const canAdjust = canAdjustWallet(getStoredRole());
  const canManage = canManagePlayers(getStoredRole());

  // Queries
  const { data: player, isLoading: usersLoading } = usePlayer(id);
  const invalidatePlayers = useInvalidatePlayers();
  
  const { data: allMatches = [], isLoading: matchesLoading } = useAdminMatches();
  const { data: disputesData, isLoading: disputesLoading } = useAdminDisputes();
  const adjustWalletMutation = useAdjustWallet();

  // Fetch player-specific wallet transactions
  const { data: userTransactions = [], isLoading: txLoading, refetch: refetchTransactions } = useQuery({
    queryKey: ['admin', 'wallet', 'transactions', 'user', id],
    queryFn: async () => {
      const data = await apiGet(`/admin/wallet/transactions?user_id=${id}`);
      return data.transactions ?? [];
    },
    enabled: !!id,
  });

  // Filter player-specific matches
  const playerMatches = useMemo(() => {
    if (!player) return [];
    return allMatches.filter((m: any) => 
      m.teamA?.toLowerCase() === player.name?.toLowerCase() ||
      m.teamB?.toLowerCase() === player.ign?.toLowerCase()
    );
  }, [allMatches, player]);

  // Filter player disputes (either filer or reported user)
  const playerDisputes = useMemo(() => {
    if (!player || !disputesData?.disputes) return [];
    return disputesData.disputes.filter((d: any) => 
      d.filer?.toLowerCase() === player.name?.toLowerCase()
    );
  }, [disputesData?.disputes, player]);

  const playerReports = useMemo(() => {
    if (!player || !disputesData?.reports) return [];
    return disputesData.reports.filter((r: any) => 
      r.reported_user?.toLowerCase() === player.ign?.toLowerCase() ||
      r.reporter?.toLowerCase() === player.name?.toLowerCase()
    );
  }, [disputesData?.reports, player]);

  // Handlers
  const handleAdjustWallet = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!player || !canAdjust) return;

    const numericAmount = parseFloat(adjustAmount);
    if (isNaN(numericAmount) || numericAmount <= 0) {
      toast.error('Please specify a positive numeric amount.');
      return;
    }

    if (!adjustReason.trim()) {
      toast.error('Please specify adjustment reason.');
      return;
    }

    const finalAmount = isIncrement ? numericAmount : -numericAmount;

    try {
      await adjustWalletMutation.mutateAsync({
        user_id: player.id,
        amount: finalAmount,
        reason: adjustReason,
      });

      toast.success('Wallet balance adjusted successfully!');
      setAdjustAmount('');
      setAdjustReason('');
      refetchTransactions();
      invalidatePlayers();
      queryClient.invalidateQueries({ queryKey: [...adminKeys.players, 'detail', id] });
    } catch (err: any) {
      toast.error('Adjustment failed', { description: err.message });
    }
  };

  const handleRevokePlayer = async () => {
    if (!player) return;
    if (!confirm(`Are you sure you want to permanently delete player ${player.name} account and revoke login access?`)) {
      return;
    }

    try {
      setIsRevoking(true);
      await apiPatch(`/admin/players/${player.id}/status`, { status: 'Revoked' });
      toast.success('Player access revoked.');
      invalidatePlayers();
      router.push('/players');
    } catch (err: any) {
      toast.error('Failed to revoke player access', { description: err.message });
    } finally {
      setIsRevoking(false);
    }
  };

  // UI Helpers
  const statusBadge = (s: string) => {
    const lookup = String(s).toLowerCase();
    if (lookup === 'active') {
      return 'bg-emerald-50 text-emerald-700 border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900';
    }
    return 'bg-amber-50 text-amber-700 border border-amber-100 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900';
  };

  const matchStatusBadge = (status: string) => {
    const lookup = String(status).toLowerCase();
    if (lookup === 'verified') {
      return 'bg-emerald-50 text-emerald-700 border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400';
    }
    if (lookup === 'pending verification' || lookup === 'pending_verification') {
      return 'bg-amber-50 text-amber-700 border border-amber-100 dark:bg-amber-950/20 dark:text-amber-400';
    }
    if (lookup === 'rejected') {
      return 'bg-rose-50 text-rose-700 border border-rose-100 dark:bg-rose-950/20 dark:text-rose-400';
    }
    return 'bg-zinc-100 text-zinc-650 border border-zinc-200 dark:bg-zinc-800/40 dark:text-zinc-400';
  };

  const transactionTypeBadge = (type: string) => {
    const lookup = String(type).toLowerCase();
    if (lookup === 'inflow') {
      return 'bg-emerald-50 text-emerald-700 border border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-450';
    }
    return 'bg-rose-50 text-rose-700 border border-rose-100 dark:bg-rose-950/20 dark:text-rose-455';
  };

  if (usersLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-3">
        <Loader2 className="w-8 h-8 animate-spin text-[#FF6B00]" />
        <span className="text-sm font-semibold text-zinc-400">Retrieving player record...</span>
      </div>
    );
  }

  if (!player) {
    return (
      <div className="p-8 text-center space-y-4 dark:bg-[#07080A] min-h-screen">
        <AlertTriangle className="w-12 h-12 text-amber-500 mx-auto animate-bounce" />
        <h3 className="text-lg font-bold text-zinc-800 dark:text-white">Player Not Found</h3>
        <Button onClick={() => router.push('/players')} className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white">
          <ArrowLeft className="w-4 h-4 mr-2" /> Back to Directory
        </Button>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 space-y-6 bg-zinc-50/50 min-h-screen dark:bg-[#07080A]">
      {/* Header section with back navigation */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-zinc-150 dark:border-zinc-800 pb-5">
        <div className="flex items-center gap-4">
          <Button
            variant="outline"
            size="icon"
            onClick={() => router.push('/players')}
            className="w-9 h-9 rounded-xl border-zinc-200 text-zinc-500 hover:text-zinc-950 bg-white dark:bg-[#0E1015] dark:border-zinc-800 dark:text-zinc-400"
          >
            <ArrowLeft className="w-4 h-4" />
          </Button>

          <Avatar className="w-12 h-12 ring-2 ring-zinc-200 dark:ring-zinc-800">
            {player.avatar_url ? (
              <img src={player.avatar_url} alt={player.name} className="object-cover rounded-full" />
            ) : (
              <AvatarFallback className="text-sm bg-orange-50 text-[#FF6B00] dark:bg-zinc-800 font-extrabold">
                {player.name.split(' ').map((n: string) => n[0]).join('').slice(0, 2).toUpperCase()}
              </AvatarFallback>
            )}
          </Avatar>

          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-black text-zinc-900 dark:text-white tracking-tight">{player.name}</h2>
              <Badge className={cn('border text-[9px] font-bold px-2 py-0.5 rounded-md hover:bg-transparent', statusBadge(player.status))}>
                {player.status.toUpperCase()}
              </Badge>
            </div>
            <p className="text-xs text-zinc-400 font-semibold mt-1">
              Esports Competitor • {player.email}
            </p>
          </div>
        </div>
      </div>

      {/* Main Tabs Container */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
        <TabsList className="bg-zinc-100 dark:bg-zinc-850 p-1 rounded-xl h-10 w-fit">
          <TabsTrigger value="overview" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <Gamepad2 className="w-3.5 h-3.5" /> Profile & Actions
          </TabsTrigger>
          <TabsTrigger value="matches" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <History className="w-3.5 h-3.5" /> Match History ({playerMatches.length})
          </TabsTrigger>
          <TabsTrigger value="ledger" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <FileText className="w-3.5 h-3.5" /> Wallet Ledger ({userTransactions.length})
          </TabsTrigger>
          <TabsTrigger value="disputes" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <ShieldAlert className="w-3.5 h-3.5" /> Auditing ({playerDisputes.length + playerReports.length})
          </TabsTrigger>
        </TabsList>

        {/* Tab 1: Profile & Actions */}
        <TabsContent value="overview" className="space-y-6 outline-none">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Card Left: Profile details */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl lg:col-span-2 dark:bg-[#0E1015] dark:border-zinc-800">
              <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Account Information</CardTitle>
              </CardHeader>
              <CardContent className="p-6">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-zinc-700 dark:text-zinc-300">
                  <div className="p-3.5 rounded-xl border border-zinc-100 dark:border-zinc-800 bg-zinc-50/50 dark:bg-zinc-900/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">In-Game Name (IGN)</span>
                    <span className="font-extrabold text-[#FF6B00] text-sm mt-0.5 block">{player.ign || '—'}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 dark:border-zinc-800 bg-zinc-50/50 dark:bg-zinc-900/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Game UID</span>
                    <span className="font-bold text-zinc-800 dark:text-white text-sm mt-0.5 block">{player.game_uid || '—'}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 dark:border-zinc-800 bg-zinc-50/50 dark:bg-zinc-900/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Current Wallet Balance</span>
                    <span className="font-black text-emerald-600 dark:text-emerald-400 text-sm mt-0.5 block">
                      NPR {parseFloat(String(player.wallet_balance || 0)).toLocaleString()}
                    </span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 dark:border-zinc-800 bg-zinc-50/50 dark:bg-zinc-900/50">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">System Role</span>
                    <span className="font-semibold text-zinc-700 dark:text-zinc-300 text-sm mt-0.5 block">{player.role}</span>
                  </div>
                  <div className="p-3.5 rounded-xl border border-zinc-100 dark:border-zinc-800 bg-zinc-50/50 dark:bg-zinc-900/50 sm:col-span-2">
                    <span className="text-[10px] text-zinc-400 font-bold block uppercase tracking-wider">Registration Date</span>
                    <span className="font-semibold text-zinc-800 dark:text-white text-sm mt-0.5 block">
                      {new Date(player.created_at).toLocaleDateString('en-US', {
                        weekday: 'long', month: 'short', day: 'numeric', year: 'numeric'
                      })}
                    </span>
                  </div>
                </div>

                {canManage && (
                <div className="border-t border-zinc-100 dark:border-zinc-800 mt-6 pt-6 space-y-4">
                  <h4 className="text-xs font-bold text-zinc-800 dark:text-white">Admin Restrictions & Controls</h4>
                  <p className="text-[11px] text-zinc-400">
                    Revoking access blocks sign-in. Wallet balance must be zero before revoke.
                  </p>
                  <Button
                    onClick={handleRevokePlayer}
                    disabled={isRevoking}
                    className="bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold rounded-xl h-10 flex items-center gap-2"
                  >
                    {isRevoking ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserX className="w-4.5 h-4.5" />}
                    Revoke Login Access
                  </Button>
                </div>
                )}
              </CardContent>
            </Card>

            {/* Card Right: Wallet Adjustments Form */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800">
              <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-805 dark:text-white flex items-center gap-1.5">
                  <Coins className="w-4 h-4 text-[#FF8F00]" />
                  Modify Wallet Cash
                </CardTitle>
              </CardHeader>
              <CardContent className="p-6">
                <form onSubmit={handleAdjustWallet} className="space-y-4">
                  <div className="flex items-center gap-2 border border-zinc-150 dark:border-zinc-800 rounded-xl p-1 bg-zinc-50 dark:bg-zinc-900">
                    <Button
                      type="button"
                      onClick={() => setIsIncrement(true)}
                      className={cn(
                        "w-full h-8 text-xs font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all shadow-none",
                        isIncrement 
                          ? "bg-emerald-600 text-white hover:bg-emerald-600" 
                          : "bg-transparent text-zinc-500 hover:bg-zinc-100 dark:hover:bg-zinc-800"
                      )}
                    >
                      <PlusCircle className="w-4.5 h-4.5" />
                      Add Cash
                    </Button>
                    <Button
                      type="button"
                      onClick={() => setIsIncrement(false)}
                      className={cn(
                        "w-full h-8 text-xs font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all shadow-none",
                        !isIncrement 
                          ? "bg-rose-600 text-white hover:bg-rose-600" 
                          : "bg-transparent text-zinc-500 hover:bg-zinc-100 dark:hover:bg-zinc-800"
                      )}
                    >
                      <MinusCircle className="w-4.5 h-4.5" />
                      Deduct
                    </Button>
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Adjustment Amount (NPR)</Label>
                    <Input
                      type="number"
                      value={adjustAmount}
                      onChange={(e) => setAdjustAmount(e.target.value)}
                      placeholder="e.g. 500"
                      className="bg-white h-9 text-xs rounded-lg border-zinc-200 dark:bg-zinc-900 dark:border-zinc-800"
                    />
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Verification Note / Reason</Label>
                    <Input
                      value={adjustReason}
                      onChange={(e) => setAdjustReason(e.target.value)}
                      placeholder="e.g. Prize discrepancy fix"
                      className="bg-white h-9 text-xs rounded-lg border-zinc-200 dark:bg-zinc-900 dark:border-zinc-800"
                    />
                  </div>

                  <Button
                    type="submit"
                    disabled={adjustWalletMutation.isPending}
                    className="w-full bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-bold text-xs h-9 rounded-xl shadow-sm flex items-center justify-center gap-1"
                  >
                    {adjustWalletMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Coins className="w-4 h-4" />}
                    Commit Balance adjustment
                  </Button>
                </form>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Tab 2: Match History Log */}
        <TabsContent value="matches" className="space-y-4 outline-none">
          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 dark:bg-[#0E1015] dark:border-zinc-800">
            <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
              <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Player Match history ledger</CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <Table>
                <TableHeader className="border-zinc-100 bg-zinc-50/50 dark:bg-zinc-900/50 dark:border-zinc-800">
                  <TableRow className="border-zinc-105 dark:border-zinc-800 hover:bg-transparent">
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 pl-6">Match ID</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Tournament Name</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Game</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Achieved Rank</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Prize amount</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Verification status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {matchesLoading ? (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center py-8">
                        <Loader2 className="w-6 h-6 animate-spin mx-auto text-[#FF6B00]" />
                      </TableCell>
                    </TableRow>
                  ) : playerMatches.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center py-10 text-zinc-400 text-xs font-semibold">
                        No registered match history for this competitor.
                      </TableCell>
                    </TableRow>
                  ) : (
                    playerMatches.map((m: any) => (
                      <TableRow key={m.id} className="border-b border-zinc-50 dark:border-zinc-800 hover:bg-zinc-50/30">
                        <TableCell className="font-bold text-xs text-zinc-500 py-3.5 pl-6">{m.id}</TableCell>
                        <TableCell className="text-xs font-bold text-zinc-800 dark:text-white py-3.5">{m.tournament}</TableCell>
                        <TableCell className="text-xs font-semibold text-zinc-500 py-3.5">{m.game}</TableCell>
                        <TableCell className="text-xs font-black text-[#FF6B00] py-3.5">{m.score ?? m.rank ?? '—'}</TableCell>
                        <TableCell className="text-xs font-extrabold text-emerald-600 dark:text-emerald-400 py-3.5">
                          NPR {(m.prizeAmount ?? 0).toLocaleString()}
                        </TableCell>
                        <TableCell className="py-3.5">
                          <Badge className={cn('border text-[9px] font-bold px-2 py-0.5 rounded-md hover:bg-transparent', matchStatusBadge(m.status))}>
                            {m.status}
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Tab 3: Transaction Ledger Log */}
        <TabsContent value="ledger" className="space-y-4 outline-none">
          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 dark:bg-[#0E1015] dark:border-zinc-800">
            <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
              <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Wallet Transaction history</CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <Table>
                <TableHeader className="border-zinc-100 bg-zinc-50/50 dark:bg-zinc-900/50 dark:border-zinc-800">
                  <TableRow className="border-zinc-100 dark:border-zinc-800 hover:bg-transparent">
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 pl-6">Transaction ID</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Type</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Payment Method</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Reference Description</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Value Amount</TableHead>
                    <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 pr-6 text-right">Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {txLoading ? (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center py-8">
                        <Loader2 className="w-6 h-6 animate-spin mx-auto text-[#FF6B00]" />
                      </TableCell>
                    </TableRow>
                  ) : userTransactions.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center py-10 text-zinc-400 text-xs font-semibold">
                        No financial transactions found.
                      </TableCell>
                    </TableRow>
                  ) : (
                    (userTransactions as any[]).map((tx) => (
                      <TableRow key={tx.id} className="border-b border-zinc-50 dark:border-zinc-800 hover:bg-zinc-50/30">
                        <TableCell className="font-extrabold text-xs text-zinc-500 py-3.5 pl-6">{tx.id}</TableCell>
                        <TableCell className="py-3.5">
                          <Badge className={cn('border text-[9px] font-bold px-2 py-0.5 rounded-md hover:bg-transparent', transactionTypeBadge(tx.type))}>
                            {tx.type.toUpperCase()}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-xs font-bold text-zinc-705 dark:text-zinc-350 capitalize py-3.5">
                          {tx.payment_method?.replace('_', ' ') || 'wallet'}
                        </TableCell>
                        <TableCell className="text-xs font-medium text-zinc-650 dark:text-zinc-400 py-3.5">{tx.description}</TableCell>
                        <TableCell className={cn('text-xs font-extrabold py-3.5', tx.type === 'Inflow' ? 'text-emerald-600' : 'text-rose-600')}>
                          {tx.amount}
                        </TableCell>
                        <TableCell className="py-3.5 pr-6 text-right">
                          <Badge className="bg-emerald-50 text-emerald-700 border border-emerald-100 hover:bg-transparent font-extrabold text-[9px] px-2 py-0.5 rounded-md">
                            {tx.status?.toUpperCase()}
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Tab 4: Auditing & Disputes */}
        <TabsContent value="disputes" className="space-y-6 outline-none">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Disputes Filed */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800">
              <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Disputes Filed ({playerDisputes.length})</CardTitle>
              </CardHeader>
              <CardContent className="p-6 space-y-4">
                {disputesLoading ? (
                  <Loader2 className="w-5 h-5 animate-spin mx-auto text-[#FF6B00]" />
                ) : playerDisputes.length === 0 ? (
                  <p className="text-xs text-zinc-400 font-semibold py-8 text-center border border-zinc-150 border-dashed rounded-xl bg-zinc-50/20 dark:border-zinc-800">
                    No result disputes filed by this player.
                  </p>
                ) : (
                  playerDisputes.map((d: any) => (
                    <div key={d.id} className="p-4 rounded-xl border border-zinc-150 dark:border-zinc-800 bg-white dark:bg-zinc-900/50 space-y-3 text-xs shadow-sm">
                      <div className="flex justify-between items-start">
                        <div>
                          <p className="font-bold text-zinc-800 dark:text-white">Tournament: <span className="font-medium text-zinc-450">{d.tournament_title || '—'}</span></p>
                          <p className="text-[10px] text-zinc-400 font-semibold mt-0.5">Type: {d.type?.replace('_', ' ').toUpperCase()}</p>
                        </div>
                        <Badge className="bg-amber-50 text-amber-700 border border-amber-100 text-[9px] font-bold px-2 py-0.5 rounded-md">
                          {d.status?.toUpperCase()}
                        </Badge>
                      </div>
                      <p className="text-zinc-650 dark:text-zinc-400 bg-zinc-50 dark:bg-[#08090C] p-2.5 rounded-lg font-medium border border-zinc-100 dark:border-zinc-800/80 leading-relaxed">
                        {d.reason}
                      </p>
                    </div>
                  ))
                )}
              </CardContent>
            </Card>

            {/* Integrity Reports */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800">
              <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Integrity / Player Reports ({playerReports.length})</CardTitle>
              </CardHeader>
              <CardContent className="p-6 space-y-4">
                {disputesLoading ? (
                  <Loader2 className="w-5 h-5 animate-spin mx-auto text-[#FF6B00]" />
                ) : playerReports.length === 0 ? (
                  <p className="text-xs text-zinc-400 font-semibold py-8 text-center border border-zinc-150 border-dashed rounded-xl bg-zinc-50/20 dark:border-zinc-800">
                    No anti-cheat complaints related to this user.
                  </p>
                ) : (
                  playerReports.map((r: any) => {
                    const isReported = r.reported_user?.toLowerCase() === player.ign?.toLowerCase();
                    return (
                      <div key={r.id} className="p-4 rounded-xl border border-zinc-150 dark:border-zinc-800 bg-white dark:bg-zinc-900/50 space-y-3 text-xs shadow-sm">
                        <div className="flex justify-between items-start">
                          <div>
                            <p className="font-bold text-zinc-800 dark:text-white">
                              Role in report: 
                              <Badge className={cn('ml-2 text-[8px] font-bold', isReported ? 'bg-rose-50 text-rose-600 border border-rose-100' : 'bg-blue-50 text-blue-600 border border-blue-100')}>
                                {isReported ? 'REPORTED TARGET' : 'ACCUSER / REPORTER'}
                              </Badge>
                            </p>
                            <p className="text-[10px] text-zinc-450 mt-0.5">
                              {isReported ? `Reporter: ${r.reporter}` : `Reported User: ${r.reported_user}`}
                            </p>
                          </div>
                          <Badge className="bg-amber-50 text-amber-700 border border-amber-100 text-[9px] font-bold px-2 py-0.5 rounded-md">
                            {r.status?.toUpperCase()}
                          </Badge>
                        </div>
                        <p className="text-zinc-650 dark:text-zinc-400 bg-zinc-50 dark:bg-[#08090C] p-2.5 rounded-lg font-medium border border-zinc-100 dark:border-zinc-800/80 leading-relaxed">
                          {r.reason}
                        </p>
                      </div>
                    );
                  })
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
