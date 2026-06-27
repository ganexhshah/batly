'use client';

import React from 'react';
import { AlertCircle, RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

interface QueryErrorBannerProps {
  error: unknown;
  onRetry?: () => void;
  title?: string;
  className?: string;
}

export function QueryErrorBanner({
  error,
  onRetry,
  title = 'Failed to load data',
  className,
}: QueryErrorBannerProps) {
  if (!error) return null;

  const message = error instanceof Error ? error.message : 'An unexpected error occurred.';

  return (
    <div
      className={cn(
        'rounded-xl border border-rose-200 bg-rose-50 p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3',
        className,
      )}
      role="alert"
    >
      <div className="flex items-start gap-3">
        <AlertCircle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
        <div>
          <p className="text-sm font-semibold text-rose-900">{title}</p>
          <p className="text-xs text-rose-700 mt-0.5">{message}</p>
        </div>
      </div>
      {onRetry && (
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={onRetry}
          className="text-xs h-8 rounded-lg border-rose-200 text-rose-800 hover:bg-rose-100 shrink-0"
        >
          <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
          Retry
        </Button>
      )}
    </div>
  );
}
