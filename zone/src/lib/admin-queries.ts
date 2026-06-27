import {
  useQuery,
  useMutation,
  useQueryClient,
  keepPreviousData,
  type QueryClient,
} from '@tanstack/react-query';
import {
  getStoredRole,
  isAdmin,
  prefetchKeysForRole,
  type StaffRole,
} from './role-permissions';
import { apiGet, apiPost, apiPut, apiDelete, apiPostMultipart } from './api';

export const ADMIN_STALE_MS = 5 * 60 * 1000;
export const ADMIN_GC_MS = 30 * 60 * 1000;

export const adminKeys = {
  overview: ['admin', 'overview'] as const,
  matches: ['admin', 'matches'] as const,
  pendingResults: ['admin', 'pending-results'] as const,
  disputes: ['admin', 'disputes'] as const,
  walletTransactions: ['admin', 'wallet', 'transactions'] as const,
  walletWithdrawals: ['admin', 'wallet', 'withdrawals'] as const,
  walletBalance: ['admin', 'wallet', 'balance'] as const,
  supportTickets: ['admin', 'support'] as const,
  notifications: ['admin', 'notifications'] as const,
  tournaments: ['admin', 'tournaments'] as const,
  users: ['admin', 'users'] as const,
  players: ['admin', 'players'] as const,
  teams: ['admin', 'teams'] as const,
  scrims: ['admin', 'scrims'] as const,
  banners: ['admin', 'banners'] as const,
};

const listQueryDefaults = {
  staleTime: ADMIN_STALE_MS,
  gcTime: ADMIN_GC_MS,
  placeholderData: keepPreviousData,
  refetchOnMount: false as const,
};

export interface AdminOverview {
  totalUsers: number;
  activeTournaments: number;
  matchesPlayed: number;
  totalRevenue: number;
  totalPrizePool: number;
  newUsers: number;
  totalTransactions: number;
  openTickets: number;
  pendingMatchVerifications: number;
  pendingResultApprovals: number;
  openDisputes: number;
  openReports: number;
  pendingWithdrawals: number;
  openSupportTickets: number;
}

export interface WalletTransaction {
  id: string;
  type: 'Inflow' | 'Outflow';
  transaction_type?: string;
  amount: string;
  amount_numeric?: number;
  description: string;
  date: string;
  status: 'completed' | 'pending' | 'failed' | 'rejected' | 'Completed' | 'Pending';
  created_at?: string;
  payment_method?: string;
  user?: { name?: string; email?: string; ign?: string; game_uid?: string };
}

export interface NotificationItem {
  id: number;
  title: string;
  message: string;
  created_at: string;
  unread: boolean;
}

export interface BannerItem {
  id: number;
  title: string;
  prizePool: string | null;
  dateText: string | null;
  isLive: boolean;
  imagePath: string;
  isActive: boolean;
}

export async function fetchAdminOverview(): Promise<AdminOverview> {
  return apiGet('/admin/overview') as Promise<AdminOverview>;
}

export async function fetchAdminMatches() {
  const data = await apiGet('/admin/matches');
  return data.matches ?? [];
}

export async function fetchPendingResults() {
  const data = await apiGet('/admin/tournaments/pending-results');
  return data.tournaments ?? [];
}

export async function fetchAdminDisputes() {
  const data = await apiGet('/admin/disputes');
  return { disputes: data.disputes ?? [], reports: data.reports ?? [] };
}

export async function fetchWalletTransactions(): Promise<WalletTransaction[]> {
  const data = await apiGet('/admin/wallet/transactions');
  return data.transactions ?? [];
}

export async function fetchWalletWithdrawals(): Promise<WalletTransaction[]> {
  const data = await apiGet('/admin/wallet/withdrawals');
  return data.withdrawals ?? [];
}

export async function fetchWalletBalance(): Promise<number> {
  const data = await apiGet('/wallet/balance').catch(() => ({ balance: 0 }));
  return data.balance ?? 0;
}

export async function fetchSupportTickets(): Promise<Array<{
  id: number;
  subject: string;
  message: string;
  status: 'open' | 'pending' | 'resolved' | 'closed';
  priority: 'low' | 'normal' | 'high' | 'urgent';
  admin_reply?: string | null;
  created_at: string;
  user?: { name?: string; email?: string; ign?: string; game_uid?: string };
}>> {
  const data = await apiGet('/admin/support/tickets');
  return data.tickets ?? [];
}

export async function fetchNotifications(): Promise<NotificationItem[]> {
  const data = await apiGet('/notifications');
  return data.notifications ?? [];
}

export async function fetchTournamentsRaw(): Promise<Record<string, unknown>[]> {
  const data = await apiGet('/tournaments');
  return data.tournaments ?? [];
}

export interface AdminUser {
  id: number;
  name: string;
  email: string;
  ign?: string | null;
  game_uid?: string | null;
  avatar_url?: string | null;
  wallet_balance?: string | number;
  role: 'Admin' | 'Moderator' | 'Host' | 'Player';
  status: 'Active' | 'Pending' | 'Revoked' | 'Suspended';
  created_at: string;
}

export async function fetchAdminUsers(): Promise<AdminUser[]> {
  const data = await apiGet('/admin/users');
  return data.users ?? [];
}

export async function fetchPlayers(search?: string, status?: string): Promise<AdminUser[]> {
  const params = new URLSearchParams();
  if (search) params.set('search', search);
  if (status && status !== 'all') params.set('status', status);
  const qs = params.toString();
  const data = await apiGet(`/admin/players${qs ? `?${qs}` : ''}`);
  return data.players ?? [];
}

export async function fetchPlayer(id: number | string): Promise<AdminUser> {
  const data = await apiGet(`/admin/players/${id}`);
  return data.player;
}

export async function fetchTeams(): Promise<Array<{
  id: number;
  name: string;
  tag: string;
  game: string;
  members: string[];
  points: number;
  is_verified?: boolean;
}>> {
  const data = await apiGet('/teams');
  return data.teams ?? [];
}

export async function fetchScrims(): Promise<Array<{
  id: number;
  teams: string;
  game: string;
  time: string;
  status: 'Open' | 'Full' | 'Finished';
}>> {
  const data = await apiGet('/scrims');
  return data.scrims ?? [];
}

export async function fetchBanners(): Promise<BannerItem[]> {
  const data = await apiGet('/banners?all=true');
  return data.banners ?? [];
}

/** Prefetch admin lists after login — role-aware to avoid 403 noise */
export function prefetchAdminQueries(queryClient: QueryClient, role?: StaffRole | null) {
  const effectiveRole = role ?? getStoredRole();
  const allowed = new Set(prefetchKeysForRole(effectiveRole));

  const tasks: Array<[readonly unknown[], () => Promise<unknown>]> = [
    [adminKeys.overview, fetchAdminOverview],
    [adminKeys.matches, fetchAdminMatches],
    [adminKeys.pendingResults, fetchPendingResults],
    [adminKeys.disputes, fetchAdminDisputes],
    [adminKeys.walletTransactions, fetchWalletTransactions],
    [adminKeys.walletWithdrawals, fetchWalletWithdrawals],
    [adminKeys.walletBalance, fetchWalletBalance],
    [adminKeys.supportTickets, fetchSupportTickets],
    [adminKeys.notifications, fetchNotifications],
    [adminKeys.tournaments, fetchTournamentsRaw],
    [adminKeys.users, fetchAdminUsers],
    [adminKeys.players, () => fetchPlayers()],
    [adminKeys.teams, fetchTeams],
    [adminKeys.scrims, fetchScrims],
    [adminKeys.banners, fetchBanners],
  ];

  const keyToName: Record<string, string> = {
    [adminKeys.overview.join()]: 'overview',
    [adminKeys.matches.join()]: 'matches',
    [adminKeys.pendingResults.join()]: 'pendingResults',
    [adminKeys.disputes.join()]: 'disputes',
    [adminKeys.walletTransactions.join()]: 'walletTransactions',
    [adminKeys.walletWithdrawals.join()]: 'walletWithdrawals',
    [adminKeys.walletBalance.join()]: 'walletBalance',
    [adminKeys.supportTickets.join()]: 'supportTickets',
    [adminKeys.notifications.join()]: 'notifications',
    [adminKeys.tournaments.join()]: 'tournaments',
    [adminKeys.users.join()]: 'users',
    [adminKeys.players.join()]: 'players',
    [adminKeys.teams.join()]: 'teams',
    [adminKeys.scrims.join()]: 'scrims',
    [adminKeys.banners.join()]: 'banners',
  };

  tasks.forEach(([key, fn]) => {
    const name = keyToName[key.join()];
    if (name && !allowed.has(name)) return;
    queryClient.prefetchQuery({ queryKey: key, queryFn: fn, staleTime: ADMIN_STALE_MS });
  });
}

export function prefetchAdminRoute(queryClient: QueryClient, href: string) {
  const entries: Record<string, Array<{ key: readonly unknown[]; fn: () => Promise<unknown> }>> = {
    '/': [
      { key: adminKeys.overview, fn: fetchAdminOverview },
      { key: adminKeys.tournaments, fn: fetchTournamentsRaw },
      { key: adminKeys.notifications, fn: fetchNotifications },
    ],
    '/tournaments': [{ key: adminKeys.tournaments, fn: fetchTournamentsRaw }],
    '/scrims': [{ key: adminKeys.scrims, fn: fetchScrims }],
    '/matches': [{ key: adminKeys.matches, fn: fetchAdminMatches }],
    '/results': [{ key: adminKeys.pendingResults, fn: fetchPendingResults }],
    '/disputes': [{ key: adminKeys.disputes, fn: fetchAdminDisputes }],
    '/teams': [{ key: adminKeys.teams, fn: fetchTeams }],
    '/users': [{ key: adminKeys.users, fn: fetchAdminUsers }],
    '/players': [{ key: adminKeys.players, fn: () => fetchPlayers() }],
    '/wallet': [
      { key: adminKeys.walletTransactions, fn: fetchWalletTransactions },
      { key: adminKeys.walletWithdrawals, fn: fetchWalletWithdrawals },
      { key: adminKeys.walletBalance, fn: fetchWalletBalance },
    ],
    '/notifications': [{ key: adminKeys.notifications, fn: fetchNotifications }],
    '/banners': [{ key: adminKeys.banners, fn: fetchBanners }],
    '/support': [{ key: adminKeys.supportTickets, fn: fetchSupportTickets }],
  };

  (entries[href] ?? []).forEach(({ key, fn }) => {
    queryClient.prefetchQuery({ queryKey: key, queryFn: fn, staleTime: ADMIN_STALE_MS });
  });
}

export function useAdminOverview() {
  return useQuery({ queryKey: adminKeys.overview, queryFn: fetchAdminOverview, ...listQueryDefaults });
}

export function useAdminMatches() {
  return useQuery({ queryKey: adminKeys.matches, queryFn: fetchAdminMatches, ...listQueryDefaults });
}

export function usePendingResults() {
  return useQuery({ queryKey: adminKeys.pendingResults, queryFn: fetchPendingResults, ...listQueryDefaults });
}

export function useAdminDisputes() {
  return useQuery({ queryKey: adminKeys.disputes, queryFn: fetchAdminDisputes, ...listQueryDefaults });
}

export function useWalletTransactions() {
  return useQuery({ queryKey: adminKeys.walletTransactions, queryFn: fetchWalletTransactions, ...listQueryDefaults });
}

export function useWalletWithdrawals() {
  return useQuery({ queryKey: adminKeys.walletWithdrawals, queryFn: fetchWalletWithdrawals, ...listQueryDefaults });
}

export function useWalletBalance() {
  return useQuery({ queryKey: adminKeys.walletBalance, queryFn: fetchWalletBalance, ...listQueryDefaults });
}

export function useNotifications() {
  return useQuery({ queryKey: adminKeys.notifications, queryFn: fetchNotifications, ...listQueryDefaults });
}

export function useTournamentsRaw() {
  return useQuery({ queryKey: adminKeys.tournaments, queryFn: fetchTournamentsRaw, ...listQueryDefaults });
}

export function useAdminUsers() {
  return useQuery({
    queryKey: adminKeys.users,
    queryFn: fetchAdminUsers,
    enabled: isAdmin(getStoredRole()),
    ...listQueryDefaults,
  });
}

export function usePlayers(search?: string, status?: string) {
  return useQuery({
    queryKey: [...adminKeys.players, search ?? '', status ?? 'all'],
    queryFn: () => fetchPlayers(search, status),
    ...listQueryDefaults,
  });
}

export function usePlayer(id: number | string | undefined) {
  return useQuery({
    queryKey: [...adminKeys.players, 'detail', id],
    queryFn: () => fetchPlayer(id!),
    enabled: !!id,
    ...listQueryDefaults,
  });
}

export function useTeams() {
  return useQuery({ queryKey: adminKeys.teams, queryFn: fetchTeams, ...listQueryDefaults });
}

export function useScrims() {
  return useQuery({ queryKey: adminKeys.scrims, queryFn: fetchScrims, ...listQueryDefaults });
}

export function useBanners() {
  return useQuery({
    queryKey: adminKeys.banners,
    queryFn: fetchBanners,
    enabled: isAdmin(getStoredRole()),
    ...listQueryDefaults,
  });
}

export function useSupportTickets() {
  return useQuery({
    queryKey: adminKeys.supportTickets,
    queryFn: fetchSupportTickets,
    ...listQueryDefaults,
  });
}

export function useApproveResults() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (tournamentId: number) => apiPost(`/admin/tournaments/${tournamentId}/approve-results`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.pendingResults });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useRejectResults() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ tournamentId, reason }: { tournamentId: number; reason?: string }) =>
      apiPost(`/admin/tournaments/${tournamentId}/reject-results`, { reason }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.pendingResults });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useResolveDispute() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, status, admin_note }: { id: number; status: string; admin_note?: string }) =>
      apiPost(`/admin/disputes/${id}/resolve`, { status, admin_note }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.disputes });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useResolveReport() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, status, admin_note }: { id: number; status: string; admin_note?: string }) =>
      apiPost(`/admin/reports/${id}/resolve`, { status, admin_note }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.disputes });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useVerifyMatch() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: Record<string, unknown> }) =>
      apiPost(`/admin/matches/${id}/verify`, payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.matches });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useRejectMatch() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      apiPost(`/admin/matches/${id}/reject`, { reason }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.matches });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useAdjustWallet() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { user_id: number; amount: number; reason: string }) =>
      apiPost('/admin/wallet/adjust', body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.walletTransactions });
      qc.invalidateQueries({ queryKey: adminKeys.walletBalance });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useWithdrawalAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, action }: { id: string; action: 'approve' | 'reject' }) =>
      apiPost(`/admin/wallet/withdrawals/${id}/${action}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.walletWithdrawals });
      qc.invalidateQueries({ queryKey: adminKeys.walletTransactions });
      qc.invalidateQueries({ queryKey: adminKeys.walletBalance });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useUpdateSupportTicket() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, body }: { id: number; body: Record<string, unknown> }) =>
      apiPut(`/admin/support/tickets/${id}`, body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: adminKeys.supportTickets });
      qc.invalidateQueries({ queryKey: adminKeys.overview });
    },
  });
}

export function useNotificationMutations() {
  const qc = useQueryClient();
  const invalidate = () => qc.invalidateQueries({ queryKey: adminKeys.notifications });

  return {
    markAllRead: useMutation({
      mutationFn: () => apiPost('/notifications/mark-read'),
      onSuccess: invalidate,
    }),
    deleteNotification: useMutation({
      mutationFn: (id: number) => apiDelete(`/notifications/${id}`),
      onSuccess: invalidate,
    }),
    sendBroadcast: useMutation({
      mutationFn: (body: FormData) =>
        apiPostMultipart('/notifications', body),
      onSuccess: invalidate,
    }),
  };
}

export function useInvalidateAdminUsers() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: adminKeys.users });
}

export function useInvalidatePlayers() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: adminKeys.players });
}

export function useInvalidateTournaments() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: adminKeys.tournaments });
}

export function useInvalidateTeams() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: adminKeys.teams });
}

export function useInvalidateScrims() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: adminKeys.scrims });
}

export function useInvalidateBanners() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: adminKeys.banners });
}

/** Only show full-page loader when there is no cached data yet */
export function isInitialLoad(isPending: boolean, data: unknown) {
  return isPending && data === undefined;
}
