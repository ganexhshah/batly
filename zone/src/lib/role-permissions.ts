export type StaffRole = 'admin' | 'moderator' | 'host';

export function normalizeRole(role: string | null | undefined): StaffRole | null {
  const r = String(role ?? '').toLowerCase();
  if (r === 'admin' || r === 'moderator' || r === 'host') return r;
  return null;
}

export function getStoredRole(): StaffRole | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = localStorage.getItem('battly_user');
    if (!raw) return null;
    return normalizeRole(JSON.parse(raw).role);
  } catch {
    return null;
  }
}

export function isAdmin(role: StaffRole | null): boolean {
  return role === 'admin';
}

export function isModeratorOrAbove(role: StaffRole | null): boolean {
  return role === 'admin' || role === 'moderator';
}

export function isStaff(role: StaffRole | null): boolean {
  return role === 'admin' || role === 'moderator' || role === 'host';
}

/** Sidebar routes visible per role */
export function canViewNav(href: string, role: StaffRole | null): boolean {
  if (!role) return false;

  const adminOnly = ['/users', '/banners'];
  const moderatorOnly = [] as string[];

  if (adminOnly.includes(href)) return isAdmin(role);
  if (moderatorOnly.includes(href)) return isModeratorOrAbove(role);

  return isStaff(role);
}

export function canManageStaff(role: StaffRole | null): boolean {
  return isAdmin(role);
}

export function canManageBanners(role: StaffRole | null): boolean {
  return isAdmin(role);
}

export function canAdjustWallet(role: StaffRole | null): boolean {
  return isAdmin(role);
}

export function canManageWithdrawals(role: StaffRole | null): boolean {
  return isModeratorOrAbove(role);
}

export function canResolveDisputes(role: StaffRole | null): boolean {
  return isModeratorOrAbove(role);
}

export function canManageNotifications(role: StaffRole | null): boolean {
  return isModeratorOrAbove(role);
}

export function canCreateTeams(role: StaffRole | null): boolean {
  return isModeratorOrAbove(role);
}

export function canManagePlayers(role: StaffRole | null): boolean {
  return isAdmin(role);
}

export function canDeleteTournaments(role: StaffRole | null): boolean {
  return isAdmin(role);
}

export function canUpdateSupport(role: StaffRole | null): boolean {
  return isModeratorOrAbove(role);
}

export function canApproveResults(role: StaffRole | null): boolean {
  return isModeratorOrAbove(role);
}

/** Route-level access (sidebar hiding is not enough). */
export function canAccessRoute(pathname: string, role: StaffRole | null): boolean {
  if (!role || !isStaff(role)) return false;
  if (pathname.startsWith('/users')) return canManageStaff(role);
  if (pathname.startsWith('/banners')) return canManageBanners(role);
  return true;
}

/** Prefetch keys allowed per role (avoids 403 noise on login) */
export function prefetchKeysForRole(role: StaffRole | null): string[] {
  if (!role) return [];

  const base = [
    'overview',
    'matches',
    'pendingResults',
    'disputes',
    'walletTransactions',
    'walletWithdrawals',
    'walletBalance',
    'supportTickets',
    'notifications',
    'tournaments',
    'teams',
    'scrims',
    'players',
  ];

  if (isAdmin(role)) {
    return [...base, 'users', 'banners'];
  }

  return base;
}
