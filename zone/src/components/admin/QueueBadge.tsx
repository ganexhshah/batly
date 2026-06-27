'use client';

import React from 'react';

interface QueueBadgeProps {
  count: number;
}

export function QueueBadge({ count }: QueueBadgeProps) {
  if (count <= 0) return null;

  return (
    <span className="bg-[#FFF6F0] text-[#FF6B00] text-[10px] font-bold px-2 py-0.5 rounded-full border border-orange-100 dark:bg-[#FF6B00]/10 dark:border-[#FF6B00]/30 min-w-[20px] text-center">
      {count > 99 ? '99+' : count}
    </span>
  );
}
