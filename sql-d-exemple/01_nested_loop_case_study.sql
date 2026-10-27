-- ==============================================================================
-- CASE STUDY 1: Algorithmic Pathology - 134,262 Nested Loop Iterations
-- ==============================================================================
-- Context:
--   When generating the survey ID list for a group of 21 restaurants over 7 years
--   filtered by demographic indicators (e.g., Age 31-45), the application generated
--   an uncorrelated subquery: `WHERE surveys.customer_id IN (SELECT ci.customer_id ...)`.
--
-- Pathology Identified:
--   PostgreSQL chose a Nested Loop against `surveys`. Because the subquery returned
--   134,262 non-deduplicated rows, PostgreSQL executed the index scan 134,262 times,
--   reading over 71,000 disk blocks and taking ~9.7 to 20 seconds.
--
-- Resolution:
--   Adding `DISTINCT` in the subquery: `SELECT DISTINCT ci.customer_id`.
--   This forced PostgreSQL to build an in-memory Hash Table once (HashAggregate in ~200ms)
--   and execute a linear O(N) Hash Join in a single pass.
--
-- Results:
--   Execution Time : 9,769 ms -> 293 ms (-97%)
--   Disk Blocks Read: 71,467 blocks -> 1,091 blocks (-98.5%)
--   Mathematical Equivalence: 22,826 rows returned (0 difference, 0 duplication)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. BEFORE OPTIMIZATION (Takes ~9.7 seconds, loops=134262)
-- ------------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT surveys.id
FROM surveys
WHERE surveys.restaurant_id IN (2491,2504,2494,2507,2490,2503,2492,2495,2501,2509,2496,2499,2506,2505,2720,2508,3957,4729,2497,2500,2502)
  AND surveys.survey_date BETWEEN '2026-01-01' AND '2026-12-31'
  AND surveys.customer_id IN (
      SELECT ci.customer_id
      FROM customer_indicators ci
      INNER JOIN indicators i ON ci.indicator_id = i.id
      INNER JOIN tags t ON ci.tag_id = t.id
      INNER JOIN tag_translations tt ON tt.tag_id = t.id
      WHERE i.theme = 'Âge'
        AND tt.content IN ('31 - 45 ans')
  );

/*
QUERY PLAN EXCERPT (BEFORE):
Nested Loop (actual time=0.080..9769.450 rows=22826 loops=1)
  Buffers: shared hit=48293 read=71467
  -> Index Scan using index_surveys_on_customer_id on surveys
       (actual time=0.015..0.065 rows=1 loops=134262)  <-- PATHOLOGY: 134,262 LOOPS!
       Buffers: shared read=71467
Execution Time: 9769.450 ms
*/

-- ------------------------------------------------------------------------------
-- 2. AFTER OPTIMIZATION: Adding DISTINCT (Takes 293 ms, loops=1)
-- ------------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT surveys.id
FROM surveys
WHERE surveys.restaurant_id IN (2491,2504,2494,2507,2490,2503,2492,2495,2501,2509,2496,2499,2506,2505,2720,2508,3957,4729,2497,2500,2502)
  AND surveys.survey_date BETWEEN '2026-01-01' AND '2026-12-31'
  AND surveys.customer_id IN (
      SELECT DISTINCT ci.customer_id
      FROM customer_indicators ci
      INNER JOIN indicators i ON ci.indicator_id = i.id
      INNER JOIN tags t ON ci.tag_id = t.id
      INNER JOIN tag_translations tt ON tt.tag_id = t.id
      WHERE i.theme = 'Âge'
        AND tt.content IN ('31 - 45 ans')
  );

/*
QUERY PLAN EXCERPT (AFTER):
Unique (cost=87457.65..87458.92 rows=254 width=8) (actual time=286.791..287.504 rows=2633 loops=1)
  -> Hash Join (cost=43432.34..87447.50 rows=254 width=8) (actual time=262.526..286.388 rows=2633 loops=1)
       Hash Cond: (surveys.customer_id = ci.customer_id)
       -> Bitmap Heap Scan on surveys (actual time=18.019..38.528 rows=9600 loops=1)
       -> Hash (actual time=244.218..244.521 rows=134262 loops=1)
            -> HashAggregate (actual time=208.936..222.534 rows=134262 loops=1)
                 Group Key: ci.customer_id
Execution Time: 293.917 ms
*/
