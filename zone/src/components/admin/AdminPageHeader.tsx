'use client';

import React from 'react';
import { useAppStore } from '@/store/useAppStore';
import { cn } from '@/lib/utils';

interface AdminPageHeaderProps {
  title: string;
  description?: string;
  action?: React.ReactNode;
}

export function AdminPageHeader({ title, description, action }: AdminPageHeaderProps) {
  const { theme } = useAppStore();

  return (
    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <div>
        <h2 className={cn('text-xl font-bold tracking-tight', theme === 'dark' ? 'text-white' : 'text-zinc-900')}>
          {title}
        </h2>
        {description && (
          <p className={cn('text-xs mt-0.5', theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500')}>
            {description}
          </p>
        )}
      </div>
      {action}
    </div>
  );
}
