# PostgreSQL row-level security

- **RETURNING is checked against SELECT policies** When an INSERT or UPDATE has a `RETURNING` clause, every row it inserts or updates must satisfy the table's SELECT policies, or the statement errors. Such rows are never silently dropped. A function that inserts a row and returns its id therefore needs a SELECT policy that already admits the new row.
  source: https://www.postgresql.org/docs/15/sql-createpolicy.html (read 2026-10-26) · unconfirmed — proposed by prep removed-member-access, 2026-10-26
- **UPDATE policies and the old row** An UPDATE's `USING` picks which existing rows it may touch. `WITH CHECK` is evaluated only against the proposed new contents, never the original. An UPDATE that reads columns (WHERE, RETURNING, the right side of SET) also applies the SELECT policies to the existing and the new row. A policy alone therefore cannot allow one column to change on a row and forbid another: column grants are per column, not per row.
  source: https://www.postgresql.org/docs/15/sql-createpolicy.html (read 2026-10-26) · unconfirmed — proposed by prep removed-member-access, 2026-10-26
