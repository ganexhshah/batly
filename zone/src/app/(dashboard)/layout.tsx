'use client';

import React, { useState, useEffect } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { useQueryClient } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { cn } from '@/lib/utils';
import { prefetchAdminQueries } from '@/lib/admin-queries';
import { canAccessRoute, normalizeRole } from '@/lib/role-permissions';
import DashboardSidebar from '@/components/dashboard-sidebar';
import DashboardHeader from '@/components/dashboard-header';
import { Toaster } from '@/components/ui/sonner';

const ALLOWED_ROLES = ['admin', 'moderator', 'host'];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { theme, logout } = useAppStore();
  const queryClient = useQueryClient();
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false);
  const [authorized, setAuthorized] = useState(false);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    const checkAuth = () => {
      const token = localStorage.getItem('battly_token');
      const storedUser = localStorage.getItem('battly_user');
      if (!token || !storedUser) {
        logout();
        router.push('/auth');
        return;
      }
      try {
        const user = JSON.parse(storedUser);
        const role = String(user.role ?? '').toLowerCase();
        if (!ALLOWED_ROLES.includes(role)) {
          logout();
          router.push('/auth');
          return;
        }
        setAuthorized(true);
        prefetchAdminQueries(queryClient, normalizeRole(user.role));
      } catch {
        logout();
        router.push('/auth');
      }
    };

    checkAuth();
    window.addEventListener('storage', checkAuth);
    return () => window.removeEventListener('storage', checkAuth);
  }, [router, logout, queryClient]);

  useEffect(() => {
    if (!authorized) return;
    const storedUser = localStorage.getItem('battly_user');
    if (!storedUser) return;
    try {
      const user = JSON.parse(storedUser);
      const role = normalizeRole(user.role);
      if (!canAccessRoute(pathname, role)) {
        router.replace('/');
      }
    } catch {
      router.replace('/auth');
    }
  }, [authorized, pathname, router]);

  if (!authorized) {
    return (
      <div className={cn(
        "flex h-screen w-screen items-center justify-center bg-zinc-50 font-sans",
        theme === 'dark' && "bg-[#0F1115] text-white"
      )}>
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-4 border-zinc-900 dark:border-white border-t-transparent rounded-full animate-spin" />
          <p className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Verifying session...</p>
        </div>
      </div>
    );
  }

  return (
    <div className={cn(
      "flex h-screen overflow-hidden bg-zinc-50 font-sans",
      theme === 'dark' && "bg-[#0F1115] text-white"
    )}>
      {/* Desktop Sidebar */}
      <div className="hidden md:block">
        <DashboardSidebar />
      </div>

      {/* Mobile Sidebar Slide-over */}
      {mobileSidebarOpen && (
        <div className="fixed inset-0 z-50 flex md:hidden animate-fade-in">
          {/* Backdrop */}
          <div 
            onClick={() => setMobileSidebarOpen(false)}
            className="fixed inset-0 bg-black/40 transition-opacity" 
          />
          {/* Drawer content */}
          <div className="relative flex w-64 max-w-xs flex-col bg-white h-full">
            <DashboardSidebar onCloseMobile={() => setMobileSidebarOpen(false)} />
          </div>
        </div>
      )}

      {/* Main content area */}
      <div className="flex-1 flex flex-col overflow-hidden">
        <DashboardHeader onOpenMobileSidebar={() => setMobileSidebarOpen(true)} />
        <div className="flex-1 overflow-y-auto">
          {children}
        </div>
      </div>
      <Toaster />
    </div>
  );
}
