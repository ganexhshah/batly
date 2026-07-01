import { formatApiError } from '@/lib/error-message';

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, '') ?? 'http://localhost:8888/api';

export const BACKEND_BASE_URL =
  process.env.NEXT_PUBLIC_BACKEND_BASE_URL?.replace(/\/$/, '') ??
  API_BASE_URL.replace(/\/api$/, '');

/** Admin carousel CRUD — works whether API base ends with `/api` or `/api/admin`. */
export function adminHomeCarouselPath(suffix = ''): string {
  const base = API_BASE_URL.replace(/\/$/, '');
  const prefix = base.endsWith('/admin') ? '/home-carousel' : '/admin/home-carousel';
  return `${prefix}${suffix}`;
}

function getHeaders() {
  const token = typeof window !== 'undefined' ? localStorage.getItem('battly_token') : null;
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
  };
}

export async function apiGet(endpoint: string) {
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    method: 'GET',
    headers: getHeaders(),
    cache: 'no-store',
  });
  if (!response.ok) {
    if (response.status === 401) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('battly_token');
        localStorage.removeItem('battly_user');
      }
    }
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData.message || `API Error: ${response.status}`);
  }
  return response.json();
}

export async function apiPost(endpoint: string, body?: unknown) {
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    method: 'POST',
    headers: getHeaders(),
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData.message || `API Error: ${response.status}`);
  }
  return response.json();
}

export async function apiPostMultipart(endpoint: string, formData: FormData) {
  const token = typeof window !== 'undefined' ? localStorage.getItem('battly_token') : null;
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    method: 'POST',
    headers: {
      'Accept': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    },
    body: formData,
  });
  if (!response.ok) {
    const errData = await response.json().catch(() => ({}));
    throw new Error(formatApiError(errData, `API Error: ${response.status}`));
  }
  return response.json();
}

export async function apiPatch(endpoint: string, body: unknown) {
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    method: 'PATCH',
    headers: getHeaders(),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData.message || `API Error: ${response.status}`);
  }
  return response.json();
}

export async function apiPut(endpoint: string, body: unknown) {
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    method: 'PUT',
    headers: getHeaders(),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData.message || `API Error: ${response.status}`);
  }
  return response.json();
}

export async function apiDelete(endpoint: string) {
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    method: 'DELETE',
    headers: getHeaders(),
  });
  if (!response.ok) {
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData.message || `API Error: ${response.status}`);
  }
  return response.json();
}
