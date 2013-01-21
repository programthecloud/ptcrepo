
-- Here's the core SQL
CREATE VIEW mapped AS
  SELECT node, pagerank, adjacencyList
    FROM graph
  UNION ALL
  SELECT unnest(adjacencyList) AS node, 
         pagerank/array_upper(adjacencyList,1) AS pagerank, 
         NULL AS adjacencyList
    FROM graph
  UNION ALL
  SELECT -1, pagerank, NULL
    FROM graph
   WHERE adjacencyList IS NULL;

DROP TABLE IF EXISTS reduced;
CREATE TABLE reduced
AS (SELECT node, 
          SUM(CASE WHEN adjacencyList IS NULL THEN pagerank END) AS pagerank, 
          first(adjacencyList) AS adjacencyList
     FROM mapped
    WHERE node >= 0
  GROUP BY node);
  
UPDATE reduced 
   SET pagerank = reduced.pagerank + m.pagerank
  FROM mapped m
  WHERE m.node = -1;
    
DROP TABLE graph CASCADE;
ALTER TABLE reduced RENAME TO graph;