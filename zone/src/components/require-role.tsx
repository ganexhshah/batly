'use client';

import React from 'react';
import { useAppStore } from '@/store/useAppStore';
import { normalizeRole, type StaffRole } from '@/lib/role-permissions';

export function useStaffRole(): StaffRole | null {
  const { user } = useAppStore();
  return normalizeRole(user?.role);
}

interface RequireRoleProps {
  allow: (role: StaffRole | null) => boolean;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export function RequireRole({ allow, children, fallback = null }: RequireRoleProps) {
  const role = useStaffRole();
  if (!allow(role)) return <>{fallback}</>;
  return <>{children}</>;
}
