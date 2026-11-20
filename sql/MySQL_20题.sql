-- =====================================================================
-- 作品集 2：MySQL 分析练习库（消费电子线上销售）
-- 数据规模：5,000 笔订单 / 20 个 SKU / 800 个客户 / 2025 全年
-- 用途：从「基础查询」练到「窗口函数」，20 题覆盖面试高频考点
-- =====================================================================

-- ---------- 第一步：建库 ----------
CREATE DATABASE IF NOT EXISTS ec_sales DEFAULT CHARSET utf8mb4;
USE ec_sales;

-- ---------- 第二步：建表 ----------
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
  order_id     VARCHAR(20)  PRIMARY KEY,
  order_date   DATE,
  month        VARCHAR(7),
  channel      VARCHAR(20),
  region       VARCHAR(20),
  product_id   VARCHAR(10),
  product_name VARCHAR(50),
  category     VARCHAR(20),
  quantity     INT,
  unit_price   DECIMAL(10,2),
  discount     DECIMAL(5,3),
  amount       DECIMAL(12,2),
  cost         DECIMAL(12,2),
  profit       DECIMAL(12,2),
  customer_id  VARCHAR(10),
  KEY idx_month (month),
  KEY idx_channel (channel),
  KEY idx_product (product_id),
  KEY idx_customer (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS products;
CREATE TABLE products (
  product_id   VARCHAR(10) PRIMARY KEY,
  product_name VARCHAR(50),
  category     VARCHAR(20),
  list_price   DECIMAL(10,2),
  cost         DECIMAL(10,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
  customer_id   VARCHAR(10) PRIMARY KEY,
  city          VARCHAR(20),
  tier          VARCHAR(10),
  register_date DATE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS inventory;
CREATE TABLE inventory (
  stat_date    DATE,
  product_id   VARCHAR(10),
  warehouse    VARCHAR(20),
  stock_qty    INT,
  outbound_qty INT,
  KEY idx_pd (product_id, stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 第三步：导入数据（二选一）----------
-- 方式 A（推荐新手）：MySQL Workbench
--   右键 ec_sales -> Table Data Import Wizard -> 选 data/orders.csv -> 表名 orders -> 下一步到底
--   注意：UTF-8 编码；orders.csv 带 BOM，若首列名异常，导入时勾选「包含列名」并手工指定
-- 方式 B（命令行）：把下面的路径换成你自己的绝对路径，注意反斜杠写成 / 或 \\
-- LOAD DATA LOCAL INFILE 'C:/Users/你的用户名/Desktop/作品集_消费电子销售分析/data/orders.csv'
--   INTO TABLE orders CHARACTER SET utf8mb4
--   FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
--   LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- 导入自检：应返回 5000
-- SELECT COUNT(*) FROM orders;


-- =====================================================================
-- 20 道题：从基础 → 聚合 → JOIN → 窗口函数 → 业务分析
-- 每题先自己写，写不出来再看参考答案
-- =====================================================================

-- 【Level 1 · 基础查询】

-- Q1. 查 2025 年 11 月的订单，按金额从高到低取前 20 条
--     考点：WHERE + ORDER BY + LIMIT
SELECT order_id, order_date, channel, category, amount
FROM orders
WHERE month = '2025-11'
ORDER BY amount DESC
LIMIT 20;

-- Q2. 全店核心指标：订单数、总销售额、客单价、毛利率
--     考点：聚合函数 / 一行汇总
SELECT COUNT(*)                                    AS 订单数,
       ROUND(SUM(amount), 0)                       AS 销售额,
       ROUND(SUM(amount) / COUNT(*), 0)            AS 客单价,
       ROUND(SUM(profit) / SUM(amount) * 100, 2)   AS 毛利率百分比
FROM orders;

-- Q3. 各渠道的订单数、销售额、销售额占比
--     考点：GROUP BY + 子查询算占比
SELECT channel,
       COUNT(*)                                              AS 订单数,
       ROUND(SUM(amount), 0)                                  AS 销售额,
       ROUND(SUM(amount) / (SELECT SUM(amount) FROM orders) * 100, 1) AS 占比百分比
FROM orders
GROUP BY channel
ORDER BY 销售额 DESC;

-- Q4. 销售额 Top 10 商品
--     考点：GROUP BY + ORDER BY + LIMIT
SELECT product_id, product_name,
       COUNT(*)              AS 订单数,
       ROUND(SUM(amount), 0) AS 销售额
FROM orders
GROUP BY product_id, product_name
ORDER BY 销售额 DESC
LIMIT 10;

-- Q5. 各大区的销售额与客单价
SELECT region,
       ROUND(SUM(amount), 0)            AS 销售额,
       ROUND(SUM(amount) / COUNT(*), 0) AS 客单价
FROM orders
GROUP BY region
ORDER BY 销售额 DESC;


-- 【Level 2 · 聚合进阶】

-- Q6. 月度销售额 + 环比增长率  ★面试高频
--     考点：窗口函数 LAG
SELECT month,
       ROUND(SUM(amount), 0) AS 销售额,
       LAG(ROUND(SUM(amount), 0)) OVER (ORDER BY month) AS 上月销售额,
       ROUND((SUM(amount) - LAG(SUM(amount)) OVER (ORDER BY month))
             / LAG(SUM(amount)) OVER (ORDER BY month) * 100, 1) AS 环比百分比
FROM orders
GROUP BY month
ORDER BY month;

-- Q7. 每个品类内部，商品按销售额排名（取前 3）
--     考点：窗口函数 ROW_NUMBER + PARTITION BY + 外层过滤
SELECT * FROM (
    SELECT category, product_name,
           ROUND(SUM(amount), 0) AS 销售额,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY SUM(amount) DESC) AS 品类内排名
    FROM orders
    GROUP BY category, product_name
) t
WHERE 品类内排名 <= 3
ORDER BY category, 品类内排名;

-- Q8. 每月销售额及全年累计销售额
--     考点：窗口函数 SUM() OVER (ORDER BY ...)
SELECT month,
       ROUND(SUM(amount), 0) AS 月销售额,
       ROUND(SUM(SUM(amount)) OVER (ORDER BY month), 0) AS 累计销售额
FROM orders
GROUP BY month
ORDER BY month;

-- Q9. 每月客单价变化（找客单价异常的月份）
SELECT month,
       COUNT(*)                         AS 订单数,
       ROUND(SUM(amount) / COUNT(*), 0) AS 客单价
FROM orders
GROUP BY month
ORDER BY 客单价 DESC;


-- 【Level 3 · 多表 JOIN】

-- Q10. 订单表 JOIN 商品表，校验「订单里的单价 = 商品标价」，并算实际毛利
--      考点：INNER JOIN + 条件统计（找出异常数据是数据分析的基本功）
SELECT COUNT(*)                                              AS 总订单,
       SUM(CASE WHEN o.unit_price <> p.list_price THEN 1 ELSE 0 END) AS 单价不一致条数,
       ROUND(SUM(o.amount - o.cost), 2)                       AS 实际毛利
FROM orders o
JOIN products p ON o.product_id = p.product_id;

-- Q11. 渠道 × 品类 交叉透视表（用 CASE WHEN 手工透视）
--      考点：条件聚合，这是 Excel 透视表的 SQL 版
SELECT channel,
       ROUND(SUM(CASE WHEN category = '耳机'     THEN amount ELSE 0 END), 0) AS 耳机,
       ROUND(SUM(CASE WHEN category = '音箱'     THEN amount ELSE 0 END), 0) AS 音箱,
       ROUND(SUM(CASE WHEN category = '移动电源' THEN amount ELSE 0 END), 0) AS 移动电源,
       ROUND(SUM(CASE WHEN category = '充电器'   THEN amount ELSE 0 END), 0) AS 充电器,
       ROUND(SUM(CASE WHEN category = '数据线'   THEN amount ELSE 0 END), 0) AS 数据线
FROM orders
GROUP BY channel
ORDER BY SUM(amount) DESC;

-- Q12. 找出全年「一笔订单都没有」的商品（滞销 SKU）
--      考点：LEFT JOIN + IS NULL
SELECT p.product_id, p.product_name, p.category
FROM products p
LEFT JOIN orders o ON p.product_id = o.product_id
WHERE o.order_id IS NULL;

-- Q13. 库存周转分析（★两种口径都要会，面试必问）
--      口径 A（数量口径）：出库量 ÷ 平均库存量。适合同款追踪，但跨品类不可比
--      口径 B（金额口径）：营业成本(COGS) ÷ 平均存货金额。**这是财务标准口径**
--      注意：天数用 365 ÷ 次数（不要用 12，那是按月算的错法）
SELECT t.product_id,
       ROUND(t.avg_qty, 0)                        AS 平均库存数量,
       ROUND(t.avg_stock_val, 0)                  AS 平均存货金额,
       ROUND(t.cogs, 0)                           AS 年度营业成本,
       ROUND(t.cogs / t.avg_stock_val, 2)         AS 周转次数,
       ROUND(365 / (t.cogs / t.avg_stock_val), 1) AS 周转天数
FROM (
    SELECT i.product_id,
           AVG(i.stock_qty)            AS avg_qty,
           AVG(i.stock_qty * p.cost)   AS avg_stock_val,
           (SELECT SUM(o.cost) FROM orders o
             WHERE o.product_id = i.product_id) AS cogs
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    GROUP BY i.product_id
) t
ORDER BY 周转天数 DESC;


-- 【Level 4 · 窗口函数与 CTE】

-- Q14. 各品类销售额占全店比重（一条 SQL 出结论）
--      考点：聚合结果再套窗口函数
SELECT category,
       ROUND(SUM(amount), 0)                                     AS 品类销售额,
       ROUND(SUM(amount) / SUM(SUM(amount)) OVER () * 100, 1)    AS 占比百分比
FROM orders
GROUP BY category
ORDER BY 品类销售额 DESC;

-- Q15. 每个月销售额 Top 3 的商品
--      考点：PARTITION BY month 的排名
SELECT * FROM (
    SELECT month, product_name,
           ROUND(SUM(amount), 0) AS 销售额,
           ROW_NUMBER() OVER (PARTITION BY month ORDER BY SUM(amount) DESC) AS 排名
    FROM orders
    GROUP BY month, product_name
) t
WHERE 排名 <= 3
ORDER BY month, 排名;

-- Q16. 大促月（6 月、11 月）vs 平销月 的对比 ★需求计划核心
--      考点：CASE WHEN 分组 + 聚合
SELECT CASE WHEN month IN ('2025-06', '2025-11') THEN '大促月' ELSE '平销月' END AS 月份类型,
       COUNT(DISTINCT month)            AS 月份数,
       COUNT(*)                         AS 订单数,
       ROUND(SUM(amount), 0)            AS 销售额,
       ROUND(SUM(amount) / COUNT(DISTINCT month), 0) AS 月均销售额,
       ROUND(SUM(amount) / COUNT(*), 0) AS 客单价
FROM orders
GROUP BY 月份类型;

-- Q17. 客户复购分析：下单次数分布
--      考点：CTE + 子查询聚合
WITH cust_orders AS (
    SELECT customer_id, COUNT(*) AS 下单次数, ROUND(SUM(amount), 0) AS 累计金额
    FROM orders
    GROUP BY customer_id
)
SELECT CASE WHEN 下单次数 = 1 THEN '1 单（一次性）'
            WHEN 下单次数 BETWEEN 2 AND 5 THEN '2-5 单'
            WHEN 下单次数 BETWEEN 6 AND 10 THEN '6-10 单'
            ELSE '10 单以上' END AS 客户分层,
       COUNT(*)     AS 客户数,
       SUM(累计金额) AS 该层总金额
FROM cust_orders
GROUP BY 客户分层
ORDER BY 客户数 DESC;

-- Q18. 客户价值分层（简化版 RFM：只看购买频次与金额）★面试常问
WITH c AS (
    SELECT customer_id,
           COUNT(*)             AS F_频次,
           ROUND(SUM(amount), 0) AS M_金额,
           MAX(order_date)      AS 最近购买日
    FROM orders
    GROUP BY customer_id
)
SELECT customer_id, F_频次, M_金额, 最近购买日,
       CASE WHEN F_频次 >= 7 AND M_金额 >= 3000 THEN '高价值'
            WHEN F_频次 >= 4 THEN '潜力客户'
            ELSE '普通/流失预警' END AS 客户标签
FROM c
ORDER BY M_金额 DESC
LIMIT 30;

-- Q19. 每个客户的「复购间隔天数」平均值（判断复购节奏）
--      考点：LAG 按客户分区
SELECT ROUND(AVG(间隔天数), 1) AS 平均复购间隔天数 FROM (
    SELECT customer_id,
           DATEDIFF(order_date,
                    LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)) AS 间隔天数
    FROM orders
) t
WHERE 间隔天数 IS NOT NULL;

-- Q20. 用「3 个月移动平均」做简单的需求预测 ★供应链方向加分项
--      考点：窗口函数 ROWS BETWEEN
SELECT month,
       ROUND(SUM(amount), 0) AS 实际销售额,
       ROUND(AVG(SUM(amount)) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS 三月移动均值
FROM orders
GROUP BY month
ORDER BY month;


-- =====================================================================
-- 做完这 20 题，你就覆盖了：聚合、分组、子查询、JOIN、CASE 透视、
-- 窗口函数（LAG / ROW_NUMBER / SUM OVER / ROWS BETWEEN）、CTE
-- 这些正是「数据分析岗 / 供应链计划岗」面试必考的范围。
-- =====================================================================
