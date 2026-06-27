'use client';
 
import React, { useMemo, useState, useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { useRouter } from 'next/navigation';
import { apiDelete, apiPost, apiPut } from '@/lib/api';
import { 
  useTournamentsRaw, 
  useInvalidateTournaments, 
  isInitialLoad
} from '@/lib/admin-queries';
import { TournamentActionsDropdown } from '@/components/admin/TournamentActionsDropdown';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { useStaffRole } from '@/components/require-role';
import { canDeleteTournaments } from '@/lib/role-permissions';
 
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetFooter,
} from '@/components/ui/sheet';
import { Badge } from '@/components/ui/badge';
import { DatePicker } from '@/components/ui/date-picker';
import { 
  Plus, Edit, Eye, MoreVertical, Calendar, Play, Trophy, 
  CheckCircle, ArrowUpDown, Search, Gamepad, Layers, 
  SlidersHorizontal, Download, ChevronLeft, ChevronRight, ChevronDown, Loader2, Trash2
} from 'lucide-react';
 
// Form validation schema
const tournamentSchema = z.object({
  name: z.string().min(3, { message: 'Tournament name must be at least 3 characters' }),
  game: z.string().min(2, { message: 'Please specify the game' }),
  mode: z.string().min(2, { message: 'Please specify the mode (e.g. Squad TPP)' }),
  stage: z.string().min(2, { message: 'Please specify the stage (e.g. Quarter Final)' }),
  prize: z.string().min(1, { message: 'Prize pool is required' }),
  entryFee: z.string(),
  isFeatured: z.boolean(),
  startDate: z.date({ message: 'Start date is required' }),
  slots: z.number().min(2, { message: 'Must have at least 2 slots' }),
  status: z.enum(['ONGOING', 'UPCOMING', 'COMPLETED', 'CANCELLED']),
  matchFormat: z.enum(['classic', '1v1', '2v2', '3v3', '4v4']),
});
 
type TournamentFormValues = z.infer<typeof tournamentSchema>;
 
interface Tournament {
  id: number;
  name: string;
  game: string;
  mode: string;
  stage: string;
  prize: string;
  entryFee: string;
  isFeatured: boolean;
  startDate: Date;
  slots: number;
  joined: number;
  status: 'ONGOING' | 'UPCOMING' | 'COMPLETED' | 'CANCELLED';
  matchFormat: 'classic' | '1v1' | '2v2' | '3v3' | '4v4';
}

function parsePoolAmount(prize: string): number {
  return Number(String(prize).replace(/[^0-9.]/g, '')) || 0;
}

function buildPrizePreview(prize: string, matchFormat: Tournament['matchFormat']) {
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

function buildCustomSettings(matchFormat: Tournament['matchFormat']) {
  if (matchFormat === 'classic') {
    return { prize_distribution: 'classic_top3' };
  }
  return {
    prize_distribution: 'winner_takes_all',
    team_size: matchFormat,
    room_type: 'Custom Room',
  };
}

function resolveTypeFromFormat(matchFormat: Tournament['matchFormat'], mode: string): string {
  if (matchFormat === '1v1') return 'Solo';
  if (matchFormat === '2v2') return 'Duo';
  if (matchFormat !== 'classic') return 'Squad';
  if (mode.toLowerCase().includes('solo')) return 'Solo';
  if (mode.toLowerCase().includes('duo')) return 'Duo';
  return 'Squad';
}
 
export default function TournamentsPage() {
  const router = useRouter();
  const { theme } = useAppStore();
  const role = useStaffRole();
  const canDelete = canDeleteTournaments(role);
  const { data: rawTournaments, isPending, isError, error, refetch } = useTournamentsRaw();
  const invalidateTournaments = useInvalidateTournaments();
  const loading = isInitialLoad(isPending, rawTournaments);

  const tournaments = useMemo(() => {
    return (rawTournaments ?? []).map((t: Record<string, unknown>) => {
      let status: Tournament['status'] = 'UPCOMING';
      const stText = String(t.statusText || '').toUpperCase();
      if (stText === 'LIVE' || stText === 'ONGOING') status = 'ONGOING';
      else if (stText === 'COMPLETED') status = 'COMPLETED';
      else if (stText === 'CANCELLED') status = 'CANCELLED';
      const customSettings = t.customSettings as Record<string, unknown> | undefined;
      return {
        id: t.id as number,
        name: t.title as string,
        game: t.game as string,
        mode: t.mode as string,
        stage: t.stage as string,
        prize: t.prizePool as string,
        entryFee: (t.entryFee as string) || 'Free',
        isFeatured: Boolean(t.isFeatured),
        startDate: t.starts_at ? new Date(t.starts_at as string) : new Date(String(t.dateText || '').replace('•', '') || Date.now()),
        slots: t.maxPlayers as number,
        joined: t.currentPlayers as number,
        status,
        matchFormat: (customSettings?.team_size as Tournament['matchFormat']) ||
          (String(t.stage || '').match(/\[(1v1|2v2|3v3|4v4)\]/)?.[1] as Tournament['matchFormat']) ||
          'classic',
      };
    });
  }, [rawTournaments]);
  const [createDialogOpen, setCreateDialogOpen] = useState(false);
  const [editingTournament, setEditingTournament] = useState<Tournament | null>(null);
  const [deletingTournament, setDeletingTournament] = useState<Tournament | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);
  
  // Search state
  const [searchQuery, setSearchQuery] = useState('');
  const [page, setPage] = useState(1);
  const PAGE_SIZE = 10;
  // Filter states
  const [gameFilter, setGameFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
 
  // Forms hook setup
  const createForm = useForm<TournamentFormValues>({
    resolver: zodResolver(tournamentSchema),
    defaultValues: {
      name: '',
      game: '',
      mode: 'Squad TPP',
      stage: 'Quarter Final',
      prize: '',
      entryFee: 'Free',
      isFeatured: false,
      slots: 16,
      status: 'UPCOMING',
      matchFormat: 'classic',
    },
  });
 
  const editForm = useForm<TournamentFormValues>({
    resolver: zodResolver(tournamentSchema),
  });

  const mapStatusToBackend = (status: 'ONGOING' | 'UPCOMING' | 'COMPLETED' | 'CANCELLED'): string => {
    switch (status) {
      case 'ONGOING': return 'live';
      case 'UPCOMING': return 'upcoming';
      case 'COMPLETED': return 'completed';
      case 'CANCELLED': return 'cancelled';
    }
  };

  const handleCreateSubmit = async (values: TournamentFormValues) => {
    try {
      const type = resolveTypeFromFormat(values.matchFormat, values.mode);
      const stage =
        values.matchFormat === 'classic'
          ? values.stage
          : `${values.stage} [${values.matchFormat}]`;

      await apiPost('/admin/tournaments', {
        title: values.name,
        game: values.game,
        stage,
        type,
        mode: values.matchFormat === 'classic' ? values.mode : 'Custom Room',
        prize_pool: values.prize,
        entry_fee: values.entryFee,
        max_players: values.slots,
        starts_at: values.startDate.toISOString(),
        status: mapStatusToBackend(values.status),
        is_featured: values.isFeatured,
        custom_settings: buildCustomSettings(values.matchFormat),
      });

      setCreateDialogOpen(false);
      createForm.reset();
      toast.success('Tournament created successfully!');
      invalidateTournaments();
    } catch (err: any) {
      toast.error('Failed to create tournament', { description: err.message });
    }
  };
 
  const handleEditClick = (tournament: Tournament) => {
    setEditingTournament(tournament);
    editForm.reset({
      name: tournament.name,
      game: tournament.game,
      mode: tournament.mode,
      stage: tournament.stage,
      prize: tournament.prize,
      entryFee: tournament.entryFee,
      isFeatured: tournament.isFeatured,
      startDate: tournament.startDate,
      slots: tournament.slots,
      status: tournament.status,
      matchFormat: tournament.matchFormat,
    });
  };
 
  const handleEditSubmit = async (values: TournamentFormValues) => {
    if (!editingTournament) return;
    try {
      const type = resolveTypeFromFormat(values.matchFormat, values.mode);
      const stage =
        values.matchFormat === 'classic'
          ? values.stage
          : `${values.stage} [${values.matchFormat}]`;

      await apiPut(`/admin/tournaments/${editingTournament.id}`, {
        title: values.name,
        game: values.game,
        stage,
        type,
        mode: values.matchFormat === 'classic' ? values.mode : 'Custom Room',
        prize_pool: values.prize,
        entry_fee: values.entryFee,
        max_players: values.slots,
        starts_at: values.startDate.toISOString(),
        status: mapStatusToBackend(values.status),
        is_featured: values.isFeatured,
        custom_settings: buildCustomSettings(values.matchFormat),
      });

      setEditingTournament(null);
      toast.success('Tournament updated successfully!');
      invalidateTournaments();
    } catch (err: any) {
      toast.error('Failed to update tournament', { description: err.message });
    }
  };

  const handleCancelTournament = async (tournament: Tournament) => {
    if (!confirm(`Cancel ${tournament.name}? Players will no longer see it as active.`)) return;
    try {
      await apiPut(`/admin/tournaments/${tournament.id}`, { status: 'cancelled' });
      toast.success('Tournament cancelled.');
      invalidateTournaments();
    } catch (err: any) {
      toast.error('Failed to cancel tournament', { description: err.message });
    }
  };

  const handleDeleteTournament = (tournament: Tournament) => {
    setDeletingTournament(tournament);
  };

  const confirmDeleteTournament = async () => {
    if (!deletingTournament) return;
    setIsDeleting(true);
    try {
      await apiDelete(`/admin/tournaments/${deletingTournament.id}`);
      toast.success('Tournament deleted permanently.');
      setDeletingTournament(null);
      invalidateTournaments();
    } catch (err: any) {
      toast.error('Failed to delete tournament', { description: err.message });
    } finally {
      setIsDeleting(false);
    }
  };
 
  // Status badge visual helper
  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'ONGOING':
        return (
          <Badge className="bg-emerald-50 text-emerald-600 border border-emerald-100 hover:bg-emerald-50 font-extrabold text-[9px] px-2 py-0.5 rounded-md">
            ONGOING
          </Badge>
        );
      case 'UPCOMING':
        return (
          <Badge className="bg-blue-50 text-blue-600 border border-blue-100 hover:bg-blue-50 font-extrabold text-[9px] px-2 py-0.5 rounded-md">
            UPCOMING
          </Badge>
        );
      case 'COMPLETED':
        return (
          <Badge className="bg-purple-50 text-purple-600 border border-purple-100 hover:bg-purple-50 font-extrabold text-[9px] px-2 py-0.5 rounded-md">
            COMPLETED
          </Badge>
        );
      case 'CANCELLED':
        return (
          <Badge className="bg-rose-50 text-rose-600 border border-rose-100 hover:bg-rose-50 font-extrabold text-[9px] px-2 py-0.5 rounded-md">
            CANCELLED
          </Badge>
        );
      default:
        return null;
    }
  };
 
  // Filtered tournament lists
  const filteredTournaments = tournaments.filter(t => {
    const matchesSearch = t.name.toLowerCase().includes(searchQuery.toLowerCase()) || t.game.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesGame = gameFilter === 'all' || t.game.toLowerCase() === gameFilter.toLowerCase();
    const matchesStatus = statusFilter === 'all' || t.status === statusFilter;
    return matchesSearch && matchesGame && matchesStatus;
  });

  useEffect(() => {
    setPage(1);
  }, [searchQuery, gameFilter, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredTournaments.length / PAGE_SIZE));
  const paginatedTournaments = filteredTournaments.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const rangeStart = filteredTournaments.length === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const rangeEnd = Math.min(page * PAGE_SIZE, filteredTournaments.length);
 
  return (
    <div className="p-6 md:p-8 space-y-6 bg-zinc-50/50 min-h-screen">
      {/* Title section and Add Tournament Button */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="text-2xl font-black text-zinc-900 tracking-tight">Tournaments</h2>
          <p className="text-xs text-zinc-400 font-medium mt-1">Manage and monitor all tournaments.</p>
        </div>
 
        {/* Dialog for creating tournament */}
        <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
          <DialogTrigger
            render={
              <Button className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-extrabold text-xs rounded-xl flex items-center gap-2 h-10 px-4 shadow-sm" />
            }
          >
            <Plus className="w-4.5 h-4.5" />
            Create Tournament
          </DialogTrigger>
          <DialogContent className="sm:max-w-md bg-white border border-zinc-200 shadow-xl rounded-2xl">
            <DialogHeader>
              <DialogTitle className="text-sm font-bold">New Esports Tournament</DialogTitle>
              <DialogDescription className="text-[11px] text-zinc-400">
                Setup registration parameters and prize details below.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={createForm.handleSubmit(handleCreateSubmit)} className="space-y-4 py-2">
              <div className="space-y-1">
                <Label htmlFor="name" className="text-xs font-semibold text-zinc-700">Tournament Name</Label>
                <Input
                  id="name"
                  {...createForm.register('name')}
                  placeholder="e.g. Cyberpunk Pro V"
                  className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                />
                {createForm.formState.errors.name && (
                  <p className="text-[10px] text-rose-600 font-semibold">{createForm.formState.errors.name.message}</p>
                )}
              </div>
 
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="game" className="text-xs font-semibold text-zinc-700">Game Title</Label>
                  <Input
                    id="game"
                    {...createForm.register('game')}
                    placeholder="Valorant, BGMI..."
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {createForm.formState.errors.game && (
                    <p className="text-[10px] text-rose-600 font-semibold">{createForm.formState.errors.game.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="mode" className="text-xs font-semibold text-zinc-700">Match Mode</Label>
                  <Input
                    id="mode"
                    {...createForm.register('mode')}
                    placeholder="e.g. Squad TPP"
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {createForm.formState.errors.mode && (
                    <p className="text-[10px] text-rose-600 font-semibold">{createForm.formState.errors.mode.message}</p>
                  )}
                </div>
              </div>
 
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="matchFormat" className="text-xs font-semibold text-zinc-700">Match Format</Label>
                  <select
                    id="matchFormat"
                    {...createForm.register('matchFormat')}
                    className="w-full bg-white border border-zinc-200 rounded-lg text-xs px-2.5 h-9 outline-none cursor-pointer"
                  >
                    <option value="classic">Classic Squad (Top 3)</option>
                    <option value="1v1">1v1 Winner Takes All</option>
                    <option value="2v2">2v2 Winner Takes All</option>
                    <option value="3v3">3v3 Winner Takes All</option>
                    <option value="4v4">4v4 Winner Takes All</option>
                  </select>
                </div>
                <div className="space-y-1">
                  <Label htmlFor="prize" className="text-xs font-semibold text-zinc-700">Prize Pool</Label>
                  <Input
                    id="prize"
                    {...createForm.register('prize')}
                    placeholder="e.g. NPR 5,000"
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {createForm.formState.errors.prize && (
                    <p className="text-[10px] text-rose-600 font-semibold">{createForm.formState.errors.prize.message}</p>
                  )}
                </div>
              </div>

              {(() => {
                const prize = createForm.watch('prize');
                const matchFormat = createForm.watch('matchFormat');
                const preview = buildPrizePreview(prize, matchFormat);
                return (
                  <div className="rounded-xl border border-orange-100 bg-orange-50/50 p-3 space-y-2">
                    <p className="text-[10px] font-bold text-[#FF6B00] uppercase tracking-wider">
                      {matchFormat === 'classic' ? 'Classic Top 3 Distribution' : `${matchFormat} — Winner Takes All`}
                    </p>
                    {preview.map((row) => (
                      <div key={row.label} className="flex items-center justify-between text-xs">
                        <span className="font-semibold text-zinc-700">{row.label} <span className="text-zinc-400">({row.share})</span></span>
                        <span className="font-extrabold text-emerald-600">NPR {Math.round(row.amount).toLocaleString()}</span>
                      </div>
                    ))}
                  </div>
                );
              })()}

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="stage" className="text-xs font-semibold text-zinc-700">Stage / Subtitle</Label>
                  <Input
                    id="stage"
                    {...createForm.register('stage')}
                    placeholder="e.g. Quarter Final"
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {createForm.formState.errors.stage && (
                    <p className="text-[10px] text-rose-600 font-semibold">{createForm.formState.errors.stage.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="entryFee" className="text-xs font-semibold text-zinc-700">Entry Fee</Label>
                  <Input
                    id="entryFee"
                    {...createForm.register('entryFee')}
                    placeholder="Free or NPR 200"
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                </div>
              </div>

              <label className="flex items-center gap-2 text-xs font-semibold text-zinc-700">
                <input type="checkbox" {...createForm.register('isFeatured')} className="h-4 w-4 rounded border-zinc-300" />
                Featured on app home
              </label>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label className="text-xs font-semibold text-zinc-700">Start Date</Label>
                  <Controller
                    control={createForm.control}
                    name="startDate"
                    render={({ field }) => (
                      <DatePicker
                        date={field.value}
                        setDate={field.onChange}
                        placeholder="Pick start date"
                      />
                    )}
                  />
                  {createForm.formState.errors.startDate && (
                    <p className="text-[10px] text-rose-600 font-semibold">{createForm.formState.errors.startDate.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="slots" className="text-xs font-semibold text-zinc-700">Team Slots</Label>
                  <Input
                    id="slots"
                    type="number"
                    {...createForm.register('slots', { valueAsNumber: true })}
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {createForm.formState.errors.slots && (
                    <p className="text-[10px] text-rose-600 font-semibold">{createForm.formState.errors.slots.message}</p>
                  )}
                </div>
              </div>

              <DialogFooter className="pt-4">
                <Button type="submit" className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-semibold text-xs rounded-xl h-10 px-4">
                  Publish Tournament
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {isError && (
        <QueryErrorBanner error={error} onRetry={() => refetch()} title="Failed to load tournaments" />
      )}
 
      {/* Stat Cards Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Total Tournaments */}
        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Tournaments</span>
              <span className="text-2xl font-black text-zinc-900 block">
                {loading ? '...' : tournaments.length}
              </span>
              <span className="text-[10px] font-bold text-emerald-500 flex items-center gap-1">
                <span>↑ 12.5%</span> <span className="text-zinc-400 font-medium">from last week</span>
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-blue-50 flex items-center justify-center border border-blue-100 shrink-0">
              <Calendar className="w-6 h-6 text-[#3B82F6]" />
            </div>
          </CardContent>
        </Card>
 
        {/* Upcoming */}
        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Upcoming</span>
              <span className="text-2xl font-black text-zinc-900 block">
                {loading ? '...' : tournaments.filter(t => t.status === 'UPCOMING').length}
              </span>
              <span className="text-[10px] font-bold text-emerald-500 flex items-center gap-1">
                <span>↑ 8.7%</span> <span className="text-zinc-400 font-medium">from last week</span>
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 flex items-center justify-center border border-emerald-100 shrink-0">
              <Play className="w-6 h-6 text-[#10B981] fill-[#10B981]/10" />
            </div>
          </CardContent>
        </Card>
 
        {/* Ongoing */}
        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Ongoing</span>
              <span className="text-2xl font-black text-zinc-900 block">
                {loading ? '...' : tournaments.filter(t => t.status === 'ONGOING').length}
              </span>
              <span className="text-[10px] font-bold text-emerald-500 flex items-center gap-1">
                <span>↑ 15.4%</span> <span className="text-zinc-400 font-medium">from last week</span>
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-purple-50 flex items-center justify-center border border-purple-100 shrink-0">
              <Trophy className="w-6 h-6 text-[#A855F7]" />
            </div>
          </CardContent>
        </Card>
 
        {/* Completed */}
        <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden">
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Completed</span>
              <span className="text-2xl font-black text-zinc-900 block">
                {loading ? '...' : tournaments.filter(t => t.status === 'COMPLETED').length}
              </span>
              <span className="text-[10px] font-bold text-rose-500 flex items-center gap-1">
                <span>↓ 4.3%</span> <span className="text-zinc-400 font-medium">from last week</span>
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-amber-50 flex items-center justify-center border border-amber-100 shrink-0">
              <CheckCircle className="w-6 h-6 text-[#FF8F00] fill-[#FF8F00]/10" />
            </div>
          </CardContent>
        </Card>
      </div>
 
      {/* Filters and Search row matching screenshot */}
      <div className="flex flex-col lg:flex-row justify-between items-stretch lg:items-center gap-4">
        {/* Left-hand Filters controls */}
        <div className="flex flex-wrap items-center gap-3 flex-1">
          {/* Search field */}
          <div className="relative max-w-xs w-full">
            <Search className="w-4 h-4 text-zinc-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <Input 
              placeholder="Search tournaments..." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="bg-white border-zinc-200 pl-9 pr-4 text-xs h-9 rounded-xl w-full"
            />
          </div>
 
          {/* All Games Dropdown */}
          <div className="relative">
            <select 
              value={gameFilter}
              onChange={(e) => setGameFilter(e.target.value)}
              className="bg-white border border-zinc-200 rounded-xl px-3 py-1.5 text-xs font-semibold text-zinc-700 outline-none pr-8 appearance-none cursor-pointer shadow-sm hover:bg-zinc-50"
            >
              <option value="all">All Games</option>
              <option value="BGMI">BGMI</option>
              <option value="Valorant">Valorant</option>
              <option value="Free Fire">Free Fire</option>
              <option value="COD Mobile">COD Mobile</option>
              <option value="Mobile Legends">Mobile Legends</option>
            </select>
            <Gamepad className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
 
          {/* All Status Dropdown */}
          <div className="relative">
            <select 
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="bg-white border border-zinc-200 rounded-xl px-3 py-1.5 text-xs font-semibold text-zinc-700 outline-none pr-8 appearance-none cursor-pointer shadow-sm hover:bg-zinc-50"
            >
              <option value="all">All Status</option>
              <option value="ONGOING">Ongoing</option>
              <option value="UPCOMING">Upcoming</option>
              <option value="COMPLETED">Completed</option>
              <option value="CANCELLED">Cancelled</option>
            </select>
            <Layers className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
 
          {/* All Modes Dropdown */}
          <div className="relative">
            <select 
              className="bg-white border border-zinc-200 rounded-xl px-3 py-1.5 text-xs font-semibold text-zinc-700 outline-none pr-8 appearance-none cursor-pointer shadow-sm hover:bg-zinc-50"
            >
              <option value="all">All Modes</option>
              <option value="squad">Squad</option>
              <option value="solo">Solo</option>
            </select>
            <SlidersHorizontal className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
 
          {/* More Filters button */}
          <Button variant="outline" className="border-zinc-200 text-xs font-semibold h-9 rounded-xl px-3.5 bg-white hover:bg-zinc-50 shadow-sm flex items-center gap-1.5 text-zinc-600">
            <SlidersHorizontal className="w-3.5 h-3.5" />
            More Filters
          </Button>
        </div>
 
        {/* Right-hand export */}
        <Button variant="outline" className="border-zinc-200 text-xs font-semibold h-9 rounded-xl px-4 bg-white hover:bg-zinc-50 shadow-sm flex items-center gap-1.5 text-zinc-600 self-start lg:self-auto">
          <Download className="w-4 h-4" />
          Export
        </Button>
      </div>
 
      {/* Catalog Table */}
      <Card className="bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0">
        <CardContent className="p-0">
          <Table>
            <TableHeader className="border-zinc-100 bg-zinc-50/50">
              <TableRow className="border-zinc-100 hover:bg-transparent">
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 flex items-center gap-1 cursor-pointer select-none">
                  Tournament <ArrowUpDown className="w-3 h-3 text-zinc-400" />
                </TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Game</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Mode</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 cursor-pointer select-none">
                  Teams <ArrowUpDown className="w-3 h-3 text-zinc-400" />
                </TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 cursor-pointer select-none">
                  Prize Pool <ArrowUpDown className="w-3 h-3 text-zinc-400" />
                </TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Start Date</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 cursor-pointer select-none">
                  Status <ArrowUpDown className="w-3 h-3 text-zinc-400" />
                </TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={8} className="text-center py-10 text-zinc-400 text-xs">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto text-[#FF6B00]" />
                    <p className="mt-2 text-zinc-400 font-semibold">Loading tournaments catalog...</p>
                  </TableCell>
                </TableRow>
              ) : paginatedTournaments.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="text-center py-10 text-zinc-400 text-xs font-semibold">
                    No tournaments found.
                  </TableCell>
                </TableRow>
              ) : (
                paginatedTournaments.map((t) => (
                  <TableRow key={t.id} className="border-b border-zinc-50 hover:bg-zinc-50/30">
                    {/* Tournament Title */}
                    <TableCell className="py-3 flex items-center gap-3">
                      <div className="w-9 h-9 rounded-lg bg-orange-50 text-[#FF6B00] border border-orange-100 flex items-center justify-center shrink-0">
                        <Trophy className="w-4.5 h-4.5" />
                      </div>
                      <div>
                        <p className="text-xs font-bold text-zinc-805">{t.name}</p>
                        <p className="text-[10px] text-zinc-400 font-medium">{t.stage}</p>
                      </div>
                    </TableCell>
                    
                    {/* Game Title with inline thumbnail element style */}
                    <TableCell className="py-3">
                      <div className="flex items-center gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-[#FF6B00]" />
                        <span className="text-xs font-bold text-zinc-800">{t.game}</span>
                      </div>
                    </TableCell>
                    
                    <TableCell className="text-xs font-semibold text-zinc-500 py-3">{t.mode}</TableCell>
                    
                    <TableCell className="text-xs font-bold text-zinc-700 py-3">{t.joined} / {t.slots}</TableCell>
                    
                    <TableCell className="text-xs font-extrabold text-emerald-600 py-3">{t.prize}</TableCell>
                    
                    {/* Start date */}
                    <TableCell className="py-3">
                      <div>
                        <p className="text-xs font-bold text-zinc-800">
                          {t.startDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                        </p>
                        <p className="text-[9px] text-zinc-400 font-semibold mt-0.5">
                          {t.startDate.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true })}
                        </p>
                      </div>
                    </TableCell>
                    
                    <TableCell className="py-3">{getStatusBadge(t.status)}</TableCell>
                             {/* Action buttons matching screenshot */}
                    <TableCell className="py-3 text-right">
                      <div className="flex items-center gap-1.5 justify-end">
                        <Button 
                          variant="outline" 
                          size="icon" 
                          onClick={() => router.push(`/tournaments/${t.id}`)}
                          className="w-8 h-8 rounded-lg border-zinc-200 text-zinc-500 hover:text-[#FF6B00] bg-white"
                          title="View Details"
                        >
                          <Eye className="w-3.5 h-3.5" />
                        </Button>
                        <Button 
                          variant="outline" 
                          size="icon" 
                          onClick={() => handleEditClick(t)}
                          className="w-8 h-8 rounded-lg border-zinc-200 text-zinc-500 hover:text-[#FF6B00] bg-white"
                          title="Edit"
                        >
                          <Edit className="w-3.5 h-3.5" />
                        </Button>
                        
                        <TournamentActionsDropdown
                          tournament={t}
                          onEditSettings={handleEditClick}
                          onCancelTournament={handleCancelTournament}
                          onDeleteTournament={handleDeleteTournament}
                          canDelete={canDelete}
                        />
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
 
          {/* Table pagination matching screenshot */}
          <div className="flex items-center justify-between p-4 border-t border-zinc-100 bg-white text-xs font-semibold text-zinc-500">
            <span>Showing {rangeStart} to {rangeEnd} of {filteredTournaments.length} tournaments</span>
            
            <div className="flex items-center gap-1.5">
              <Button
                variant="outline"
                size="icon"
                disabled={page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                className="w-7 h-7 rounded-lg border-zinc-200 bg-white hover:bg-zinc-50 disabled:opacity-50"
              >
                <ChevronLeft className="w-3.5 h-3.5" />
              </Button>
              <span className="px-2 text-zinc-600">{page} / {totalPages}</span>
              <Button
                variant="outline"
                size="icon"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                className="w-7 h-7 rounded-lg border-zinc-200 bg-white hover:bg-zinc-50 disabled:opacity-50"
              >
                <ChevronRight className="w-3.5 h-3.5" />
              </Button>
            </div>
 
            <div className="flex items-center gap-2 border border-zinc-200 rounded-xl px-2.5 py-1 bg-white">
              <span>{PAGE_SIZE} / page</span>
            </div>
          </div>
        </CardContent>
      </Card>
 
      {/* Slide-over sheet for editing tournament */}
      <Sheet open={!!editingTournament} onOpenChange={(open) => !open && setEditingTournament(null)}>
        <SheetContent className="sm:max-w-md bg-white border-l border-zinc-200 shadow-xl overflow-y-auto">
          <SheetHeader className="pb-4">
            <SheetTitle className="text-sm font-bold">Edit Tournament Settings</SheetTitle>
            <SheetDescription className="text-[11px] text-zinc-400">
              Modify details for {editingTournament?.name}. Changes persist immediately.
            </SheetDescription>
          </SheetHeader>
          {editingTournament && (
            <form onSubmit={editForm.handleSubmit(handleEditSubmit)} className="space-y-4 py-2">
              <div className="space-y-1">
                <Label htmlFor="edit-name" className="text-xs font-semibold text-zinc-700">Tournament Name</Label>
                <Input
                  id="edit-name"
                  {...editForm.register('name')}
                  className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                />
                {editForm.formState.errors.name && (
                  <p className="text-[10px] text-rose-600 font-semibold">{editForm.formState.errors.name.message}</p>
                )}
              </div>
 
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="edit-game" className="text-xs font-semibold text-zinc-700">Game Title</Label>
                  <Input
                    id="edit-game"
                    {...editForm.register('game')}
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {editForm.formState.errors.game && (
                    <p className="text-[10px] text-rose-600 font-semibold">{editForm.formState.errors.game.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="edit-mode" className="text-xs font-semibold text-zinc-700">Match Mode</Label>
                  <Input
                    id="edit-mode"
                    {...editForm.register('mode')}
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {editForm.formState.errors.mode && (
                    <p className="text-[10px] text-rose-600 font-semibold">{editForm.formState.errors.mode.message}</p>
                  )}
                </div>
              </div>
 
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="edit-stage" className="text-xs font-semibold text-zinc-700">Stage / Subtitle</Label>
                  <Input
                    id="edit-stage"
                    {...editForm.register('stage')}
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {editForm.formState.errors.stage && (
                    <p className="text-[10px] text-rose-600 font-semibold">{editForm.formState.errors.stage.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="edit-prize" className="text-xs font-semibold text-zinc-700">Prize Pool</Label>
                  <Input
                    id="edit-prize"
                    {...editForm.register('prize')}
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {editForm.formState.errors.prize && (
                    <p className="text-[10px] text-rose-600 font-semibold">{editForm.formState.errors.prize.message}</p>
                  )}
                </div>
              </div>
 
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label className="text-xs font-semibold text-zinc-700">Start Date</Label>
                  <Controller
                    control={editForm.control}
                    name="startDate"
                    render={({ field }) => (
                      <DatePicker
                        date={field.value}
                        setDate={field.onChange}
                      />
                    )}
                  />
                  {editForm.formState.errors.startDate && (
                    <p className="text-[10px] text-rose-600 font-semibold">{editForm.formState.errors.startDate.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="edit-slots" className="text-xs font-semibold text-zinc-700">Team Slots</Label>
                  <Input
                    id="edit-slots"
                    type="number"
                    {...editForm.register('slots', { valueAsNumber: true })}
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                  {editForm.formState.errors.slots && (
                    <p className="text-[10px] text-rose-600 font-semibold">{editForm.formState.errors.slots.message}</p>
                  )}
                </div>
              </div>
 
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="edit-entryFee" className="text-xs font-semibold text-zinc-700">Entry Fee</Label>
                  <Input
                    id="edit-entryFee"
                    {...editForm.register('entryFee')}
                    className="bg-white border-zinc-200 h-9 rounded-lg text-xs"
                  />
                </div>
                <label className="flex items-center gap-2 text-xs font-semibold text-zinc-700 pt-6">
                  <input type="checkbox" {...editForm.register('isFeatured')} className="h-4 w-4 rounded border-zinc-300" />
                  Featured on app home
                </label>
              </div>

              <div className="space-y-1">
                <Label htmlFor="edit-status" className="text-xs font-semibold text-zinc-700">Tournament Status</Label>
                <select
                  id="edit-status"
                  {...editForm.register('status')}
                  className="w-full bg-white border border-zinc-200 rounded-lg text-xs px-2.5 h-9 outline-none cursor-pointer"
                >
                  <option value="ONGOING">ONGOING</option>
                  <option value="UPCOMING">UPCOMING</option>
                  <option value="COMPLETED">COMPLETED</option>
                  <option value="CANCELLED">CANCELLED</option>
                </select>
              </div>
 
              <SheetFooter className="pt-6">
                <Button type="submit" className="w-full bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-semibold text-xs rounded-xl h-10">
                  Save Changes
                </Button>
              </SheetFooter>
            </form>
          )}
        </SheetContent>
      </Sheet>

      <Dialog open={!!deletingTournament} onOpenChange={(open) => !open && setDeletingTournament(null)}>
        <DialogContent className="max-w-sm bg-white border border-zinc-200 rounded-2xl shadow-2xl">
          <DialogHeader>
            <DialogTitle className="text-base font-black tracking-tight text-red-600 flex items-center gap-2">
              <Trash2 className="w-5 h-5" />
              Delete Tournament
            </DialogTitle>
            <DialogDescription className="text-xs text-zinc-500">
              This will permanently remove the tournament, its matches, registrations, and chat history. This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <div className="py-2 flex flex-col gap-1">
            <span className="text-xs font-bold text-zinc-800">{deletingTournament?.name}</span>
            <span className="text-[10px] text-zinc-400">
              {deletingTournament?.game} · {deletingTournament?.joined}/{deletingTournament?.slots} players
            </span>
          </div>
          <DialogFooter className="pt-2 border-t border-zinc-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setDeletingTournament(null)}
              disabled={isDeleting}
              className="border-zinc-200 hover:bg-zinc-50 font-bold text-xs rounded-xl"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={confirmDeleteTournament}
              disabled={isDeleting}
              className="bg-red-600 hover:bg-red-700 text-white font-bold text-xs rounded-xl"
            >
              {isDeleting ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 mr-2 animate-spin" /> Deleting...
                </>
              ) : 'Delete'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
