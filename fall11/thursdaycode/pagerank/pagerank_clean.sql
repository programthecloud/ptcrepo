-- CLEAN UP
DROP TABLE IF EXISTS input_graph;
DROP TABLE IF EXISTS graph;
DROP AGGREGATE public.first(anyelement);
DROP FUNCTION public.first_agg ( anyelement, anyelement ) CASCADE;
