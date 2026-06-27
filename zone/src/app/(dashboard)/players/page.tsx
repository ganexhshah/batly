'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useRouter } from 'next/navigation';
import { useAppStore } from '@/store/useAppStore';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { 
  Plus, Loader2, Search, Trash2, Mail, Gamepad2, Coins, 
  UserCheck, Calendar, ChevronLeft, ChevronRight, Users2, Trophy, ChevronDown, Eye
} from 'lucide-react';
import { apiPost, apiPatch } from '@/lib/api';
import { usePlayers, useInvalidatePlayers, isInitialLoad, type AdminUser } from '@/lib/admin-queries';
import { canManagePlayers, getStoredRole } from '@/lib/role-permissions';
import { toast } from 'sonner';

// Zod schema for player invitation
const addPlayerSchema = z.object({
  name: z.string().min(2, { message: 'Name must be at least 2 characters' }),
  email: z.string().email({ message: 'Please enter a valid email address' }),
});

type AddPlayerFormValues = z.infer<typeof addPlayerSchema>;

export default function PlayersPage() {
  const router = useRouter();
  const { theme } = useAppStore();
  const canManage = canManagePlayers(getStoredRole());
  const [dialogOpen, setDialogOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [revokingId, setRevokingId] = useState<number | null>(null);
  const { data: players = [], isPending } = usePlayers(searchQuery, statusFilter);
  const invalidatePlayers = useInvalidatePlayers();
  const loading = isInitialLoad(isPending, players);

  const playerForm = useForm<AddPlayerFormValues>({
    resolver: zodResolver(addPlayerSchema),
    defaultValues: {
      name: '',
      email: '',
    },
  });

  const handleAddPlayerSubmit = async (values: AddPlayerFormValues) => {
    try {
      await apiPost('/admin/users/invite', {
        name: values.name,
        email: values.email,
        role: 'Player',
      });

      setDialogOpen(false);
      playerForm.reset();
      toast.success('Player registered / invited successfully!');
      invalidatePlayers();
    } catch (err: any) {
      toast.error('Failed to register player', { description: err.message });
    }
  };

  const handleRevokeAccess = async (player: AdminUser) => {
    if (!confirm(`Are you sure you want to revoke access/delete account for ${player.name}?`)) {
      return;
    }

    try {
      setRevokingId(player.id);
      await apiPatch(`/admin/players/${player.id}/status`, { status: 'Revoked' });
      toast.success(`Access revoked for ${player.name}`);
      invalidatePlayers();
    } catch (err: any) {
      toast.error('Failed to revoke access', { description: err.message });
    } finally {
      setRevokingId(null);
    }
  };

  // Status Badge visual helper
  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'Active':
        return (
          <Badge className="bg-emerald-50 text-emerald-600 border border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900/30 hover:bg-emerald-50 font-bold text-[9px] px-2 py-0.5 rounded-md">
            ACTIVE
          </Badge>
        );
      case 'Pending':
        return (
          <Badge className="bg-amber-50 text-amber-600 border border-amber-100 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900/30 hover:bg-amber-50 font-bold text-[9px] px-2 py-0.5 rounded-md">
            PENDING
          </Badge>
        );
      default:
        return (
          <Badge className="bg-zinc-50 text-zinc-600 border border-zinc-200 hover:bg-zinc-50 font-bold text-[9px] px-2 py-0.5 rounded-md">
            {status.toUpperCase()}
          </Badge>
        );
    }
  };

  // Client-side filter for instant UI (server also filters via query params)
  const filteredPlayers = players.filter((p) => {
    const matchesSearch =
      !searchQuery ||
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.ign && p.ign.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (p.game_uid && p.game_uid.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesStatus = statusFilter === 'all' || p.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  // Calculate dynamic stats
  const totalPlayers = players.length;
  const activePlayers = players.filter(p => p.status === 'Active').length;
  const pendingPlayers = players.filter(p => p.status === 'Pending').length;
  const totalBalance = players.reduce((sum, p) => sum + parseFloat(String(p.wallet_balance || 0)), 0);

  return (
    <div className={`p-6 md:p-8 space-y-6 min-h-screen bg-zinc-50/50 ${theme === 'dark' ? 'bg-[#0F1115]' : ''}`}>
      {/* Title & Action Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className={`text-2xl font-black tracking-tight ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
            Players Directory
          </h2>
          <p className={`text-xs font-medium mt-1 ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>
            Monitor registrations, system access, and profiles for regular platform players.
          </p>
        </div>

        {/* Add Player Dialog — admin only */}
        {canManage && (
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger
            render={
              <Button className={`bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-extrabold text-xs rounded-xl flex items-center gap-2 h-10 px-4 shadow-sm`} />
            }
          >
            <Plus className="w-4.5 h-4.5" />
            Add Player
          </DialogTrigger>
          <DialogContent className={`sm:max-w-md bg-white border border-zinc-200 shadow-xl rounded-2xl ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
            <DialogHeader>
              <DialogTitle className="text-sm font-bold">Register Esports Player</DialogTitle>
              <DialogDescription className={`text-[11px] ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>
                Add a new regular gamer account to the platform directory.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={playerForm.handleSubmit(handleAddPlayerSubmit)} className="space-y-4 py-2">
              <div className="space-y-1">
                <Label htmlFor="name" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>
                  Full Name
                </Label>
                <Input
                  id="name"
                  {...playerForm.register('name')}
                  placeholder="e.g. Ganesh Shah"
                  className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                />
                {playerForm.formState.errors.name && (
                  <p className="text-[10px] text-rose-600 font-semibold">{playerForm.formState.errors.name.message}</p>
                )}
              </div>

              <div className="space-y-1">
                <Label htmlFor="email" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>
                  Email Address
                </Label>
                <Input
                  id="email"
                  type="email"
                  {...playerForm.register('email')}
                  placeholder="gamer@domain.com"
                  className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                />
                {playerForm.formState.errors.email && (
                  <p className="text-[10px] text-rose-600 font-semibold">{playerForm.formState.errors.email.message}</p>
                )}
              </div>

              <DialogFooter className="pt-4">
                <Button type="submit" className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-semibold text-xs rounded-xl h-10 px-4">
                  Register Player
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
        )}
      </div>

      {/* Stats Cards Panel */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Players</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : totalPlayers}
              </span>
              <span className="text-[10px] font-bold text-emerald-500">Registered competitors</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-orange-50 flex items-center justify-center border border-orange-100 shrink-0">
              <Users2 className="w-6 h-6 text-[#FF6B00]" />
            </div>
          </CardContent>
        </Card>

        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Active Players</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : activePlayers}
              </span>
              <span className="text-[10px] font-bold text-emerald-500">Live verified accounts</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 flex items-center justify-center border border-emerald-100 shrink-0">
              <UserCheck className="w-6 h-6 text-[#10B981]" />
            </div>
          </CardContent>
        </Card>

        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Pending setups</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : pendingPlayers}
              </span>
              <span className="text-[10px] font-bold text-amber-500">Awaiting login profile</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-amber-50 flex items-center justify-center border border-amber-100 shrink-0">
              <Calendar className="w-6 h-6 text-[#FF8F00]" />
            </div>
          </CardContent>
        </Card>

        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Cumulative Balances</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : `NPR ${totalBalance.toLocaleString()}`}
              </span>
              <span className="text-[10px] font-bold text-purple-505 text-[#FF6B00]">Total cash in wallets</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-purple-50 flex items-center justify-center border border-purple-100 shrink-0">
              <Coins className="w-6 h-6 text-[#A855F7]" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Search & Filter Controls */}
      <div className="flex flex-col lg:flex-row justify-between items-stretch lg:items-center gap-4">
        <div className="flex flex-wrap items-center gap-3 flex-1">
          {/* Search field */}
          <div className="relative max-w-xs w-full">
            <Search className="w-4 h-4 text-zinc-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <Input 
              placeholder="Search by name, email, IGN..." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className={`bg-white border-zinc-200 pl-9 pr-4 text-xs h-9 rounded-xl w-full ${theme === 'dark' ? 'bg-[#161920] border-zinc-800 text-white' : ''}`}
            />
          </div>

          {/* Status Filter select */}
          <div className="relative">
            <select 
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className={`bg-white border border-zinc-200 rounded-xl pl-3 pr-8 py-1.5 text-xs font-semibold text-zinc-700 outline-none appearance-none cursor-pointer shadow-sm hover:bg-zinc-50 ${theme === 'dark' ? 'bg-[#161920] border-zinc-800 text-zinc-300 hover:bg-[#1A1D24]' : ''}`}
            >
              <option value="all">All Status</option>
              <option value="Active">Active</option>
              <option value="Pending">Pending</option>
            </select>
            <ChevronDown className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
        </div>
      </div>

      {/* Directory Table */}
      <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden p-0 ${theme === 'dark' ? 'bg-[#161920] border-zinc-800 text-white' : ''}`}>
        <CardContent className="p-0">
          <Table>
            <TableHeader className={`border-zinc-100 bg-zinc-50/50 ${theme === 'dark' ? 'border-zinc-800 bg-zinc-950/20' : ''}`}>
              <TableRow className={`border-zinc-100 hover:bg-transparent ${theme === 'dark' ? 'border-zinc-800' : ''}`}>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3 pl-6">Player</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">In-Game Profile</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">Status</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">Wallet Balance</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3">Registration Date</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-500 py-3 pr-6 text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-20 text-zinc-400 text-xs">
                    <Loader2 className="w-7 h-7 animate-spin mx-auto text-[#FF6B00]" />
                    <p className="mt-3 text-zinc-400 font-semibold">Retrieving player directory roster...</p>
                  </TableCell>
                </TableRow>
              ) : filteredPlayers.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-12 text-zinc-400 text-xs font-semibold">
                    No players found matching the query.
                  </TableCell>
                </TableRow>
              ) : (
                filteredPlayers.map((player) => (
                  <TableRow 
                    key={player.id} 
                    className={`border-b border-zinc-50 hover:bg-zinc-50/30 ${theme === 'dark' ? 'border-zinc-800 hover:bg-[#1A1D24]/30' : ''}`}
                  >
                    {/* Player profile avatar metadata */}
                    <TableCell className="py-4 pl-6 flex items-center gap-3">
                      <Avatar className="w-8 h-8 ring-1 ring-zinc-200 dark:ring-zinc-800">
                        {player.avatar_url ? (
                          <img src={player.avatar_url} alt={player.name} className="object-cover rounded-full" />
                        ) : (
                          <AvatarFallback className="text-[10px] bg-orange-50 text-[#FF6B00] dark:bg-zinc-800 font-bold">
                            {player.name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
                          </AvatarFallback>
                        )}
                      </Avatar>
                      <div>
                        <span className={`text-xs font-bold block ${theme === 'dark' ? 'text-zinc-100' : 'text-zinc-805'}`}>
                          {player.name}
                        </span>
                        <span className="text-[10px] text-zinc-400 font-medium block mt-0.5">
                          {player.email}
                        </span>
                      </div>
                    </TableCell>

                    {/* IGN & UID */}
                    <TableCell className="py-4">
                      {player.ign || player.game_uid ? (
                        <div>
                          <div className="flex items-center gap-1">
                            <Gamepad2 className="w-3.5 h-3.5 text-zinc-400 shrink-0" />
                            <span className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-200' : 'text-zinc-700'}`}>
                              {player.ign || '—'}
                            </span>
                          </div>
                          <span className="text-[9px] text-zinc-400 font-semibold block mt-0.5">
                            UID: {player.game_uid || '—'}
                          </span>
                        </div>
                      ) : (
                        <span className="text-xs text-zinc-400 font-medium">—</span>
                      )}
                    </TableCell>

                    {/* Status Badge */}
                    <TableCell className="py-4">
                      {getStatusBadge(player.status)}
                    </TableCell>

                    {/* Wallet Balance */}
                    <TableCell className="py-4">
                      <div className="flex items-center gap-1 text-xs">
                        <Coins className="w-3.5 h-3.5 text-[#FF8F00] shrink-0" />
                        <span className={`font-extrabold ${theme === 'dark' ? 'text-zinc-205' : 'text-zinc-800'}`}>
                          NPR {parseFloat(String(player.wallet_balance || 0)).toLocaleString()}
                        </span>
                      </div>
                    </TableCell>

                    {/* Registered at */}
                    <TableCell className="py-4">
                      <span className="text-xs font-semibold text-zinc-505">
                        {new Date(player.created_at).toLocaleDateString('en-US', {
                          month: 'short',
                          day: 'numeric',
                          year: 'numeric'
                        })}
                      </span>
                    </TableCell>

                    {/* Actions */}
                    <TableCell className="py-4 pr-6 text-right">
                      <div className="flex items-center gap-1.5 justify-end">
                        <Button
                          variant="outline"
                          size="icon"
                          onClick={() => router.push(`/players/${player.id}`)}
                          className={`w-8 h-8 rounded-lg border-zinc-200 text-zinc-500 hover:text-[#FF6B00] bg-white shadow-sm hover:bg-zinc-50 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-zinc-400 hover:text-[#FF6B00] hover:bg-zinc-800' : ''}`}
                          title="View Player Console"
                        >
                          <Eye className="w-3.5 h-3.5" />
                        </Button>
                        {canManage && (
                        <Button
                          variant="outline"
                          size="icon"
                          disabled={revokingId === player.id}
                          onClick={() => handleRevokeAccess(player)}
                          className={`w-8 h-8 rounded-lg border-zinc-200 text-zinc-500 hover:text-rose-600 bg-white shadow-sm hover:border-rose-100 hover:bg-rose-50/50 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-zinc-400 hover:bg-rose-950/20 hover:text-rose-400' : ''}`}
                          title="Revoke Player Access"
                        >
                          {revokingId === player.id ? (
                            <Loader2 className="w-3.5 h-3.5 animate-spin" />
                          ) : (
                            <Trash2 className="w-3.5 h-3.5" />
                          )}
                        </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>

          {/* Simple directory footer */}
          {!loading && filteredPlayers.length > 0 && (
            <div className={`flex items-center justify-between p-4 border-t border-zinc-100 bg-white text-xs font-semibold text-zinc-500 ${theme === 'dark' ? 'border-zinc-800 bg-[#161920] text-zinc-400' : ''}`}>
              <span>Showing 1 to {filteredPlayers.length} of {players.length} players</span>
              
              <div className="flex items-center gap-1.5">
                <Button variant="outline" size="icon" disabled className="w-7 h-7 rounded-lg border-zinc-200 dark:border-zinc-800 bg-white dark:bg-[#161920] hover:bg-zinc-50 disabled:opacity-40">
                  <ChevronLeft className="w-3.5 h-3.5" />
                </Button>
                <Button className="w-7 h-7 rounded-lg bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white text-xs font-bold">1</Button>
                <Button variant="outline" size="icon" disabled className="w-7 h-7 rounded-lg border-zinc-200 dark:border-zinc-800 bg-white dark:bg-[#161920] hover:bg-zinc-50 disabled:opacity-40">
                  <ChevronRight className="w-3.5 h-3.5" />
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
