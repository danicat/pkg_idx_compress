/* pkg_index_compress.sql
 * Copyright (C) 2016 Daniela Petruzalek
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
  pkg_idx_compress: Index compression helper
  
  Description: This packages helps automating the process of index prefix 
  compression in Oracle 9i and above.

  Installation:
  1. Create the global temporary table GTT_INDEX_STATS as specified below.
  2. Compile package header
  3. Compile package specification

  Usage:
  1. Run the procedure pkg_idx_compress.idx_compress_analyze to calculate the
  optimal compression ratio and prefix count for every index in the specified
  schema. Example:
  
    exec pkg_idx_compress.idx_compress_analyze(pOwner => 'HR');
    
  2. [optional] Query the GTT_INDEX_STATS table to check the analysis results:
  - The column opt_cmpr_count indicates the number of prefix columns that will 
    be compressed.
  - The column opt_cmpr_pctsave indicates the expected percent savings in 
    storage that will be achieved with the recommended prefix compression.
    
  3. Run the idx_compress_execute procedure to perform the compression with the
  recommended prefix count. You can optionally inform a minimal percent saving
  that will trigger the compression with the parameter pPctSave (defaults to
  10 percent). Also, you can optionally ask Oracle to perform the index rebuild 
  online specifying pOnline = true. Example:
  
    -- Compress all indexes with expected savings equal or above 15 percent
    -- and perform the rebuild online
    exec pkg_idx_compress.idx_compress_execute(pPctSave => 15, pOnline => true);
    
  Notes:
  - In order to rebuild indexes, you need appropriate priviledges on the target
  indexes or the ALTER ANY INDEX priviledge.
 */

-- Temporary table to hold ANALYZE INDEX results
CREATE GLOBAL TEMPORARY TABLE GTT_INDEX_STATS(
  OWNER            VARCHAR2(30),
  NAME             VARCHAR2(30),
  OPT_CMPR_COUNT   NUMBER(1),
  OPT_CMPR_PCTSAVE NUMBER(2)
) ON COMMIT PRESERVE ROWS;

-- Package header
CREATE OR REPLACE PACKAGE pkg_idx_compress 
AUTHID CURRENT_USER
AS

  -- This procedure analyzes all indexes from the specified owner.
  -- Defaults to the current user.
  PROCEDURE idx_compress_analyze(pOwner IN VARCHAR2 DEFAULT USER);
  
  -- This procedure compresses all indexes analyzed previously that have
  -- an expected compression rate equal or better than pPctSave (default=10)
  PROCEDURE idx_compress_execute(pPctSave IN NUMBER  DEFAULT 10, 
                                 pOnline  IN BOOLEAN DEFAULT FALSE);

END pkg_idx_compress;
/

-- Package body
CREATE OR REPLACE PACKAGE BODY pkg_idx_compress AS

  PROCEDURE idx_compress_analyze(pOwner IN VARCHAR2 DEFAULT USER) AS
  BEGIN
    FOR r IN (SELECT owner,
                     index_name
                FROM all_indexes
               WHERE owner = pOwner)
    loop
      EXECUTE IMMEDIATE 'ANALYZE INDEX ' || r.owner || '.' || r.index_name 
                     || ' VALIDATE STRUCTURE';
      
      -- Temporary table to hold all index analysis
      INSERT INTO GTT_INDEX_STATS
      SELECT pOwner, 
             NAME, 
             OPT_CMPR_COUNT, 
             OPT_CMPR_PCTSAVE 
        FROM INDEX_STATS;
      
    END LOOP;
   
  END idx_compress_analyze;
  
  PROCEDURE idx_compress_execute(pPctSave IN NUMBER  DEFAULT 10,
                                 pOnline  IN BOOLEAN DEFAULT FALSE) AS
  BEGIN
    FOR r IN (SELECT OWNER, 
                     NAME, 
                     OPT_CMPR_COUNT, 
                     OPT_CMPR_PCTSAVE
                FROM GTT_INDEX_STATS
               WHERE OPT_CMPR_PCTSAVE >= pPctSave)
    LOOP
      BEGIN
        EXECUTE IMMEDIATE 'ALTER INDEX ' || r.owner || '.' || r.NAME 
                       || ' REBUILD COMPRESS ' || r.opt_cmpr_count
                       || CASE WHEN pOnline THEN ' ONLINE' ELSE '' END;
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Failure compressing index ' || r.owner || '.'
                             || r.name || ': SQLCODE - ' || SQLCODE || CHR(10)
                             || DBMS_UTILITY.FORMAT_ERROR_STACK);
      END;
    END LOOP;
   
  END idx_compress_execute;

END pkg_idx_compress;
/
