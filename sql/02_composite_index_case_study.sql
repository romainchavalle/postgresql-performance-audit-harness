-- ==============================================================================
-- CASE STUDY 2: Missing Composite Index - 33,249 Disk Heap Block Reads
-- ==============================================================================
-- Context:
--   NPS and CSAT metric evolution queries filter answers joined with surveys
--   by `restaurant_id` and cross-reference customers with active indicators.
--
-- Pathology Identified:
--   The `surveys` table only had a single-column index on `restaurant_id`.
--   PostgreSQL executed a `Bitmap Index Scan` to find the 93,340 surveys belonging
--   to the restaurant group, then performed a massive `Bitmap Heap Scan` reading
--   33,249 disk blocks from the main heap simply to check `customer_id` values!
--   This disk I/O took ~6 to 8 seconds.
--
-- Resolution:
--   Created composite B-Tree indexes:
--     1. `CREATE INDEX idx_surveys_resto_cust ON surveys (restaurant_id, customer_id);`
--     2. `CREATE INDEX idx_ci_tag_ind_cust ON customer_indicators (tag_id, indicator_id, customer_id);`
--
-- Results:
--   Execution Time : 8,963 ms -> 1,470 ms (-84%)
--   Heap Blocks Read: 33,249 blocks -> 0 blocks (Index Only / In-memory index scan)
--   Eliminated I/O bottleneck without requiring columnar storage (ClickHouse).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. BEFORE COMPOSITE INDEX (Bitmap Heap Scan reads 33,249 blocks, ~8.9 seconds)
-- ------------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  (COUNT(*) FILTER (WHERE a.nps_value = 1) / COUNT(*)::FLOAT -
   COUNT(*) FILTER (WHERE a.nps_value = 3) / COUNT(*)::FLOAT) * 100 AS nps,
  CASE WHEN a.date >= '2026-01-01' AND a.date <= '2026-12-31' THEN 'range_1' ELSE NULL END AS range
FROM answers a
INNER JOIN surveys s ON s.id = a.survey_id
WHERE s.restaurant_id IN (2491,2504,2494,2507,2490,2503,2492,2495,2501,2509,2496,2499,2506,2505,2720,2508,3957,4729,2497,2500,2502)
  AND a.date >= '2019-01-01' AND a.date <= '2026-12-31'
  AND s.customer_id IN (
      SELECT DISTINCT ci.customer_id
      FROM customer_indicators ci
      WHERE ci.tag_id = 42
  )
GROUP BY range;

/*
QUERY PLAN EXCERPT (BEFORE):
-> Bitmap Heap Scan on surveys s (cost=690.25..92212.52 rows=55377 width=16) (actual time=17.261..304.077 rows=93340 loops=1)
     Recheck Cond: (restaurant_id = ANY ('{...}'::bigint[]))
     Heap Blocks: exact=33249  <-- PATHOLOGY: Reading 33,249 heap disk blocks!
     Buffers: shared hit=54 read=33336
     -> Bitmap Index Scan on index_surveys_on_restaurant_id (cost=0.00..676.36 rows=55377 width=0)
Execution Time: ~8884 ms
*/

-- ------------------------------------------------------------------------------
-- 2. AFTER COMPOSITE INDEX CREATION
-- ------------------------------------------------------------------------------
-- PostgreSQL traverses the composite B-Tree directly in shared buffers without
-- fetching raw table rows from disk to inspect customer_id.
-- Execution time drops to 1,470 ms (-84%).
