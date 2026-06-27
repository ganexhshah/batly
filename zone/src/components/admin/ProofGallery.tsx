'use client';

import React from 'react';
import { BACKEND_BASE_URL } from '@/lib/api';
import { ImageIcon } from 'lucide-react';

interface ProofGalleryProps {
  images?: string[];
  className?: string;
}

function resolveUrl(url: string): string {
  if (url.startsWith('http')) return url;
  return `${BACKEND_BASE_URL}${url.startsWith('/') ? '' : '/'}${url}`;
}

export function ProofGallery({ images = [], className = '' }: ProofGalleryProps) {
  if (images.length === 0) {
    return (
      <div className={`flex items-center justify-center h-32 rounded-xl border border-dashed border-zinc-300 dark:border-zinc-700 bg-zinc-50/50 dark:bg-zinc-900/50 ${className}`}>
        <div className="text-center text-zinc-400">
          <ImageIcon className="w-6 h-6 mx-auto mb-1 opacity-50" />
          <p className="text-[10px] font-medium">No proof uploaded</p>
        </div>
      </div>
    );
  }

  return (
    <div className={`grid grid-cols-2 gap-2 ${className}`}>
      {images.map((img, i) => (
        <a
          key={i}
          href={resolveUrl(img)}
          target="_blank"
          rel="noopener noreferrer"
          className="block aspect-video rounded-lg overflow-hidden border border-zinc-200 dark:border-zinc-700 hover:ring-2 hover:ring-[#FF6B00]/40 transition-all"
        >
          <img src={resolveUrl(img)} alt={`Proof ${i + 1}`} className="w-full h-full object-cover" />
        </a>
      ))}
    </div>
  );
}
