# Maven Fuzzy Factory: E-commerce Business Performance and Customer Behaviour Analysis

**AnalystLab Africa Experience Lab · Week 2 · Track 1: Data Analytics**
Tools: SQL Server (SSMS) · Power BI Desktop · Power Query

> How is Maven Fuzzy Factory performing, which products and marketing channels earn the money, how many visitors become buyers, and how much is lost to refunds?

Full step-by-step record, including mistakes and fixes: **[docs/project_log.md](docs/project_log.md)**

---

## 1. The business question

Maven Fuzzy Factory is an online shop selling four plush toys. Management wanted one trusted view of its website traffic, orders, products and refunds between **19 March 2012 and 19 March 2015**, so it can decide where to put effort to raise revenue and conversion.

This project cleans the six supplied files in SQL Server, answers ten business questions with SQL, and presents the results in a two-page Power BI dashboard with filters.

## 2. Headline results

| # | Question | Answer |
|---|---|---|
| 1 | Unique orders | **32,313** |
| 2 | Total revenue (gross, before refunds) | **$1,938,509.75** |
| 3 | Top products by revenue | The Original Mr. Fuzzy $1,211,057.74 (62.5%) · The Forever Love Bear $347,702.04 · The Birthday Sugar Panda $229,260.15 · The Hudson River Mini bear $150,489.82 |
| 4 | Product types (no category column exists, so `product_name` is used) | Items sold and price: Mr. Fuzzy 24,226 at $49.99 · Love Bear 5,796 at $59.99 · Mini bear 5,018 at $29.99 · Sugar Panda 4,985 at $45.99 |
| 5 | Sessions by marketing source | gsearch 316,035 · Direct / unpaid 83,328 · bsearch 62,823 · socialbook 10,685 |
| 6 | Sessions by device | desktop 327,027 (69.2%) · mobile 145,844 (30.8%) |
| 7 | Session-to-order conversion rate | **6.83%** (32,313 orders from 472,871 sessions) |
| 8 | Refunds | **1,731** refunded items worth **$85,338.69** (4.40% of revenue, 4.32% of items sold) |
| 9 | Highest and lowest revenue months | Highest: **December 2014** ($144,823.02). Lowest full month: **April 2012** ($4,949.01). March 2012 has a lower total ($2,999.40) but is a partial month |
| 10 | Average order value | **$59.99** |

## 3. Dashboard

Two pages, each with a page navigator and Year, Product (or Marketing Source) and Device Type slicers. A custom theme is included.

| Page | Contents |
|---|---|
| **Overview** | Total Orders, Total Revenue, Average Order Value, Total Refunds, Website Sessions, Conversion Rate · Revenue by month · Top performing products · Sales by product |
| **Traffic** | Sessions, Conversion Rate, Total Refunds, Refund Value · Sessions by marketing channel · Sessions by device type · Refund analysis (refund rate by product, Refund Rate, Average Refund, Refund % of Revenue) |

![Overview Dashboard](images/Screenshot%202026-11-21%20091758.png)

![Page 2 Traffic](images/Screenshot%202026-11-21%20091836.png)

## 4. Data, model and method

**Source files:** `website_sessions`, `website_pageviews`, `orders_mav`, `order_items`, `order_item_refunds`, `products`, plus the data dictionary.

| Table | Rows | Primary key |
|---|---|---|
| website_sessions | 472,871 | website_session_id |
| Orders_mav | 32,313 | order_id |
| order_items | 40,025 | order_item_id |
| order_item_refunds | 1,731 | order_item_refund_id |
| products | 4 | product_id |
| website_pageviews | 1,048,575 | website_pageview_id (imported, not used; see data quality) |

**Relationships (all tested, zero orphan rows):** sessions → orders (one to one) · orders → order items (one to many) · products → order items (one to many) · order items → refunds (one to one). Refunds also link to orders through `order_id`, which was checked in SQL.

**Method:** every CSV was imported as text so that bad values could be found instead of blocking the import. The raw tables were never changed. Five clean tables were built with `SELECT ... INTO`, using `CAST`, `TRY_CONVERT` (US date style 101) and `NULLIF`: `sessions_clean`, `orders_clean`, `order_items_clean`, `refunds_clean`, `products_clean`. Power BI loads only the clean tables.

## 5. Data quality findings

| Finding | What I did |
|---|---|
| **Blanks were stored as the text `'NULL'`.** A first count of blanks returned 0, which was wrong. Grouping by `utm_source` showed 83,328 sessions (17.6%) labelled NULL | Converted to real NULLs with `NULLIF(NULLIF(col,''),'NULL')`. Rows kept. Labelled **Direct / unpaid** in analysis. Proved with 83,328 real NULLs and 0 text NULLs |
| **`website_pageviews` stops on 16 Jan 2015**, two months before sessions and orders. It holds exactly 1,048,575 rows, Excel's row limit | Not used in any question. No page-level analysis was made |
| Dates are US format (M/D/YYYY) | Converted with style 101. 0 failures in all tables |
| No product category column | `product_name` used as the product type |
| No users table | `user_id` could not be checked as a key |
| March 2012 and March 2015 are partial months | Stated in the answer to Q9 and labelled on the chart |
| **Dashboard bug found in testing:** a Year column built on the items table did not filter sessions | Moved the Year column to `sessions_clean` and retested against SQL |

## 6. Validation: SQL against Power BI

| Check | SQL | Power BI |
|---|---|---|
| Total orders | 32,313 | 32,313 |
| Total revenue | 1,938,509.75 (orders table and items table agree to the cent) | $1.94M |
| Average order value | 59.99 | $59.99 |
| Refunds | 1,731 | 1,731 |
| Sessions | 472,871 | 472,871 |
| Conversion rate | 6.83% | 6.83% |
| 2014 only: sessions, orders, refunds | 233,422 · 16,860 · 985 | 233,422 · 16,860 · 985 |
| 2014 revenue | 1,075,612.19 (sum of the monthly figures) | $1.08M |
| Refund rate by product | Panda 6.04% · Mr. Fuzzy 5.11% · Love Bear 2.23% · Mini bear 1.28% | same |
| Sessions by channel and device | match Q5 and Q6 | same |

## 7. Findings and recommendations

1. **Growth is the main story.** December 2014 earned about 2.5 times December 2013. The three best months are the three latest. *Plan stock and staffing on the growth trend, with a build-up from November to January.*
2. **The website converts better every year.** Conversion rose from 4.14% (2012) to 6.60%, 7.22% and 8.44% (early 2015; 2012 and 2015 are partial years). On the same traffic, one extra point is worth about 4,700 orders. *Find which site changes were made and repeat them.*
3. **Traffic depends on one channel.** gsearch brings 66.8% of sessions. *Test the smaller channels and measure conversion by channel before moving budget.*
4. **One product earns most of the revenue.** The Original Mr. Fuzzy brings 62.5% of revenue, but it has also been on sale the longest. *Promote the newer products and compare revenue per month on sale.*
5. **A bigger basket adds revenue directly.** The average order is $59.99 against about $48 per item, with 1.24 items per order. *Test bundles and a low-price add-on.*
6. **Refunds cost $85,338.69, and one product stands out.** The Birthday Sugar Panda has the highest refund rate (6.04%), while Mr. Fuzzy has 71.5% of all refunded items. *Investigate the Panda's quality and description, and record a refund reason.*
7. **Desktop dominates traffic, but its conversion is untested.** *Measure conversion by device before investing in mobile.*

## 8. Limitations

- `website_pageviews` is incomplete, so there is no page-level or funnel analysis.
- 2012 and 2015 are partial years, and the products launched at different dates, so comparisons need care.
- The data has no refund reasons, so findings show associations, not causes.
- Revenue is gross (before refunds). Net revenue is about $1.85M.

## 9. Repository structure

```
├── README.md
├── sql/
│   └── MavenFuzzyFactory_Week2.sql      # inspection, cleaning scripts and Q1 to Q10
├── powerbi/
│   ├── Maven_Fuzzy_Factory_Dashboard.pbix
│   └── MavenFuzzy_Custom.json           # Power BI theme
├── images/                              # dashboard screenshots
└── docs/
    └── project_log.md                   # step-by-step log of the analysis
```

> The raw CSV files are not included in this repository.

## 10. How to reproduce

1. In SQL Server Management Studio, import each CSV with **Import Flat File** (all columns as `nvarchar(MAX)`, nulls allowed).
2. Run `sql/MavenFuzzyFactory_Week2.sql`. Part 2 builds the five clean tables (run it once) and Part 3 answers Q1 to Q10.
3. Open the [.pbix](main/powerbi/MavenFuzzyFactory.pbix) in Power BI Desktop and point the data source at your server and database.
4. To apply the theme: View › Themes › Browse for themes › `MavenFuzzy_Custom.json`.

## 11. How I worked

I wrote and ran the SQL myself and checked every result against a second source (another table, a hand calculation or the dashboard). Where a query was supplied to me, or corrected after an error, the [project log](docs/project_log.md) says so. The log records every step, including the mistakes and how they were fixed.

## Author

**Babatunde Omotayo** · AnalystLab Africa Experience Lab, Track 1: Data Analytics
[LinkedIn](https://www.linkedin.com/in/omotayo-babatunde) · [![Watch the presentation on YouTube](https://img.youtube.com/vi/EhdINSj-TdY/hqdefault.jpg)](https://youtu.be/EhdINSj-TdY)

▶️ [Watch the presentation on YouTube](https://youtu.be/EhdINSj-TdY)


#AnalystLabAfrica
