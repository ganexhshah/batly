'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useAppStore } from '@/store/useAppStore';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Plus, Zap, Loader2 } from 'lucide-react';
import { apiPost } from '@/lib/api';
import { useScrims, useInvalidateScrims, isInitialLoad } from '@/lib/admin-queries';
import { toast } from 'sonner';

const scrimSchema = z.object({
  teams: z.string().min(3, { message: 'Teams description must be at least 3 characters' }),
  game: z.string().min(2, { message: 'Game title must be at least 2 characters' }),
  time: z.string().min(2, { message: 'Time detail is required (e.g. Today, 21:00)' }),
  status: z.enum(['Open', 'Full', 'Finished']),
});

type ScrimFormValues = z.infer<typeof scrimSchema>;

interface Scrim {
  id: number;
  teams: string;
  game: string;
  time: string;
  status: 'Open' | 'Full' | 'Finished';
}

export default function ScrimsPage() {
  const { theme } = useAppStore();
  const { data: scrimsData, isPending } = useScrims();
  const invalidateScrims = useInvalidateScrims();
  const loading = isInitialLoad(isPending, scrimsData);
  const scrims = scrimsData ?? [];
  const [dialogOpen, setDialogOpen] = useState(false);

  const scrimForm = useForm<ScrimFormValues>({
    resolver: zodResolver(scrimSchema),
    defaultValues: {
      teams: '',
      game: '',
      time: '',
      status: 'Open',
    },
  });

  const handleHostSubmit = async (values: ScrimFormValues) => {
    try {
      await apiPost('/scrims', values);
      setDialogOpen(false);
      scrimForm.reset();
      toast.success('Scrim room hosted successfully!');
      invalidateScrims();
    } catch (err: any) {
      toast.error('Failed to host scrim room', { description: err.message });
    }
  };

  // Filter helper
  const filterScrims = (statusFilter?: 'Open' | 'Finished') => {
    if (!statusFilter) return scrims;
    return scrims.filter((s) => s.status === statusFilter);
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className={`text-xl font-bold tracking-tight ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>Scrim Sessions</h2>
          <p className={`text-xs ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Practice matches and quick challenge rooms</p>
        </div>

        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger
            render={
              <Button className={`bg-zinc-900 hover:bg-zinc-800 text-white font-semibold text-xs rounded-lg flex items-center gap-2 h-9 px-4 ${theme === 'dark' ? 'bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white' : ''}`} />
            }
          >
            <Plus className="w-4 h-4" />
            Host Scrim
          </DialogTrigger>
          <DialogContent className={`sm:max-w-md bg-white border border-zinc-200 shadow-xl rounded-xl ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
            <DialogHeader>
              <DialogTitle className="text-sm font-bold">Host New Scrim Session</DialogTitle>
              <DialogDescription className={`text-[11px] ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>
                Create a practice lobby for esports teams to challenge.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={scrimForm.handleSubmit(handleHostSubmit)} className="space-y-4 py-2">
              <div className="space-y-1">
                <Label htmlFor="scrim-teams" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Matchup / Teams Details</Label>
                <Input
                  id="scrim-teams"
                  {...scrimForm.register('teams')}
                  placeholder="e.g. Viper Esports vs Open Challenge"
                  className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                />
                {scrimForm.formState.errors.teams && (
                  <p className="text-[10px] text-rose-600 font-semibold">{scrimForm.formState.errors.teams.message}</p>
                )}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <Label htmlFor="scrim-game" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Esports Game Title</Label>
                  <Input
                    id="scrim-game"
                    {...scrimForm.register('game')}
                    placeholder="e.g. Valorant"
                    className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                  />
                  {scrimForm.formState.errors.game && (
                    <p className="text-[10px] text-rose-600 font-semibold">{scrimForm.formState.errors.game.message}</p>
                  )}
                </div>
                <div className="space-y-1">
                  <Label htmlFor="scrim-time" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Schedule Details</Label>
                  <Input
                    id="scrim-time"
                    {...scrimForm.register('time')}
                    placeholder="e.g. Today, 22:30"
                    className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                  />
                  {scrimForm.formState.errors.time && (
                    <p className="text-[10px] text-rose-600 font-semibold">{scrimForm.formState.errors.time.message}</p>
                  )}
                </div>
              </div>

              <div className="space-y-1">
                <Label htmlFor="scrim-status" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Initial Lobby Status</Label>
                <select
                  id="scrim-status"
                  {...scrimForm.register('status')}
                  className={`w-full bg-white border border-zinc-200 h-9 rounded-lg text-xs px-3 focus:outline-none focus:ring-1 focus:ring-[#FF6B00] ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                >
                  <option value="Open">Open</option>
                  <option value="Full">Full</option>
                  <option value="Finished">Finished</option>
                </select>
                {scrimForm.formState.errors.status && (
                  <p className="text-[10px] text-rose-600 font-semibold">{scrimForm.formState.errors.status.message}</p>
                )}
              </div>

              <DialogFooter className="pt-4">
                <Button type="submit" className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white font-semibold text-xs rounded-lg h-9 w-full">
                  Host Scrim Session
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <Tabs defaultValue="all" className="w-full">
        <TabsList className={`bg-zinc-100 p-1 rounded-xl flex gap-1 w-fit border border-zinc-200/50 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800' : ''}`}>
          <TabsTrigger value="all" className="rounded-lg text-xs font-semibold px-3 py-1.5 data-[state=active]:bg-white data-[state=active]:text-zinc-900 dark:data-[state=active]:bg-[#0F1115] dark:data-[state=active]:text-white">All Scrims</TabsTrigger>
          <TabsTrigger value="open" className="rounded-lg text-xs font-semibold px-3 py-1.5 data-[state=active]:bg-white data-[state=active]:text-zinc-900 dark:data-[state=active]:bg-[#0F1115] dark:data-[state=active]:text-white">Open</TabsTrigger>
          <TabsTrigger value="finished" className="rounded-lg text-xs font-semibold px-3 py-1.5 data-[state=active]:bg-white data-[state=active]:text-zinc-900 dark:data-[state=active]:bg-[#0F1115] dark:data-[state=active]:text-white">Finished</TabsTrigger>
        </TabsList>

        {loading ? (
          <div className="text-center py-20">
            <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#FF6B00]" />
            <p className="text-xs text-zinc-400 mt-3 font-semibold">Loading scrim sessions...</p>
          </div>
        ) : (
          <>
            <TabsContent value="all" className="mt-4">
              {renderScrimsTable(filterScrims())}
            </TabsContent>
            <TabsContent value="open" className="mt-4">
              {renderScrimsTable(filterScrims('Open'))}
            </TabsContent>
            <TabsContent value="finished" className="mt-4">
              {renderScrimsTable(filterScrims('Finished'))}
            </TabsContent>
          </>
        )}
      </Tabs>
    </div>
  );

  function renderScrimsTable(items: Scrim[]) {
    if (items.length === 0) {
      return (
        <Card className={`p-12 text-center text-zinc-400 text-xs font-semibold ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800' : ''}`}>
          No scrim rooms found.
        </Card>
      );
    }

    return (
      <Card className={`bg-white border-zinc-200 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
        <CardHeader>
          <CardTitle className="text-sm font-semibold">Active Scrim Rooms</CardTitle>
          <CardDescription className={theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}>Join lobbies or review match logs.</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader className={theme === 'dark' ? 'border-zinc-800' : 'border-zinc-200'}>
              <TableRow className={`hover:bg-transparent ${theme === 'dark' ? 'border-zinc-800' : 'border-zinc-200'}`}>
                <TableHead className={`text-[10px] uppercase font-bold ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Teams</TableHead>
                <TableHead className={`text-[10px] uppercase font-bold ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Game</TableHead>
                <TableHead className={`text-[10px] uppercase font-bold ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Time</TableHead>
                <TableHead className={`text-[10px] uppercase font-bold ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Status</TableHead>
                <TableHead className={`text-[10px] uppercase font-bold text-right ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Action</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {items.map((s) => (
                <TableRow key={s.id} className={`border-b ${theme === 'dark' ? 'border-zinc-800 hover:bg-zinc-800/10' : 'border-zinc-200 hover:bg-zinc-50/50'}`}>
                  <TableCell className={`font-semibold ${theme === 'dark' ? 'text-zinc-200' : 'text-zinc-800'}`}>{s.teams}</TableCell>
                  <TableCell>
                    <Badge variant="outline" className={`bg-zinc-50 border-zinc-200 text-zinc-600 font-medium text-[10px] ${theme === 'dark' ? 'bg-zinc-800 border-zinc-700 text-zinc-300' : ''}`}>
                      {s.game}
                    </Badge>
                  </TableCell>
                  <TableCell className={`text-xs ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-600'}`}>{s.time}</TableCell>
                  <TableCell>
                    <Badge className={
                      s.status === 'Open' ? 'bg-emerald-50 text-emerald-700 border-emerald-100 dark:bg-emerald-950/20 dark:text-emerald-400 dark:border-emerald-900/30' :
                      s.status === 'Full' ? 'bg-amber-50 text-amber-700 border-amber-100 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900/30' :
                      'bg-zinc-100 text-zinc-600 border-zinc-200 dark:bg-zinc-800 dark:text-zinc-400 dark:border-zinc-700'
                    }>
                      {s.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right">
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={s.status === 'Finished'}
                      className={`border-zinc-200 text-zinc-600 hover:text-zinc-900 bg-white h-7 px-2.5 rounded-md text-xs gap-1 ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-zinc-300 hover:text-white' : ''}`}
                    >
                      <Zap className="w-3.5 h-3.5" />
                      {s.status === 'Open' ? 'Join' : s.status === 'Full' ? 'Spectate' : 'Closed'}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    );
  }
}
