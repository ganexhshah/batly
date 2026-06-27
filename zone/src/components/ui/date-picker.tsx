'use client';

import * as React from 'react';
import { CalendarIcon } from 'lucide-react';
import { Calendar } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

interface DatePickerProps {
  date?: Date;
  setDate: (date?: Date) => void;
  placeholder?: string;
}

export function DatePicker({ date, setDate, placeholder = "Pick a date" }: DatePickerProps) {
  return (
    <Popover>
      <PopoverTrigger
        render={
          <Button
            variant="outline"
            className={cn(
              "w-full justify-start text-left font-normal border-zinc-250 h-9 rounded-lg bg-white hover:bg-zinc-50 text-zinc-900",
              !date && "text-zinc-400"
            )}
          />
        }
      >
        <CalendarIcon className="mr-2 h-4 w-4 text-zinc-500" />
        {date ? date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : <span>{placeholder}</span>}
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0 bg-white border border-zinc-200 rounded-lg shadow-md" align="start">
        <Calendar
          mode="single"
          selected={date}
          onSelect={setDate}
          className="bg-white"
        />
      </PopoverContent>
    </Popover>
  );
}
