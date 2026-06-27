'use client';

import React from 'react';

interface DataTableSkeletonProps {
  rows?: number;
  cols?: number;
}

export function DataTableSkeleton({ rows = 5, cols = 6 }: DataTableSkeletonProps) {
  return (
    <>
      {Array.from({ length: rows }).map((_, ri) => (
        <tr key={ri} className="border-b border-zinc-100 dark:border-zinc-800">
          {Array.from({ length: cols }).map((_, ci) => (
            <td key={ci} className="py-3 px-2">
              <div className="h-3 bg-zinc-100 dark:bg-zinc-800 rounded animate-pulse" style={{ width: `${50 + (ci * 7) % 40}%` }} />
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}
