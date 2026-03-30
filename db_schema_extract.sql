-- ============================================================
-- DATABASE DOCUMENTATION EXTRACTOR
-- Run each section separately in SSMS
-- ============================================================


-- ============================================================
-- QUERY 1: ALL TABLES & SCHEMAS (Overview)
-- ============================================================
SELECT 
    s.name                          AS [Schema],
    t.name                          AS [Table Name],
    t.create_date                   AS [Created Date],
    t.modify_date                   AS [Last Modified],
    p.rows                          AS [Row Count],
    CAST(
        (SUM(a.total_pages) * 8) / 1024.0 
    AS DECIMAL(10,2))               AS [Size (MB)],
    ISNULL(ep.value, '')            AS [Description]
FROM 
    sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.indexes i ON t.object_id = i.object_id AND i.index_id IN (0,1)
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    LEFT JOIN sys.extended_properties ep 
        ON ep.major_id = t.object_id 
        AND ep.minor_id = 0 
        AND ep.name = 'MS_Description'
GROUP BY 
    s.name, t.name, t.create_date, t.modify_date, p.rows, ep.value
ORDER BY 
    s.name, t.name;


-- ============================================================
-- QUERY 2: ALL COLUMNS (Detailed)
-- ============================================================
SELECT 
    s.name                          AS [Schema],
    t.name                          AS [Table Name],
    c.column_id                     AS [Column Order],
    c.name                          AS [Column Name],
    tp.name                         AS [Data Type],
    CASE 
        WHEN tp.name IN ('varchar','nvarchar','char','nchar') 
            THEN CAST(c.max_length AS VARCHAR) + ' chars'
        WHEN tp.name IN ('decimal','numeric') 
            THEN CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR)
        ELSE ''
    END                             AS [Length / Precision],
    CASE c.is_nullable 
        WHEN 1 THEN 'YES' ELSE 'NO' 
    END                             AS [Nullable],
    ISNULL(d.definition, '')        AS [Default Value],
    CASE WHEN ic.column_id IS NOT NULL 
        THEN 'YES' ELSE 'NO' 
    END                             AS [Is Identity],
    ISNULL(ep.value, '')            AS [Description]
FROM 
    sys.columns c
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.types tp ON c.user_type_id = tp.user_type_id
    LEFT JOIN sys.default_constraints d ON c.default_object_id = d.object_id
    LEFT JOIN sys.identity_columns ic ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    LEFT JOIN sys.extended_properties ep 
        ON ep.major_id = c.object_id 
        AND ep.minor_id = c.column_id 
        AND ep.name = 'MS_Description'
ORDER BY 
    s.name, t.name, c.column_id;


-- ============================================================
-- QUERY 3: PRIMARY KEYS
-- ============================================================
SELECT 
    s.name                          AS [Schema],
    t.name                          AS [Table Name],
    kc.name                         AS [PK Name],
    c.name                          AS [PK Column],
    ic.key_ordinal                  AS [Key Order]
FROM 
    sys.key_constraints kc
    INNER JOIN sys.tables t ON kc.parent_object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE 
    kc.type = 'PK'
ORDER BY 
    s.name, t.name, ic.key_ordinal;


-- ============================================================
-- QUERY 4: FOREIGN KEYS (Relationships)
-- ============================================================
SELECT 
    s1.name                         AS [Parent Schema],
    tp.name                         AS [Parent Table],
    cp.name                         AS [Parent Column],
    s2.name                         AS [Referenced Schema],
    tr.name                         AS [Referenced Table],
    cr.name                         AS [Referenced Column],
    fk.name                         AS [FK Constraint Name],
    CASE fk.delete_referential_action
        WHEN 0 THEN 'NO ACTION'
        WHEN 1 THEN 'CASCADE'
        WHEN 2 THEN 'SET NULL'
        WHEN 3 THEN 'SET DEFAULT'
    END                             AS [On Delete],
    CASE fk.update_referential_action
        WHEN 0 THEN 'NO ACTION'
        WHEN 1 THEN 'CASCADE'
        WHEN 2 THEN 'SET NULL'
        WHEN 3 THEN 'SET DEFAULT'
    END                             AS [On Update]
FROM 
    sys.foreign_keys fk
    INNER JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
    INNER JOIN sys.schemas s1 ON tp.schema_id = s1.schema_id
    INNER JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id
    INNER JOIN sys.schemas s2 ON tr.schema_id = s2.schema_id
    INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
    INNER JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
    INNER JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id
ORDER BY 
    s1.name, tp.name;


-- ============================================================
-- QUERY 5: INDEXES
-- ============================================================
SELECT 
    s.name                          AS [Schema],
    t.name                          AS [Table Name],
    i.name                          AS [Index Name],
    CASE i.type
        WHEN 1 THEN 'Clustered'
        WHEN 2 THEN 'Non-Clustered'
        WHEN 3 THEN 'XML'
        WHEN 4 THEN 'Spatial'
        ELSE 'Other'
    END                             AS [Index Type],
    CASE i.is_unique WHEN 1 THEN 'YES' ELSE 'NO' END AS [Is Unique],
    STRING_AGG(c.name, ', ') 
        WITHIN GROUP (ORDER BY ic.key_ordinal) AS [Indexed Columns]
FROM 
    sys.indexes i
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE 
    i.name IS NOT NULL
    AND ic.is_included_column = 0
GROUP BY 
    s.name, t.name, i.name, i.type, i.is_unique
ORDER BY 
    s.name, t.name, i.name;


-- ============================================================
-- QUERY 6: VIEWS
-- ============================================================
SELECT 
    s.name                          AS [Schema],
    v.name                          AS [View Name],
    v.create_date                   AS [Created Date],
    v.modify_date                   AS [Last Modified],
    m.definition                    AS [View Definition],
    ISNULL(ep.value, '')            AS [Description]
FROM 
    sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    INNER JOIN sys.sql_modules m ON v.object_id = m.object_id
    LEFT JOIN sys.extended_properties ep 
        ON ep.major_id = v.object_id 
        AND ep.minor_id = 0 
        AND ep.name = 'MS_Description'
ORDER BY 
    s.name, v.name;


-- ============================================================
-- QUERY 7: STORED PROCEDURES
-- ============================================================
SELECT 
    s.name                          AS [Schema],
    p.name                          AS [Procedure Name],
    p.create_date                   AS [Created Date],
    p.modify_date                   AS [Last Modified],
    ISNULL(ep.value, '')            AS [Description]
FROM 
    sys.procedures p
    INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
    LEFT JOIN sys.extended_properties ep 
        ON ep.major_id = p.object_id 
        AND ep.minor_id = 0 
        AND ep.name = 'MS_Description'
ORDER BY 
    s.name, p.name;


-- ============================================================
-- QUERY 8: ADD DESCRIPTIONS (Extended Properties)
-- Use these templates to document tables and columns inline
-- Replace placeholders with actual names and descriptions
-- ============================================================

-- Add description to a TABLE:
-- EXEC sp_addextendedproperty 
--     @name = N'MS_Description',
--     @value = N'Your table description here',
--     @level0type = N'SCHEMA', @level0name = N'dbo',
--     @level1type = N'TABLE',  @level1name = N'YourTableName';

-- Update existing description on a TABLE:
-- EXEC sp_updateextendedproperty 
--     @name = N'MS_Description',
--     @value = N'Updated description here',
--     @level0type = N'SCHEMA', @level0name = N'dbo',
--     @level1type = N'TABLE',  @level1name = N'YourTableName';

-- Add description to a COLUMN:
-- EXEC sp_addextendedproperty 
--     @name = N'MS_Description',
--     @value = N'Your column description here',
--     @level0type = N'SCHEMA', @level0name = N'dbo',
--     @level1type = N'TABLE',  @level1name = N'YourTableName',
--     @level2type = N'COLUMN', @level2name = N'YourColumnName';

