'use client';
 
import React, { useState } from 'react';
import Link from 'next/link';
import { toast } from 'sonner';
import { useAppStore } from '@/store/useAppStore';
import { cn } from '@/lib/utils';
import { 
  Menu, Sun, Moon, Bell, Search, Calendar, ChevronDown
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { 
  DropdownMenu, 
  DropdownMenuContent, 
  DropdownMenuGroup,
  DropdownMenuItem, 
  DropdownMenuLabel, 
  DropdownMenuSeparator, 
  DropdownMenuTrigger 
} from '@/components/ui/dropdown-menu';
import { useNotifications } from '@/lib/admin-queries';
 
interface HeaderProps {
  onOpenMobileSidebar: () => void;
}
 
export default function DashboardHeader({ onOpenMobileSidebar }: HeaderProps) {
  const { theme, toggleTheme, user, logout } = useAppStore();
  const { data: notifications = [] } = useNotifications();
  const [searchQuery, setSearchQuery] = useState('');

  const unreadCount = notifications.filter(n => n.unread).length;

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(e.target.value);
  };

  const handleSearchKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && searchQuery.trim()) {
      toast.info('Search coming soon', {
        description: 'Global search across tournaments, players, and tickets is in development.',
      });
    }
  };
  
  const fallbackInitials = user?.name
    ? user.name.split(' ').map((n: string) => n[0]).join('').slice(0, 2).toUpperCase()
    : 'AD';
 
  return (
    <header className={cn(
      "h-20 border-b border-zinc-200 bg-white px-6 flex items-center justify-between sticky top-0 z-40 select-none",
      theme === 'dark' && "bg-[#161920] border-zinc-800"
    )}>
      <div className="flex items-center gap-4 flex-1">
        <button 
          onClick={onOpenMobileSidebar}
          className={cn(
            "p-1.5 rounded-lg text-zinc-500 hover:bg-zinc-100 md:hidden",
            theme === 'dark' && "text-zinc-400 hover:bg-zinc-800"
          )}
        >
          <Menu className="w-5 h-5" />
        </button>
 
        <div className="relative max-w-sm w-full hidden md:block">
          <Search className="w-4 h-4 text-zinc-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <Input 
            type="search" 
            placeholder="Search anything..."
            value={searchQuery}
            onChange={handleSearchChange}
            onKeyDown={handleSearchKeyDown}
            className={cn(
              "bg-zinc-50 border-zinc-200 pl-10 pr-16 text-xs h-10 rounded-xl w-full border-none shadow-sm focus-visible:ring-zinc-300 focus-visible:ring-1",
              theme === 'dark' && "bg-[#1f222b] border-zinc-800 text-white placeholder-zinc-500"
            )}
          />
          <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-0.5 px-1.5 py-0.5 border border-zinc-200 rounded-lg bg-zinc-50 text-[10px] font-bold text-zinc-400">
            <span>⌘</span>
            <span>K</span>
          </div>
        </div>
      </div>
 
      <div className="flex items-center gap-4">
        <div className={cn(
          "hidden sm:flex items-center gap-2 px-4 py-2 border border-zinc-200 rounded-xl text-xs font-semibold text-zinc-700 bg-zinc-50/50 shadow-sm",
          theme === 'dark' && "bg-[#1f222b] border-zinc-800 text-zinc-300"
        )}>
          <span>{new Date().toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })}</span>
          <Calendar className="w-4 h-4 text-zinc-400" />
        </div>
 
        <Button
          variant="ghost"
          size="icon"
          onClick={toggleTheme}
          className={cn(
            "rounded-xl h-10 w-10 text-zinc-500 hover:bg-zinc-50 border border-transparent hover:border-zinc-200",
            theme === 'dark' && "text-zinc-400 hover:bg-zinc-800 hover:text-white"
          )}
        >
          {theme === 'dark' ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
        </Button>
 
        <DropdownMenu>
          <DropdownMenuTrigger
            render={
              <Button
                variant="ghost"
                size="icon"
                className={cn(
                  "rounded-xl h-10 w-10 text-zinc-500 hover:bg-zinc-50 border border-transparent hover:border-zinc-200 relative",
                  theme === 'dark' && "text-zinc-400 hover:bg-zinc-800 hover:text-white"
                )}
              />
            }
          >
            <Bell className="w-4 h-4" />
            {unreadCount > 0 && (
              <span className="absolute -top-0.5 -right-0.5 w-5 h-5 bg-[#FF6B00] text-white text-[9px] font-bold flex items-center justify-center rounded-full border-2 border-white dark:border-[#161920]">
                {unreadCount}
              </span>
            )}
          </DropdownMenuTrigger>
          <DropdownMenuContent className="w-64 bg-white border border-zinc-200 rounded-lg shadow-lg p-1" align="end">
            <DropdownMenuGroup>
              <DropdownMenuLabel className="text-xs font-bold px-3 py-2">Notifications</DropdownMenuLabel>
              <DropdownMenuSeparator className="border-zinc-100" />
              <div className="max-h-60 overflow-y-auto">
                {notifications.length === 0 ? (
                  <div className="text-[10px] text-zinc-400 text-center py-4 font-medium">No notifications</div>
                ) : (
                  notifications.slice(0, 5).map((n) => (
                    <DropdownMenuItem key={n.id} className="text-[11px] p-2 hover:bg-zinc-50 rounded cursor-pointer flex flex-col items-start">
                      <p className="font-semibold text-zinc-800">{n.title}</p>
                      <p className="text-zinc-400 mt-0.5">{n.message}</p>
                    </DropdownMenuItem>
                  ))
                )}
              </div>
            </DropdownMenuGroup>
            <DropdownMenuSeparator className="border-zinc-100" />
            <Link href="/notifications" className="block text-center text-[10px] font-semibold text-zinc-600 hover:text-[#FF6B00] py-2">
              View all notifications
            </Link>
          </DropdownMenuContent>
        </DropdownMenu>
 
        <DropdownMenu>
          <DropdownMenuTrigger
            render={
              <button className="flex items-center gap-3 outline-none hover:opacity-90 transition-opacity" />
            }
          >
            <div className="hidden sm:flex flex-col text-right">
              <span className={cn(
                "text-xs font-bold text-zinc-900 leading-tight",
                theme === 'dark' && "text-white"
              )}>
                {user?.name || 'Admin'}
              </span>
              <span className="text-[10px] text-zinc-400 font-medium">
                {user?.role || 'Super Admin'}
              </span>
            </div>
            <Avatar className="w-9 h-9 border border-zinc-200">
              <AvatarFallback className="bg-[#FF6B00] text-white font-bold text-xs">
                {fallbackInitials}
              </AvatarFallback>
            </Avatar>
          </DropdownMenuTrigger>
          <DropdownMenuContent className="w-48 bg-white border border-zinc-200 rounded-lg shadow-lg p-1" align="end">
            <DropdownMenuGroup>
              <DropdownMenuLabel className="px-3 py-2">
                <p className="text-xs font-bold text-zinc-800">{user?.name || 'Administrator'}</p>
                <p className="text-[10px] text-zinc-400">{user?.email || 'admin@battly.zone'}</p>
              </DropdownMenuLabel>
              <DropdownMenuSeparator className="border-zinc-100" />
              <DropdownMenuItem
                render={
                  <Link href="/settings" className="text-xs px-3 py-2 flex items-center gap-2 hover:bg-zinc-50 rounded cursor-pointer text-zinc-700" />
                }
              >
                Profile Settings
              </DropdownMenuItem>
              <DropdownMenuItem
                render={
                  <Link href="/wallet" className="text-xs px-3 py-2 flex items-center gap-2 hover:bg-zinc-50 rounded cursor-pointer text-zinc-700" />
                }
              >
                Wallet Balance
              </DropdownMenuItem>
              <DropdownMenuSeparator className="border-zinc-100" />
              <DropdownMenuItem
                onClick={logout}
                className="text-xs px-3 py-2 flex items-center gap-2 hover:bg-rose-50 text-rose-600 rounded cursor-pointer font-semibold"
              >
                Log Out
              </DropdownMenuItem>
            </DropdownMenuGroup>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}
