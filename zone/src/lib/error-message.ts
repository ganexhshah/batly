export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  return 'Unknown error';
}

/** Flatten Laravel-style `{ message, errors: { field: [msg] } }` into one string. */
export function formatApiError(payload: unknown, fallback = 'Request failed'): string {
  const record = asRecord(payload);
  const message = readString(record, 'message');
  const errors = record.errors;

  if (errors && typeof errors === 'object') {
    const parts = Object.values(errors as Record<string, unknown>)
      .flatMap((value) => (Array.isArray(value) ? value.map(String) : [String(value)]))
      .filter(Boolean);
    if (parts.length > 0) {
      return parts.join(' ');
    }
  }

  return message || fallback;
}
export type JsonRecord = Record<string, unknown>;

export function asRecord(value: unknown): JsonRecord {
  return value !== null && typeof value === 'object' ? (value as JsonRecord) : {};
}

export function readString(record: JsonRecord, key: string): string {
  const value = record[key];
  return value == null ? '' : String(value);
}

export function readNumber(record: JsonRecord, key: string): number {
  const value = record[key];
  if (typeof value === 'number') return value;
  return Number(value ?? 0);
}
