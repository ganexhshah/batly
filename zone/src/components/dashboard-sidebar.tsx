'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQueryClient } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { cn } from '@/lib/utils';
import {
  LayoutDashboard, Trophy, Swords, Gamepad,
  Users, Wallet, CheckSquare, Bell, HelpCircle, Settings, X,
  Users2, Gamepad2, Image, Gavel,
} from 'lucide-react';
import { useAdminOverview, prefetchAdminRoute } from '@/lib/admin-queries';
import { canViewNav, getStoredRole, normalizeRole } from '@/lib/role-permissions';
import { QueueBadge } from '@/components/admin/QueueBadge';

interface SidebarProps {
  onCloseMobile?: () => void;
}

type BadgeKey = 'pendingResultApprovals' | 'pendingMatchVerifications' | 'openDisputes' | 'openSupportTickets';

export default function DashboardSidebar({ onCloseMobile }: SidebarProps) {
  const pathname = usePathname();
  const queryClient = useQueryClient();
  const { theme } = useAppStore();
  const { data: overview } = useAdminOverview();
  const [userLabel, setUserLabel] = useState({ name: 'Admin', role: 'Staff' });

  const [staffRole, setStaffRole] = useState(() => getStoredRole());

  useEffect(() => {
    try {
      const raw = localStorage.getItem('battly_user');
      if (raw) {
        const u = JSON.parse(raw);
        setUserLabel({
          name: u.name ?? u.ign ?? 'Admin',
          role: u.role ?? 'Staff',
        });
        setStaffRole(normalizeRole(u.role));
      }
    } catch (_) {}
  }, []);

  const navigation: Array<{
    name: string;
    href: string;
    icon: React.ComponentType<{ className?: string }>;
    badgeKey?: BadgeKey;
  }> = [
    { name: 'Dashboard', href: '/', icon: LayoutDashboard },
    { name: 'Tournaments', href: '/tournaments', icon: Trophy },
    { name: 'Scrims', href: '/scrims', icon: Swords },
    { name: 'Matches', href: '/matches', icon: Gamepad, badgeKey: 'pendingMatchVerifications' },
    { name: 'Results Approval', href: '/results', icon: CheckSquare, badgeKey: 'pendingResultApprovals' },
    { name: 'Disputes', href: '/disputes', icon: Gavel, badgeKey: 'openDisputes' },
    { name: 'Teams', href: '/teams', icon: Users },
    { name: 'Staff', href: '/users', icon: Users2 },
    { name: 'Players', href: '/players', icon: Gamepad2 },
    { name: 'Wallet', href: '/wallet', icon: Wallet },
    { name: 'Notifications', href: '/notifications', icon: Bell },
    { name: 'Banners', href: '/banners', icon: Image },
    { name: 'Support Tickets', href: '/support', icon: HelpCircle, badgeKey: 'openSupportTickets' },
    { name: 'Settings', href: '/settings', icon: Settings },
  ];

  const visibleNav = navigation.filter((item) => canViewNav(item.href, staffRole));

  const isNavActive = (href: string) => {
    if (href === '/') return pathname === '/';
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const badgeCount = (key?: BadgeKey) => {
    if (!key || !overview) return 0;
    return (overview[key] as number) ?? 0;
  };

  const initials = userLabel.name.slice(0, 2).toUpperCase();

  return (
    <aside className={cn(
      'w-64 h-full flex flex-col bg-white border-r border-zinc-200 select-none',
      theme === 'dark' && 'bg-[#161920] border-zinc-800',
    )}>
      <div className={cn(
        'h-20 flex items-center justify-between px-6 border-b border-zinc-100',
        theme === 'dark' && 'border-zinc-800',
      )}>
        <Link href="/" className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-orange-50 flex items-center justify-center border border-orange-100 shrink-0">
            <Trophy className="w-5 h-5 text-[#FF6B00]" />
          </div>
          <div className="flex flex-col">
            <span className={cn('font-black text-lg tracking-wider text-zinc-900 leading-tight', theme === 'dark' && 'text-white')}>
              BATTLY
            </span>
            <span className="text-[9px] font-bold text-zinc-400 uppercase tracking-widest leading-none">
              ADMIN PANEL
            </span>
          </div>
        </Link>
        {onCloseMobile && (
          <button onClick={onCloseMobile} className="md:hidden text-zinc-400 hover:text-zinc-600 p-1">
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      <nav className="flex-1 px-4 py-6 space-y-1 overflow-y-auto">
        {visibleNav.map((item) => {
          const isActive = isNavActive(item.href);
          const Icon = item.icon;
          const count = badgeCount(item.badgeKey);
          return (
            <Link
              key={item.name}
              href={item.href}
              onClick={onCloseMobile}
              onMouseEnter={() => prefetchAdminRoute(queryClient, item.href)}
              onFocus={() => prefetchAdminRoute(queryClient, item.href)}
              className={cn(
                'flex items-center justify-between px-4 py-2.5 text-xs font-semibold rounded-xl transition-all relative group',
                isActive ? 'bg-[#FFF6F0] text-[#FF6B00]' : 'text-zinc-500 hover:text-zinc-900 hover:bg-zinc-50',
                theme === 'dark' && (isActive ? 'bg-[#FF6B00]/10 text-[#FF6B00]' : 'text-zinc-400 hover:text-white hover:bg-zinc-800/40'),
              )}
            >
              {isActive && <div className="absolute left-0 top-2 bottom-2 w-[4px] bg-[#FF6B00] rounded-r-md" />}
              <div className="flex items-center gap-3">
                <Icon className={cn(
                  'w-4 h-4 transition-colors shrink-0',
                  isActive ? 'text-[#FF6B00]' : 'text-zinc-400 group-hover:text-zinc-600',
                  theme === 'dark' && (isActive ? 'text-[#FF6B00]' : 'text-zinc-500 group-hover:text-zinc-300'),
                )} />
                <span>{item.name}</span>
              </div>
              <QueueBadge count={count} />
            </Link>
          );
        })}
      </nav>

      <div className={cn('p-4 border-t border-zinc-100', theme === 'dark' && 'border-zinc-800')}>
        <div className={cn(
          'flex items-center gap-3 p-2 rounded-xl bg-zinc-50/50 border border-zinc-100',
          theme === 'dark' && 'bg-[#1f222b]/40 border-zinc-800',
        )}>
          <div className="w-8 h-8 rounded-full bg-[#FF6B00] text-white flex items-center justify-center font-bold text-xs">
            {initials}
          </div>
          <div className="flex flex-col min-w-0">
            <span className={cn('text-xs font-bold text-zinc-900 leading-tight truncate', theme === 'dark' && 'text-white')}>
              {userLabel.name}
            </span>
            <span className="text-[10px] text-zinc-400 font-medium truncate">{userLabel.role}</span>
          </div>
        </div>
      </div>
    </aside>
  );
}
