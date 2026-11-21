/* =====================================================================
   Maven Fuzzy Factory - Week 2 (AnalystLab Africa Experience Lab)
   Track 1: Data Analytics. SQL Server.

   Raw tables (imported as text, never changed):
     website_sessions, website_pageviews, Orders_mav,
     order_items, order_item_refunds, products
   Clean tables built below:
     sessions_clean, orders_clean, order_items_clean,
     refunds_clean, products_clean
   ===================================================================== */

CREATE DATABASE MavenFuzzyFactory;
GO
USE MavenFuzzyFactory;


/* =====================================================================
   PART 1. DATA INSPECTION
   ===================================================================== */

-- 1.1 First column names (a hidden marker can be stuck on them)
SELECT 'website_sessions' AS tbl, name FROM sys.columns WHERE object_id = OBJECT_ID('website_sessions') AND column_id = 1
UNION ALL SELECT 'Orders_mav',         name FROM sys.columns WHERE object_id = OBJECT_ID('Orders_mav')         AND column_id = 1
UNION ALL SELECT 'order_items',        name FROM sys.columns WHERE object_id = OBJECT_ID('order_items')        AND column_id = 1
UNION ALL SELECT 'order_item_refunds', name FROM sys.columns WHERE object_id = OBJECT_ID('order_item_refunds') AND column_id = 1
UNION ALL SELECT 'products',           name FROM sys.columns WHERE object_id = OBJECT_ID('products')           AND column_id = 1
UNION ALL SELECT 'website_pageviews',  name FROM sys.columns WHERE object_id = OBJECT_ID('website_pageviews')  AND column_id = 1;

-- 1.2 Are the ID columns unique? total_rows must equal unique_ids
SELECT 'website_sessions' AS tbl, COUNT(*) AS total_rows, COUNT(DISTINCT website_session_id) AS unique_ids FROM website_sessions
UNION ALL SELECT 'Orders_mav',         COUNT(*), COUNT(DISTINCT order_id)              FROM Orders_mav
UNION ALL SELECT 'order_items',        COUNT(*), COUNT(DISTINCT order_item_id)         FROM order_items
UNION ALL SELECT 'order_item_refunds', COUNT(*), COUNT(DISTINCT order_item_refund_id)  FROM order_item_refunds
UNION ALL SELECT 'products',           COUNT(*), COUNT(DISTINCT product_id)            FROM products
UNION ALL SELECT 'website_pageviews',  COUNT(*), COUNT(DISTINCT website_pageview_id)   FROM website_pageviews;

-- 1.3 Orphan checks (foreign keys). Expect 0 each.
SELECT COUNT(*) AS orders_without_session
FROM Orders_mav o WHERE NOT EXISTS (SELECT 1 FROM website_sessions s WHERE s.website_session_id = o.website_session_id);

SELECT COUNT(*) AS items_without_order
FROM order_items i WHERE NOT EXISTS (SELECT 1 FROM Orders_mav o WHERE o.order_id = i.order_id);

SELECT COUNT(*) AS refunds_without_item
FROM order_item_refunds r WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_item_id = r.order_item_id);

SELECT COUNT(*) AS items_without_product
FROM order_items i WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = i.product_id);

SELECT COUNT(*) AS refunds_without_order
FROM order_item_refunds r
WHERE NOT EXISTS (SELECT 1 FROM Orders_mav o WHERE o.order_id = r.order_id);

-- 1.4 Can one session have more than one order? (equal numbers = no)
SELECT COUNT(*) AS orders, COUNT(DISTINCT website_session_id) AS sessions_with_order FROM Orders_mav;

-- 1.5 Date ranges. website_pageviews stops on 2015-01-16 (cut off at Excel's row limit).
SELECT 'website_sessions' AS tbl, MIN(TRY_CONVERT(datetime, created_at, 101)) AS first_date, MAX(TRY_CONVERT(datetime, created_at, 101)) AS last_date FROM website_sessions
UNION ALL SELECT 'website_pageviews', MIN(TRY_CONVERT(datetime, created_at, 101)), MAX(TRY_CONVERT(datetime, created_at, 101)) FROM website_pageviews
UNION ALL SELECT 'Orders_mav',        MIN(TRY_CONVERT(datetime, created_at, 101)), MAX(TRY_CONVERT(datetime, created_at, 101)) FROM Orders_mav;

-- 1.6 Did every date convert (US month/day/year, style 101)? Expect 0 each.
SELECT 'website_sessions' AS tbl, COUNT(*) AS bad_dates FROM website_sessions WHERE TRY_CONVERT(datetime, created_at, 101) IS NULL
UNION ALL SELECT 'Orders_mav',         COUNT(*) FROM Orders_mav         WHERE TRY_CONVERT(datetime, created_at, 101) IS NULL
UNION ALL SELECT 'order_items',        COUNT(*) FROM order_items        WHERE TRY_CONVERT(datetime, created_at, 101) IS NULL
UNION ALL SELECT 'order_item_refunds', COUNT(*) FROM order_item_refunds WHERE TRY_CONVERT(datetime, created_at, 101) IS NULL;

-- 1.7 Missing values in the marketing columns.
-- A plain NULLIF(col,'') count returns 0 because blanks are stored as the TEXT 'NULL'.
SELECT utm_source, COUNT(*) AS total_sessions
FROM website_sessions
GROUP BY utm_source
ORDER BY COUNT(*) DESC;

SELECT COUNT(*) AS Total_rows,
    SUM(CASE WHEN NULLIF(NULLIF(utm_source,   ''), 'NULL') IS NULL THEN 1 ELSE 0 END) AS missing_utm_source,
    SUM(CASE WHEN NULLIF(NULLIF(utm_campaign, ''), 'NULL') IS NULL THEN 1 ELSE 0 END) AS missing_utm_campaign,
    SUM(CASE WHEN NULLIF(NULLIF(utm_content,  ''), 'NULL') IS NULL THEN 1 ELSE 0 END) AS missing_utm_content,
    SUM(CASE WHEN NULLIF(NULLIF(http_referer, ''), 'NULL') IS NULL THEN 1 ELSE 0 END) AS missing_http_referer
FROM website_sessions;

-- 1.8 Data type check: values that cannot be converted. Expect 0 each.
SELECT COUNT(*) AS Total_rows,
    SUM(CASE WHEN TRY_CAST(user_id            AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_user_id,
    SUM(CASE WHEN TRY_CAST(primary_product_id AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_primary_product_id,
    SUM(CASE WHEN TRY_CAST(items_purchased    AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_items_purchased,
    SUM(CASE WHEN TRY_CAST(price_usd          AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_price_usd,
    SUM(CASE WHEN TRY_CAST(cogs_usd           AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_cogs_usd
FROM Orders_mav;

SELECT COUNT(*) AS Total_rows,
    SUM(CASE WHEN TRY_CAST(order_item_id   AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_order_item_id,
    SUM(CASE WHEN TRY_CAST(order_id        AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_order_id,
    SUM(CASE WHEN TRY_CAST(product_id      AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_product_id,
    SUM(CASE WHEN TRY_CAST(is_primary_item AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_is_primary_item,
    SUM(CASE WHEN TRY_CAST(price_usd       AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_price_usd,
    SUM(CASE WHEN TRY_CAST(cogs_usd        AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_cogs_usd
FROM order_items;

SELECT COUNT(*) AS Total_rows,
    SUM(CASE WHEN TRY_CAST(order_item_refund_id AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_refund_id,
    SUM(CASE WHEN TRY_CAST(order_item_id        AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_order_item_id,
    SUM(CASE WHEN TRY_CAST(order_id             AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_order_id,
    SUM(CASE WHEN TRY_CAST(refund_amount_usd    AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_refund_amount
FROM order_item_refunds;


/* =====================================================================
   PART 2. CLEAN TABLES (raw tables are left unchanged)
   ===================================================================== */

SELECT
    CAST(order_item_refund_id AS BIGINT)        AS order_item_refund_id,
    TRY_CONVERT(datetime, created_at, 101)      AS created_at,
    CAST(order_item_id        AS BIGINT)        AS order_item_id,
    CAST(order_id             AS BIGINT)        AS order_id,
    CAST(refund_amount_usd    AS DECIMAL(10,2)) AS refund_amount_usd
INTO refunds_clean
FROM order_item_refunds;

SELECT
    CAST(order_id           AS BIGINT)        AS order_id,
    TRY_CONVERT(datetime, created_at, 101)    AS created_at,
    CAST(website_session_id AS BIGINT)        AS website_session_id,
    CAST(user_id            AS BIGINT)        AS user_id,
    CAST(primary_product_id AS BIGINT)        AS primary_product_id,
    CAST(items_purchased    AS INT)           AS items_purchased,
    CAST(price_usd          AS DECIMAL(10,2)) AS price_usd,
    CAST(cogs_usd           AS DECIMAL(10,2)) AS cogs_usd
INTO orders_clean
FROM Orders_mav;

SELECT
    CAST(order_item_id   AS BIGINT)        AS order_item_id,
    TRY_CONVERT(datetime, created_at, 101) AS created_at,
    CAST(order_id        AS BIGINT)        AS order_id,
    CAST(product_id      AS BIGINT)        AS product_id,
    CAST(is_primary_item AS INT)           AS is_primary_item,
    CAST(price_usd       AS DECIMAL(10,2)) AS price_usd,
    CAST(cogs_usd        AS DECIMAL(10,2)) AS cogs_usd
INTO order_items_clean
FROM order_items;

SELECT
    CAST(product_id AS BIGINT)             AS product_id,
    TRY_CONVERT(datetime, created_at, 101) AS created_at,
    CAST(product_name AS NVARCHAR(100))    AS product_name
INTO products_clean
FROM products;

-- The text 'NULL' (and empty text) becomes a real NULL in the marketing columns
SELECT
    CAST(website_session_id AS BIGINT)         AS website_session_id,
    TRY_CONVERT(datetime, created_at, 101)     AS created_at,
    CAST(user_id            AS BIGINT)         AS user_id,
    CAST(is_repeat_session  AS INT)            AS is_repeat_session,
    NULLIF(NULLIF(utm_source,   ''), 'NULL')   AS utm_source,
    NULLIF(NULLIF(utm_campaign, ''), 'NULL')   AS utm_campaign,
    NULLIF(NULLIF(utm_content,  ''), 'NULL')   AS utm_content,
    CAST(device_type        AS NVARCHAR(50))   AS device_type,
    NULLIF(NULLIF(http_referer, ''), 'NULL')   AS http_referer
INTO sessions_clean
FROM website_sessions;

-- Proof of the fix: real NULLs = 83,328, text NULLs = 0
SELECT
    SUM(CASE WHEN utm_source IS NULL  THEN 1 ELSE 0 END) AS real_nulls,
    SUM(CASE WHEN utm_source = 'NULL' THEN 1 ELSE 0 END) AS text_nulls
FROM sessions_clean;


/* =====================================================================
   PART 3. BUSINESS QUESTIONS (Task 2)
   ===================================================================== */

-- Q1: What is the total number of unique orders?  (32,313)
SELECT COUNT(DISTINCT order_id) AS total_unique_orders
FROM orders_clean;

-- Q2: What is the total revenue generated?  (1,938,509.75, gross before refunds)
SELECT SUM(price_usd) AS Total_revenue
FROM orders_clean;

-- Q2 check: the item-level table must give the same total
SELECT SUM(price_usd) AS Total_revenue_items
FROM order_items_clean;

-- Q3: Which five products generate the highest revenue?  (only 4 products exist)
SELECT TOP 5 p.product_name, SUM(i.price_usd) AS total_revenue
FROM order_items_clean i
JOIN products_clean p ON i.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- Q4: Which product types perform best?  (no category column, so product_name is used)
SELECT p.product_name,
       COUNT(*)           AS items_sold,
       AVG(i.price_usd)   AS avg_price
FROM order_items_clean i
JOIN products_clean p ON i.product_id = p.product_id
GROUP BY p.product_name
ORDER BY items_sold DESC;

-- Q5: Which marketing sources generate the most website sessions?
SELECT ISNULL(utm_source, 'Direct / unpaid') AS marketing_source,
       COUNT(*)                              AS total_sessions
FROM sessions_clean
GROUP BY ISNULL(utm_source, 'Direct / unpaid')
ORDER BY total_sessions DESC;

-- Q6: Which device type generates the most website traffic?
SELECT device_type,
       COUNT(*) AS total_sessions
FROM sessions_clean
GROUP BY device_type
ORDER BY total_sessions DESC;

-- Q7: What is the website session-to-order conversion rate?  (6.83%)
-- 100.0 forces decimal division; one order per session was confirmed in 1.4
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM orders_clean)                  AS total_orders,
    (SELECT COUNT(*) FROM sessions_clean)                                AS total_sessions,
    (SELECT COUNT(DISTINCT order_id) FROM orders_clean) * 100.0
        / (SELECT COUNT(*) FROM sessions_clean)                          AS conversion_rate_pct;

-- Q8: What is the total number and value of refunds?  (1,731 items, 85,338.69)
SELECT COUNT(order_item_refund_id) AS total_refunds,
       SUM(refund_amount_usd)      AS total_refund_value
FROM refunds_clean;

-- Q9: Which months recorded the highest and lowest revenue?
-- Note: March 2012 and March 2015 are partial months.
SELECT DATEFROMPARTS(YEAR(created_at), MONTH(created_at), 1) AS revenue_month,
       SUM(price_usd)                                        AS monthly_revenue
FROM orders_clean
GROUP BY DATEFROMPARTS(YEAR(created_at), MONTH(created_at), 1)
ORDER BY revenue_month;

SELECT TOP 3 DATEFROMPARTS(YEAR(created_at), MONTH(created_at), 1) AS revenue_month,
       SUM(price_usd) AS monthly_revenue
FROM orders_clean
GROUP BY DATEFROMPARTS(YEAR(created_at), MONTH(created_at), 1)
ORDER BY monthly_revenue DESC;

SELECT TOP 3 DATEFROMPARTS(YEAR(created_at), MONTH(created_at), 1) AS revenue_month,
       SUM(price_usd) AS monthly_revenue
FROM orders_clean
GROUP BY DATEFROMPARTS(YEAR(created_at), MONTH(created_at), 1)
ORDER BY monthly_revenue ASC;

-- Q10: What is the average order value?  (59.99)
SELECT AVG(price_usd) AS average_order_value
FROM orders_clean;


/* =====================================================================
   PART 4. VALIDATION QUERIES (used to check the Power BI dashboard)
   ===================================================================== */

-- Sessions and orders by session year (Power BI Year slicer sits on sessions_clean)
SELECT YEAR(s.created_at) AS yr,
       COUNT(*)           AS sessions,
       COUNT(o.order_id)  AS orders
FROM sessions_clean s
LEFT JOIN orders_clean o ON o.website_session_id = s.website_session_id
GROUP BY YEAR(s.created_at)
ORDER BY yr;

-- Refunds by year of the original session
SELECT YEAR(s.created_at) AS yr, COUNT(*) AS refunds
FROM refunds_clean r
JOIN order_items_clean i ON i.order_item_id = r.order_item_id
JOIN orders_clean o      ON o.order_id = i.order_id
JOIN sessions_clean s    ON s.website_session_id = o.website_session_id
GROUP BY YEAR(s.created_at)
ORDER BY yr;

-- Refund rate by product (refunded items divided by items sold)
SELECT p.product_name,
       COUNT(*)                                         AS items_sold,
       COUNT(r.order_item_refund_id)                    AS refunds,
       100.0 * COUNT(r.order_item_refund_id) / COUNT(*) AS refund_rate_pct
FROM order_items_clean i
JOIN products_clean p     ON p.product_id = i.product_id
LEFT JOIN refunds_clean r ON r.order_item_id = i.order_item_id
GROUP BY p.product_name
ORDER BY refund_rate_pct DESC;
