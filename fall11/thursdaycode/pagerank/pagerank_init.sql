-- INITIALIZE
CREATE TABLE input_graph(node integer, adjacent integer);
\COPY input_graph FROM './graph.csv' WITH CSV
CREATE TABLE graph  AS
SELECT node, 1.0 AS pagerank, array_agg(distinct adjacent) as adjacencyList 
  FROM input_graph
GROUP BY node;

-- http://archives.postgresql.org/pgsql-hackers/2006-03/msg01324.php
-- Create a function that always returns the first non-NULL item
CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
RETURNS anyelement AS $$
        SELECT CASE WHEN $1 IS NULL THEN $2 ELSE $1 END;
$$ LANGUAGE SQL STABLE;

-- And then wrap an aggreagate around it
CREATE AGGREGATE public.first (
        sfunc    = public.first_agg,
        basetype = anyelement,
        stype    = anyelement
);
