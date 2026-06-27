'use client';
 
import React from 'react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { useWalletTransactions } from '@/lib/admin-queries';
import { format, subDays, isSameDay, parseISO } from 'date-fns';
import { cn } from '@/lib/utils';

const parseTxDate = (tx: any) => {
  if (!tx.created_at) return null;
  try {
    return parseISO(tx.created_at);
  } catch {
    try {
      return new Date(tx.created_at);
    } catch {
      return null;
    }
  }
};

export default function RevenueChart() {
  const { data: transactions = [], isLoading } = useWalletTransactions();
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => {
    setMounted(true);
  }, []);

  const chartData = React.useMemo(() => {
    const today = new Date();
    const days = Array.from({ length: 7 }, (_, i) => subDays(today, 6 - i));
    
    let maxRevenue = 0;
    let peakIndex = 6; 
    let peakDateStr = '';
    
    const mappedData = days.map((day, idx) => {
      const formattedDayName = format(day, 'd MMM'); 
      
      const dailyRevenue = transactions
        .filter((tx) => {
          const isCompletedInflow = tx.type === 'Inflow' && 
            (tx.status?.toLowerCase() === 'completed' || tx.status?.toLowerCase() === 'success');
          if (!isCompletedInflow) return false;
          
          const txDate = parseTxDate(tx);
          return txDate ? isSameDay(txDate, day) : false;
        })
        .reduce((sum, tx) => {
          const val = Number(tx.amount_numeric) || 
            Number(String(tx.amount).replace(/[^0-9.]/g, '')) || 0;
          return sum + val;
        }, 0);
        
      if (dailyRevenue >= maxRevenue) {
        maxRevenue = dailyRevenue;
        peakIndex = idx;
        peakDateStr = format(day, 'd MMM yyyy');
      }
      
      return {
        name: formattedDayName,
        revenue: dailyRevenue,
        display: `NPR ${dailyRevenue.toLocaleString()}`,
      };
    });

    if (maxRevenue === 0 && mappedData.length > 0) {
      peakDateStr = format(today, 'd MMM yyyy');
    }

    return {
      data: mappedData,
      peakIndex,
      peakValueText: `NPR ${maxRevenue.toLocaleString()}`,
      peakDateStr,
    };
  }, [transactions]);

  if (!mounted || isLoading) {
    return <div className="mt-4 h-[280px] w-full bg-zinc-50/50 rounded-2xl animate-pulse" />;
  }

  const { data, peakIndex, peakValueText, peakDateStr } = chartData;

  // Determine the dynamic vertical position based on the value range
  const maxVal = Math.max(...data.map(d => d.revenue), 1);
  const peakVal = data[peakIndex]?.revenue ?? 0;
  // Calculate relative top position percentage (higher revenue = smaller top percentage)
  const relativeTopPercent = Math.max(14, Math.min(65, 80 - (peakVal / maxVal) * 60));

  return (
    <div className="relative mt-4 h-[280px] min-h-[280px] w-full min-w-0">
      {/* Dynamic indicator badge overlay on peak point */}
      <div 
        className={cn(
          "absolute -translate-x-1/2 -translate-y-full bg-zinc-900 text-white rounded-lg px-2.5 py-1 text-[10px] font-bold shadow-md flex flex-col items-center pointer-events-none z-10 dark:bg-zinc-800",
          peakIndex === 0 && "left-[12%]",
          peakIndex === 1 && "left-[25%]",
          peakIndex === 2 && "left-[38%]",
          peakIndex === 3 && "left-[51%]",
          peakIndex === 4 && "left-[64%]",
          peakIndex === 5 && "left-[77%]",
          peakIndex === 6 && "left-[90%]"
        )}
        style={{ top: `${relativeTopPercent}%` }}
      >
        <span className="text-white">{peakValueText}</span>
        <span className="text-zinc-400 text-[8px] font-medium">{peakDateStr}</span>
        <div className="w-1.5 h-1.5 bg-zinc-900 dark:bg-zinc-800 rotate-45 mt-0.5 -mb-1" />
      </div>
 
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 15, right: 15, left: -10, bottom: 0 }}>
          <defs>
            <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#FF6B00" stopOpacity={0.25}/>
              <stop offset="95%" stopColor="#FF6B00" stopOpacity={0.0}/>
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f1f4" vertical={true} horizontal={true} />
          <XAxis 
            dataKey="name" 
            fontSize={11} 
            stroke="#71717a" 
            tickLine={false} 
            axisLine={false}
            dy={8}
          />
          <YAxis 
            fontSize={11} 
            stroke="#71717a" 
            tickLine={false} 
            axisLine={false} 
            tickFormatter={(value) => `${value / 1000}K`}
            dx={-8}
          />
          <Tooltip 
            content={({ active, payload }) => {
              if (active && payload && payload.length) {
                return (
                  <div className="bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-lg p-2 shadow-md text-[10px]">
                    <p className="font-bold text-zinc-900 dark:text-white">{payload[0].payload.name}</p>
                    <p className="text-[#FF6B00] font-extrabold">{payload[0].payload.display}</p>
                  </div>
                );
              }
              return null;
            }}
          />
          <Area 
            type="monotone" 
            dataKey="revenue" 
            stroke="#FF6B00" 
            strokeWidth={3} 
            fillOpacity={1} 
            fill="url(#colorRevenue)" 
            activeDot={{ r: 6, stroke: '#fff', strokeWidth: 2, fill: '#FF6B00' }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
