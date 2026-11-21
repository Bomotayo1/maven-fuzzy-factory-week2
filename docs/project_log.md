# Project log: Maven Fuzzy Factory

**AnalystLab Africa Experience Lab · Week 2 · Track 1: Data Analytics**

This is the step-by-step record of the analysis: what I checked, what I found, what went wrong and how it was fixed. Every number here comes from a SQL query or a dashboard check. For the short version, read the [README](../README.md).

**Contents**
1. [Environment](#1-environment)
2. [The business problem](#2-the-business-problem)
3. [Step 1: Import](#3-step-1-import)
4. [Step 2: Data inspection](#4-step-2-data-inspection)
5. [Step 3: Cleaning and the data model](#5-step-3-cleaning-and-the-data-model)
6. [Step 4: The ten business questions](#6-step-4-the-ten-business-questions)
7. [Step 5: The Power BI dashboard](#7-step-5-the-power-bi-dashboard)
8. [Step 6: Validation](#8-step-6-validation)
9. [Step 7: Findings and recommendations](#9-step-7-findings-and-recommendations)
10. [Mistakes and fixes](#10-mistakes-and-fixes)
11. [How the SQL was written](#11-how-the-sql-was-written)
12. [Limitations](#12-limitations)

---

## 1. Environment

| Item | Detail |
|---|---|
| Database | Microsoft SQL Server (SSMS), database `MavenFuzzyFactory` |
| Reporting | Power BI Desktop, connected to the clean tables |
| Cleaning | Done in SQL (Step 3). Power Query only loads the clean tables |

## 2. The business problem

Maven Fuzzy Factory is an online shop selling four plush toys. Management wants one trusted view of how its website performs, which products and marketing channels earn the money, how many visitors become buyers, and how much is lost to refunds. The data covers **19 March 2012 to 19 March 2015**.

## 3. Step 1: Import

Each CSV was imported with SSMS **Import Flat File**, with every column as text (`nvarchar(MAX)`), nulls allowed and no primary key. I did this so bad values would show up in checks instead of crashing the import. Keys are confirmed in Step 2 and types are converted in Step 3.

| Source file | Table | Rows |
|---|---|---|
| website_sessions.csv | website_sessions | 472,871 |
| website_pageviews.csv | website_pageviews | 1,048,575 |
| orders_mav.csv | Orders_mav | 32,313 |
| order_items.csv | order_items | 40,025 |
| order_item_refunds.csv | order_item_refunds | 1,731 |
| products.csv | products | 4 |

The pageviews row count equals Excel's row limit, which turned out to matter (see 2.6).

## 4. Step 2: Data inspection

| # | Check | Result | Decision |
|---|---|---|---|
| 2.1 | Table names | My first script used short names (`sessions`, `orders`) that do not exist, so it returned 2 of 6 rows | Script bug, not a data problem. Rewritten with the real names |
| 2.2 | First column names (hidden character check) | 6 clean names, no hidden character | None needed |
| 2.3 | Are ID columns unique? | Row count equals distinct IDs in all six tables | Each ID column works as the primary key |
| 2.4 | Orphan checks (foreign keys) | 0 orders without a session, 0 items without an order, 0 refunds without an item, 0 items without a product, 0 refunds without an order | All relationships are intact |
| 2.5 | Can a session have more than one order? | 32,313 orders and 32,313 sessions with an order | One order per session, so conversion = orders ÷ sessions |
| 2.6 | Date ranges | Sessions and orders: 19 Mar 2012 to 19 Mar 2015. **Pageviews stop on 16 Jan 2015** | Pageviews were cut off at Excel's row limit, so they are not used |
| 2.7 | Do all dates convert (US month/day/year, style 101)? | 0 failures in all four tables that have dates | Dates convert safely |
| 2.8 | Missing values in the marketing columns | See below | Blanks converted to real NULLs in Step 3 |
| 2.9 | Data dictionary review | No category column on `products`; both orders and items hold `price_usd`; no users table | `product_name` used as the product type; revenue checked two ways |
| 2.10 to 2.12 | Can numbers convert? (`TRY_CAST`) | 0 failures in Orders_mav (32,313 rows), order_items (40,025) and order_item_refunds (1,731) | Safe to convert |

**2.8 in detail: blanks stored as the word `NULL`.** My first count of blanks (`NULLIF(col,'')`) returned 0 for all four marketing columns. That was suspicious, because some visitors type the address directly. Grouping by `utm_source` showed 83,328 sessions labelled NULL, so the blanks were the **text word `NULL`**, not real NULLs. Rerunning the count with `NULLIF(NULLIF(col,''),'NULL')` gave:

| Column | Missing |
|---|---|
| utm_source | 83,328 (17.6% of sessions) |
| utm_campaign | 83,328 |
| utm_content | 83,328 |
| http_referer | 39,917 |

The three `utm` columns are blank together, so these are sessions with no tracked campaign (direct or unpaid visits), not random gaps.

## 5. Step 3: Cleaning and the data model

The raw tables were never changed. Five clean tables were built with `SELECT ... INTO`, using `CAST`, `TRY_CONVERT(datetime, created_at, 101)` and `NULLIF`.

| Clean table | Rows | What changed |
|---|---|---|
| refunds_clean | 1,731 | IDs to BIGINT, date to DATETIME, `refund_amount_usd` to DECIMAL(10,2) |
| orders_clean | 32,313 | IDs to BIGINT, date to DATETIME, `items_purchased` to INT, prices to DECIMAL(10,2) |
| order_items_clean | 40,025 | IDs to BIGINT, date to DATETIME, `is_primary_item` to INT, prices to DECIMAL(10,2) |
| products_clean | 4 | `product_id` to BIGINT, date to DATETIME, `product_name` to NVARCHAR(100) |
| sessions_clean | 472,871 | IDs and date converted, and the text `'NULL'` in `utm_source`, `utm_campaign`, `utm_content` and `http_referer` became a real NULL |

**Proof the NULL fix worked:** in `sessions_clean`, `utm_source IS NULL` counts 83,328 and `utm_source = 'NULL'` counts 0. Grouping by source still adds up to 472,871, so no rows were lost.

**The data model in Power BI** uses the five clean tables (`website_pageviews` is not loaded). Relationships:

| From | To | Type |
|---|---|---|
| products_clean | order_items_clean | one to many |
| orders_clean | order_items_clean | one to many |
| sessions_clean | orders_clean | one to one, both directions |
| refunds_clean | order_items_clean | one to one, both directions |

Power BI chose one to one for the last two by itself, which agrees with the SQL findings (one order per session, at most one refund per item).

## 6. Step 4: The ten business questions

| # | Question | Answer | What it means |
|---|---|---|---|
| 1 | Total unique orders | **32,313** | Also the number of sessions that ended in a purchase |
| 2 | Total revenue | **1,938,509.75** (gross, before refunds). The item-level table gives the same total to the cent | About 1.94 million dollars in three years |
| 3 | Top five products by revenue | Only four products exist: Original Mr. Fuzzy 1,211,057.74 (62.5%) · Forever Love Bear 347,702.04 · Birthday Sugar Panda 229,260.15 · Hudson River Mini bear 150,489.82. They add up to the Q2 total | The original toy brings in nearly two thirds of revenue, but it has also been on sale longest |
| 4 | Which product types perform best? | No category column, so product name is used. Items sold at a fixed price: Mr. Fuzzy 24,226 at 49.99 · Love Bear 5,796 at 59.99 · Mini bear 5,018 at 29.99 · Sugar Panda 4,985 at 45.99. Items add up to 40,025 | Each product has one price (no discounting in the data). The cheapest product sold more items than the Panda in less time |
| 5 | Sessions by marketing source | gsearch 316,035 (66.8%) · Direct / unpaid 83,328 (17.6%) · bsearch 62,823 (13.3%) · socialbook 10,685 (2.3%) | Two thirds of traffic comes from one channel |
| 6 | Traffic by device | desktop 327,027 (69.2%) · mobile 145,844 (30.8%) | Desktop dominates, but mobile is nearly a third |
| 7 | Session-to-order conversion rate | **6.83%** (32,313 ÷ 472,871) | About 7 in 100 sessions end in an order |
| 8 | Total number and value of refunds | **1,731** refunded items worth **85,338.69** (4.40% of revenue, 4.32% of items sold, average 49.30) | Net revenue is about 1.85 million |
| 9 | Highest and lowest revenue months | Highest: **December 2014** (144,823.02). Lowest full month: **April 2012** (4,949.01). March 2012 has a lower total (2,999.40) but is a partial month (data starts on the 19th) | The three best months are the three latest, so growth matters more than seasonality |
| 10 | Average order value | **59.99** (equals revenue ÷ orders) | Above the average item price of about 48, because orders hold 1.24 items on average |

## 7. Step 5: The Power BI dashboard

**Two pages**, each with a page navigator and Year, Product (or Marketing Source) and Device Type slicers, in a custom theme (`powerbi/MavenFuzzy_Custom.json`).

| Page | Contents |
|---|---|
| Overview | Six cards (Total Orders, Total Revenue, Average Order Value, Total Refunds, Website Sessions, Conversion Rate), Revenue by month, Top performing products, Sales by product |
| Traffic | Four cards (Website Sessions, Conversion Rate, Total Refunds, Refund Value), Sessions by marketing channel, Sessions by device type, Refund analysis (refund rate by product plus Refund Rate, Average Refund and Refund % of Revenue cards) |

**Measures** (built on `order_items_clean` so that product, year and device slicers filter every card the same way):

```
Total Orders        = DISTINCTCOUNT(order_items_clean[order_id])
Total Revenue       = SUM(order_items_clean[price_usd])
Average Order Value = DIVIDE([Total Revenue], [Total Orders])
Total Refunds       = COUNTROWS(refunds_clean)
Refund Value        = SUM(refunds_clean[refund_amount_usd])
Website Sessions    = CALCULATE(COUNTROWS(sessions_clean), REMOVEFILTERS(products_clean))
Conversion Rate     = DIVIDE([Total Orders], [Website Sessions])
Refund Rate         = DIVIDE([Total Refunds], COUNTROWS(order_items_clean))
Refund % of Revenue = DIVIDE([Refund Value], [Total Revenue])
Average Refund      = DIVIDE([Refund Value], [Total Refunds])
```

**Calculated columns:** `Month Start` on `order_items_clean` (first day of the month, so the revenue chart has one column per month), `Year` on `sessions_clean`, and `Marketing Source` on `sessions_clean` (a blank source shown as "Direct / unpaid").

`REMOVEFILTERS(products_clean)` in Website Sessions stops a product selection from cutting sessions down to only the sessions that bought something. Without it, conversion would be wrong under a product filter.

## 8. Step 6: Validation

Every dashboard figure was compared with a separate SQL result.

| Check | SQL | Power BI |
|---|---|---|
| Total orders | 32,313 | 32,313 |
| Total revenue | 1,938,509.75 | $1.94M |
| Average order value | 59.99 | $59.99 |
| Refunds | 1,731 | 1,731 |
| Sessions | 472,871 | 472,871 |
| Conversion rate | 6.83% | 6.83% |
| Refund value, refund rate, average refund, share of revenue | 85,338.69 · 4.32% · 49.30 · 4.40% | $85,339 · 4.32% · $49.30 · 4.40% |
| 2014 only: sessions, orders, refunds | 233,422 · 16,860 · 985 | 233,422 · 16,860 · 985 |
| 2014 revenue | 1,075,612.19 (sum of the twelve monthly figures) | $1.08M |
| Refund rate by product | Panda 6.04% (301 of 4,985) · Mr. Fuzzy 5.11% (1,237 of 24,226) · Love Bear 2.23% (129 of 5,796) · Mini bear 1.28% (64 of 5,018) | same; refunds add up to 1,731 |
| Sessions by channel and by device | Q5 and Q6 | same |
| Revenue by month | Dec 2014 144,823.02 · Mar 2012 2,999.40 | $145K and $3K labels |

**Yearly figures behind the Year slicer test** (grouped by the year of the session):

| Year | Sessions | Orders | Conversion | Refunds |
|---|---|---|---|---|
| 2012 (from 19 Mar) | 62,470 | 2,586 | 4.14% | 178 |
| 2013 | 112,781 | 7,447 | 6.60% | 336 |
| 2014 | 233,422 | 16,860 | 7.22% | 985 |
| 2015 (to 19 Mar) | 64,198 | 5,420 | 8.44% | 232 |

## 9. Step 7: Findings and recommendations

1. **Growth is the main story.** Revenue rose every year. December 2014 earned about 2.5 times December 2013, and the best full month earned about 29 times the lowest full month. *Plan stock and staffing on the growth trend, with a build-up from November to January.*
2. **The website converts better every year.** Conversion rose from 4.14% to 6.60%, 7.22% and 8.44% (2012 and 2015 are partial years). One extra point is worth about 4,700 orders on the same traffic. *Find which site changes were made and repeat them.*
3. **Traffic depends on one channel.** gsearch brings 66.8% of sessions. *Test the smaller channels and measure conversion by channel before moving budget.*
4. **One product earns most of the revenue.** The Original Mr. Fuzzy brings 62.5% of revenue and 24,226 of 40,025 items, but it has also been on sale longest. *Promote the newer products and compare revenue per month on sale.*
5. **A bigger basket adds revenue directly.** The average order is 59.99 against about 48 per item. The Hudson River Mini bear, the cheapest at 29.99, sold 5,018 items in about 13 months. *Test bundles and a low-price add-on.*
6. **Refunds cost 85,338.69, and one product stands out.** The Birthday Sugar Panda has the highest refund rate (6.04%) and the Mini bear the lowest (1.28%). The Original Mr. Fuzzy has 71.5% of all refunded items. Refunds per 100 orders rose in 2014 (5.8) compared with 2013 (4.5). *Investigate the Panda's quality and description, and record a refund reason.*
7. **Desktop dominates traffic, but its conversion is untested.** *Measure conversion by device before investing in mobile.*

## 10. Mistakes and fixes

| What went wrong | How it was found | Fix |
|---|---|---|
| First checking script used table names that do not exist | It returned 2 of 6 rows | Rewrote it with the real table names |
| A count of blanks returned 0 | Visitors who type the address directly must have no source | Grouped by `utm_source`, found the text `'NULL'`, converted it to a real NULL |
| Pageviews file was cut off | Last date was 16 Jan 2015, two months before sessions | Not used; limitation stated |
| First draft of `orders_clean` named the wrong source table and left out three columns | Read the last two lines of the query before running it | Corrected and rebuilt |
| First draft of `order_items_clean` used a table name that does not exist | Same habit | Corrected |
| Year slicer did not change Website Sessions | Selected 2014 and watched all six cards | Moved the `Year` column from the items table to the sessions table (filters flow from sessions to orders to items, not backwards) |
| Traffic charts used a raw count of `website_session_id` | Numbers had no thousands separator and the chart had a default title | Replaced with the `Website Sessions` measure |
| Early March 2012 looked like the worst month | It starts on the 19th | Reported April 2012 as the lowest full month, and both versions |

## 11. How the SQL was written

I wrote and ran the SQL myself and checked each result against a second source. Where a query was supplied to me, or corrected after an error, it is listed here.

| Query | Who wrote it |
|---|---|
| Q1, Q2 (and its check), Q8 | Written by me |
| Q3, Q4, Q6, Q10 | Written by me, then corrected (a few column names, a missing `GROUP BY`, a missing comma) |
| Q5, Q7 | Supplied to me, then run and checked by me |
| Q9 | Monthly query written by me from a skeleton; the top 3 and bottom 3 versions were supplied |
| `orders_clean`, `order_items_clean`, `products_clean` | Written by me, then corrected |
| `refunds_clean`, `sessions_clean`, the inspection scripts and the validation queries | Supplied to me, then run and checked by me |
| Refunds-to-orders orphan check | Written by me, using the pattern of the earlier checks |

## 12. Limitations

- `website_pageviews` is incomplete, so there is no page-level or funnel analysis.
- 2012 and 2015 are partial years, March 2012 and March 2015 are partial months, and the products launched at different dates, so comparisons need care.
- The data has no refund reasons, so findings show associations, not causes.
- Revenue is gross (before refunds). Net revenue is about 1.85 million.
- `user_id` could not be checked as a key because there is no users table.
