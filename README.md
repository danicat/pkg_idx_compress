# pkg_idx_compress

PL/SQL package to automate the index compression process on Oracle 9i and above.

# Description

This package helps automating the process of index prefix compression on Oracle database. This type of compression is available on all Oracle editions (standard one, standard 2, standard and enterprise) and it's not an extra-cost option. This should not be mistaken with the Advanced Index Compression that is part of the Advanced Compression (that **is** an *extra-cost option*).

The index prefix compression works by reducing the key repetitions within the index leaf blocks. This package has two procedures: one to calculate the optimal prefix count to compress (idx_compress_analyze) and other to actually perform the compression (idx_compress_execute).

# Requirements

This package works with all Oracle versions above 9i and all editions.

# Installation

1. Create the global temporary table GTT_INDEX_STATS as specified in the supplied script.
2. Compile package header
3. Compile package body

# Usage

1. Run the procedure pkg_idx_compress.idx_compress_analyze to calculate the optimal compression ratio and prefix count for every index in the specified schema. Example:

	-- Analyse optimal prefix count and expected compression percent for all indexes in the HR schema
	exec pkg_idx_compress.idx_compress_analyze(pOwner => 'HR');

2. [optional] Query the GTT_INDEX_STATS table to check the analysis results:
- The column opt_cmpr_count indicates the number of prefix columns that will be compressed.
- The column opt_cmpr_pctsave indicates the expected percent savings in storage that will be achieved with the recommended prefix compression.

3. Run the idx_compress_execute procedure to perform the compression with the recommended prefix count. You can optionally inform a minimal percent saving that will trigger the compression with the parameter pPctSave (defaults to 10 percent). Also, you can optionally ask Oracle to perform the index rebuild online specifying pOnline = true. Example:

	-- Compress all indexes with expected savings equal or above 15 percent
	-- and perform the rebuild online
	exec pkg_idx_compress.idx_compress_execute(pPctSave => 15, pOnline => true);

# Notes

In order to rebuild indexes, you need appropriate priviledges on the target indexes or the ALTER ANY INDEX priviledge.

# Licensing

This project is open source released on the AGPLv3 license.

# Bugs

In case you find any bug, please use the Github's issue tracker to report.

# Contact Info

For any questions, contact the author at <daniela.petruzalek@gmail.com>.