'use client';
 
import React from 'react';
import dynamic from 'next/dynamic';
import { useAppStore } from '@/store/useAppStore';
import { cn } from '@/lib/utils';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { 
  Users, Trophy, Swords, Wallet, 
  ArrowUpRight, Users2, Award, UserPlus, 
  ArrowRightLeft, HelpCircle, CheckCircle, Flag, ChevronDown, Loader2
} from 'lucide-react';
import { useAdminOverview, useTournamentsRaw, useNotifications, isInitialLoad } from '@/lib/admin-queries';
import Link from 'next/link';
 
// Dynamically import charts to prevent hydration issues
const RevenueChart = dynamic(() => import('@/components/RevenueChart'), { ssr: false });
const TournamentStatusChart = dynamic(() => import('@/components/TournamentStatusChart'), { ssr: false });
 
export default function DashboardOverview() {
  const { theme } = useAppStore();
  const { data: overview, isPending: overviewPending } = useAdminOverview();
  const { data: tournamentsRaw, isPending: tournamentsPending } = useTournamentsRaw();
  const { data: notificationsRaw, isPending: notificationsPending } = useNotifications();

  const recentTournaments = (tournamentsRaw ?? []).slice(0, 4);
  const recentActivities = (notificationsRaw ?? []).slice(0, 5);
  const loading = isInitialLoad(overviewPending, overview)
    || isInitialLoad(tournamentsPending, tournamentsRaw)
    || isInitialLoad(notificationsPending, notificationsRaw);

  const stats = {
    totalUsers: overview?.totalUsers ?? 0,
    activeTournaments: overview?.activeTournaments ?? 0,
    matchesPlayed: overview?.matchesPlayed ?? 0,
    totalRevenue: 'NPR ' + (overview?.totalRevenue ?? 0).toLocaleString(),
    totalPrizePool: 'NPR ' + (overview?.totalPrizePool ?? 0).toLocaleString(),
    newUsers: overview?.newUsers ?? 0,
    totalTransactions: overview?.totalTransactions ?? 0,
    openTickets: overview?.openSupportTickets ?? overview?.openTickets ?? 0,
  };
 
  // Status badge style helper
  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'ONGOING':
        return (
          <Badge className="bg-emerald-50 text-emerald-600 border border-emerald-100 hover:bg-emerald-50 font-bold text-[9px] px-2 py-0.5 rounded-md">
            ONGOING
          </Badge>
        );
      case 'UPCOMING':
        return (
          <Badge className="bg-blue-50 text-blue-600 border border-blue-100 hover:bg-blue-50 font-bold text-[9px] px-2 py-0.5 rounded-md">
            UPCOMING
          </Badge>
        );
      case 'COMPLETED':
        return (
          <Badge className="bg-purple-50 text-purple-600 border border-purple-100 hover:bg-purple-50 font-bold text-[9px] px-2 py-0.5 rounded-md">
            COMPLETED
          </Badge>
        );
      case 'CANCELLED':
        return (
          <Badge className="bg-rose-50 text-rose-600 border border-rose-100 hover:bg-rose-50 font-bold text-[9px] px-2 py-0.5 rounded-md">
            CANCELLED
          </Badge>
        );
      default:
        return null;
    }
  };
 
  return (
    <div className={cn(
      "p-6 md:p-8 space-y-6 bg-zinc-50/50 min-h-screen",
      theme === 'dark' && "bg-[#0F1115]"
    )}>
      {/* Welcome & Title Header */}
      <div>
        <h1 className={cn("text-2xl font-black text-zinc-900 tracking-tight", theme === 'dark' && "text-white")}>
          Dashboard
        </h1>
        <p className="text-xs text-zinc-400 font-medium mt-1">
          Welcome back, Admin! Here's what's happening today.
        </p>
      </div>
 
      {/* Row 1: Premium Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Total Users */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Users</span>
              <span className={cn("text-2xl font-black text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.totalUsers.toLocaleString()}
              </span>
              <span className="text-[10px] font-medium text-zinc-400">
                {stats.newUsers} new this week
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-amber-50 flex items-center justify-center border border-amber-100 shrink-0">
              <Users2 className="w-6 h-6 text-[#FF8F00]" />
            </div>
          </CardContent>
        </Card>
 
        {/* Active Tournaments */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Active Tournaments</span>
              <span className={cn("text-2xl font-black text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.activeTournaments.toLocaleString()}
              </span>
              <span className="text-[10px] font-medium text-zinc-400">Live & registration</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-purple-50 flex items-center justify-center border border-purple-100 shrink-0">
              <Trophy className="w-6 h-6 text-[#A855F7]" />
            </div>
          </CardContent>
        </Card>
 
        {/* Matches Played */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Matches Played</span>
              <span className={cn("text-2xl font-black text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.matchesPlayed.toLocaleString()}
              </span>
              <span className="text-[10px] font-medium text-zinc-400">All time</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-blue-50 flex items-center justify-center border border-blue-100 shrink-0">
              <Swords className="w-6 h-6 text-[#3B82F6]" />
            </div>
          </CardContent>
        </Card>
 
        {/* Total Revenue */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Revenue</span>
              <span className={cn("text-2xl font-black text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.totalRevenue}
              </span>
              <span className="text-[10px] font-medium text-zinc-400">Completed inflows</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 flex items-center justify-center border border-emerald-100 shrink-0">
              <Wallet className="w-6 h-6 text-[#10B981]" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Admin action queues */}
      {overview && (
        <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
          {[
            { label: 'Match Verifications', count: overview.pendingMatchVerifications, href: '/matches', color: 'text-amber-600' },
            { label: 'Result Approvals', count: overview.pendingResultApprovals, href: '/results', color: 'text-[#FF6B00]' },
            { label: 'Open Disputes', count: overview.openDisputes, href: '/disputes', color: 'text-rose-600' },
            { label: 'Withdrawals', count: overview.pendingWithdrawals, href: '/wallet', color: 'text-blue-600' },
            { label: 'Support Tickets', count: overview.openSupportTickets, href: '/support', color: 'text-emerald-600' },
          ].map((q) => (
            <Link key={q.href} href={q.href}>
              <Card className={cn('bg-white border-zinc-200 hover:border-[#FF6B00]/40 transition-colors cursor-pointer', theme === 'dark' && 'bg-[#161920] border-zinc-800')}>
                <CardContent className="p-4">
                  <p className="text-[10px] font-bold text-zinc-400 uppercase">{q.label}</p>
                  <p className={cn('text-2xl font-black mt-1', q.color)}>{q.count}</p>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
      )}

      {/* Row 2: Charts (Revenue Overview & Tournament Status) */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Revenue Overview Area Chart */}
        <Card className={cn("lg:col-span-2 min-w-0 bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-6", theme === 'dark' && "bg-[#161920] border-zinc-800 text-white")}>
          <div className="flex justify-between items-center pb-2 border-b border-zinc-50 dark:border-zinc-800">
            <h3 className="text-sm font-extrabold text-zinc-900 dark:text-white">Revenue Overview</h3>
            <div className={cn(
              "flex items-center gap-2.5 px-3 py-1.5 border border-zinc-200 rounded-xl text-[10px] font-bold text-zinc-700 bg-white shadow-sm cursor-pointer hover:bg-zinc-50",
              theme === 'dark' && "bg-[#1f222b] border-zinc-800 text-zinc-300 hover:bg-zinc-800"
            )}>
              <span>This Week</span>
              <ChevronDown className="w-3.5 h-3.5 text-zinc-400" />
            </div>
          </div>
          <RevenueChart />
        </Card>
 
        {/* Tournament Status Donut Chart */}
        <Card className={cn("min-w-0 bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-6", theme === 'dark' && "bg-[#161920] border-zinc-800 text-white")}>
          <div className="flex justify-between items-center pb-2 border-b border-zinc-50 dark:border-zinc-800">
            <h3 className="text-sm font-extrabold text-zinc-900 dark:text-white">Tournament Status</h3>
            <div className={cn(
              "flex items-center gap-2.5 px-3 py-1.5 border border-zinc-200 rounded-xl text-[10px] font-bold text-zinc-700 bg-white shadow-sm cursor-pointer hover:bg-zinc-50",
              theme === 'dark' && "bg-[#1f222b] border-zinc-800 text-zinc-300 hover:bg-zinc-800"
            )}>
              <span>All Tournaments</span>
              <ChevronDown className="w-3.5 h-3.5 text-zinc-400" />
            </div>
          </div>
          <TournamentStatusChart />
        </Card>
      </div>
 
      {/* Row 3: Tables & Activity Feeds */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Tournaments Table */}
        <Card className={cn("lg:col-span-2 bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-6", theme === 'dark' && "bg-[#161920] border-zinc-800 text-white")}>
          <div className="flex justify-between items-center pb-4 border-b border-zinc-100 dark:border-zinc-800">
            <h3 className="text-sm font-extrabold text-zinc-900 dark:text-white">Recent Tournaments</h3>
            <Link href="/tournaments">
              <Button variant="outline" className={cn(
                "border-zinc-200 text-[10px] font-bold h-8 rounded-xl px-3 bg-white hover:bg-zinc-50 shadow-sm",
                theme === 'dark' && "bg-[#1f222b] border-zinc-800 text-zinc-300 hover:bg-[#161920]"
              )}>
                View All
              </Button>
            </Link>
          </div>
          <div className="overflow-x-auto mt-4">
            <Table>
              <TableHeader className="border-zinc-100 hover:bg-transparent">
                <TableRow className="border-zinc-100 hover:bg-transparent">
                  <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Tournament</TableHead>
                  <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Mode</TableHead>
                  <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Teams</TableHead>
                  <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Prize Pool</TableHead>
                  <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {loading ? (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center py-8 text-zinc-400 text-xs">
                      <Loader2 className="w-5 h-5 animate-spin mx-auto mr-2 inline" />
                      Loading recent tournaments...
                    </TableCell>
                  </TableRow>
                ) : recentTournaments.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center py-8 text-zinc-400 text-xs">
                      No tournaments found.
                    </TableCell>
                  </TableRow>
                ) : (
                  recentTournaments.map((t) => {
                    const row = t as Record<string, unknown>;
                    return (
                    <TableRow key={String(row.id)} className="border-b border-zinc-50 hover:bg-zinc-50/30 dark:border-zinc-800">
                      <TableCell className="py-3.5 flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-orange-50 text-[#FF6B00] border border-orange-100 flex items-center justify-center shrink-0">
                          <Trophy className="w-4.5 h-4.5" />
                        </div>
                        <div>
                          <p className="text-xs font-bold text-zinc-800 dark:text-zinc-200">{String(row.title ?? '')}</p>
                          <p className="text-[10px] text-zinc-400 font-medium">{String(row.stage ?? '')}</p>
                        </div>
                      </TableCell>
                      <TableCell className="text-xs font-semibold text-zinc-500 py-3.5">{String(row.mode ?? '')}</TableCell>
                      <TableCell className="text-xs font-bold text-zinc-700 dark:text-zinc-300 py-3.5">
                        {String(row.currentPlayers ?? 0)} / {String(row.maxPlayers ?? 0)}
                      </TableCell>
                      <TableCell className="text-xs font-extrabold text-zinc-800 dark:text-zinc-200 py-3.5">{String(row.prizePool ?? '')}</TableCell>
                      <TableCell className="py-3.5">{getStatusBadge(String(row.statusText ?? 'UPCOMING'))}</TableCell>
                    </TableRow>
                    );
                  })
                )}
              </TableBody>
            </Table>
          </div>
        </Card>
 
        {/* Recent Activity Feed */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-6", theme === 'dark' && "bg-[#161920] border-zinc-800 text-white")}>
          <div className="flex justify-between items-center pb-4 border-b border-zinc-100 dark:border-zinc-800">
            <h3 className="text-sm font-extrabold text-zinc-900 dark:text-white">Recent Activities</h3>
            <Link href="/notifications">
              <Button variant="outline" className={cn(
                "border-zinc-200 text-[10px] font-bold h-8 rounded-xl px-3 bg-white hover:bg-zinc-50 shadow-sm",
                theme === 'dark' && "bg-[#1f222b] border-zinc-800 text-zinc-300 hover:bg-[#161920]"
              )}>
                View All
              </Button>
            </Link>
          </div>
 
          <div className="mt-5 space-y-4">
            {loading ? (
              <div className="text-center py-6 text-zinc-400 text-xs">
                <Loader2 className="w-5 h-5 animate-spin mx-auto mr-2 inline" />
                Loading activities...
              </div>
            ) : recentActivities.length === 0 ? (
              <div className="text-center py-6 text-zinc-400 text-xs">
                No recent activities.
              </div>
            ) : (
              recentActivities.map((act) => {
                const text = `${act.title} ${act.message}`.toLowerCase();
                let icon = <Trophy className="w-4 h-4" />;
                let bg = "bg-emerald-50 text-emerald-500 border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900/30";
                
                if (text.includes('wallet') || text.includes('withdraw') || text.includes('credit')) {
                  icon = <Wallet className="w-4 h-4" />;
                  bg = "bg-amber-50 text-amber-500 border-amber-100 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900/30";
                } else if (text.includes('user') || text.includes('team') || text.includes('register')) {
                  icon = <Users className="w-4 h-4" />;
                  bg = "bg-blue-50 text-blue-500 border-blue-100 dark:bg-blue-950/20 dark:text-blue-400 dark:border-blue-900/30";
                } else if (text.includes('support') || text.includes('ticket') || text.includes('dispute') || text.includes('reject')) {
                  icon = <Flag className="w-4 h-4" />;
                  bg = "bg-rose-50 text-rose-500 border-rose-100 dark:bg-rose-950/20 dark:text-rose-400 dark:border-rose-900/30";
                }

                let timeStr = 'Just Now';
                try {
                  const diffMs = Date.now() - new Date(act.created_at).getTime();
                  const diffMin = Math.floor(diffMs / 60000);
                  if (diffMin > 119) {
                    const diffHr = Math.floor(diffMin / 60);
                    if (diffHr > 23) {
                      timeStr = `${Math.floor(diffHr / 24)} days ago`;
                    } else {
                      timeStr = `${diffHr} hr ago`;
                    }
                  } else if (diffMin > 0) {
                    timeStr = `${diffMin} min ago`;
                  }
                } catch (_) {}

                return (
                  <div key={act.id} className="flex items-start justify-between gap-3 text-xs">
                    <div className="flex items-start gap-3">
                      <div className={cn("w-8 h-8 rounded-full flex items-center justify-center shrink-0 border", bg)}>
                        {icon}
                      </div>
                      <div>
                        <p className="font-extrabold text-zinc-800 dark:text-zinc-200 leading-tight">{act.title}</p>
                        <p className="text-[10px] text-zinc-400 font-medium mt-0.5">{act.message}</p>
                      </div>
                    </div>
                    <span className="text-[9px] text-zinc-400 font-bold shrink-0">{timeStr}</span>
                  </div>
                );
              })
            )}
          </div>
        </Card>
      </div>

      {/* Row 4: Smaller Horizontal Footer Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Total Prize Pool */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center border border-amber-100 shrink-0">
              <Award className="w-5 h-5 text-[#FF8F00]" />
            </div>
            <div className="space-y-0.5">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Prize Pool</span>
              <span className={cn("text-sm font-extrabold text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.totalPrizePool}
              </span>
              <span className="text-[9px] font-bold text-emerald-500">
                ↑ 15.2% <span className="text-zinc-400 font-medium">this month</span>
              </span>
            </div>
          </CardContent>
        </Card>

        {/* New Users */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center border border-blue-100 shrink-0">
              <UserPlus className="w-5 h-5 text-[#3B82F6]" />
            </div>
            <div className="space-y-0.5">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">New Users</span>
              <span className={cn("text-sm font-extrabold text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.newUsers.toLocaleString()}
              </span>
              <span className="text-[9px] font-bold text-emerald-500">
                ↑ 8.4% <span className="text-zinc-400 font-medium">this week</span>
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Total Transactions */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="w-10 h-10 rounded-xl bg-emerald-50 flex items-center justify-center border border-emerald-100 shrink-0">
              <ArrowRightLeft className="w-5 h-5 text-[#10B981]" />
            </div>
            <div className="space-y-0.5">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Transactions</span>
              <span className={cn("text-sm font-extrabold text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.totalTransactions.toLocaleString()}
              </span>
              <span className="text-[9px] font-bold text-emerald-500">
                ↑ 13.7% <span className="text-zinc-400 font-medium">this week</span>
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Open Support Tickets */}
        <Card className={cn("bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden", theme === 'dark' && "bg-[#161920] border-zinc-800")}>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="w-10 h-10 rounded-xl bg-rose-50 flex items-center justify-center border border-rose-100 shrink-0">
              <HelpCircle className="w-5 h-5 text-[#EF4444]" />
            </div>
            <div className="space-y-0.5">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Open Support Tickets</span>
              <span className={cn("text-sm font-extrabold text-zinc-900 block", theme === 'dark' && "text-white")}>
                {loading ? '...' : stats.openTickets.toLocaleString()}
              </span>
              <span className="text-[9px] font-bold text-rose-500">
                ↓ 12.5% <span className="text-zinc-400 font-medium">this week</span>
              </span>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
