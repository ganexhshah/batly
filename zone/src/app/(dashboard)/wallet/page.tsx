'use client';

import React, { useState, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Wallet, ArrowUpRight, ArrowDownLeft, DollarSign, Loader2,
  Search, SlidersHorizontal, ArrowLeftRight, Landmark, Coins, HelpCircle, FileText
} from 'lucide-react';
import { apiPost } from '@/lib/api';
import { RequireRole } from '@/components/require-role';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { canAdjustWallet, canManageWithdrawals } from '@/lib/role-permissions';
import {
  useWalletTransactions,
  useWalletWithdrawals,
  useWithdrawalAction,
  useAdjustWallet,
  useAdminOverview,
  usePlayers,
  isInitialLoad
} from '@/lib/admin-queries';
import { cn } from '@/lib/utils';

// Zod schema for Admin personal withdrawals (prize pool payouts)
const withdrawSchema = z.object({
  amount: z.number().min(10, { message: 'Minimum withdrawal is Rs. 10' }),
  recipient: z.string().min(3, { message: 'Must provide valid gamer withdrawal address' }),
});

type WithdrawValues = z.infer<typeof withdrawSchema>;

export default function WalletPage() {
  const { theme } = useAppStore();
  
  // Queries & Mutations
  const { data: overview, isError: overviewError, error: overviewErr, refetch: refetchOverview } = useAdminOverview();
  const { data: txs, isPending: txsPending, isError: txsError, error: txsErr, refetch: refetchTxs } = useWalletTransactions();
  const { data: withdrawalsData, isError: withdrawalsError, error: withdrawalsErr, refetch: refetchWithdrawals } = useWalletWithdrawals();
  const { data: players = [], refetch: refetchPlayers } = usePlayers();

  const withdrawalAction = useWithdrawalAction();
  const adjustMutation = useAdjustWallet();

  const withdrawals = withdrawalsData ?? [];
  const txsList = txs ?? [];
  const loading = isInitialLoad(txsPending, txs);
  const adminFundPool = overview?.totalRevenue ?? 0;

  // States
  const [activeTab, setActiveTab] = useState('ledger');
  const [withdrawDialogOpen, setWithdrawDialogOpen] = useState(false);

  // Search & Filters states for Tab 1
  const [ledgerSearch, setLedgerSearch] = useState('');
  const [ledgerTypeFilter, setLedgerTypeFilter] = useState('all');
  const [ledgerStatusFilter, setLedgerStatusFilter] = useState('all');

  // Operations Form States for Tab 3
  const [depositUserId, setDepositUserId] = useState('');
  const [depositAmount, setDepositAmount] = useState('');
  const [depositReason, setDepositReason] = useState('');

  const [debitUserId, setDebitUserId] = useState('');
  const [debitAmount, setDebitAmount] = useState('');
  const [debitReason, setDebitReason] = useState('');

  const [transferSourceId, setTransferSourceId] = useState('');
  const [transferTargetId, setTransferTargetId] = useState('');
  const [transferAmount, setTransferAmount] = useState('');
  const [transferReason, setTransferReason] = useState('');
  const [isTransferring, setIsTransferring] = useState(false);

  const withdrawForm = useForm<WithdrawValues>({
    resolver: zodResolver(withdrawSchema),
    defaultValues: { amount: 10, recipient: '' },
  });

  const escrow = overview?.totalPrizePool ?? 0;

  // Handlers
  const handleWithdrawalDecision = async (id: string, action: 'approve' | 'reject') => {
    try {
      await withdrawalAction.mutateAsync({ id, action });
      toast.success(action === 'approve' ? 'Withdrawal approved.' : 'Withdrawal rejected and refunded.');
      refetchTxs();
      refetchPlayers();
    } catch (err: unknown) {
      toast.error(`Failed to ${action} withdrawal`, { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const handleWithdrawSubmit = async (values: WithdrawValues) => {
    if (values.amount > adminFundPool) {
      toast.error('Insufficient wallet balance!', {
        description: `Admin fund pool is Rs. ${adminFundPool.toLocaleString()}, cannot withdraw Rs. ${values.amount}.`,
      });
      return;
    }

    try {
      await apiPost('/admin/wallet/withdraw', values);
      setWithdrawDialogOpen(false);
      withdrawForm.reset();
      toast.success('Withdrawal request submitted!', {
        description: `Rs. ${values.amount} withdrawal is pending transfer.`,
      });
      refetchTxs();
      refetchWithdrawals();
    } catch (err: unknown) {
      toast.error('Failed to process withdrawal', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  // Tab 3 Fund Operations Handlers
  const handleDepositSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!depositUserId) {
      toast.error('Please select a player to credit.');
      return;
    }
    const amount = parseFloat(depositAmount);
    if (isNaN(amount) || amount <= 0) {
      toast.error('Please specify a positive deposit amount.');
      return;
    }
    if (!depositReason.trim()) {
      toast.error('Please specify deposit reference description.');
      return;
    }

    try {
      await adjustMutation.mutateAsync({
        user_id: Number(depositUserId),
        amount: amount,
        reason: depositReason,
      });
      toast.success('Funds successfully credited to player wallet!');
      setDepositUserId('');
      setDepositAmount('');
      setDepositReason('');
      refetchTxs();
      refetchPlayers();
    } catch (err: any) {
      toast.error('Deposit adjustment failed', { description: err.message });
    }
  };

  const handleDebitSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!debitUserId) {
      toast.error('Please select a player to charge.');
      return;
    }
    const amount = parseFloat(debitAmount);
    if (isNaN(amount) || amount <= 0) {
      toast.error('Please specify a positive deduction amount.');
      return;
    }
    if (!debitReason.trim()) {
      toast.error('Please specify charge explanation notes.');
      return;
    }

    try {
      await adjustMutation.mutateAsync({
        user_id: Number(debitUserId),
        amount: -amount,
        reason: debitReason,
      });
      toast.success('Funds successfully debited from player wallet.');
      setDebitUserId('');
      setDebitAmount('');
      setDebitReason('');
      refetchTxs();
      refetchPlayers();
    } catch (err: any) {
      toast.error('Deduction adjustment failed', { description: err.message });
    }
  };

  const handlePlayerTransfer = async (e: React.FormEvent) => {
    e.preventDefault();
    const sourceId = Number(transferSourceId);
    const targetId = Number(transferTargetId);
    const amount = parseFloat(transferAmount);

    if (!transferSourceId || !transferTargetId) {
      toast.error('Please select both sender and recipient players.');
      return;
    }
    if (sourceId === targetId) {
      toast.error('Sender and recipient cannot be the same player.');
      return;
    }
    if (isNaN(amount) || amount <= 0) {
      toast.error('Please specify a positive numeric transfer value.');
      return;
    }
    if (!transferReason.trim()) {
      toast.error('Please enter transfer reference remarks.');
      return;
    }

    try {
      setIsTransferring(true);
      await apiPost('/admin/wallet/transfer', {
        source_user_id: sourceId,
        target_user_id: targetId,
        amount,
        reason: transferReason,
      });

      toast.success('Funds successfully transferred between players!');
      setTransferSourceId('');
      setTransferTargetId('');
      setTransferAmount('');
      setTransferReason('');
      refetchTxs();
      refetchPlayers();
    } catch (err: any) {
      toast.error('Fund transfer adjustment failed', { description: err.message });
    } finally {
      setIsTransferring(false);
    }
  };

  // Dynamic Ledger calculations & filtering
  const filteredTxs = useMemo(() => {
    return txsList.filter((tx) => {
      const matchSearch =
        tx.id.toLowerCase().includes(ledgerSearch.toLowerCase()) ||
        (tx.user?.name || '').toLowerCase().includes(ledgerSearch.toLowerCase()) ||
        (tx.user?.ign || '').toLowerCase().includes(ledgerSearch.toLowerCase()) ||
        (tx.description || '').toLowerCase().includes(ledgerSearch.toLowerCase());

      const matchType =
        ledgerTypeFilter === 'all' ||
        (ledgerTypeFilter === 'Inflow' && tx.type === 'Inflow') ||
        (ledgerTypeFilter === 'Outflow' && tx.type === 'Outflow');

      const matchStatus =
        ledgerStatusFilter === 'all' ||
        tx.status?.toLowerCase() === ledgerStatusFilter.toLowerCase();

      return matchSearch && matchType && matchStatus;
    });
  }, [txsList, ledgerSearch, ledgerTypeFilter, ledgerStatusFilter]);

  const totalSystemDeposits = useMemo(() => {
    return txsList
      .filter((tx) => tx.type === 'Inflow' && (tx.status?.toLowerCase() === 'completed' || tx.status?.toLowerCase() === 'success'))
      .reduce((sum, tx) => sum + (tx.amount_numeric ?? 0), 0);
  }, [txsList]);

  const handleRefreshAll = () => {
    refetchOverview();
    refetchTxs();
    refetchWithdrawals();
    refetchPlayers();
    toast.success('Ledger accounts synchronized.');
  };

  return (
    <div className="p-6 md:p-8 space-y-6 bg-zinc-50/50 dark:bg-[#07080A]">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className={cn('text-2xl font-black tracking-tight text-zinc-900 dark:text-white')}>
            Wallet & Ledger Command
          </h2>
          <p className="text-xs font-semibold text-zinc-400 mt-1">
            Monitor deposits, approve bank withdrawals, and credit payouts
          </p>
        </div>

        <div className="flex gap-2.5">
          <RequireRole allow={canAdjustWallet}>
            <Dialog open={withdrawDialogOpen} onOpenChange={setWithdrawDialogOpen}>
              <DialogTrigger
                render={
                  <Button className="bg-zinc-900 hover:bg-zinc-800 text-white font-extrabold text-xs rounded-xl flex items-center gap-2 h-10 px-4 shadow-sm dark:bg-[#FF6B00] dark:hover:bg-[#FF6B00]/90" />
                }
              >
                <ArrowUpRight className="w-4 h-4" />
                Withdraw Pool Funds
              </DialogTrigger>
              <DialogContent className={cn('sm:max-w-md bg-white border border-zinc-200 shadow-xl rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white')}>
                <DialogHeader>
                  <DialogTitle className="text-sm font-bold">Withdraw Prize Pool Funds</DialogTitle>
                  <DialogDescription className="text-xs text-zinc-400 mt-1">
                    Transfer prize distributions directly to team captains.
                  </DialogDescription>
                </DialogHeader>
                <form onSubmit={withdrawForm.handleSubmit(handleWithdrawSubmit)} className="space-y-4 py-2">
                  <div className="space-y-1">
                    <Label htmlFor="withdraw-amount" className="text-xs font-semibold">Withdraw Amount (NPR)</Label>
                    <Input
                      id="withdraw-amount"
                      type="number"
                      {...withdrawForm.register('amount', { valueAsNumber: true })}
                      className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                    />
                    {withdrawForm.formState.errors.amount && (
                      <p className="text-[10px] text-rose-600 font-semibold">{withdrawForm.formState.errors.amount.message}</p>
                    )}
                  </div>

                  <div className="space-y-1">
                    <Label htmlFor="recipient" className="text-xs font-semibold">Recipient Address / Tag</Label>
                    <Input
                      id="recipient"
                      {...withdrawForm.register('recipient')}
                      placeholder="e.g. CaptainApex007"
                      className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                    />
                    {withdrawForm.formState.errors.recipient && (
                      <p className="text-[10px] text-rose-600 font-semibold">{withdrawForm.formState.errors.recipient.message}</p>
                    )}
                  </div>

                  <DialogFooter className="pt-4">
                    <Button type="submit" className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-bold text-xs rounded-xl h-10 w-full">
                      Execute Withdrawal
                    </Button>
                  </DialogFooter>
                </form>
              </DialogContent>
            </Dialog>
          </RequireRole>

          <Button variant="outline" size="sm" onClick={handleRefreshAll} className="text-xs h-10 rounded-xl bg-white border-zinc-200 shadow-sm dark:bg-[#0E1015] dark:border-zinc-800">
            Sync Ledger
          </Button>
        </div>
      </div>

      {(overviewError || txsError || withdrawalsError) && (
        <QueryErrorBanner
          error={overviewErr ?? txsErr ?? withdrawalsErr}
          onRetry={() => {
            if (overviewError) refetchOverview();
            if (txsError) refetchTxs();
            if (withdrawalsError) refetchWithdrawals();
          }}
          title="Failed to load wallet data"
        />
      )}

      {/* Overview Analytics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Available Balance</span>
              <span className="text-2xl font-black text-zinc-900 block dark:text-white">Rs. {adminFundPool.toLocaleString()}</span>
              <span className="text-[9px] text-zinc-500 font-bold block text-emerald-500">Admin fund pool</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-emerald-50 dark:bg-emerald-950/25 flex items-center justify-center border border-emerald-100 shrink-0">
              <Wallet className="w-5 h-5 text-emerald-500" />
            </div>
          </CardContent>
        </Card>

        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Prize Escrow</span>
              <span className="text-2xl font-black text-zinc-900 block dark:text-white">Rs. {escrow.toLocaleString()}</span>
              <span className="text-[9px] text-zinc-400 font-semibold block">Locked in active pools</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-blue-50 dark:bg-blue-950/25 flex items-center justify-center border border-blue-100 shrink-0">
              <DollarSign className="w-5 h-5 text-blue-500" />
            </div>
          </CardContent>
        </Card>

        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Pending payouts</span>
              <span className="text-2xl font-black text-zinc-900 block dark:text-white">{withdrawals.length} Requests</span>
              <span className="text-[9px] text-zinc-500 font-bold block text-orange-500">Needs verification</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-orange-50 dark:bg-orange-950/25 flex items-center justify-center border border-orange-100 shrink-0">
              <Landmark className="w-5 h-5 text-orange-500" />
            </div>
          </CardContent>
        </Card>

        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Gross user Inflows</span>
              <span className="text-xl font-black text-emerald-600 block dark:text-emerald-450">
                Rs. {totalSystemDeposits.toLocaleString()}
              </span>
              <span className="text-[9px] text-zinc-400 font-semibold block">Total deposits completed</span>
            </div>
            <div className="w-11 h-11 rounded-xl bg-purple-50 dark:bg-purple-950/25 flex items-center justify-center border border-purple-100 shrink-0">
              <Coins className="w-5 h-5 text-purple-500" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Workspace Navigation Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
        <TabsList className="bg-zinc-100 dark:bg-zinc-800 p-1 rounded-xl h-10 w-fit">
          <TabsTrigger value="ledger" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <FileText className="w-3.5 h-3.5" /> Ledger Audit Log ({filteredTxs.length})
          </TabsTrigger>
          <TabsTrigger value="withdrawals" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
            <Landmark className="w-3.5 h-3.5" /> Withdrawal Requests ({withdrawals.length})
          </TabsTrigger>
          <RequireRole allow={canAdjustWallet}>
            <TabsTrigger value="operations" className="text-xs font-semibold rounded-lg px-4 flex items-center gap-1.5">
              <ArrowLeftRight className="w-3.5 h-3.5" /> Fund Operations Console
            </TabsTrigger>
          </RequireRole>
        </TabsList>

        {/* Tab 1: Ledger Audit Log */}
        <TabsContent value="ledger" className="space-y-4 outline-none">
          {/* Filtering controls */}
          <div className="flex flex-col lg:flex-row justify-between items-stretch lg:items-center gap-4">
            <div className="flex flex-wrap items-center gap-3 flex-1">
              <div className="relative max-w-xs w-full">
                <Search className="w-4 h-4 text-zinc-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  placeholder="Search ledger (ID, User, notes)..."
                  value={ledgerSearch}
                  onChange={(e) => setLedgerSearch(e.target.value)}
                  className="bg-white border-zinc-200 pl-9 pr-4 text-xs h-9 rounded-xl w-full dark:bg-[#0E1015] dark:border-zinc-800"
                />
              </div>

              <div className="relative">
                <select
                  value={ledgerTypeFilter}
                  onChange={(e) => setLedgerTypeFilter(e.target.value)}
                  className="bg-white border border-zinc-200 rounded-xl pl-3 pr-8 py-1.5 text-xs font-semibold text-zinc-700 outline-none appearance-none cursor-pointer dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white"
                >
                  <option value="all">All Cash Flows</option>
                  <option value="Inflow">Inflow (+)</option>
                  <option value="Outflow">Outflow (-)</option>
                </select>
                <SlidersHorizontal className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
              </div>

              <div className="relative">
                <select
                  value={ledgerStatusFilter}
                  onChange={(e) => setLedgerStatusFilter(e.target.value)}
                  className="bg-white border border-zinc-200 rounded-xl pl-3 pr-8 py-1.5 text-xs font-semibold text-zinc-700 outline-none appearance-none cursor-pointer dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white"
                >
                  <option value="all">All Statuses</option>
                  <option value="completed">Completed</option>
                  <option value="pending">Pending</option>
                  <option value="failed">Failed</option>
                  <option value="rejected">Rejected</option>
                </select>
                <SlidersHorizontal className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
              </div>
            </div>
          </div>

          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 dark:bg-[#0E1015] dark:border-zinc-800">
            <CardContent className="p-0">
              {loading ? (
                <div className="text-center py-20">
                  <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#FF6B00]" />
                  <p className="text-xs text-zinc-400 mt-3 font-semibold">Retrieving system ledger...</p>
                </div>
              ) : filteredTxs.length === 0 ? (
                <div className="text-center py-12 text-zinc-500 text-xs font-semibold">
                  No transaction ledger rows found matching selection.
                </div>
              ) : (
                <Table>
                  <TableHeader className="border-zinc-100 bg-zinc-50/50 dark:bg-zinc-900/50 dark:border-zinc-800">
                    <TableRow className="border-zinc-100 hover:bg-transparent dark:border-zinc-800">
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3 pl-6">ID</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">Category</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">Player / Details</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">Cash Value</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">Transaction Date</TableHead>
                      <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3 pr-6 text-right">Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filteredTxs.map((tx) => (
                      <TableRow key={tx.id} className="border-b border-zinc-50 dark:border-zinc-800 hover:bg-zinc-50/20">
                        <TableCell className="font-extrabold text-xs text-zinc-400 py-3.5 pl-6">{tx.id}</TableCell>
                        <TableCell className="py-3.5">
                          <Badge className={cn(
                            'border text-[9px] font-bold px-2 py-0.5 rounded-md hover:bg-transparent',
                            tx.transaction_type === 'adjustment' || tx.transaction_type === 'admin_adjustment'
                              ? 'bg-purple-50 text-purple-700 border-purple-100 dark:bg-purple-950/20 dark:text-purple-400'
                              : tx.type === 'Inflow' 
                              ? 'bg-emerald-50 text-emerald-700 border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-450' 
                              : 'bg-rose-50 text-rose-700 border-rose-100 dark:bg-rose-950/20 dark:text-rose-455'
                          )}>
                            {tx.transaction_type === 'adjustment' || tx.transaction_type === 'admin_adjustment' ? (
                              'ADJUSTMENT'
                            ) : (
                              tx.type.toUpperCase()
                            )}
                          </Badge>
                        </TableCell>
                        <TableCell className="py-3.5 text-xs text-zinc-700 dark:text-zinc-300">
                          <span className="font-bold">{tx.user?.name || 'System'}</span>
                          {tx.user?.ign && <span className="text-[10px] text-zinc-400 font-semibold ml-1.5">({tx.user.ign})</span>}
                          <span className="block text-[10px] text-zinc-500 font-medium mt-0.5">{tx.description}</span>
                        </TableCell>
                        <TableCell className={cn('text-xs font-black py-3.5', tx.type === 'Inflow' ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-455')}>
                          {tx.amount}
                        </TableCell>
                        <TableCell className="text-xs font-semibold text-zinc-500 py-3.5">
                          {tx.created_at ? new Date(tx.created_at).toLocaleString() : tx.date}
                        </TableCell>
                        <TableCell className="py-3.5 pr-6 text-right">
                          <Badge className="bg-emerald-50 text-emerald-700 border border-emerald-100 hover:bg-transparent font-extrabold text-[9px] px-2 py-0.5 rounded-md">
                            {tx.status?.toUpperCase()}
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Tab 2: Withdrawal Review Queue */}
        <TabsContent value="withdrawals" className="space-y-4 outline-none">
          <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 dark:bg-[#0E1015] dark:border-zinc-800">
            <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
              <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white">Active Withdrawal Requests Queue</CardTitle>
              <CardDescription className="text-xs dark:text-zinc-400">
                Confirm payout checks. Approving deducts from the balance pool, while rejecting refunds the player.
              </CardDescription>
            </CardHeader>
            <CardContent className="p-6">
              {withdrawals.length === 0 ? (
                <div className="text-center py-10 text-zinc-400 text-xs font-semibold border border-zinc-100 border-dashed rounded-xl bg-zinc-50/20 dark:border-zinc-800">
                  No bank or wallet withdrawal requests pending admin validation.
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {withdrawals.map((tx) => (
                    <div
                      key={tx.id}
                      className="p-4 rounded-xl border border-zinc-150 bg-white dark:bg-[#08090C] dark:border-zinc-800 shadow-sm flex flex-col justify-between gap-4 text-xs font-semibold"
                    >
                      <div className="space-y-2">
                        <div className="flex justify-between items-start">
                          <div>
                            <p className="font-extrabold text-zinc-800 dark:text-white">{tx.user?.name || 'Player'}</p>
                            <p className="text-[10px] text-zinc-400 font-semibold mt-0.5">IGN: {tx.user?.ign || '—'} · UID: {tx.user?.game_uid || '—'}</p>
                          </div>
                          <Badge className="bg-rose-50 text-rose-700 border border-rose-100 text-[10px] font-black">
                            {tx.amount}
                          </Badge>
                        </div>
                        <div className="p-2.5 rounded-lg border border-zinc-100 dark:border-zinc-800/80 bg-zinc-50 dark:bg-zinc-900/60 font-medium text-zinc-650 dark:text-zinc-450">
                          <p><span className="text-zinc-400 font-semibold text-[10px] uppercase block">Payout Method</span> {tx.payment_method?.replace('_', ' ').toUpperCase()}</p>
                          <p className="mt-1"><span className="text-zinc-400 font-semibold text-[10px] uppercase block">Address / Account</span> {tx.description}</p>
                        </div>
                      </div>

                      <div className="flex gap-2 border-t border-zinc-50 dark:border-zinc-800/80 pt-3">
                        <RequireRole allow={canManageWithdrawals}>
                          <div className="flex gap-2 w-full">
                            <Button
                              size="sm"
                              onClick={() => handleWithdrawalDecision(tx.id, 'reject')}
                              variant="outline"
                              disabled={withdrawalAction.isPending}
                              className="w-full h-8 text-xs font-bold text-rose-600 border-rose-200 hover:bg-rose-50 rounded-xl"
                            >
                              Reject / Refund
                            </Button>
                            <Button
                              size="sm"
                              onClick={() => handleWithdrawalDecision(tx.id, 'approve')}
                              disabled={withdrawalAction.isPending}
                              className="w-full h-8 text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl"
                            >
                              Approve payout
                            </Button>
                          </div>
                        </RequireRole>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Tab 3: Fund Operations Console */}
        <RequireRole allow={canAdjustWallet}>
        <TabsContent value="operations" className="space-y-6 outline-none">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            
            {/* Operation 1: Direct Credit Deposit */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white">
              <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white flex items-center gap-1.5">
                  <ArrowDownLeft className="w-4.5 h-4.5 text-emerald-500" />
                  Deposit (Credit Player)
                </CardTitle>
                <CardDescription className="text-xs">Credit user wallet with an audit trail note.</CardDescription>
              </CardHeader>
              <CardContent className="p-5">
                <form onSubmit={handleDepositSubmit} className="space-y-4">
                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Select Target Player</Label>
                    <select
                      value={depositUserId}
                      onChange={(e) => setDepositUserId(e.target.value)}
                      className="w-full bg-white border border-zinc-200 rounded-lg text-xs px-2.5 h-9 outline-none cursor-pointer dark:bg-[#08090C] dark:border-zinc-800"
                    >
                      <option value="">Select a player...</option>
                      {players.map((u: any) => (
                        <option key={u.id} value={u.id}>
                          #{u.id} · {u.name} ({u.ign || 'No IGN'}) — NPR {parseFloat(String(u.wallet_balance || 0)).toLocaleString()}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Credit Amount (NPR)</Label>
                    <Input
                      type="number"
                      value={depositAmount}
                      onChange={(e) => setDepositAmount(e.target.value)}
                      placeholder="e.g. 1000"
                      className="bg-white border-zinc-200 h-9 text-xs rounded-lg dark:bg-[#08090C] dark:border-zinc-800"
                    />
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Reference / Reason</Label>
                    <Input
                      value={depositReason}
                      onChange={(e) => setDepositReason(e.target.value)}
                      placeholder="e.g. Sponsor deposit"
                      className="bg-white border-zinc-200 h-9 text-xs rounded-lg dark:bg-[#08090C] dark:border-zinc-800"
                    />
                  </div>

                  <Button
                    type="submit"
                    disabled={adjustMutation.isPending}
                    className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs h-9 rounded-xl"
                  >
                    {adjustMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Coins className="w-4 h-4 mr-1.5" />}
                    Credit Wallet
                  </Button>
                </form>
              </CardContent>
            </Card>

            {/* Operation 2: Direct Debit Charge */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white">
              <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-800 dark:text-white flex items-center gap-1.5">
                  <ArrowUpRight className="w-4.5 h-4.5 text-rose-500" />
                  Deduct (Charge Player)
                </CardTitle>
                <CardDescription className="text-xs">Debit user wallet balance for penalty or charge.</CardDescription>
              </CardHeader>
              <CardContent className="p-5">
                <form onSubmit={handleDebitSubmit} className="space-y-4">
                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Select Target Player</Label>
                    <select
                      value={debitUserId}
                      onChange={(e) => setDebitUserId(e.target.value)}
                      className="w-full bg-white border border-zinc-200 rounded-lg text-xs px-2.5 h-9 outline-none cursor-pointer dark:bg-[#08090C] dark:border-zinc-800"
                    >
                      <option value="">Select a player...</option>
                      {players.map((u: any) => (
                        <option key={u.id} value={u.id}>
                          #{u.id} · {u.name} ({u.ign || 'No IGN'}) — NPR {parseFloat(String(u.wallet_balance || 0)).toLocaleString()}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Debit Amount (NPR)</Label>
                    <Input
                      type="number"
                      value={debitAmount}
                      onChange={(e) => setDebitAmount(e.target.value)}
                      placeholder="e.g. 500"
                      className="bg-white border-zinc-200 h-9 text-xs rounded-lg dark:bg-[#08090C] dark:border-zinc-800"
                    />
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Debit Reason</Label>
                    <Input
                      value={debitReason}
                      onChange={(e) => setDebitReason(e.target.value)}
                      placeholder="e.g. Tournament fee adjustment"
                      className="bg-white border-zinc-200 h-9 text-xs rounded-lg dark:bg-[#08090C] dark:border-zinc-800"
                    />
                  </div>

                  <Button
                    type="submit"
                    disabled={adjustMutation.isPending}
                    className="w-full bg-rose-600 hover:bg-rose-700 text-white font-bold text-xs h-9 rounded-xl"
                  >
                    {adjustMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Coins className="w-4 h-4 mr-1.5" />}
                    Debit Wallet
                  </Button>
                </form>
              </CardContent>
            </Card>

            {/* Operation 3: Player to Player Transfer */}
            <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl dark:bg-[#0E1015] dark:border-zinc-800 dark:text-white">
              <CardHeader className="border-b border-zinc-50 dark:border-zinc-800 pb-4">
                <CardTitle className="text-sm font-bold text-zinc-805 dark:text-white flex items-center gap-1.5">
                  <ArrowLeftRight className="w-4.5 h-4.5 text-[#FF6B00]" />
                  Inter-Player Fund Transfer
                </CardTitle>
                <CardDescription className="text-xs">Transfer cash directly from one player to another.</CardDescription>
              </CardHeader>
              <CardContent className="p-5">
                <form onSubmit={handlePlayerTransfer} className="space-y-4">
                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Source Player (Debit)</Label>
                    <select
                      value={transferSourceId}
                      onChange={(e) => setTransferSourceId(e.target.value)}
                      className="w-full bg-white border border-zinc-200 rounded-lg text-xs px-2.5 h-9 outline-none cursor-pointer dark:bg-[#08090C] dark:border-zinc-800"
                    >
                      <option value="">Select sender player...</option>
                      {players.map((u: any) => (
                        <option key={u.id} value={u.id}>
                          #{u.id} · {u.name} ({u.ign || 'No IGN'}) — NPR {parseFloat(String(u.wallet_balance || 0)).toLocaleString()}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Recipient Player (Credit)</Label>
                    <select
                      value={transferTargetId}
                      onChange={(e) => setTransferTargetId(e.target.value)}
                      className="w-full bg-white border border-zinc-200 rounded-lg text-xs px-2.5 h-9 outline-none cursor-pointer dark:bg-[#08090C] dark:border-zinc-800"
                    >
                      <option value="">Select recipient player...</option>
                      {players.map((u: any) => (
                        <option key={u.id} value={u.id}>
                          #{u.id} · {u.name} ({u.ign || 'No IGN'}) — NPR {parseFloat(String(u.wallet_balance || 0)).toLocaleString()}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Transfer Amount (NPR)</Label>
                    <Input
                      type="number"
                      value={transferAmount}
                      onChange={(e) => setTransferAmount(e.target.value)}
                      placeholder="e.g. 500"
                      className="bg-white border-zinc-200 h-9 text-xs rounded-lg dark:bg-[#08090C] dark:border-zinc-800"
                    />
                  </div>

                  <div className="space-y-1">
                    <Label className="text-xs font-bold">Transfer Notes</Label>
                    <Input
                      value={transferReason}
                      onChange={(e) => setTransferReason(e.target.value)}
                      placeholder="e.g. Private wager payout"
                      className="bg-white border-zinc-200 h-9 text-xs rounded-lg dark:bg-[#08090C] dark:border-zinc-800"
                    />
                  </div>

                  <Button
                    type="submit"
                    disabled={isTransferring}
                    className="w-full bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-bold text-xs h-9 rounded-xl flex items-center justify-center gap-1.5"
                  >
                    {isTransferring ? <Loader2 className="w-4 h-4 animate-spin" /> : <ArrowLeftRight className="w-4 h-4" />}
                    Execute Transfer
                  </Button>
                </form>
              </CardContent>
            </Card>

          </div>
        </TabsContent>
        </RequireRole>
      </Tabs>
    </div>
  );
}
