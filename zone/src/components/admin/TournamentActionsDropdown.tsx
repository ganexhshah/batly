'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import { 
  DropdownMenu, 
  DropdownMenuContent, 
  DropdownMenuItem, 
  DropdownMenuLabel, 
  DropdownMenuSeparator, 
  DropdownMenuTrigger 
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';
import { Eye, Edit, FileText, ShieldAlert, Trash, MoreVertical } from 'lucide-react';

interface BaseTournament {
  id: number;
  name: string;
  game: string;
  status: string;
}

interface TournamentActionsDropdownProps<T> {
  tournament: T;
  onEditSettings: (t: T) => void;
  onCancelTournament: (t: T) => void;
  onDeleteTournament?: (t: T) => void;
  canDelete?: boolean;
  align?: 'start' | 'end';
}

export function TournamentActionsDropdown<T extends BaseTournament>({
  tournament,
  onEditSettings,
  onCancelTournament,
  onDeleteTournament,
  canDelete = false,
  align = 'end',
}: TournamentActionsDropdownProps<T>) {
  const router = useRouter();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        render={
          <Button 
            variant="outline" 
            size="icon" 
            className="w-8 h-8 rounded-lg border-zinc-200 text-zinc-500 hover:bg-zinc-50 bg-white"
            title="Actions"
          />
        }
      >
        <MoreVertical className="w-3.5 h-3.5" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align={align} className="w-44 bg-white border border-zinc-200 rounded-xl shadow-lg p-1">
        <DropdownMenuLabel className="text-[10px] font-bold text-zinc-400 px-2 py-1.5 uppercase tracking-wider">
          Actions
        </DropdownMenuLabel>
        <DropdownMenuSeparator className="border-zinc-100" />
        
        <DropdownMenuItem 
          onClick={() => router.push(`/tournaments/${tournament.id}`)}
          className="text-xs font-semibold p-2 hover:bg-zinc-50 rounded-lg cursor-pointer flex items-center gap-2 text-zinc-700"
        >
          <Eye className="w-3.5 h-3.5 text-zinc-400" />
          View Hub
        </DropdownMenuItem>

        <DropdownMenuItem 
          onClick={() => onEditSettings(tournament)}
          className="text-xs font-semibold p-2 hover:bg-zinc-50 rounded-lg cursor-pointer flex items-center gap-2 text-zinc-700"
        >
          <Edit className="w-3.5 h-3.5 text-zinc-400" />
          Edit Settings
        </DropdownMenuItem>

        <DropdownMenuItem 
          onClick={() => router.push(`/tournaments/${tournament.id}?tab=report`)}
          className="text-xs font-semibold p-2 hover:bg-zinc-50 rounded-lg cursor-pointer flex items-center gap-2 text-zinc-700"
        >
          <FileText className="w-3.5 h-3.5 text-zinc-400" />
          Tournament Report
        </DropdownMenuItem>

        <DropdownMenuItem 
          onClick={() => router.push(`/tournaments/${tournament.id}?tab=disputes`)}
          className="text-xs font-semibold p-2 hover:bg-zinc-50 rounded-lg cursor-pointer flex items-center gap-2 text-zinc-700"
        >
          <ShieldAlert className="w-3.5 h-3.5 text-zinc-400" />
          Disputes & Reports
        </DropdownMenuItem>

        <DropdownMenuSeparator className="border-zinc-100" />
        
        <DropdownMenuItem 
          onClick={() => onCancelTournament(tournament)}
          className="text-xs font-semibold p-2 hover:bg-zinc-50 rounded-lg cursor-pointer flex items-center gap-2 text-rose-600"
        >
          <Trash className="w-3.5 h-3.5 text-rose-600" />
          Cancel Tournament
        </DropdownMenuItem>

        {canDelete && onDeleteTournament && (
          <DropdownMenuItem 
            onClick={() => onDeleteTournament(tournament)}
            className="text-xs font-semibold p-2 hover:bg-zinc-50 rounded-lg cursor-pointer flex items-center gap-2 text-rose-600 font-bold"
          >
            <Trash className="w-3.5 h-3.5 text-rose-600" />
            Delete Tournament
          </DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
