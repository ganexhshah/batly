'use client';

import React, { useState } from 'react';
import { useAppStore } from '@/store/useAppStore';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Bell, Check, Trash, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import { RequireRole } from '@/components/require-role';
import { QueryErrorBanner } from '@/components/query-error-banner';
import { canManageNotifications } from '@/lib/role-permissions';
import { useNotifications, useNotificationMutations, isInitialLoad, usePlayers } from '@/lib/admin-queries';

export default function NotificationsPage() {
  const { theme } = useAppStore();
  const { data: alerts, isPending, isError, error, refetch } = useNotifications();
  const { data: players = [] } = usePlayers();
  const { markAllRead, deleteNotification, sendBroadcast } = useNotificationMutations();

  // Form states
  const [broadcastTitle, setBroadcastTitle] = useState('');
  const [broadcastMessage, setBroadcastMessage] = useState('');
  const [targetType, setTargetType] = useState('all');
  const [targetUserId, setTargetUserId] = useState('');
  const [notificationType, setNotificationType] = useState('text');
  const [deepLink, setDeepLink] = useState('');
  const [imageFile, setImageFile] = useState<File | null>(null);
 
  const loading = isInitialLoad(isPending, alerts);
  const items = alerts ?? [];
 
  const handleMarkAllRead = async () => {
    try {
      await markAllRead.mutateAsync();
      toast.success('All notifications marked as read.');
    } catch (err: unknown) {
      toast.error('Failed to mark notifications as read', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };
 
  const handleDeleteAlert = async (id: number) => {
    try {
      await deleteNotification.mutateAsync(id);
      toast.success('Notification removed.');
    } catch (err: unknown) {
      toast.error('Failed to delete notification', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };
 
  const handleSendBroadcast = async () => {
    if (!broadcastTitle.trim() || !broadcastMessage.trim()) {
      toast.error('Title and message are required.');
      return;
    }
    if (targetType === 'specific' && !targetUserId) {
      toast.error('Please select a target user.');
      return;
    }
    try {
      const formData = new FormData();
      formData.append('title', broadcastTitle);
      formData.append('message', broadcastMessage);
      formData.append('type', notificationType);
      if (targetType === 'specific') {
        formData.append('user_id', String(targetUserId));
      }
      if (deepLink.trim()) {
        formData.append('deep_link', deepLink.trim());
      }
      if (imageFile) {
        formData.append('image', imageFile);
      }

      await sendBroadcast.mutateAsync(formData);

      setBroadcastTitle('');
      setBroadcastMessage('');
      setTargetUserId('');
      setDeepLink('');
      setImageFile(null);

      const fileInput = document.getElementById('notification-image-file') as HTMLInputElement;
      if (fileInput) fileInput.value = '';

      toast.success('Notification sent successfully.');
    } catch (err: unknown) {
      toast.error('Failed to send notification', { description: err instanceof Error ? err.message : 'Unknown error' });
    }
  };

  const formatRelativeTime = (time: string) => {
    let timeStr = 'Just Now';
    try {
      const diffMs = Date.now() - new Date(time).getTime();
      const diffMin = Math.floor(diffMs / 60000);
      if (diffMin > 119) {
        const diffHr = Math.floor(diffMin / 60);
        if (diffHr > 23) {
          const days = Math.floor(diffHr / 24);
          timeStr = days === 1 ? '1 day ago' : `${days} days ago`;
        } else {
          timeStr = `${diffHr} hr ago`;
        }
      } else if (diffMin > 0) {
        timeStr = `${diffMin} min ago`;
      }
    } catch (_) {}
    return timeStr;
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className={`text-xl font-bold tracking-tight ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>Notifications</h2>
          <p className={`text-xs ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Stay updated with match reports, registration signups, and wallet actions</p>
        </div>
        {!loading && items.some(a => a.unread) && (
          <RequireRole allow={canManageNotifications}>
            <Button 
              onClick={handleMarkAllRead}
              variant="outline"
              disabled={markAllRead.isPending}
              className={`border-zinc-200 text-zinc-600 hover:text-zinc-900 bg-white h-9 px-4 rounded-lg text-xs gap-1.5 ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-zinc-300 hover:text-white' : ''}`}
            >
              <Check className="w-4 h-4" />
              Mark all as read
            </Button>
          </RequireRole>
        )}
      </div>

      {isError && (
        <QueryErrorBanner error={error} onRetry={() => refetch()} title="Failed to load notifications" />
      )}

      <Card className={`bg-white border-zinc-200 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
        <CardHeader>
          <CardTitle className="text-sm font-semibold">Create & Send Notification</CardTitle>
          <CardDescription className={theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}>Send targeted text feed messages or popup banner alerts to players.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block">Target Audience</label>
              <select
                value={targetType}
                onChange={(e) => setTargetType(e.target.value)}
                className={`h-9 w-full rounded-lg border px-2.5 text-xs outline-none cursor-pointer ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115] text-white' : 'border-zinc-200 bg-white text-zinc-900'}`}
              >
                <option value="all">All Users (Broadcast)</option>
                <option value="specific">Specific User (Targeted)</option>
              </select>
            </div>

            <div className="space-y-1">
              <label className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block">Alert Type</label>
              <select
                value={notificationType}
                onChange={(e) => setNotificationType(e.target.value)}
                className={`h-9 w-full rounded-lg border px-2.5 text-xs outline-none cursor-pointer ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115] text-white' : 'border-zinc-200 bg-white text-zinc-900'}`}
              >
                <option value="text">Feed Alert (Inbox Text)</option>
                <option value="banner">Popup Banner (In-App Modal)</option>
              </select>
            </div>
          </div>

          {targetType === 'specific' && (
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block">Select Target User</label>
              <select
                value={targetUserId}
                onChange={(e) => setTargetUserId(e.target.value)}
                className={`h-9 w-full rounded-lg border px-2.5 text-xs outline-none cursor-pointer ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115] text-white' : 'border-zinc-200 bg-white text-zinc-900'}`}
              >
                <option value="">Choose user profile...</option>
                {players.map((u: any) => (
                  <option key={u.id} value={u.id}>
                    #{u.id} · {u.name} ({u.ign || 'No IGN'}) - {u.email}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block">Notification Title</label>
            <input
              className={`h-9 w-full rounded-lg border px-3 text-xs outline-none ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115] text-white' : 'border-zinc-200 bg-white text-zinc-900'}`}
              placeholder="e.g. Server Maintenance Notice"
              value={broadcastTitle}
              onChange={(event) => setBroadcastTitle(event.target.value)}
            />
          </div>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block">Message Body</label>
            <textarea
              className={`min-h-20 w-full rounded-lg border p-3 text-xs outline-none ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115] text-white' : 'border-zinc-200 bg-white text-zinc-900'}`}
              placeholder="Details regarding this notice..."
              value={broadcastMessage}
              onChange={(event) => setBroadcastMessage(event.target.value)}
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block">Banner Image URL / Deep Link (Optional)</label>
              <input
                className={`h-9 w-full rounded-lg border px-3 text-xs outline-none ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115] text-white' : 'border-zinc-200 bg-white text-zinc-900'}`}
                placeholder="e.g. https://domain.com/banner.png or screens/wallet"
                value={deepLink}
                onChange={(event) => setDeepLink(event.target.value)}
              />
            </div>

            <div className="space-y-1">
              <label className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block">Or Upload Image Directly</label>
              <input
                id="notification-image-file"
                type="file"
                accept="image/*"
                onChange={(e) => setImageFile(e.target.files?.[0] ?? null)}
                className={`flex h-9 w-full rounded-lg border px-3 py-1.5 text-xs file:border-0 file:bg-transparent file:text-xs file:font-semibold outline-none cursor-pointer ${theme === 'dark' ? 'border-zinc-800 bg-[#0F1115] text-white file:text-[#FF6B00]' : 'border-zinc-200 bg-white text-zinc-950 file:text-[#FF6B00]'}`}
              />
            </div>
          </div>

          <RequireRole allow={canManageNotifications}>
            <Button onClick={handleSendBroadcast} disabled={sendBroadcast.isPending} className="bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white h-9 text-xs w-full sm:w-fit font-bold rounded-lg px-6">
              {sendBroadcast.isPending && <Loader2 className="w-3.5 h-3.5 animate-spin mr-1.5" />}
              Send Notification
            </Button>
          </RequireRole>
        </CardContent>
      </Card>

      <Card className={`bg-white border-zinc-200 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
        <CardHeader>
          <CardTitle className="text-sm font-semibold">Activity Alert Feed</CardTitle>
          <CardDescription className={theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}>Review and dismiss notifications.</CardDescription>
        </CardHeader>
        <CardContent className="divide-y divide-zinc-100 dark:divide-zinc-800">
          {loading ? (
            <div className="text-center py-12">
              <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#FF6B00]" />
              <p className="text-xs text-zinc-400 mt-3 font-semibold">Loading notifications...</p>
            </div>
          ) : items.length === 0 ? (
            <div className="text-center py-12 text-zinc-400 text-xs flex flex-col items-center gap-2">
              <Bell className="w-8 h-8 text-zinc-300" />
              <span>You have no notifications.</span>
            </div>
          ) : (
            items.map((a) => (
              <div key={a.id} className="py-4 flex justify-between items-start gap-4 first:pt-0 last:pb-0 border-b border-zinc-100 dark:border-zinc-800 last:border-0">
                <div className="flex items-start gap-3">
                  <div className={`mt-1.5 w-2 h-2 rounded-full shrink-0 ${a.unread ? 'bg-[#FF6B00]' : 'bg-transparent'}`} />
                  <div>
                    <h4 className={`text-xs font-bold ${theme === 'dark' ? 'text-zinc-200' : 'text-zinc-800'}`}>{a.title}</h4>
                    <p className={`text-xs ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'} mt-0.5`}>{a.message}</p>
                    <span className="text-[10px] text-zinc-400 mt-1 block">{formatRelativeTime(a.created_at)}</span>
                  </div>
                </div>
                <RequireRole allow={canManageNotifications}>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => handleDeleteAlert(a.id)}
                    className="rounded-lg h-7 w-7 text-zinc-400 hover:text-rose-600 hover:bg-rose-50/50"
                  >
                    <Trash className="w-3.5 h-3.5" />
                  </Button>
                </RequireRole>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
