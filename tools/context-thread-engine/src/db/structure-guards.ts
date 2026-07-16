import { SqliteDatabase } from './sqlite-adapter';

const STRUCTURE_CONTENT_GUARDS_SQL = `
  CREATE TRIGGER IF NOT EXISTS structure_guard_nodes_insert
  BEFORE INSERT ON nodes
  WHEN EXISTS (
    SELECT 1 FROM project_metadata
    WHERE key = 'content_mode_v1' AND value = 'structure'
  )
  AND (
    NEW.docstring IS NOT NULL OR NEW.signature IS NOT NULL OR
    NEW.decorators IS NOT NULL OR NEW.type_parameters IS NOT NULL
  )
  BEGIN
    INSERT OR REPLACE INTO nodes (
      id, kind, name, qualified_name, file_path, language,
      start_line, end_line, start_column, end_column,
      docstring, signature, visibility,
      is_exported, is_async, is_static, is_abstract,
      decorators, type_parameters, updated_at
    ) VALUES (
      NEW.id, NEW.kind, NEW.name, NEW.qualified_name, NEW.file_path, NEW.language,
      NEW.start_line, NEW.end_line, NEW.start_column, NEW.end_column,
      NULL, NULL, NEW.visibility,
      NEW.is_exported, NEW.is_async, NEW.is_static, NEW.is_abstract,
      NULL, NULL, NEW.updated_at
    );
    SELECT RAISE(IGNORE);
  END;

  CREATE TRIGGER IF NOT EXISTS structure_guard_nodes_update
  BEFORE UPDATE OF docstring, signature, decorators, type_parameters ON nodes
  WHEN EXISTS (
    SELECT 1 FROM project_metadata
    WHERE key = 'content_mode_v1' AND value = 'structure'
  )
  AND (
    NEW.docstring IS NOT NULL OR NEW.signature IS NOT NULL OR
    NEW.decorators IS NOT NULL OR NEW.type_parameters IS NOT NULL
  )
  BEGIN
    UPDATE nodes SET
      kind = NEW.kind,
      name = NEW.name,
      qualified_name = NEW.qualified_name,
      file_path = NEW.file_path,
      language = NEW.language,
      start_line = NEW.start_line,
      end_line = NEW.end_line,
      start_column = NEW.start_column,
      end_column = NEW.end_column,
      docstring = NULL,
      signature = NULL,
      visibility = NEW.visibility,
      is_exported = NEW.is_exported,
      is_async = NEW.is_async,
      is_static = NEW.is_static,
      is_abstract = NEW.is_abstract,
      decorators = NULL,
      type_parameters = NULL,
      updated_at = NEW.updated_at
    WHERE id = OLD.id;
    SELECT RAISE(IGNORE);
  END;

  CREATE TRIGGER IF NOT EXISTS structure_guard_edges_insert
  BEFORE INSERT ON edges
  WHEN EXISTS (
    SELECT 1 FROM project_metadata
    WHERE key = 'content_mode_v1' AND value = 'structure'
  )
  AND NEW.metadata IS NOT NULL
  BEGIN
    INSERT OR IGNORE INTO edges (id, source, target, kind, metadata, line, col, provenance)
    VALUES (
      CASE WHEN NEW.id IS NULL OR NEW.id < 0 THEN NULL ELSE NEW.id END,
      NEW.source, NEW.target, NEW.kind, NULL, NEW.line, NEW.col, NEW.provenance
    );
    SELECT RAISE(IGNORE);
  END;

  CREATE TRIGGER IF NOT EXISTS structure_guard_edges_update
  BEFORE UPDATE OF metadata ON edges
  WHEN EXISTS (
    SELECT 1 FROM project_metadata
    WHERE key = 'content_mode_v1' AND value = 'structure'
  )
  AND NEW.metadata IS NOT NULL
  BEGIN
    UPDATE edges SET
      source = NEW.source,
      target = NEW.target,
      kind = NEW.kind,
      metadata = NULL,
      line = NEW.line,
      col = NEW.col,
      provenance = NEW.provenance
    WHERE id = OLD.id;
    SELECT RAISE(IGNORE);
  END;

  CREATE TRIGGER IF NOT EXISTS structure_guard_refs_insert
  BEFORE INSERT ON unresolved_refs
  WHEN EXISTS (
    SELECT 1 FROM project_metadata
    WHERE key = 'content_mode_v1' AND value = 'structure'
  )
  AND NEW.candidates IS NOT NULL
  BEGIN
    INSERT INTO unresolved_refs (
      id, from_node_id, reference_name, reference_kind,
      line, col, candidates, file_path, language
    ) VALUES (
      CASE WHEN NEW.id IS NULL OR NEW.id < 0 THEN NULL ELSE NEW.id END,
      NEW.from_node_id, NEW.reference_name, NEW.reference_kind,
      NEW.line, NEW.col, NULL, NEW.file_path, NEW.language
    );
    SELECT RAISE(IGNORE);
  END;

  CREATE TRIGGER IF NOT EXISTS structure_guard_refs_update
  BEFORE UPDATE OF candidates ON unresolved_refs
  WHEN EXISTS (
    SELECT 1 FROM project_metadata
    WHERE key = 'content_mode_v1' AND value = 'structure'
  )
  AND NEW.candidates IS NOT NULL
  BEGIN
    UPDATE unresolved_refs SET
      from_node_id = NEW.from_node_id,
      reference_name = NEW.reference_name,
      reference_kind = NEW.reference_kind,
      line = NEW.line,
      col = NEW.col,
      candidates = NULL,
      file_path = NEW.file_path,
      language = NEW.language
    WHERE id = OLD.id;
    SELECT RAISE(IGNORE);
  END;
`;

/** Install persistent structure-mode guards for legacy or unaware writers. */
export function installStructureContentGuards(db: SqliteDatabase): void {
  db.exec(STRUCTURE_CONTENT_GUARDS_SQL);
}
