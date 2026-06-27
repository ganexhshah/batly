'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { AdminPageHeader } from '@/components/admin/AdminPageHeader';
import { ProofGallery } from '@/components/admin/ProofGallery';
import { DataTableSkeleton } from '@/components/admin/DataTableSkeleton';
import { useAdminMatches, useVerifyMatch, useRejectMatch } from '@/lib/admin-queries';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetFooter } from '@/components/ui/sheet';
import { Badge } from '@/components/ui/badge';
import { ShieldCheck, Eye, ClipboardCheck, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

const verifySchema = z.object({
  rank: z.number().min(1).max(100),
  kills: z.number().min(0).max(100),
  points: z.number().min(0).max(500),
  notes: z.string().optional(),
});

type VerifyValues = z.infer<typeof verifySchema>;

interface AdminMatch {
  id: string;
  tournament: string;
  teamA: string;
  teamB: string;
  game: string;
  status: string;
  score?: string;
  kills?: string | number;
  points?: number;
  rank?: string | number;
  proofImages?: string[];
  notes?: string;
}

export default function MatchesPage() {
  const { theme } = useAppStore();
  const { data: matches = [], isLoading, refetch } = useAdminMatches();
  const verifyMutation = useVerifyMatch();
  const rejectMutation = useRejectMatch();
  const [selectedMatch, setSelectedMatch] = useState<AdminMatch | null>(null);
  const [verifyingMatch, setVerifyingMatch] = useState<AdminMatch | null>(null);

  const verifyForm = useForm<VerifyValues>({
    resolver: zodResolver(verifySchema),
    defaultValues: { rank: 1, kills: 0, points: 0, notes: '' },
  });

  const openVerify = (m: AdminMatch) => {
    const rankNum = m.rank ? parseInt(String(m.rank).replace(/\D/g, ''), 10) : 1;
    verifyForm.reset({
      rank: rankNum || 1,
      kills: Number(m.kills) || 0,
      points: m.points ?? 0,
      notes: m.notes ?? '',
    });
    setVerifyingMatch(m);
  };

  const handleVerifySubmit = async (values: VerifyValues) => {
    if (!verifyingMatch) return;
    try {
      const rawId = verifyingMatch.id.replace('M-', '');
      await verifyMutation.mutateAsync({
        id: rawId,
        payload: {
          rank: values.rank,
          kills: values.kills,
          points: values.points,
          notes: values.notes,
        },
      });
      setVerifyingMatch(null);
      toast.success('Match results verified!');
    } catch (err: unknown) {
      toast.error('Failed to verify', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const handleReject = async () => {
    if (!verifyingMatch) return;
    try {
      const rawId = verifyingMatch.id.replace('M-', '');
      await rejectMutation.mutateAsync({ id: rawId, reason: 'Rejected from admin review panel.' });
      setVerifyingMatch(null);
      toast.error('Match results rejected');
    } catch (err: unknown) {
      toast.error('Failed to reject', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const statusBadge = (status: string) => {
    if (status === 'Verified') return 'bg-emerald-50 text-emerald-700 border-emerald-100';
    if (status === 'Pending Verification') return 'bg-amber-50 text-amber-700 border-amber-100 animate-pulse';
    if (status === 'Rejected') return 'bg-rose-50 text-rose-700 border-rose-100';
    return 'bg-zinc-100 text-zinc-600 border-zinc-200';
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <AdminPageHeader
        title="Matches & Results"
        description="Verify individual player scorecards and proof uploads"
        action={<Button variant="outline" size="sm" className="text-xs" onClick={() => refetch()}>Refresh</Button>}
      />

      <Card className={cn('bg-white border-zinc-200', theme === 'dark' && 'bg-[#1A1D24] border-zinc-800 text-white')}>
        <CardHeader>
          <CardTitle className="text-sm font-semibold">All Match Records</CardTitle>
          <CardDescription className={theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}>
            Pending verification matches need admin action before prizes finalize.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow className={theme === 'dark' ? 'border-zinc-800' : 'border-zinc-200'}>
                <TableHead className="text-[10px] uppercase font-bold text-zinc-500">Match ID</TableHead>
                <TableHead className="text-[10px] uppercase font-bold text-zinc-500">Tournament</TableHead>
                <TableHead className="text-[10px] uppercase font-bold text-zinc-500">Player</TableHead>
                <TableHead className="text-[10px] uppercase font-bold text-zinc-500">Rank</TableHead>
                <TableHead className="text-[10px] uppercase font-bold text-zinc-500">Status</TableHead>
                <TableHead className="text-[10px] uppercase font-bold text-right text-zinc-500">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <DataTableSkeleton rows={5} cols={6} />
              ) : (matches as AdminMatch[]).length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-8 text-zinc-400 text-xs font-semibold">
                    No matches found.
                  </TableCell>
                </TableRow>
              ) : (
                (matches as AdminMatch[]).map((m) => (
                  <TableRow key={m.id} className={theme === 'dark' ? 'border-zinc-800' : 'border-zinc-200'}>
                    <TableCell className="font-semibold text-xs text-zinc-500">{m.id}</TableCell>
                    <TableCell className="text-xs">{m.tournament}</TableCell>
                    <TableCell className="text-xs font-semibold">{m.teamA}</TableCell>
                    <TableCell className="text-xs font-bold text-[#FF6B00]">{m.score ?? m.rank ?? '—'}</TableCell>
                    <TableCell>
                      <Badge className={statusBadge(m.status)}>{m.status}</Badge>
                    </TableCell>
                    <TableCell className="text-right flex justify-end gap-2">
                      <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => setSelectedMatch(m)}>
                        <Eye className="w-3 h-3 mr-1" /> Details
                      </Button>
                      {m.status === 'Pending Verification' && (
                        <Button size="sm" className="h-7 text-xs bg-zinc-900 hover:bg-zinc-800 dark:bg-[#FF6B00]" onClick={() => openVerify(m)}>
                          <ClipboardCheck className="w-3 h-3 mr-1" /> Verify
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Dialog open={!!selectedMatch} onOpenChange={(o) => !o && setSelectedMatch(null)}>
        <DialogContent className={cn('sm:max-w-md', theme === 'dark' && 'bg-[#1A1D24] border-zinc-800 text-white')}>
          <DialogHeader>
            <DialogTitle className="text-sm font-bold">Match {selectedMatch?.id}</DialogTitle>
            <DialogDescription className="text-xs">{selectedMatch?.tournament} · {selectedMatch?.game}</DialogDescription>
          </DialogHeader>
          {selectedMatch && (
            <div className="space-y-3 text-xs">
              <p><span className="text-zinc-500">Player:</span> {selectedMatch.teamA}</p>
              <p><span className="text-zinc-500">Rank:</span> {selectedMatch.score ?? selectedMatch.rank ?? '—'}</p>
              <p><span className="text-zinc-500">Kills:</span> {selectedMatch.kills ?? '—'}</p>
              <p><span className="text-zinc-500">Points:</span> {selectedMatch.points ?? '—'}</p>
              <ProofGallery images={selectedMatch.proofImages ?? (selectedMatch as AdminMatch & { screenshotProof?: string }).screenshotProof ? [(selectedMatch as AdminMatch & { screenshotProof?: string }).screenshotProof!] : []} />
            </div>
          )}
        </DialogContent>
      </Dialog>

      <Sheet open={!!verifyingMatch} onOpenChange={(o) => !o && setVerifyingMatch(null)}>
        <SheetContent className={cn('sm:max-w-md overflow-y-auto', theme === 'dark' && 'bg-[#1A1D24] border-zinc-800 text-white')}>
          <SheetHeader>
            <SheetTitle className="text-sm font-bold flex items-center gap-2">
              <ShieldCheck className="w-4 h-4 text-emerald-500" />
              Verify Match Result
            </SheetTitle>
            <SheetDescription className="text-xs">{verifyingMatch?.teamA} · {verifyingMatch?.tournament}</SheetDescription>
          </SheetHeader>
          {verifyingMatch && (
            <div className="space-y-5 py-4">
              <ProofGallery images={verifyingMatch.proofImages ?? []} />
              <form onSubmit={verifyForm.handleSubmit(handleVerifySubmit)} className="space-y-4">
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <Label className="text-xs">Rank</Label>
                    <Input type="number" {...verifyForm.register('rank', { valueAsNumber: true })} className="h-9 text-xs" />
                  </div>
                  <div>
                    <Label className="text-xs">Kills</Label>
                    <Input type="number" {...verifyForm.register('kills', { valueAsNumber: true })} className="h-9 text-xs" />
                  </div>
                  <div>
                    <Label className="text-xs">Points</Label>
                    <Input type="number" {...verifyForm.register('points', { valueAsNumber: true })} className="h-9 text-xs" />
                  </div>
                </div>
                <div>
                  <Label className="text-xs">Notes</Label>
                  <Input {...verifyForm.register('notes')} placeholder="Verification notes..." className="h-9 text-xs" />
                </div>
                <SheetFooter className="flex flex-col gap-2 pt-2">
                  <Button type="submit" className="w-full text-xs" disabled={verifyMutation.isPending}>
                    {verifyMutation.isPending && <Loader2 className="w-4 h-4 animate-spin mr-2" />}
                    Approve Result
                  </Button>
                  <Button type="button" variant="outline" className="w-full text-rose-600 border-rose-200 text-xs" onClick={handleReject} disabled={rejectMutation.isPending}>
                    Reject Result
                  </Button>
                </SheetFooter>
              </form>
            </div>
          )}
        </SheetContent>
      </Sheet>
    </div>
  );
}
