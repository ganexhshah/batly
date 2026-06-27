'use client';

import React, { useState } from 'react';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { AdminPageHeader } from '@/components/admin/AdminPageHeader';
import { ProofGallery } from '@/components/admin/ProofGallery';
import { DataTableSkeleton } from '@/components/admin/DataTableSkeleton';
import { useAdminDisputes, useResolveDispute, useResolveReport } from '@/lib/admin-queries';
import { RequireRole } from '@/components/require-role';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { canResolveDisputes } from '@/lib/role-permissions';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import {
  Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetFooter,
} from '@/components/ui/sheet';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Gavel, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

type ResolveTarget = { kind: 'dispute' | 'report'; id: number; title: string };

const STATUS_OPTIONS = [
  { value: 'resolved', label: 'Resolved' },
  { value: 'dismissed', label: 'Dismissed' },
  { value: 'under_review', label: 'Under Review' },
];

export default function DisputesPage() {
  const { theme } = useAppStore();
  const { data, isLoading, isError, error, refetch } = useAdminDisputes();
  const resolveDispute = useResolveDispute();
  const resolveReport = useResolveReport();
  const disputes = data?.disputes ?? [];
  const reports = data?.reports ?? [];

  const [target, setTarget] = useState<ResolveTarget | null>(null);
  const [detail, setDetail] = useState<Record<string, unknown> | null>(null);
  const [status, setStatus] = useState('resolved');
  const [adminNote, setAdminNote] = useState('');

  const openResolve = (kind: 'dispute' | 'report', item: Record<string, unknown>) => {
    setTarget({ kind, id: item.id as number, title: (item.tournament_title as string) ?? 'Tournament' });
    setDetail(item);
    setStatus('resolved');
    setAdminNote('');
  };

  const handleResolve = async () => {
    if (!target) return;
    try {
      if (target.kind === 'dispute') {
        await resolveDispute.mutateAsync({ id: target.id, status, admin_note: adminNote || undefined });
      } else {
        await resolveReport.mutateAsync({ id: target.id, status, admin_note: adminNote || undefined });
      }
      toast.success(`${target.kind === 'dispute' ? 'Dispute' : 'Report'} updated`);
      setTarget(null);
      setDetail(null);
    } catch (err: unknown) {
      toast.error('Failed to update', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const statusBadge = (s: string) => {
    const colors: Record<string, string> = {
      open: 'bg-amber-50 text-amber-700 border-amber-100',
      under_review: 'bg-blue-50 text-blue-700 border-blue-100',
      resolved: 'bg-emerald-50 text-emerald-700 border-emerald-100',
      dismissed: 'bg-zinc-100 text-zinc-600 border-zinc-200',
    };
    return <Badge className={colors[s] ?? colors.open}>{s.replace('_', ' ')}</Badge>;
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <AdminPageHeader
        title="Disputes & Reports"
        description="Review match disputes and anti-cheat player reports from the mobile app"
        action={
          <Button variant="outline" size="sm" onClick={() => refetch()} className="text-xs">Refresh</Button>
        }
      />

      {isError && (
        <QueryErrorBanner error={error} onRetry={() => refetch()} title="Failed to load disputes" />
      )}

      <Tabs defaultValue="disputes">
        <TabsList className={cn('bg-zinc-100 dark:bg-zinc-800')}>
          <TabsTrigger value="disputes" className="text-xs">
            Disputes ({disputes.length})
          </TabsTrigger>
          <TabsTrigger value="reports" className="text-xs">
            Player Reports ({reports.length})
          </TabsTrigger>
        </TabsList>

        <TabsContent value="disputes">
          <Card className={cn('bg-white border-zinc-200 mt-4', theme === 'dark' && 'bg-[#1A1D24] border-zinc-800')}>
            <CardContent className="pt-4">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Tournament</TableHead>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Filer</TableHead>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Type</TableHead>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Status</TableHead>
                    <TableHead className="text-[10px] uppercase text-right text-zinc-500">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isLoading ? (
                    <DataTableSkeleton rows={4} cols={5} />
                  ) : disputes.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={5} className="text-center py-8 text-zinc-400 text-xs">No disputes.</TableCell>
                    </TableRow>
                  ) : (
                    disputes.map((d: Record<string, unknown>) => (
                      <TableRow key={d.id as number}>
                        <TableCell className="text-xs font-semibold">{d.tournament_title as string}</TableCell>
                        <TableCell className="text-xs text-zinc-500">{(d.filer as string) ?? '—'}</TableCell>
                        <TableCell className="text-xs capitalize">{(d.type as string)?.replace('_', ' ')}</TableCell>
                        <TableCell>{statusBadge(d.status as string)}</TableCell>
                        <TableCell className="text-right">
                          <RequireRole allow={canResolveDisputes}>
                            <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => openResolve('dispute', d)}>
                              <Gavel className="w-3 h-3 mr-1" /> Review
                            </Button>
                          </RequireRole>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="reports">
          <Card className={cn('bg-white border-zinc-200 mt-4', theme === 'dark' && 'bg-[#1A1D24] border-zinc-800')}>
            <CardContent className="pt-4">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Tournament</TableHead>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Reporter</TableHead>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Reported</TableHead>
                    <TableHead className="text-[10px] uppercase text-zinc-500">Status</TableHead>
                    <TableHead className="text-[10px] uppercase text-right text-zinc-500">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isLoading ? (
                    <DataTableSkeleton rows={4} cols={5} />
                  ) : reports.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={5} className="text-center py-8 text-zinc-400 text-xs">No player reports.</TableCell>
                    </TableRow>
                  ) : (
                    reports.map((r: Record<string, unknown>) => (
                      <TableRow key={r.id as number}>
                        <TableCell className="text-xs font-semibold">{r.tournament_title as string}</TableCell>
                        <TableCell className="text-xs text-zinc-500">{r.reporter as string}</TableCell>
                        <TableCell className="text-xs text-rose-600 font-medium">{r.reported_user as string}</TableCell>
                        <TableCell>{statusBadge(r.status as string)}</TableCell>
                        <TableCell className="text-right">
                          <RequireRole allow={canResolveDisputes}>
                            <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => openResolve('report', r)}>
                              <Gavel className="w-3 h-3 mr-1" /> Review
                            </Button>
                          </RequireRole>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      <Sheet open={!!target} onOpenChange={(o) => !o && setTarget(null)}>
        <SheetContent className={cn('sm:max-w-md overflow-y-auto', theme === 'dark' && 'bg-[#1A1D24] border-zinc-800 text-white')}>
          <SheetHeader>
            <SheetTitle className="text-sm font-bold">Review {target?.kind === 'dispute' ? 'Dispute' : 'Report'}</SheetTitle>
            <SheetDescription className="text-xs">{target?.title}</SheetDescription>
          </SheetHeader>
          {detail && (
            <div className="space-y-4 py-4">
              <div className="text-xs space-y-2">
                <p><span className="text-zinc-500">Reason:</span> {detail.reason as string}</p>
                {typeof detail.type === 'string' && detail.type && (
                  <p><span className="text-zinc-500">Type:</span> {detail.type.replace('_', ' ')}</p>
                )}
                {typeof detail.reported_user === 'string' && detail.reported_user && (
                  <p><span className="text-zinc-500">Reported:</span> {detail.reported_user}</p>
                )}
              </div>
              <ProofGallery images={(detail.proof_images as string[]) ?? []} />
              <div className="space-y-2">
                <Label className="text-xs">Status</Label>
                <select
                  value={status}
                  onChange={(e) => setStatus(e.target.value)}
                  className="w-full h-9 rounded-lg border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 text-xs px-3"
                >
                  {STATUS_OPTIONS.map((o) => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </div>
              <div className="space-y-2">
                <Label className="text-xs">Admin note</Label>
                <Input value={adminNote} onChange={(e) => setAdminNote(e.target.value)} placeholder="Optional note to player..." className="text-xs h-9" />
              </div>
              <SheetFooter>
                <RequireRole allow={canResolveDisputes}>
                  <Button className="w-full text-xs" onClick={handleResolve} disabled={resolveDispute.isPending || resolveReport.isPending}>
                    {(resolveDispute.isPending || resolveReport.isPending) && <Loader2 className="w-4 h-4 animate-spin mr-2" />}
                    Save Decision
                  </Button>
                </RequireRole>
              </SheetFooter>
            </div>
          )}
        </SheetContent>
      </Sheet>
    </div>
  );
}
