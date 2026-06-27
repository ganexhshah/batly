'use client';

import React from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';

const data = [
  { name: 'Valorant', players: 128 },
  { name: 'Apex Legends', players: 60 },
  { name: 'LoL', players: 256 },
  { name: 'Rocket League', players: 32 },
];

export default function RegistrationChart() {
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return <div className="mt-4 h-[200px] w-full bg-zinc-50/50 rounded-2xl animate-pulse" />;
  }

  return (
    <div className="mt-4 h-[200px] min-h-[200px] w-full min-w-0">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e4e4e7" />
          <XAxis dataKey="name" fontSize={11} stroke="#71717a" tickLine={false} axisLine={false} />
          <YAxis fontSize={11} stroke="#71717a" tickLine={false} axisLine={false} />
          <Tooltip 
            contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e4e4e7', borderRadius: '8px', boxShadow: '0 1px 3px 0 rgb(0 0 0 / 0.1)' }}
            labelStyle={{ color: '#09090b', fontWeight: 'bold', fontSize: '12px' }}
            itemStyle={{ color: '#FF6B00', fontSize: '12px' }}
          />
          <Bar dataKey="players" fill="#FF6B00" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
