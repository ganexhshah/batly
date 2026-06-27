'use client';

import React, { useState } from 'react';
import { toast } from 'sonner';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { useAppStore } from '@/store/useAppStore';
import { useSupportTickets, useUpdateSupportTicket } from '@/lib/admin-queries';
import { RequireRole } from '@/components/require-role';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { canUpdateSupport } from '@/lib/role-permissions';

type Ticket = {
  id: number;
  subject: string;
  message: string;
  status: 'open' | 'pending' | 'resolved' | 'closed';
  priority: 'low' | 'normal' | 'high' | 'urgent';
  admin_reply?: string | null;
  created_at: string;
  user?: { name?: string; email?: string; ign?: string; game_uid?: string };
};

export default function SupportTicketsPage() {
  const { theme } = useAppStore();
  const { data: tickets = [], isLoading: loading, isError, error, refetch } = useSupportTickets();
  const updateMutation = useUpdateSupportTicket();
  const [replyById, setReplyById] = useState<Record<number, string>>({});

  const updateTicket = async (ticket: Ticket, status: Ticket['status']) => {
    try {
      await updateMutation.mutateAsync({
        id: ticket.id,
        body: {
          status,
          priority: ticket.priority,
          admin_reply: replyById[ticket.id] || ticket.admin_reply || '',
        },
      });
      toast.success('Ticket updated.');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Failed to update ticket');
    }
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <div>
        <h2 className={`text-xl font-bold tracking-tight ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>Support Tickets</h2>
        <p className={`text-xs ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Reply to mobile support requests and close resolved issues.</p>
      </div>

      {isError && (
        <QueryErrorBanner error={error} onRetry={() => refetch()} title="Failed to load support tickets" />
      )}

      <Card className={`bg-white border-zinc-200 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
        <CardHeader>
          <CardTitle className="text-sm font-semibold">Ticket Inbox</CardTitle>
          <CardDescription className={theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}>Open tickets are shown first.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {loading ? (
            <div className="space-y-3">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className={`h-24 rounded-xl animate-pulse ${theme === 'dark' ? 'bg-zinc-800' : 'bg-zinc-100'}`} />
              ))}
            </div>
          ) : tickets.length === 0 ? (
            <p className="text-xs text-zinc-500">No support tickets yet.</p>
          ) : (
            tickets.map((ticket) => (
              <div key={ticket.id} className={`rounded-xl border p-4 ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115]' : 'border-zinc-200 bg-zinc-50'}`}>
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-sm font-bold">{ticket.subject}</p>
                    <p className="text-[11px] text-zinc-500">
                      {ticket.user?.ign || ticket.user?.name || 'Player'} · {ticket.user?.email || 'no email'} · {new Date(ticket.created_at).toLocaleString()}
                    </p>
                  </div>
                  <Badge className={ticket.status === 'open' ? 'bg-amber-50 text-amber-700' : 'bg-emerald-50 text-emerald-700'}>
                    {ticket.status}
                  </Badge>
                </div>
                <p className="mt-3 text-xs text-zinc-600 dark:text-zinc-300">{ticket.message}</p>
                <textarea
                  className={`mt-3 min-h-24 w-full rounded-lg border p-3 text-xs outline-none ${theme === 'dark' ? 'border-zinc-800 bg-[#1A1D24] text-white' : 'border-zinc-200 bg-white text-zinc-900'}`}
                  placeholder="Write an admin reply..."
                  value={replyById[ticket.id] ?? ticket.admin_reply ?? ''}
                  onChange={(event) => setReplyById((current) => ({ ...current, [ticket.id]: event.target.value }))}
                />
                <div className="mt-3 flex justify-end gap-2">
                  <RequireRole allow={canUpdateSupport}>
                    <Button size="sm" variant="outline" className="h-8 text-xs" onClick={() => updateTicket(ticket, 'pending')}>Mark Pending</Button>
                    <Button size="sm" className="h-8 text-xs bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white" onClick={() => updateTicket(ticket, 'resolved')}>Resolve</Button>
                  </RequireRole>
                </div>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
