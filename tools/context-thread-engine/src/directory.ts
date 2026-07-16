/**
 * Directory Management
 *
 * Manages the .Ai-config/context-thread/ directory structure for ContextThread data.
 */

import * as fs from 'fs';
import * as path from 'path';
import { execFileSync } from 'child_process';

/**
 * Project AI config directory name
 */
export const AI_CONFIG_DIR = '.Ai-config';

/**
 * ContextThread data directory name under .Ai-config
 */
export const CONTEXT_THREAD_DIR = 'context-thread';

const DATABASE_FILENAME = 'context-thread.db';

function buildGitignore(trackDb: boolean): string {
  const databasePolicy = trackDb
    ? '# context-thread.db is intentionally trackable for this project.'
    : `# The database is ignored by default because rich and legacy indexes may\n# contain extracted source details. Use --track-db only after choosing this intentionally.\n${DATABASE_FILENAME}`;

  return `# ContextThread persistence policy
${databasePolicy}

# SQLite runtime sidecar files
*.db-wal
*.db-shm
*.db-journal

# Cache
cache/

# Logs
*.log

# Locks
*.lock

# Hook markers
.dirty
`;
}

export interface DatabaseTrackingStatus {
  ignored: boolean;
  tracked: boolean;
}

/**
 * Get the .Ai-config/context-thread directory path for a project
 */
export function getContextThreadDir(projectRoot: string): string {
  return path.join(projectRoot, AI_CONFIG_DIR, CONTEXT_THREAD_DIR);
}

/**
 * Check if a project has been initialized with ContextThread
 * Requires both .Ai-config/context-thread/ directory AND context-thread.db to exist
 */
export function isInitialized(projectRoot: string): boolean {
  const contextThreadDir = getContextThreadDir(projectRoot);
  if (!fs.existsSync(contextThreadDir) || !fs.statSync(contextThreadDir).isDirectory()) {
    return false;
  }
  // Must have context-thread.db, not just .Ai-config/context-thread folder
  const dbPath = path.join(contextThreadDir, 'context-thread.db');
  return fs.existsSync(dbPath);
}

/**
 * Find the nearest parent directory containing .Ai-config/context-thread/
 *
 * Walks up from the given path to find a ContextThread-initialized project,
 * similar to how git finds .git/ directories.
 *
 * @param startPath - Directory to start searching from
 * @returns The project root containing .Ai-config/context-thread/, or null if not found
 */
export function findNearestContextThreadRoot(startPath: string): string | null {
  let current = path.resolve(startPath);
  const root = path.parse(current).root;

  while (current !== root) {
    if (isInitialized(current)) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) break; // Reached filesystem root
    current = parent;
  }

  // Check root as well
  if (isInitialized(current)) {
    return current;
  }

  return null;
}

/**
 * Create the .Ai-config/context-thread directory structure
 * Note: Only throws if context-thread.db already exists, not just if .Ai-config/context-thread/ exists.
 */
export function createDirectory(
  projectRoot: string,
  options: { trackDb?: boolean } = {}
): void {
  const contextThreadDir = getContextThreadDir(projectRoot);
  const dbPath = path.join(contextThreadDir, 'context-thread.db');

  // Only throw if ContextThread is actually initialized (db exists)
  // .Ai-config/context-thread/ folder alone is fine
  if (fs.existsSync(dbPath)) {
    throw new Error(`ContextThread already initialized in ${projectRoot}`);
  }

  // Create main directory (if it doesn't exist)
  fs.mkdirSync(contextThreadDir, { recursive: true });

  // Initialization is an explicit policy choice, so refresh the managed
  // .gitignore even when the directory existed before the database did.
  configureDatabaseTracking(projectRoot, options.trackDb ?? false);
}

/** Configure whether the durable database itself is eligible for Git tracking. */
export function configureDatabaseTracking(projectRoot: string, trackDb: boolean): void {
  const contextThreadDir = getContextThreadDir(projectRoot);
  fs.mkdirSync(contextThreadDir, { recursive: true });
  fs.writeFileSync(
    path.join(contextThreadDir, '.gitignore'),
    buildGitignore(trackDb),
    'utf-8'
  );
}

/** Read Git tracking state without changing either Git or .gitignore. */
export function getDatabaseTrackingStatus(projectRoot: string): DatabaseTrackingStatus {
  const gitignorePath = path.join(getContextThreadDir(projectRoot), '.gitignore');
  let ignored = false;
  try {
    const lines = fs.readFileSync(gitignorePath, 'utf-8').split(/\r?\n/);
    ignored = lines.some((line) => {
      const trimmed = line.trim();
      return trimmed === DATABASE_FILENAME || trimmed === `/${DATABASE_FILENAME}`;
    });
  } catch {
    ignored = false;
  }

  try {
    execFileSync(
      'git',
      ['check-ignore', '--no-index', '-q', '--', `${AI_CONFIG_DIR}/${CONTEXT_THREAD_DIR}/${DATABASE_FILENAME}`],
      {
        cwd: projectRoot,
        stdio: ['ignore', 'ignore', 'ignore'],
        timeout: 5000,
        env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' },
      }
    );
    ignored = true;
  } catch {
    // Not ignored or not a Git repository; retain the managed-file fallback.
  }

  let tracked = false;
  try {
    execFileSync(
      'git',
      ['ls-files', '--error-unmatch', '--', `${AI_CONFIG_DIR}/${CONTEXT_THREAD_DIR}/${DATABASE_FILENAME}`],
      {
        cwd: projectRoot,
        stdio: ['ignore', 'ignore', 'ignore'],
        timeout: 5000,
        env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' },
      }
    );
    tracked = true;
  } catch {
    tracked = false;
  }

  return { ignored, tracked };
}

/**
 * Remove the .Ai-config/context-thread directory
 */
export function removeDirectory(projectRoot: string): void {
  const contextThreadDir = getContextThreadDir(projectRoot);

  if (!fs.existsSync(contextThreadDir)) {
    return;
  }

  // Verify .Ai-config/context-thread is a real directory, not a symlink pointing elsewhere
  const lstat = fs.lstatSync(contextThreadDir);
  if (lstat.isSymbolicLink()) {
    // Only remove the symlink itself, never follow it for recursive delete
    fs.unlinkSync(contextThreadDir);
    return;
  }

  if (!lstat.isDirectory()) {
    // Not a directory - remove the single file
    fs.unlinkSync(contextThreadDir);
    return;
  }

  // Recursively remove directory
  fs.rmSync(contextThreadDir, { recursive: true, force: true });
}

/**
 * Get all files in the .Ai-config/context-thread directory
 */
export function listDirectoryContents(projectRoot: string): string[] {
  const contextThreadDir = getContextThreadDir(projectRoot);

  if (!fs.existsSync(contextThreadDir)) {
    return [];
  }

  const files: string[] = [];

  function walkDir(dir: string, prefix: string = ''): void {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;

      // Skip symlinks to prevent following links outside .Ai-config/context-thread
      if (entry.isSymbolicLink()) {
        continue;
      }

      if (entry.isDirectory()) {
        walkDir(path.join(dir, entry.name), relativePath);
      } else {
        files.push(relativePath);
      }
    }
  }

  walkDir(contextThreadDir);
  return files;
}

/**
 * Get the total size of the .Ai-config/context-thread directory in bytes
 */
export function getDirectorySize(projectRoot: string): number {
  const contextThreadDir = getContextThreadDir(projectRoot);

  if (!fs.existsSync(contextThreadDir)) {
    return 0;
  }

  let totalSize = 0;

  function walkDir(dir: string): void {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      // Skip symlinks to prevent following links outside .Ai-config/context-thread
      if (entry.isSymbolicLink()) {
        continue;
      }

      const fullPath = path.join(dir, entry.name);

      if (entry.isDirectory()) {
        walkDir(fullPath);
      } else {
        const stats = fs.statSync(fullPath);
        totalSize += stats.size;
      }
    }
  }

  walkDir(contextThreadDir);
  return totalSize;
}

/**
 * Ensure a subdirectory exists within .Ai-config/context-thread
 */
export function ensureSubdirectory(projectRoot: string, subdirName: string): string {
  if (subdirName.includes('..') || subdirName.includes(path.sep) || subdirName.includes('/')) {
    throw new Error(`Invalid subdirectory name: ${subdirName}`);
  }

  const subdirPath = path.join(getContextThreadDir(projectRoot), subdirName);

  if (!fs.existsSync(subdirPath)) {
    fs.mkdirSync(subdirPath, { recursive: true });
  }

  return subdirPath;
}

/**
 * Check if the .Ai-config/context-thread directory has valid structure
 */
export function validateDirectory(
  projectRoot: string,
  options: { repair?: boolean } = {}
): {
  valid: boolean;
  errors: string[];
} {
  const errors: string[] = [];
  const contextThreadDir = getContextThreadDir(projectRoot);

  if (!fs.existsSync(contextThreadDir)) {
    errors.push('ContextThread directory does not exist');
    return { valid: false, errors };
  }

  if (!fs.statSync(contextThreadDir).isDirectory()) {
    errors.push('.Ai-config/context-thread exists but is not a directory');
    return { valid: false, errors };
  }

  // Auto-repair missing .gitignore only for writable callers. A read-only open
  // must be observational, including when this non-critical file is absent.
  const gitignorePath = path.join(contextThreadDir, '.gitignore');
  if (!fs.existsSync(gitignorePath) && options.repair !== false) {
    try {
      fs.writeFileSync(gitignorePath, buildGitignore(false), 'utf-8');
    } catch {
      // Non-fatal: warn but don't block
      errors.push('.gitignore missing in .Ai-config/context-thread directory and could not be created');
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}
