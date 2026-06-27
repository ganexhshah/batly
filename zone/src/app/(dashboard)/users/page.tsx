'use client';

import React, { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
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
  Users2, Plus, Loader2, Search, Trash2, Mail, 
  Gamepad2, Coins, ShieldCheck, Shield, Award, Calendar,
  ChevronLeft, ChevronRight, ChevronDown, CheckCircle2, UserCheck
} from 'lucide-react';
import { apiPost, apiDelete } from '@/lib/api';
import { useAdminUsers, useInvalidateAdminUsers, isInitialLoad, type AdminUser } from '@/lib/admin-queries';
import { toast } from 'sonner';

// Zod schema for staff invitation
const inviteSchema = z.object({
  name: z.string().min(2, { message: 'Name must be at least 2 characters' }),
  email: z.string().email({ message: 'Please enter a valid email address' }),
  role: z.enum(['Admin', 'Moderator', 'Host', 'Player'], { message: 'Please select a valid role' }),
});

type InviteFormValues = z.infer<typeof inviteSchema>;

export default function UsersPage() {
  const { theme } = useAppStore();
  const { data: users = [], isPending } = useAdminUsers();
  const invalidateUsers = useInvalidateAdminUsers();
  const loading = isInitialLoad(isPending, users);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [page, setPage] = useState(1);
  const PAGE_SIZE = 10;
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [revokingId, setRevokingId] = useState<number | null>(null);

  const inviteForm = useForm<InviteFormValues>({
    resolver: zodResolver(inviteSchema),
    defaultValues: {
      name: '',
      email: '',
      role: 'Moderator',
    },
  });

  // Get currently logged-in user from localStorage
  const [currentUser, setCurrentUser] = useState<any>(null);
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        const stored = localStorage.getItem('battly_user');
        if (stored) {
          setCurrentUser(JSON.parse(stored));
        }
      } catch (_) {}
    }
  }, []);

  const handleInviteSubmit = async (values: InviteFormValues) => {
    try {
      await apiPost('/admin/users/invite', {
        name: values.name,
        email: values.email,
        role: values.role,
      });

      setDialogOpen(false);
      inviteForm.reset();
      toast.success('Staff invitation sent successfully!');
      invalidateUsers();
    } catch (err: any) {
      toast.error('Failed to invite staff member', { description: err.message });
    }
  };

  const handleRevokeAccess = async (user: AdminUser) => {
    if (currentUser && currentUser.id === user.id) {
      toast.error("Cannot revoke your own access!");
      return;
    }

    if (!confirm(`Are you sure you want to revoke access for ${user.name}? This will permanently delete their account.`)) {
      return;
    }

    try {
      setRevokingId(user.id);
      await apiDelete(`/admin/users/${user.id}/revoke`);
      toast.success(`Access revoked for ${user.name}`);
      invalidateUsers();
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

  // Role Badge visual helper
  const getRoleBadge = (role: string) => {
    switch (role) {
      case 'Admin':
        return (
          <Badge className="bg-rose-50 text-rose-600 border border-rose-100 dark:bg-rose-950/20 dark:text-rose-400 dark:border-rose-900/30 hover:bg-rose-50 font-bold text-[9px] px-2.5 py-0.5 rounded-md">
            ADMIN
          </Badge>
        );
      case 'Moderator':
        return (
          <Badge className="bg-blue-50 text-blue-600 border border-blue-100 dark:bg-blue-950/20 dark:text-blue-400 dark:border-blue-900/30 hover:bg-blue-50 font-bold text-[9px] px-2.5 py-0.5 rounded-md">
            MODERATOR
          </Badge>
        );
      case 'Host':
        return (
          <Badge className="bg-purple-50 text-purple-600 border border-purple-100 dark:bg-purple-950/20 dark:text-purple-400 dark:border-purple-900/30 hover:bg-purple-50 font-bold text-[9px] px-2.5 py-0.5 rounded-md">
            HOST
          </Badge>
        );
      default:
        return (
          <Badge className="bg-zinc-100 text-zinc-700 border border-zinc-200 dark:bg-zinc-800 dark:text-zinc-300 dark:border-zinc-700 hover:bg-zinc-100 font-bold text-[9px] px-2.5 py-0.5 rounded-md">
            PLAYER
          </Badge>
        );
    }
  };

  // Filter & Search Logic
  const filteredUsers = users.filter((u) => {
    const matchesSearch = 
      u.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (u.ign && u.ign.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (u.game_uid && u.game_uid.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesRole = roleFilter === 'all' || u.role === roleFilter;
    const matchesStatus = statusFilter === 'all' || u.status === statusFilter;

    return matchesSearch && matchesRole && matchesStatus;
  });

  useEffect(() => {
    setPage(1);
  }, [searchQuery, roleFilter, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / PAGE_SIZE));
  const paginatedUsers = filteredUsers.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const rangeStart = filteredUsers.length === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const rangeEnd = Math.min(page * PAGE_SIZE, filteredUsers.length);

  return (
    <div className={`p-6 md:p-8 space-y-6 min-h-screen bg-zinc-50/50 ${theme === 'dark' ? 'bg-[#0F1115]' : ''}`}>
      {/* Title & Action Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className={`text-2xl font-black tracking-tight ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
            Staff & User Management
          </h2>
          <p className={`text-xs font-medium mt-1 ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>
            Manage administration roles, system access, and user directories.
          </p>
        </div>

        {/* Invite Staff Dialog */}
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger
            render={
              <Button className={`bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-extrabold text-xs rounded-xl flex items-center gap-2 h-10 px-4 shadow-sm`} />
            }
          >
            <Plus className="w-4.5 h-4.5" />
            Invite Staff
          </DialogTrigger>
          <DialogContent className={`sm:max-w-md bg-white border border-zinc-200 shadow-xl rounded-2xl ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
            <DialogHeader>
              <DialogTitle className="text-sm font-bold">Invite New Staff Member</DialogTitle>
              <DialogDescription className={`text-[11px] ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>
                Send system access invitation and assign administrative privileges.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={inviteForm.handleSubmit(handleInviteSubmit)} className="space-y-4 py-2">
              <div className="space-y-1">
                <Label htmlFor="name" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>
                  Full Name
                </Label>
                <Input
                  id="name"
                  {...inviteForm.register('name')}
                  placeholder="e.g. Ganesh Shah"
                  className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                />
                {inviteForm.formState.errors.name && (
                  <p className="text-[10px] text-rose-600 font-semibold">{inviteForm.formState.errors.name.message}</p>
                )}
              </div>

              <div className="space-y-1">
                <Label htmlFor="email" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>
                  Email Address
                </Label>
                <Input
                  id="email"
                  type="email"
                  {...inviteForm.register('email')}
                  placeholder="name@battly.com"
                  className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                />
                {inviteForm.formState.errors.email && (
                  <p className="text-[10px] text-rose-600 font-semibold">{inviteForm.formState.errors.email.message}</p>
                )}
              </div>

              <div className="space-y-1">
                <Label htmlFor="role" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>
                  System Role
                </Label>
                <select
                  id="role"
                  {...inviteForm.register('role')}
                  className={`w-full bg-white border border-zinc-200 rounded-lg text-xs px-2.5 h-9 outline-none cursor-pointer ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                >
                  <option value="Moderator">Moderator</option>
                  <option value="Admin">Admin</option>
                  <option value="Host">Host</option>
                  <option value="Player">Player (Regular User)</option>
                </select>
                {inviteForm.formState.errors.role && (
                  <p className="text-[10px] text-rose-600 font-semibold">{inviteForm.formState.errors.role.message}</p>
                )}
              </div>

              <DialogFooter className="pt-4">
                <Button type="submit" className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-semibold text-xs rounded-xl h-10 px-4">
                  Send Invitation
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Stats Summary Panel */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Total Directory</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : users.length}
              </span>
              <span className="text-[10px] font-bold text-emerald-500">Registered users & staff</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-orange-50 flex items-center justify-center border border-orange-100 shrink-0">
              <Users2 className="w-6 h-6 text-[#FF6B00]" />
            </div>
          </CardContent>
        </Card>

        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Admins & Hosts</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : users.filter(u => u.role === 'Admin' || u.role === 'Host').length}
              </span>
              <span className="text-[10px] font-bold text-purple-500">Privileged accounts</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-purple-50 flex items-center justify-center border border-purple-100 shrink-0">
              <Shield className="w-6 h-6 text-[#A855F7]" />
            </div>
          </CardContent>
        </Card>

        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Active Accounts</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : users.filter(u => u.status === 'Active').length}
              </span>
              <span className="text-[10px] font-bold text-emerald-500">Verified status</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 flex items-center justify-center border border-emerald-100 shrink-0">
              <UserCheck className="w-6 h-6 text-[#10B981]" />
            </div>
          </CardContent>
        </Card>

        <Card className={`bg-white border-zinc-200 shadow-sm rounded-2xl overflow-hidden ${theme === 'dark' ? 'bg-[#161920] border-zinc-800' : ''}`}>
          <CardContent className="p-5 flex items-center justify-between">
            <div className="space-y-2">
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Pending Invites</span>
              <span className={`text-2xl font-black block ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>
                {loading ? '...' : users.filter(u => u.status === 'Pending').length}
              </span>
              <span className="text-[10px] font-bold text-amber-500">Awaiting setup</span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-amber-50 flex items-center justify-center border border-amber-100 shrink-0">
              <Calendar className="w-6 h-6 text-[#FF8F00]" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Search & Filter Row */}
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

          {/* Role Filter dropdown */}
          <div className="relative">
            <select 
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
              className={`bg-white border border-zinc-200 rounded-xl pl-3 pr-8 py-1.5 text-xs font-semibold text-zinc-700 outline-none appearance-none cursor-pointer shadow-sm hover:bg-zinc-50 ${theme === 'dark' ? 'bg-[#161920] border-zinc-800 text-zinc-300 hover:bg-[#1A1D24]' : ''}`}
            >
              <option value="all">All Roles</option>
              <option value="Admin">Admin</option>
              <option value="Moderator">Moderator</option>
              <option value="Host">Host</option>
              <option value="Player">Player</option>
            </select>
            <ChevronDown className="w-3.5 h-3.5 text-zinc-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>

          {/* Status Filter dropdown */}
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
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 pl-6">User</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">In-Game Profile</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Role</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Status</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Wallet Balance</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3">Joined Date</TableHead>
                <TableHead className="text-[9px] uppercase font-bold text-zinc-400 py-3 pr-6 text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={7} className="text-center py-20 text-zinc-400 text-xs">
                    <Loader2 className="w-7 h-7 animate-spin mx-auto text-[#FF6B00]" />
                    <p className="mt-3 text-zinc-400 font-semibold">Retrieving user roster directory...</p>
                  </TableCell>
                </TableRow>
              ) : filteredUsers.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} className="text-center py-12 text-zinc-400 text-xs font-semibold">
                    No users match current search criteria.
                  </TableCell>
                </TableRow>
              ) : (
                paginatedUsers.map((user) => {
                  const isSelf = currentUser && currentUser.id === user.id;
                  
                  return (
                    <TableRow 
                      key={user.id} 
                      className={`border-b border-zinc-50 hover:bg-zinc-50/30 ${theme === 'dark' ? 'border-zinc-800 hover:bg-[#1A1D24]/30' : ''}`}
                    >
                      {/* User metadata */}
                      <TableCell className="py-4 pl-6 flex items-center gap-3">
                        <Avatar className="w-8 h-8 ring-1 ring-zinc-200 dark:ring-zinc-800">
                          {user.avatar_url ? (
                            <img src={user.avatar_url} alt={user.name} className="object-cover rounded-full" />
                          ) : (
                            <AvatarFallback className="text-[10px] bg-orange-50 text-[#FF6B00] dark:bg-zinc-800 font-bold">
                              {user.name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
                            </AvatarFallback>
                          )}
                        </Avatar>
                        <div>
                          <div className="flex items-center gap-1.5">
                            <span className={`text-xs font-bold ${theme === 'dark' ? 'text-zinc-100' : 'text-zinc-800'}`}>
                              {user.name}
                            </span>
                            {isSelf && (
                              <Badge className="bg-[#FFF6F0] text-[#FF6B00] border border-orange-100 dark:bg-[#FF6B00]/10 text-[8px] py-0 px-1 hover:bg-[#FFF6F0]">
                                You
                              </Badge>
                            )}
                          </div>
                          <span className="text-[10px] text-zinc-400 font-medium block mt-0.5">
                            {user.email}
                          </span>
                        </div>
                      </TableCell>

                      {/* In game details */}
                      <TableCell className="py-4">
                        {user.ign || user.game_uid ? (
                          <div>
                            <div className="flex items-center gap-1">
                              <Gamepad2 className="w-3.5 h-3.5 text-zinc-400" />
                              <span className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-200' : 'text-zinc-700'}`}>
                                {user.ign || '—'}
                              </span>
                            </div>
                            <span className="text-[9px] text-zinc-400 font-semibold block mt-0.5">
                              ID: {user.game_uid || '—'}
                            </span>
                          </div>
                        ) : (
                          <span className="text-xs text-zinc-400 font-medium">—</span>
                        )}
                      </TableCell>

                      {/* Role */}
                      <TableCell className="py-4">
                        {getRoleBadge(user.role)}
                      </TableCell>

                      {/* Status */}
                      <TableCell className="py-4">
                        {getStatusBadge(user.status)}
                      </TableCell>

                      {/* Balance */}
                      <TableCell className="py-4">
                        <div className="flex items-center gap-1 text-xs">
                          <Coins className="w-3.5 h-3.5 text-[#FF8F00] shrink-0" />
                          <span className={`font-extrabold ${theme === 'dark' ? 'text-zinc-200' : 'text-zinc-800'}`}>
                            NPR {parseFloat(String(user.wallet_balance || 0)).toLocaleString()}
                          </span>
                        </div>
                      </TableCell>

                      {/* Created At */}
                      <TableCell className="py-4">
                        <span className="text-xs font-semibold text-zinc-500">
                          {new Date(user.created_at).toLocaleDateString('en-US', {
                            month: 'short',
                            day: 'numeric',
                            year: 'numeric'
                          })}
                        </span>
                      </TableCell>

                      {/* Actions */}
                      <TableCell className="py-4 pr-6 text-right">
                        <Button
                          variant="outline"
                          size="icon"
                          disabled={isSelf || revokingId === user.id}
                          onClick={() => handleRevokeAccess(user)}
                          className={`w-8 h-8 rounded-lg border-zinc-200 text-zinc-500 hover:text-rose-600 bg-white shadow-sm hover:border-rose-100 hover:bg-rose-50/50 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-zinc-400 hover:bg-rose-950/20 hover:text-rose-400' : ''}`}
                        >
                          {revokingId === user.id ? (
                            <Loader2 className="w-3.5 h-3.5 animate-spin" />
                          ) : (
                            <Trash2 className="w-3.5 h-3.5" />
                          )}
                        </Button>
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>

          {/* Simple pagination information footer */}
          {!loading && filteredUsers.length > 0 && (
            <div className={`flex items-center justify-between p-4 border-t border-zinc-100 bg-white text-xs font-semibold text-zinc-500 ${theme === 'dark' ? 'border-zinc-800 bg-[#161920] text-zinc-400' : ''}`}>
              <span>Showing {rangeStart} to {rangeEnd} of {filteredUsers.length} users</span>
              
              <div className="flex items-center gap-1.5">
                <Button
                  variant="outline"
                  size="icon"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  className="w-7 h-7 rounded-lg border-zinc-200 dark:border-zinc-800 bg-white dark:bg-[#161920] hover:bg-zinc-50 disabled:opacity-40"
                >
                  <ChevronLeft className="w-3.5 h-3.5" />
                </Button>
                <span className="px-2">{page} / {totalPages}</span>
                <Button
                  variant="outline"
                  size="icon"
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  className="w-7 h-7 rounded-lg border-zinc-200 dark:border-zinc-800 bg-white dark:bg-[#161920] hover:bg-zinc-50 disabled:opacity-40"
                >
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
