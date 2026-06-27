'use client';

import React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { apiPut } from '@/lib/api';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { User, Monitor } from 'lucide-react';

const settingsSchema = z.object({
  username: z.string().min(3, { message: 'Username must be at least 3 characters' }),
  email: z.string().email({ message: 'Invalid email address' }),
});

type SettingsFormValues = z.infer<typeof settingsSchema>;

export default function SettingsPage() {
  const { user, setUser, theme, toggleTheme } = useAppStore();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<SettingsFormValues>({
    resolver: zodResolver(settingsSchema),
    defaultValues: {
      username: user?.name || 'Administrator',
      email: user?.email || 'admin@battly.zone',
    },
  });

  const onSubmit = async (values: SettingsFormValues) => {
    try {
      const data = await apiPut('/user', { name: values.username });
      setUser(data.user);
      toast.success('Settings saved successfully!', {
        description: 'Your profile name has been updated.',
      });
    } catch (err: any) {
      toast.error('Failed to save profile changes', { description: err.message });
    }
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <div>
        <h2 className={`text-xl font-bold tracking-tight ${theme === 'dark' ? 'text-white' : 'text-zinc-900'}`}>Console Settings</h2>
        <p className={`text-xs ${theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}`}>Configure profile data, gamer links, and theme parameters</p>
      </div>

      <Tabs defaultValue="profile" className="w-full">
        <TabsList className={`bg-zinc-100 p-1 rounded-xl flex gap-1 w-fit border border-zinc-200/50 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800' : ''}`}>
          <TabsTrigger value="profile" className="rounded-lg text-xs font-semibold px-3 py-1.5 data-[state=active]:bg-white data-[state=active]:text-zinc-900 dark:data-[state=active]:bg-zinc-800 dark:data-[state=active]:text-white">Profile Details</TabsTrigger>
          <TabsTrigger value="preferences" className="rounded-lg text-xs font-semibold px-3 py-1.5 data-[state=active]:bg-white data-[state=active]:text-zinc-900 dark:data-[state=active]:bg-zinc-800 dark:data-[state=active]:text-white">Preferences</TabsTrigger>
        </TabsList>

        {/* Profile Tab */}
        <TabsContent value="profile" className="mt-4">
          <Card className={`bg-white border-zinc-200 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
            <CardHeader>
              <CardTitle className="text-sm font-semibold flex items-center gap-2">
                <User className="w-4.5 h-4.5 text-[#FF6B00]" />
                Staff Profile Details
              </CardTitle>
              <CardDescription className={theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}>
                Update your name and contact info. Saves directly to Zustand state.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 max-w-md">
                <div className="space-y-1">
                  <Label htmlFor="username" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Username / GamerTag</Label>
                  <Input
                    id="username"
                    {...register('username')}
                    className={`bg-white border-zinc-200 h-9 rounded-lg text-xs ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-white' : ''}`}
                  />
                  {errors.username && (
                    <p className="text-[10px] text-rose-600 font-semibold">{errors.username.message}</p>
                  )}
                </div>

                <div className="space-y-1">
                  <Label htmlFor="email" className={`text-xs font-semibold ${theme === 'dark' ? 'text-zinc-300' : 'text-zinc-700'}`}>Email Address</Label>
                  <Input
                    id="email"
                    {...register('email')}
                    readOnly
                    disabled
                    className={`bg-zinc-50 border-zinc-200 h-9 rounded-lg text-xs cursor-not-allowed opacity-70 ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-zinc-400' : ''}`}
                  />
                  <p className={`text-[10px] ${theme === 'dark' ? 'text-zinc-500' : 'text-zinc-400'}`}>
                    Email is tied to your login account and cannot be changed here. Contact an administrator to update it.
                  </p>
                </div>

                <Button 
                  type="submit" 
                  disabled={isSubmitting}
                  className={`bg-zinc-900 hover:bg-zinc-800 text-white font-semibold text-xs rounded-lg h-9 px-4 mt-2 ${theme === 'dark' ? 'bg-[#FF6B00] hover:bg-[#FF6B00]/90 text-white' : ''}`}
                >
                  Save Profile Changes
                </Button>
              </form>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Preferences Tab */}
        <TabsContent value="preferences" className="mt-4">
          <Card className={`bg-white border-zinc-200 ${theme === 'dark' ? 'bg-[#1A1D24] border-zinc-800 text-white' : ''}`}>
            <CardHeader>
              <CardTitle className="text-sm font-semibold flex items-center gap-2">
                <Monitor className="w-4.5 h-4.5 text-[#FF6B00]" />
                Display & Alerts
              </CardTitle>
              <CardDescription className={theme === 'dark' ? 'text-zinc-400' : 'text-zinc-500'}>
                Control styling themes and email subscription notifications.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6 max-w-md">
              <div className="flex justify-between items-center pb-4 border-b border-zinc-100 dark:border-zinc-800">
                <div>
                  <h4 className="text-xs font-bold">Lobby Styling Theme</h4>
                  <p className="text-[10px] text-zinc-400 mt-0.5">Toggle between dark mode and white mode.</p>
                </div>
                <Button
                  onClick={toggleTheme}
                  variant="outline"
                  type="button"
                  className={`border-zinc-200 h-9 text-xs gap-1.5 rounded-lg px-3 ${theme === 'dark' ? 'bg-[#0F1115] border-zinc-800 text-zinc-300 hover:text-white' : 'bg-white hover:bg-zinc-50'}`}
                >
                  {theme === 'dark' ? 'Switch to Light' : 'Switch to Dark'}
                </Button>
              </div>

              <p className="text-[10px] text-zinc-400">
                Email notification preferences will be available in a future update. In-app alerts are always enabled for admin queues.
              </p>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
