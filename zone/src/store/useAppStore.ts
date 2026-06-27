import { create } from 'zustand';

interface AppState {
  theme: 'dark' | 'light';
  toggleTheme: () => void;
  user: { name: string; email: string; role?: string; wallet_balance?: string | number } | null;
  setUser: (user: { name: string; email: string; role?: string; wallet_balance?: string | number } | null) => void;
  logout: () => void;
}

export const useAppStore = create<AppState>((set) => {
  let initialUser = null;
  if (typeof window !== 'undefined') {
    const saved = localStorage.getItem('battly_user');
    if (saved) {
      try {
        initialUser = JSON.parse(saved);
      } catch (_) {}
    }
  }

  return {
    theme: 'light',
    toggleTheme: () => set((state) => ({ theme: state.theme === 'dark' ? 'light' : 'dark' })),
    user: initialUser,
    setUser: (user) => {
      if (typeof window !== 'undefined') {
        if (user) {
          localStorage.setItem('battly_user', JSON.stringify(user));
        } else {
          localStorage.removeItem('battly_user');
        }
      }
      set({ user });
    },
    logout: () => {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('battly_token');
        localStorage.removeItem('battly_user');
        window.location.href = '/auth';
      }
      set({ user: null });
    },
  };
});
