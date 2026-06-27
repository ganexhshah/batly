'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useAppStore } from '@/store/useAppStore';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Users, Plus, ShieldCheck, Loader2 } from 'lucide-react';
import { apiPost } from '@/lib/api';
import { useTeams, useInvalidateTeams, isInitialLoad } from '@/lib/admin-queries';
import { RequireRole } from '@/components/require-role';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { canCreateTeams } from '@/lib/role-permissions';
import { toast } from 'sonner';

const teamSchema = z.object({
  name: z.string().min(2, { message: 'Team name must be at least 2 characters' }),
  tag: z.string().min(2).max(10, { message: 'Tag must be between 2 and 10 characters' }),
  game: z.string().min(2, { message: 'Game title is required' }),
  points: z.number().min(0, { message: 'Points must be 0 or greater' }),
  membersString: z.string().min(3, { message: 'At least one member is required (comma separated)' }),
});

type TeamFormValues = z.infer<typeof teamSchema>;

interface Team {
  id: number;
  name: string;
  tag: string;
  game: string;
  members: string[];
  points: number;
  is_verified?: boolean;
}

export default function TeamsPage() {
  const { theme } = useAppStore();
  const { data: teamsData, isPending, isError, error, refetch } = useTeams();
  const invalidateTeams = useInvalidateTeams();
  const loading = isInitialLoad(isPending, teamsData);
  const teams = teamsData ?? [];
  const [dialogOpen, setDialogOpen] = useState(false);

  const teamForm = useForm<TeamFormValues>({
    resolver: zodResolver(teamSchema),
    defaultValues: {
      name: '',
      tag: '',
      game: '',
      points: 0,
      membersString: '',
    },
  });

  const handleRegisterSubmit = async (values: TeamFormValues) => {
    try {
      const membersArray = values.membersString
        .split(',')
        .map((m) => m.trim())
        .filter((m) => m.length > 0);

      await apiPost('/teams', {
        name: values.name,
        tag: values.tag,
        game: values.game,
        points: values.points,
        is_verified: true,
        members: membersArray,
      });

      setDialogOpen(false);
      teamForm.reset();
      toast.success('Team registered successfully!');
      invalidateTeams();
    } catch (err: any) {
      toast.error('Failed to register team', { description: err.message });
    }
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className={`text-xl font-bold tracking-tight ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>Registered Teams</h2>
          <p className={`text-xs ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Manage organization structures, rosters, and points standings</p>
        </div>

        <RequireRole allow={canCreateTeams}>
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger
            render={
              <Button className={`bg-zinc-900 hover:bg-zinc-800 text-white font-semibold text-xs rounded-lg flex items-center gap-2 h-9 px-4 ${theme === 'dark' ? 'bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white' : ''}`} />
            }
          >
            <Plus className="w-4 h-4" />
            Register Team
          </DialogTrigger>
          <DialogContent className={`sm:max-w-md bg-white border border-zinc-200 shadow-xl rounded-xl ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
            <DialogHeader>
              <DialogTitle className="text-sm font-bold">Register New Esports Team</DialogTitle>
              <DialogDescription className={`text-[11px] ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>
                Add organization and initial player roster to directory.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={teamForm.handleSubmit(handleRegisterSubmit)} className="space-y-4 py-2">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="team-name" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Team Name</Label>
                  <Input
                    id="team-name"
                    {...teamForm.register('name')}
                    placeholder="e.g. Viper Esports"
                    className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                  />
                  {teamForm.formState.errors.name && (
                    <p className="text-[10px] text-rose-600 font-semibold">{teamForm.formState.errors.name.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="team-tag" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Team Tag / Abbreviation</Label>
                  <Input
                    id="team-tag"
                    {...teamForm.register('tag')}
                    placeholder="e.g. VIP"
                    className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                  />
                  {teamForm.formState.errors.tag && (
                    <p className="text-[10px] text-rose-600 font-semibold">{teamForm.formState.errors.tag.message}</p>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="team-game" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Esports Game Title</Label>
                  <Input
                    id="team-game"
                    {...teamForm.register('game')}
                    placeholder="e.g. Valorant"
                    className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                  />
                  {teamForm.formState.errors.game && (
                    <p className="text-[10px] text-rose-600 font-semibold">{teamForm.formState.errors.game.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="team-points" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Ladder Points</Label>
                  <Input
                    id="team-points"
                    type="number"
                    {...teamForm.register('points', { valueAsNumber: true })}
                    className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                  />
                  {teamForm.formState.errors.points && (
                    <p className="text-[10px] text-rose-600 font-semibold">{teamForm.formState.errors.points.message}</p>
                  )}
                </div>
              </div>

              <div className="space-y-1">
                <Label htmlFor="team-members" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Player Roster (Comma separated)</Label>
                <Input
                  id="team-members"
                  {...teamForm.register('membersString')}
                  placeholder="e.g. Jett, Omen, Sova, Sage"
                  className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                />
                {teamForm.formState.errors.membersString && (
                  <p className="text-[10px] text-rose-600 font-semibold">{teamForm.formState.errors.membersString.message}</p>
                )}
              </div>

              <DialogFooter className="pt-4">
                <Button type="submit" className="bg-zinc-900 hover:bg-zinc-800 text-white font-semibold text-xs rounded-lg h-9">
                  Register Esports Team
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
        </RequireRole>
      </div>

      {isError && (
        <QueryErrorBanner error={error} onRetry={() => refetch()} title="Failed to load teams" />
      )}

      {loading ? (
        <div className="text-center py-20">
          <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#FF6B00]" />
          <p className="text-xs text-zinc-400 mt-3 font-semibold">Loading teams standing directory...</p>
        </div>
      ) : teams.length === 0 ? (
        <Card className={`p-12 text-center text-zinc-400 text-xs font-semibold ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800' : ''}`}>
          No teams registered. Click 'Register Team' to add one.
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {teams.map((team) => (
            <Card key={team.id} className={`bg-white border-zinc-200 relative overflow-hidden ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
              <CardHeader className="pb-3 flex flex-row items-start justify-between">
                <div>
                  <CardTitle className="text-sm font-bold flex items-center gap-1.5">
                    {team.name}
                    <Badge className="bg-zinc-100 text-zinc-700 font-bold border border-zinc-200 text-[9px] py-0 px-1.5 rounded-md dark:bg-zinc-800 dark:text-zinc-300 dark:border-zinc-700">
                      {team.tag}
                    </Badge>
                  </CardTitle>
                  <CardDescription className="text-zinc-400 text-xs mt-1">{team.game}</CardDescription>
                </div>
                <div className="flex items-center gap-1 text-[10px] text-zinc-500 font-semibold bg-zinc-50 border border-zinc-200 px-2 py-0.5 rounded-full dark:bg-zinc-800 dark:border-zinc-700 dark:text-zinc-300">
                  <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
                  Verified
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-1.5">
                  <p className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider">Active Roster</p>
                  <div className="flex flex-wrap gap-1.5">
                    {team.members.map((m) => (
                      <div key={m} className="flex items-center gap-1 bg-zinc-50 border border-zinc-200 py-0.5 px-2 rounded-lg text-[10px] text-zinc-600 dark:bg-zinc-800 dark:border-zinc-700 dark:text-zinc-300">
                        <Avatar className="w-3.5 h-3.5">
                          <AvatarFallback className="text-[8px] bg-zinc-200 dark:bg-zinc-700 dark:text-zinc-300 font-bold">{m.slice(0, 1)}</AvatarFallback>
                        </Avatar>
                        <span>{m}</span>
                      </div>
                    ))}
                  </div>
                </div>
                <div className="flex justify-between items-center pt-2 border-t border-zinc-100 dark:border-zinc-800 mt-2 text-xs">
                  <span className="text-zinc-400">Ladder Points</span>
                  <span className="font-bold text-[#FF6B00]">{team.points} pts</span>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
