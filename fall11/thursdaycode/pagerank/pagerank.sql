
-- Here's the core SQL
CREATE VIEW mapped AS
  SELECT node, pagerank, adjacencyList
    FROM graph
  UNION ALL
  SELECT unnest(adjacencyList) AS node, 
         pagerank/array_upper(adjacencyList,1) AS pagerank, 
         NULL AS adjacencyList
    FROM graph;

CREATE TABLE reduced
AS SELECT node, 
          SUM(CASE WHEN adjacencyList IS NULL THEN pagerank END) AS pagerank, 
          first(adjacencyList) AS adjacencyList
     FROM mapped
    GROUP BY node;

DROP VIEW mapped;
DROP TABLE graph;
ALTER TABLE reduced RENAME TO graph;