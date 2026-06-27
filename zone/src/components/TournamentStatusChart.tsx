'use client';
 
import React from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer } from 'recharts';
import { cn } from '@/lib/utils';
import { useAppStore } from '@/store/useAppStore';
import { useTournamentsRaw } from '@/lib/admin-queries';

export default function TournamentStatusChart() {
  const { theme } = useAppStore();
  const { data: rawTournaments = [], isLoading } = useTournamentsRaw();
  
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => {
    setMounted(true);
  }, []);

  const chartData = React.useMemo(() => {
    let upcoming = 0;
    let ongoing = 0;
    let completed = 0;
    let cancelled = 0;

    rawTournaments.forEach((t) => {
      const stText = String(t.statusText || t.status || '').toUpperCase();
      if (stText === 'LIVE' || stText === 'ONGOING') {
        ongoing++;
      } else if (stText === 'COMPLETED') {
        completed++;
      } else if (stText === 'CANCELLED') {
        cancelled++;
      } else {
        upcoming++; // Default to upcoming
      }
    });

    const total = upcoming + ongoing + completed + cancelled;

    const getPercentage = (value: number) => {
      if (total === 0) return '0%';
      return ((value / total) * 100).toFixed(1) + '%';
    };

    return {
      total,
      data: [
        { name: 'Upcoming', value: upcoming, color: '#3b82f6', percentage: getPercentage(upcoming) },
        { name: 'Ongoing', value: ongoing, color: '#22c55e', percentage: getPercentage(ongoing) },
        { name: 'Completed', value: completed, color: '#a855f7', percentage: getPercentage(completed) },
        { name: 'Cancelled', value: cancelled, color: '#ef4444', percentage: getPercentage(cancelled) },
      ]
    };
  }, [rawTournaments]);

  if (!mounted || isLoading) {
    return <div className="mt-6 h-[220px] w-full bg-zinc-50/50 rounded-2xl animate-pulse" />;
  }

  const { total, data } = chartData;

  return (
    <div className="mt-6 flex min-h-[220px] min-w-0 flex-col items-center justify-between gap-6 sm:flex-row">
      {/* Donut Chart container with absolute center text label */}
      <div className="relative h-[180px] w-[180px] shrink-0 min-w-0">
        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none select-none z-10">
          <span className={cn("text-3xl font-black text-zinc-900", theme === 'dark' && "text-white")}>{total}</span>
          <span className="text-[10px] text-zinc-400 font-bold uppercase tracking-wider">Total</span>
        </div>
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius={55}
              outerRadius={75}
              paddingAngle={2}
              dataKey="value"
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Pie>
          </PieChart>
        </ResponsiveContainer>
      </div>
 
      {/* Legend details matching screenshot layout */}
      <div className="flex-1 space-y-3 w-full">
        {data.map((item) => (
          <div key={item.name} className="flex items-center justify-between text-xs font-semibold">
            <div className="flex items-center gap-2.5">
              <span className="w-3.5 h-3.5 rounded-md shrink-0" style={{ backgroundColor: item.color }} />
              <span className={cn("text-zinc-500", theme === 'dark' && "text-zinc-300")}>{item.name}</span>
            </div>
            <span className={cn("text-zinc-800 font-bold", theme === 'dark' && "text-zinc-200")}>
              {item.value} ({item.percentage})
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
