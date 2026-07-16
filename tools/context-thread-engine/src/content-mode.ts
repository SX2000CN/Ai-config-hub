import { ConfigError } from './errors';
import type { SqliteDatabase } from './db/sqlite-adapter';

export const CONTENT_MODE_METADATA_KEY = 'content_mode_v1';
export const DEFAULT_CONTENT_MODE = 'structure' as const;

export type ContentMode = 'structure' | 'rich';
export type ContentModeLabel = ContentMode | 'legacy-rich';

export interface ContentModeState {
  /** Effective persistence policy used for all new writes. */
  mode: ContentMode;
  /** User-facing label. Missing metadata is deliberately reported as legacy-rich. */
  label: ContentModeLabel;
  /** True when an older database has no explicit content-mode metadata. */
  legacy: boolean;
}

export function parseContentMode(value: string): ContentMode {
  if (value === 'structure' || value === 'rich') return value;
  throw new ConfigError(`Invalid content mode: ${value}. Expected "structure" or "rich".`, {
    value,
    allowed: ['structure', 'rich'],
  });
}

/**
 * Read the persisted policy without mutating legacy databases. Databases created
 * before content-mode metadata existed retain the old rich behavior until the
 * user explicitly chooses a policy.
 */
export function readContentModeState(db: SqliteDatabase): ContentModeState {
  let raw: string | null = null;
  try {
    const row = db
      .prepare('SELECT value FROM project_metadata WHERE key = ?')
      .get(CONTENT_MODE_METADATA_KEY) as { value: string } | undefined;
    raw = row?.value ?? null;
  } catch (error) {
    // A genuinely old read-only database may not have project_metadata yet.
    // Treat it as legacy-rich rather than migrating during a read-only open.
    const message = error instanceof Error ? error.message : String(error);
    if (!message.toLowerCase().includes('no such table')) throw error;
    raw = null;
  }

  if (raw === null) {
    return { mode: 'rich', label: 'legacy-rich', legacy: true };
  }

  const mode = parseContentMode(raw);
  return { mode, label: mode, legacy: false };
}

export function writeContentMode(db: SqliteDatabase, mode: ContentMode): void {
  db.prepare(
    'INSERT INTO project_metadata (key, value, updated_at) VALUES (?, ?, ?) ' +
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at'
  ).run(CONTENT_MODE_METADATA_KEY, mode, Date.now());
}
