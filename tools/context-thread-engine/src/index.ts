/**
 * ContextThread
 *
 * A local-first code intelligence system that builds a semantic
 * knowledge graph from any codebase.
 */

import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  Node,
  Edge,
  FileRecord,
  ExtractionResult,
  Subgraph,
  TraversalOptions,
  SearchOptions,
  SearchResult,
  Context,
  GraphStats,
  TaskInput,
  TaskContext,
  BuildContextOptions,
  FindRelevantContextOptions,
} from './types';
import { DatabaseConnection, getDatabasePath } from './db';
import { QueryBuilder } from './db/queries';
import {
  isInitialized,
  createDirectory,
  removeDirectory,
  validateDirectory,
  getContextThreadDir,
  configureDatabaseTracking,
  getDatabaseTrackingStatus,
} from './directory';
import {
  ExtractionOrchestrator,
  IndexProgress,
  IndexResult,
  SyncResult,
  extractFromSource,
  initGrammars,
} from './extraction';
import {
  ReferenceResolver,
  createResolver,
  ResolutionResult,
} from './resolution';
import { GraphTraverser, GraphQueryManager } from './graph';
import { ContextBuilder, createContextBuilder } from './context';
import { Mutex, FileLock } from './utils';
import { FileWatcher, WatchOptions } from './sync';
import { ConfigError } from './errors';
import {
  ContentMode,
  ContentModeLabel,
  ContentModeState,
  DEFAULT_CONTENT_MODE,
  parseContentMode,
} from './content-mode';

// Re-export types for consumers
export * from './types';
export { getDatabasePath } from './db';
export {
  AI_CONFIG_DIR,
  getContextThreadDir,
  isInitialized,
  findNearestContextThreadRoot,
  CONTEXT_THREAD_DIR,
} from './directory';
export { IndexProgress, IndexResult, SyncResult } from './extraction';
export { detectLanguage, isLanguageSupported, isGrammarLoaded, getSupportedLanguages, initGrammars, loadGrammarsForLanguages, loadAllGrammars } from './extraction';
export { ResolutionResult } from './resolution';
export {
  ContextThreadError,
  FileError,
  ParseError,
  DatabaseError,
  SearchError,
  VectorError,
  ConfigError,
  Logger,
  setLogger,
  getLogger,
  silentLogger,
  defaultLogger,
} from './errors';
export { Mutex, FileLock, processInBatches, debounce, throttle, MemoryMonitor } from './utils';
export { FileWatcher, WatchOptions } from './sync';
export { MCPServer } from './mcp';
export {
  ContentMode,
  ContentModeLabel,
  ContentModeState,
  CONTENT_MODE_METADATA_KEY,
  DEFAULT_CONTENT_MODE,
  parseContentMode,
} from './content-mode';

/**
 * Options for initializing a new ContextThread project
 */
export interface InitOptions {
  /** Whether to run initial indexing after init */
  index?: boolean;

  /** Progress callback for indexing */
  onProgress?: (progress: IndexProgress) => void;

  /** Persist only structural fields by default; opt into rich source details explicitly. */
  contentMode?: ContentMode;

  /** Make context-thread.db eligible for Git tracking (default: ignored). */
  trackDb?: boolean;
}

export interface InitSyncOptions {
  contentMode?: ContentMode;
  trackDb?: boolean;
}

/**
 * Options for opening an existing ContextThread project
 */
export interface OpenOptions {
  /** Whether to run sync if files have changed */
  sync?: boolean;

  /** Whether to run in read-only mode */
  readOnly?: boolean;
}

/**
 * Options for indexing
 */
export interface IndexOptions {
  /** Progress callback */
  onProgress?: (progress: IndexProgress) => void;

  /** Abort signal for cancellation */
  signal?: AbortSignal;

  /** Enable verbose logging (worker lifecycle, memory, timeouts) */
  verbose?: boolean;
}

export interface PrivacyStatus {
  contentMode: ContentMode;
  contentModeLabel: ContentModeLabel;
  legacyRich: boolean;
  databaseIgnored: boolean;
  databaseTracked: boolean;
}

export interface ContentModeTransitionResult {
  previousMode: ContentModeLabel;
  contentMode: ContentMode;
  rebuilt: boolean;
  indexResult?: IndexResult;
}

/**
 * Main ContextThread class
 *
 * Provides the primary interface for interacting with the code knowledge graph.
 */
export class ContextThread {
  private db: DatabaseConnection;
  private queries: QueryBuilder;
  private projectRoot: string;
  private orchestrator: ExtractionOrchestrator;
  private resolver: ReferenceResolver;
  private graphManager: GraphQueryManager;
  private traverser: GraphTraverser;
  private contextBuilder: ContextBuilder;
  private readOnly: boolean;

  // Mutex for preventing concurrent indexing operations (in-process)
  private indexMutex = new Mutex();

  // File lock for preventing concurrent writes across processes (CLI, MCP, git hooks)
  private fileLock: FileLock;

  // File watcher for auto-sync on file changes
  private watcher: FileWatcher | null = null;

  private constructor(
    db: DatabaseConnection,
    queries: QueryBuilder,
    projectRoot: string
  ) {
    this.db = db;
    this.queries = queries;
    this.projectRoot = projectRoot;
    this.readOnly = db.isReadOnly();
    this.fileLock = new FileLock(
      path.join(getContextThreadDir(projectRoot), 'context-thread.lock')
    );
    this.orchestrator = new ExtractionOrchestrator(projectRoot, queries);
    this.resolver = createResolver(projectRoot, queries);
    this.graphManager = new GraphQueryManager(queries);
    this.traverser = new GraphTraverser(queries);
    this.contextBuilder = createContextBuilder(
      projectRoot,
      queries,
      this.traverser
    );
  }

  // ===========================================================================
  // Lifecycle Methods
  // ===========================================================================

  /**
   * Initialize a new ContextThread project
   *
   * Creates the .ContextThread directory, database, and configuration.
   *
   * @param projectRoot - Path to the project root directory
   * @param options - Initialization options
   * @returns A new ContextThread instance
   */
  static async init(projectRoot: string, options: InitOptions = {}): Promise<ContextThread> {
    await initGrammars();
    const resolvedRoot = path.resolve(projectRoot);

    // Check if already initialized
    if (isInitialized(resolvedRoot)) {
      throw new Error(`ContextThread already initialized in ${resolvedRoot}`);
    }

    // Create directory structure
    const contentMode = parseContentMode(options.contentMode ?? DEFAULT_CONTENT_MODE);
    createDirectory(resolvedRoot, { trackDb: options.trackDb ?? false });

    // Initialize database
    const dbPath = getDatabasePath(resolvedRoot);
    const db = DatabaseConnection.initialize(dbPath, { contentMode });
    const queries = new QueryBuilder(db.getDb(), db.getContentModeState().mode);

    const instance = new ContextThread(db, queries, resolvedRoot);

    // Run initial indexing if requested
    if (options.index) {
      await instance.indexAll({ onProgress: options.onProgress });
    }

    return instance;
  }

  /**
   * Initialize synchronously (without indexing)
   */
  static initSync(projectRoot: string, options: InitSyncOptions = {}): ContextThread {
    const resolvedRoot = path.resolve(projectRoot);

    // Check if already initialized
    if (isInitialized(resolvedRoot)) {
      throw new Error(`ContextThread already initialized in ${resolvedRoot}`);
    }

    // Create directory structure
    const contentMode = parseContentMode(options.contentMode ?? DEFAULT_CONTENT_MODE);
    createDirectory(resolvedRoot, { trackDb: options.trackDb ?? false });

    // Initialize database
    const dbPath = getDatabasePath(resolvedRoot);
    const db = DatabaseConnection.initialize(dbPath, { contentMode });
    const queries = new QueryBuilder(db.getDb(), db.getContentModeState().mode);

    return new ContextThread(db, queries, resolvedRoot);
  }

  /**
   * Open an existing ContextThread project
   *
   * @param projectRoot - Path to the project root directory
   * @param options - Open options
   * @returns A ContextThread instance
   */
  static async open(projectRoot: string, options: OpenOptions = {}): Promise<ContextThread> {
    await initGrammars();
    const resolvedRoot = path.resolve(projectRoot);

    if (options.readOnly && options.sync) {
      throw new ConfigError('Cannot sync while opening ContextThread in read-only mode.', {
        operation: 'open(sync)',
        readOnly: true,
      });
    }

    // Check if initialized
    if (!isInitialized(resolvedRoot)) {
      throw new Error(`ContextThread not initialized in ${resolvedRoot}. Run init() first.`);
    }

    // Validate directory structure
    const validation = validateDirectory(resolvedRoot, { repair: options.readOnly !== true });
    if (!validation.valid) {
      throw new Error(`Invalid ContextThread directory: ${validation.errors.join(', ')}`);
    }

    // Open database
    const dbPath = getDatabasePath(resolvedRoot);
    const db = DatabaseConnection.open(dbPath, { readOnly: options.readOnly });
    const queries = new QueryBuilder(db.getDb(), db.getContentModeState().mode);

    const instance = new ContextThread(db, queries, resolvedRoot);

    // Sync if requested
    if (options.sync) {
      await instance.sync();
    }

    return instance;
  }

  /**
   * Open synchronously (without sync)
   */
  static openSync(projectRoot: string, options: OpenOptions = {}): ContextThread {
    const resolvedRoot = path.resolve(projectRoot);

    // Check if initialized
    if (!isInitialized(resolvedRoot)) {
      throw new Error(`ContextThread not initialized in ${resolvedRoot}. Run init() first.`);
    }

    // Validate directory structure
    const validation = validateDirectory(resolvedRoot, { repair: options.readOnly !== true });
    if (!validation.valid) {
      throw new Error(`Invalid ContextThread directory: ${validation.errors.join(', ')}`);
    }

    // Open database
    const dbPath = getDatabasePath(resolvedRoot);
    const db = DatabaseConnection.open(dbPath, { readOnly: options.readOnly });
    const queries = new QueryBuilder(db.getDb(), db.getContentModeState().mode);

    return new ContextThread(db, queries, resolvedRoot);
  }

  /**
   * Check if a directory has been initialized as a ContextThread project
   */
  static isInitialized(projectRoot: string): boolean {
    return isInitialized(path.resolve(projectRoot));
  }

  /**
   * Close the ContextThread instance and release resources
   */
  close(): void {
    this.unwatch();
    // Release file lock if held
    this.fileLock.release();
    this.db.close();
  }

  /**
   * Get the project root directory
   */
  getProjectRoot(): string {
    return this.projectRoot;
  }

  private assertWritable(operation: string): void {
    if (this.readOnly) {
      throw new ConfigError(
        `Cannot ${operation} while ContextThread is opened in read-only mode.`,
        { operation, readOnly: true }
      );
    }
  }

  private rebindDatabase(db: DatabaseConnection): void {
    this.db = db;
    this.queries = new QueryBuilder(db.getDb(), db.getContentModeState().mode);
    this.readOnly = db.isReadOnly();
    this.orchestrator = new ExtractionOrchestrator(this.projectRoot, this.queries);
    this.resolver = createResolver(this.projectRoot, this.queries);
    this.graphManager = new GraphQueryManager(this.queries);
    this.traverser = new GraphTraverser(this.queries);
    this.contextBuilder = createContextBuilder(
      this.projectRoot,
      this.queries,
      this.traverser
    );
  }

  private reopenWritableDatabase(): void {
    const dbPath = this.db.getPath();
    this.db.close();
    this.rebindDatabase(DatabaseConnection.open(dbPath));
  }

  getContentModeState(): ContentModeState {
    return this.db.getContentModeState();
  }

  getPrivacyStatus(): PrivacyStatus {
    const mode = this.db.getContentModeState();
    const tracking = getDatabaseTrackingStatus(this.projectRoot);
    return {
      contentMode: mode.mode,
      contentModeLabel: mode.label,
      legacyRich: mode.legacy,
      databaseIgnored: tracking.ignored,
      databaseTracked: tracking.tracked,
    };
  }

  setDatabaseTracking(trackDb: boolean): void {
    this.assertWritable('change database tracking policy');
    configureDatabaseTracking(this.projectRoot, trackDb);
  }

  /**
   * Change the durable content policy. Downgrades scrub in place and compact the
   * database; upgrades rebuild every file because structure indexes no longer
   * contain the optional source-derived fields needed by rich mode.
   */
  async setContentMode(
    requestedMode: ContentMode,
    options: IndexOptions = {}
  ): Promise<ContentModeTransitionResult> {
    this.assertWritable('change content mode');
    const mode = parseContentMode(requestedMode);

    return this.indexMutex.withLock(async () => {
      try {
        this.fileLock.acquire();
      } catch (error) {
        throw new ConfigError('Could not acquire the ContextThread write lock.', {
          operation: 'change content mode',
          cause: error instanceof Error ? error.message : String(error),
        });
      }

      const previous = this.db.getContentModeState();
      try {
        if (mode === 'rich' && previous.mode === 'rich' && !previous.legacy) {
          return { previousMode: previous.label, contentMode: mode, rebuilt: false };
        }

        if (mode === 'structure') {
          try {
            this.db.transitionToStructure();
          } catch (error) {
            // Reopening releases SQLite's exclusive privacy-transition lock and
            // refreshes in-memory mode state even when preflight/finalization
            // failed. The original error remains the user-facing failure.
            try {
              this.reopenWritableDatabase();
            } catch (reopenError) {
              throw new ConfigError('Privacy transition failed and the database could not be reopened.', {
                transitionError: error instanceof Error ? error.message : String(error),
                reopenError: reopenError instanceof Error ? reopenError.message : String(reopenError),
              });
            }
            throw error;
          }
          this.reopenWritableDatabase();
          return { previousMode: previous.label, contentMode: 'structure', rebuilt: false };
        }

        // Explicitly adopting rich on a legacy-rich database records the choice
        // but does not rewrite otherwise equivalent data.
        if (previous.legacy) {
          this.db.setContentMode('rich');
          this.queries.setContentMode('rich');
          return { previousMode: previous.label, contentMode: 'rich', rebuilt: false };
        }

        const stagingDir = fs.mkdtempSync(
          path.join(os.tmpdir(), 'context-thread-rich-stage-')
        );
        const stagingDbPath = path.join(stagingDir, 'context-thread.db');
        let stagingContext: ContextThread | null = null;
        try {
          const stagingDb = DatabaseConnection.initialize(stagingDbPath, {
            contentMode: 'rich',
          });
          const stagingQueries = new QueryBuilder(stagingDb.getDb(), 'rich');
          stagingContext = new ContextThread(stagingDb, stagingQueries, this.projectRoot);

          const result = await stagingContext.runIndexAll(options);
          const complete = result.success &&
            !result.errors.some((error) => error.severity === 'error');
          if (!complete) {
            return {
              previousMode: previous.label,
              contentMode: 'structure',
              rebuilt: true,
              indexResult: result,
            };
          }

          // Closing checkpoints the staging WAL. Only after a complete build do
          // we replace the live graph, and that replacement is one transaction.
          stagingContext.close();
          stagingContext = null;
          this.db.replaceGraphFrom(stagingDbPath, 'rich');
          this.queries.setContentMode('rich');
          this.resolver.initialize();
          return {
            previousMode: previous.label,
            contentMode: 'rich',
            rebuilt: true,
            indexResult: result,
          };
        } finally {
          try { stagingContext?.close(); } catch { /* preserve the primary result/error */ }
          fs.rmSync(stagingDir, {
            recursive: true,
            force: true,
            maxRetries: 3,
            retryDelay: 50,
          });
        }
      } finally {
        this.fileLock.release();
      }
    });
  }

  // ===========================================================================
  // Indexing
  // ===========================================================================

  /**
   * Index all files in the project
   *
   * Uses a mutex to prevent concurrent indexing operations.
   */
  async indexAll(options: IndexOptions = {}): Promise<IndexResult> {
    this.assertWritable('index files');
    return this.indexMutex.withLock(async () => {
      try {
        this.fileLock.acquire();
      } catch {
        return { success: false, filesIndexed: 0, filesSkipped: 0, filesErrored: 0, nodesCreated: 0, edgesCreated: 0, errors: [{ message: 'Could not acquire file lock - another process may be indexing', severity: 'error' as const }], durationMs: 0 };
      }
      try {
        return await this.runIndexAll(options);
      } finally {
        this.fileLock.release();
      }
    });
  }

  private async runIndexAll(options: IndexOptions): Promise<IndexResult> {
    const result = await this.orchestrator.indexAll(
      options.onProgress,
      options.signal,
      options.verbose
    );

    // Resolve references to create call/import/extends edges. Reset caches first
    // because a full index can replace every node ID visible to the resolver.
    if (result.success && result.filesIndexed > 0) {
      this.resolver.initialize();
      const unresolvedCount = this.queries.getUnresolvedReferencesCount();

      options.onProgress?.({
        phase: 'resolving',
        current: 0,
        total: unresolvedCount,
      });

      await this.resolveReferencesBatched((current, total) => {
        options.onProgress?.({
          phase: 'resolving',
          current,
          total,
        });
      });
    }

    if (result.success && result.filesIndexed > 0) {
      this.db.runMaintenance();
    }

    return result;
  }

  /**
   * Index specific files
   *
   * Uses a mutex to prevent concurrent indexing operations.
   */
  async indexFiles(filePaths: string[]): Promise<IndexResult> {
    this.assertWritable('index specific files');
    return this.indexMutex.withLock(async () => {
      try {
        this.fileLock.acquire();
      } catch {
        return { success: false, filesIndexed: 0, filesSkipped: 0, filesErrored: 0, nodesCreated: 0, edgesCreated: 0, errors: [{ message: 'Could not acquire file lock - another process may be indexing', severity: 'error' as const }], durationMs: 0 };
      }
      try {
        return this.orchestrator.indexFiles(filePaths);
      } finally {
        this.fileLock.release();
      }
    });
  }

  /**
   * Sync with current file state (incremental update)
   *
   * Uses a mutex to prevent concurrent indexing operations.
   */
  async sync(options: IndexOptions = {}): Promise<SyncResult> {
    this.assertWritable('sync files');
    return this.indexMutex.withLock(async () => {
      try {
        this.fileLock.acquire();
      } catch {
        return { filesChecked: 0, filesAdded: 0, filesModified: 0, filesRemoved: 0, nodesUpdated: 0, durationMs: 0 };
      }
      try {
        const result = await this.orchestrator.sync(options.onProgress);

        // Resolve references if files were updated
        if (result.filesAdded > 0 || result.filesModified > 0) {
          // Re-indexing deletes and recreates nodes, so resolver caches can hold
          // stale node IDs from before this sync. Clear them before resolving
          // the new unresolved refs to avoid dangling edges.
          this.resolver.initialize();

          if (result.changedFilePaths) {
            // Scope resolution to changed files (git fast path — bounded set)
            const unresolvedRefs = this.queries.getUnresolvedReferencesByFiles(result.changedFilePaths);

            options.onProgress?.({
              phase: 'resolving',
              current: 0,
              total: unresolvedRefs.length,
            });

            this.resolver.resolveAndPersist(unresolvedRefs, (current, total) => {
              options.onProgress?.({
                phase: 'resolving',
                current,
                total,
              });
            });
          } else {
            // No git info — use batched resolution to avoid OOM
            const unresolvedCount = this.queries.getUnresolvedReferencesCount();

            options.onProgress?.({
              phase: 'resolving',
              current: 0,
              total: unresolvedCount,
            });

            await this.resolveReferencesBatched((current, total) => {
              options.onProgress?.({
                phase: 'resolving',
                current,
                total,
              });
            });
          }
        }

        // Refresh planner stats + checkpoint the WAL after bulk writes.
        if (result.filesAdded > 0 || result.filesModified > 0 || result.filesRemoved > 0) {
          this.db.runMaintenance();
        }

        return result;
      } finally {
        this.fileLock.release();
      }
    });
  }

  /**
   * Check if an indexing operation is currently in progress
   */
  isIndexing(): boolean {
    return this.indexMutex.isLocked();
  }

  // ===========================================================================
  // File Watching
  // ===========================================================================

  /**
   * Start watching for file changes and auto-syncing.
   *
   * Uses native OS file events (FSEvents on macOS, inotify on Linux 19+,
   * ReadDirectoryChangesW on Windows) with debouncing to avoid thrashing.
   *
   * @param options - Watch options (debounce delay, callbacks)
   * @returns true if watching started successfully
   */
  watch(options: WatchOptions = {}): boolean {
    this.assertWritable('watch files for automatic sync');
    if (this.watcher?.isActive()) return true;

    this.watcher = new FileWatcher(
      this.projectRoot,
      async () => {
        const result = await this.sync();
        const filesChanged = result.filesAdded + result.filesModified + result.filesRemoved;
        return { filesChanged, durationMs: result.durationMs };
      },
      options
    );

    return this.watcher.start();
  }

  /**
   * Stop watching for file changes.
   */
  unwatch(): void {
    if (this.watcher) {
      this.watcher.stop();
      this.watcher = null;
    }
  }

  /**
   * Check if the file watcher is active.
   */
  isWatching(): boolean {
    return this.watcher?.isActive() ?? false;
  }

  /**
   * Get files that have changed since last index
   */
  getChangedFiles(): { added: string[]; modified: string[]; removed: string[] } {
    return this.orchestrator.getChangedFiles();
  }

  /**
   * Extract nodes and edges from source code (without storing)
   */
  extractFromSource(filePath: string, source: string): ExtractionResult {
    return extractFromSource(filePath, source);
  }

  // ===========================================================================
  // Reference Resolution
  // ===========================================================================

  /**
   * Resolve unresolved references and create edges
   *
   * This method takes unresolved references from extraction and attempts
   * to resolve them using multiple strategies:
   * - Framework-specific patterns (React, Express, Laravel)
   * - Import-based resolution
   * - Name-based symbol matching
   */
  resolveReferences(onProgress?: (current: number, total: number) => void): ResolutionResult {
    this.assertWritable('resolve references');
    // Get all unresolved references from the database
    const unresolvedRefs = this.queries.getUnresolvedReferences();
    return this.resolver.resolveAndPersist(unresolvedRefs, onProgress);
  }

  /**
   * Resolve references in batches to keep memory bounded on large codebases.
   * Processes chunks of unresolved refs, persisting results after each batch.
   */
  async resolveReferencesBatched(onProgress?: (current: number, total: number) => void): Promise<ResolutionResult> {
    this.assertWritable('resolve references in batches');
    return this.resolver.resolveAndPersistBatched(onProgress);
  }

  /**
   * Get detected frameworks in the project
   */
  getDetectedFrameworks(): string[] {
    return this.resolver.getDetectedFrameworks();
  }

  /**
   * Re-initialize the resolver (useful after adding new files)
   */
  reinitializeResolver(): void {
    this.resolver.initialize();
  }

  // ===========================================================================
  // Graph Statistics
  // ===========================================================================

  /**
   * Get statistics about the knowledge graph
   */
  getStats(): GraphStats {
    const stats = this.queries.getStats();
    stats.dbSizeBytes = this.db.getSize();
    return stats;
  }

  /**
   * Active SQLite backend for this project's connection (`node-sqlite` — Node's
   * built-in real-SQLite module). Surfaced via `context-thread status` and the
   * `context_thread_status` MCP tool alongside the effective journal mode.
   */
  getBackend(): import('./db').SqliteBackend {
    return this.db.getBackend();
  }

  /**
   * The journal mode actually in effect ('wal', 'delete', …). 'wal' means
   * readers never block on a concurrent writer; anything else means they can,
   * which is the precondition for the "database is locked" failures in issue
   * #238. Surfaced via `context-thread status` and the `context_thread_status` MCP tool.
   */
  getJournalMode(): string {
    return this.db.getJournalMode();
  }

  // ===========================================================================
  // Node Operations
  // ===========================================================================

  /**
   * Get a node by ID
   */
  getNode(id: string): Node | null {
    return this.queries.getNodeById(id);
  }

  /**
   * Get all nodes in a file
   */
  getNodesInFile(filePath: string): Node[] {
    return this.queries.getNodesByFile(filePath);
  }

  /**
   * Get all nodes of a specific kind
   */
  getNodesByKind(kind: Node['kind']): Node[] {
    return this.queries.getNodesByKind(kind);
  }

  /**
   * Search nodes by text
   */
  searchNodes(query: string, options?: SearchOptions): SearchResult[] {
    return this.queries.searchNodes(query, options);
  }

  // ===========================================================================
  // Edge Operations
  // ===========================================================================

  /**
   * Get outgoing edges from a node
   */
  getOutgoingEdges(nodeId: string): Edge[] {
    return this.queries.getOutgoingEdges(nodeId);
  }

  /**
   * Get incoming edges to a node
   */
  getIncomingEdges(nodeId: string): Edge[] {
    return this.queries.getIncomingEdges(nodeId);
  }

  // ===========================================================================
  // File Operations
  // ===========================================================================

  /**
   * Get a file record by path
   */
  getFile(filePath: string): FileRecord | null {
    return this.queries.getFileByPath(filePath);
  }

  /**
   * Get all tracked files
   */
  getFiles(): FileRecord[] {
    return this.queries.getAllFiles();
  }

  // ===========================================================================
  // Graph Query Methods
  // ===========================================================================

  /**
   * Get the context for a node (ancestors, children, references)
   *
   * Returns comprehensive context about a node including its containment
   * hierarchy, children, incoming/outgoing references, type information,
   * and relevant imports.
   *
   * @param nodeId - ID of the focal node
   * @returns Context object with all related information
   */
  getContext(nodeId: string): Context {
    return this.graphManager.getContext(nodeId);
  }

  /**
   * Traverse the graph from a starting node
   *
   * Uses breadth-first search by default. Supports filtering by edge types,
   * node types, and traversal direction.
   *
   * @param startId - Starting node ID
   * @param options - Traversal options
   * @returns Subgraph containing traversed nodes and edges
   */
  traverse(startId: string, options?: TraversalOptions): Subgraph {
    return this.traverser.traverseBFS(startId, options);
  }

  /**
   * Get the call graph for a function
   *
   * Returns both callers (functions that call this function) and
   * callees (functions called by this function) up to the specified depth.
   *
   * @param nodeId - ID of the function/method node
   * @param depth - Maximum depth in each direction (default: 2)
   * @returns Subgraph containing the call graph
   */
  getCallGraph(nodeId: string, depth: number = 2): Subgraph {
    return this.traverser.getCallGraph(nodeId, depth);
  }

  /**
   * Get the type hierarchy for a class/interface
   *
   * Returns both ancestors (types this extends/implements) and
   * descendants (types that extend/implement this).
   *
   * @param nodeId - ID of the class/interface node
   * @returns Subgraph containing the type hierarchy
   */
  getTypeHierarchy(nodeId: string): Subgraph {
    return this.traverser.getTypeHierarchy(nodeId);
  }

  /**
   * Find all usages of a symbol
   *
   * Returns all nodes that reference the specified symbol through
   * any edge type (calls, references, type_of, etc.).
   *
   * @param nodeId - ID of the symbol node
   * @returns Array of nodes and edges that reference this symbol
   */
  findUsages(nodeId: string): Array<{ node: Node; edge: Edge }> {
    return this.traverser.findUsages(nodeId);
  }

  /**
   * Get callers of a function/method
   *
   * @param nodeId - ID of the function/method node
   * @param maxDepth - Maximum depth to traverse (default: 1)
   * @returns Array of nodes that call this function
   */
  getCallers(nodeId: string, maxDepth: number = 1): Array<{ node: Node; edge: Edge }> {
    return this.traverser.getCallers(nodeId, maxDepth);
  }

  /**
   * Get callees of a function/method
   *
   * @param nodeId - ID of the function/method node
   * @param maxDepth - Maximum depth to traverse (default: 1)
   * @returns Array of nodes called by this function
   */
  getCallees(nodeId: string, maxDepth: number = 1): Array<{ node: Node; edge: Edge }> {
    return this.traverser.getCallees(nodeId, maxDepth);
  }

  /**
   * Calculate the impact radius of a node
   *
   * Returns all nodes that could be affected by changes to this node.
   *
   * @param nodeId - ID of the node
   * @param maxDepth - Maximum depth to traverse (default: 3)
   * @returns Subgraph containing potentially impacted nodes
   */
  getImpactRadius(nodeId: string, maxDepth: number = 3): Subgraph {
    return this.traverser.getImpactRadius(nodeId, maxDepth);
  }

  /**
   * Find the shortest path between two nodes
   *
   * @param fromId - Starting node ID
   * @param toId - Target node ID
   * @param edgeKinds - Edge types to consider (all if empty)
   * @returns Array of nodes and edges forming the path, or null if no path exists
   */
  findPath(
    fromId: string,
    toId: string,
    edgeKinds?: Edge['kind'][]
  ): Array<{ node: Node; edge: Edge | null }> | null {
    return this.traverser.findPath(fromId, toId, edgeKinds);
  }

  /**
   * Get ancestors of a node in the containment hierarchy
   *
   * @param nodeId - ID of the node
   * @returns Array of ancestor nodes from immediate parent to root
   */
  getAncestors(nodeId: string): Node[] {
    return this.traverser.getAncestors(nodeId);
  }

  /**
   * Get immediate children of a node
   *
   * @param nodeId - ID of the node
   * @returns Array of child nodes
   */
  getChildren(nodeId: string): Node[] {
    return this.traverser.getChildren(nodeId);
  }

  /**
   * Get dependencies of a file
   *
   * @param filePath - Path to the file
   * @returns Array of file paths this file depends on
   */
  getFileDependencies(filePath: string): string[] {
    return this.graphManager.getFileDependencies(filePath);
  }

  /**
   * Get dependents of a file
   *
   * @param filePath - Path to the file
   * @returns Array of file paths that depend on this file
   */
  getFileDependents(filePath: string): string[] {
    return this.graphManager.getFileDependents(filePath);
  }

  /**
   * Find circular dependencies in the codebase
   *
   * @returns Array of cycles, each cycle is an array of file paths
   */
  findCircularDependencies(): string[][] {
    return this.graphManager.findCircularDependencies();
  }

  /**
   * Find dead code (unreferenced symbols)
   *
   * @param kinds - Node kinds to check (default: functions, methods, classes)
   * @returns Array of unreferenced nodes
   */
  findDeadCode(kinds?: Node['kind'][]): Node[] {
    return this.graphManager.findDeadCode(kinds);
  }

  /**
   * Get complexity metrics for a node
   *
   * @param nodeId - ID of the node
   * @returns Object containing various complexity metrics
   */
  getNodeMetrics(nodeId: string): {
    incomingEdgeCount: number;
    outgoingEdgeCount: number;
    callCount: number;
    callerCount: number;
    childCount: number;
    depth: number;
  } {
    return this.graphManager.getNodeMetrics(nodeId);
  }

  // ===========================================================================
  // Context Building
  // ===========================================================================

  /**
   * Get the source code for a node
   *
   * Reads the file and extracts the code between startLine and endLine.
   *
   * @param nodeId - ID of the node
   * @returns Code string or null if not found
   */
  async getCode(nodeId: string): Promise<string | null> {
    return this.contextBuilder.getCode(nodeId);
  }

  /**
   * Find relevant subgraph for a query
   *
   * Combines semantic search with graph traversal to find the most
   * relevant nodes and their relationships for a given query.
   *
   * @param query - Natural language query describing the task
   * @param options - Search and traversal options
   * @returns Subgraph of relevant nodes and edges
   */
  async findRelevantContext(
    query: string,
    options?: FindRelevantContextOptions
  ): Promise<Subgraph> {
    return this.contextBuilder.findRelevantContext(query, options);
  }

  /**
   * Build context for a task
   *
   * Creates comprehensive context by:
   * 1. Running FTS search to find entry points
   * 2. Expanding the graph around entry points
   * 3. Extracting code blocks for key nodes
   * 4. Formatting output for Claude
   *
   * @param input - Task description (string or {title, description})
   * @param options - Build options (maxNodes, includeCode, format, etc.)
   * @returns TaskContext object or formatted string (markdown/JSON)
   */
  async buildContext(
    input: TaskInput,
    options?: BuildContextOptions
  ): Promise<TaskContext | string> {
    return this.contextBuilder.buildContext(input, options);
  }

  // ===========================================================================
  // Database Management
  // ===========================================================================

  /**
   * Optimize the database (vacuum and analyze)
   */
  optimize(): void {
    this.assertWritable('optimize the database');
    this.db.optimize();
  }

  /**
   * Clear all data from the graph
   */
  clear(): void {
    this.assertWritable('clear the graph');
    this.queries.clear();
  }

  /**
   * Alias for close() for backwards compatibility.
   * @deprecated Use close() instead
   */
  destroy(): void {
    this.close();
  }

  /**
   * Completely remove ContextThread from the project.
   * This closes the database and deletes the .ContextThread directory.
   *
   * WARNING: This permanently deletes all ContextThread data for the project.
   */
  uninitialize(): void {
    this.assertWritable('uninitialize the project');
    this.close();
    removeDirectory(this.projectRoot);
  }
}

// Default export
export default ContextThread;
