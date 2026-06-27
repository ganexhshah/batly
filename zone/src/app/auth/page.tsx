'use client';

import React, { useState, useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAppStore } from '@/store/useAppStore';
import { apiPost } from '@/lib/api';

import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { ShieldCheck, Mail, Lock, AlertCircle, Compass } from 'lucide-react';

// Form validation schema with Zod
const loginSchema = z.object({
  email: z.string().min(1, { message: 'Email is required' }).email({ message: 'Invalid email address' }),
  password: z.string().min(6, { message: 'Password must be at least 6 characters' }),
  rememberMe: z.boolean(),
});

type LoginFormValues = z.infer<typeof loginSchema>;

export default function LoginPage() {
  const { setUser } = useAppStore();
  const [success, setSuccess] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const router = useRouter();

  useEffect(() => {
    const token = localStorage.getItem('battly_token');
    const storedUser = localStorage.getItem('battly_user');
    if (token && storedUser) {
      router.push('/');
    }
  }, [router]);

  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: '',
      password: '',
      rememberMe: false,
    },
  });

  const onSubmit = async (values: LoginFormValues) => {
    setErrorMessage(null);
    setSuccess(false);
    try {
      const data = await apiPost('/login', {
          email: values.email,
          password: values.password,
      });

      const role = String(data.user?.role || '').toLowerCase();
      if (!['admin', 'moderator', 'host'].includes(role)) {
        setErrorMessage('This account does not have admin panel access.');
        return;
      }

      localStorage.setItem('battly_token', data.token);
      setUser(data.user);
      setSuccess(true);
      setTimeout(() => {
        router.push('/');
      }, 1500);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Authentication failed.');
    }
  };

  return (
    <div className="flex-1 min-h-screen bg-zinc-50 text-zinc-900 flex items-center justify-center p-4 md:p-8">
      <div className="w-full max-w-md">
        
        {/* Brand header */}
        <div className="flex flex-col items-center mb-8">
          <div className="p-2.5 bg-zinc-900 text-white rounded-xl mb-3">
            <Compass className="w-6 h-6" />
          </div>
          <h2 className="text-xl font-bold tracking-tight text-zinc-900">
            Battly Zone
          </h2>
          <p className="text-xs text-zinc-500 mt-1">Management Portal</p>
        </div>

        <Card className="bg-white border-zinc-200 text-zinc-900 rounded-xl shadow-md border relative">
          
          <CardHeader className="pt-8 pb-4">
            <CardTitle className="text-xl font-semibold tracking-tight text-center">
              Welcome back
            </CardTitle>
            <CardDescription className="text-zinc-500 text-center">
              Enter your credentials to access your console
            </CardDescription>
          </CardHeader>
          
          <CardContent className="space-y-4">
            {success ? (
              <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 p-4 rounded-xl flex items-start gap-3">
                <ShieldCheck className="w-5 h-5 shrink-0 text-emerald-600 mt-0.5" />
                <div>
                  <h4 className="font-semibold text-sm">Successfully Logged In!</h4>
                  <p className="text-xs text-emerald-700 mt-1">
                    Your global profile state has been updated. You can now access your dashboard workspace.
                  </p>
                  <div className="mt-4">
                    <Link href="/">
                      <Button size="sm" className="bg-zinc-900 hover:bg-zinc-800 text-white font-medium rounded-lg px-4">
                        Go to Dashboard
                      </Button>
                    </Link>
                  </div>
                </div>
              </div>
            ) : (
              <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                
                {errorMessage && (
                  <div className="bg-rose-50 border border-rose-200 text-rose-700 p-3 rounded-lg flex items-center gap-2 text-xs">
                    <AlertCircle className="w-4 h-4 shrink-0 text-rose-500" />
                    <span>{errorMessage}</span>
                  </div>
                )}

                {/* Email input field */}
                <div className="space-y-2">
                  <div className="flex justify-between items-center">
                    <Label htmlFor="email" className="text-zinc-700 font-medium">Email address</Label>
                  </div>
                  <div className="relative">
                    <span className="absolute inset-y-0 left-3 flex items-center text-zinc-400">
                      <Mail className="w-4 h-4" />
                    </span>
                    <Input
                      id="email"
                      {...register('email')}
                      type="email"
                      placeholder="name@example.com"
                      className="bg-white border-zinc-200 pl-10 text-zinc-900 placeholder-zinc-400 focus-visible:ring-zinc-400 rounded-lg h-9 border"
                    />
                  </div>
                  {errors.email && (
                    <p className="text-xs text-rose-600 font-medium mt-1">{errors.email.message}</p>
                  )}
                </div>

                {/* Password input field */}
                <div className="space-y-2">
                  <div className="flex justify-between items-center">
                    <Label htmlFor="password" className="text-zinc-700 font-medium">Password</Label>
                    <a href="#" className="text-xs text-zinc-600 hover:text-zinc-900 hover:underline">
                      Forgot?
                    </a>
                  </div>
                  <div className="relative">
                    <span className="absolute inset-y-0 left-3 flex items-center text-zinc-400">
                      <Lock className="w-4 h-4" />
                    </span>
                    <Input
                      id="password"
                      {...register('password')}
                      type="password"
                      placeholder="••••••••"
                      className="bg-white border-zinc-200 pl-10 text-zinc-900 placeholder-zinc-400 focus-visible:ring-zinc-400 rounded-lg h-9 border"
                    />
                  </div>
                  {errors.password && (
                    <p className="text-xs text-rose-600 font-medium mt-1">{errors.password.message}</p>
                  )}
                </div>

                {/* Remember me checkbox */}
                <div className="flex items-center space-x-2 pt-1">
                  <Controller
                    control={control}
                    name="rememberMe"
                    render={({ field }) => (
                      <Checkbox
                        id="rememberMe"
                        checked={field.value}
                        onCheckedChange={(checked) => field.onChange(!!checked)}
                        className="border-zinc-300 data-checked:bg-zinc-900 data-checked:border-zinc-900 focus-visible:ring-zinc-400"
                      />
                    )}
                  />
                  <Label
                    htmlFor="rememberMe"
                    className="text-xs text-zinc-600 font-medium cursor-pointer"
                  >
                    Remember me on this device
                  </Label>
                </div>

                {/* Submit button */}
                <Button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full bg-zinc-900 hover:bg-zinc-800 text-white font-medium py-2 rounded-lg transition-colors duration-200 mt-6 h-9"
                >
                  {isSubmitting ? (
                    <span className="flex items-center gap-2 justify-center">
                      <span className="w-4 h-4 border-2 border-t-transparent border-white rounded-full animate-spin"></span>
                      Authenticating...
                    </span>
                  ) : (
                    'Sign In'
                  )}
                </Button>

                {/* Divider */}
                <div className="relative my-4">
                  <div className="absolute inset-0 flex items-center">
                    <div className="w-full border-t border-zinc-200" />
                  </div>
                  <div className="relative flex justify-center text-xs">
                    <span className="bg-white px-2 text-zinc-500">OR</span>
                  </div>
                </div>

                {/* Continue with Google Button */}
                <button
                  type="button"
                  className="w-full flex items-center justify-center gap-3 bg-white border border-zinc-300 text-zinc-700 font-medium py-2 rounded-lg hover:bg-zinc-50 hover:border-zinc-400 transition-colors duration-200 h-10"
                  onClick={() => {
                    // TODO: Implement Google Sign-In
                  }}
                >
                  <img
                    src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Google_Favicon_2025.svg/120px-Google_Favicon_2025.svg.png"
                    alt="Google"
                    width={20}
                    height={20}
                  />
                  Continue with Google
                </button>

                {/* Continue with Apple Button */}
                <button
                  type="button"
                  className="w-full flex items-center justify-center gap-3 bg-black border border-zinc-700 text-white font-medium py-2 rounded-lg hover:bg-zinc-900 transition-colors duration-200 h-10"
                  onClick={() => {
                    // TODO: Implement Apple Sign-In
                  }}
                >
                  <img
                    src="https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/500px-Apple_logo_black.svg.png"
                    alt="Apple"
                    width={20}
                    height={20}
                    className="invert"
                  />
                  Continue with Apple
                </button>
              </form>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
