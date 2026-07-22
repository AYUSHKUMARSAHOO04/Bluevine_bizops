CREATE DATABASE bluevine_bizops;
USE bluevine_bizops;

RENAME TABLE bluevinetask TO clients;
DROP TABLE IF EXISTS Spend;

CREATE TABLE clients (
    client VARCHAR(20),
    account_created VARCHAR(20),
    channel VARCHAR(20),
    sub_channel VARCHAR(30),
    date VARCHAR(20),
    gross_profit DECIMAL(10,2)
);

CREATE TABLE Spend (
    channel VARCHAR(20) NOT NULL,
    sub_channel VARCHAR(30) NOT NULL,
    january DECIMAL(10,2) NOT NULL,
    february DECIMAL(10,2) NOT NULL,
    march DECIMAL(10,2) NOT NULL
);

INSERT INTO Spend (channel, sub_channel, january, february, march)
VALUES
('Direct', 'Facebook', 2211.00, 3809.00, 5467.00),
('Direct', 'Google',   1385.00, 1710.00, 4578.00),
('Direct', 'LinkedIn',  702.00, 1007.00, 1458.00),
('Partner', 'AffilCo', 5928.00,10055.00,10802.00),
('Partner', 'FundCo', 20742.00,29117.00,22220.00),
('Partner', 'ReferCo', 1949.00, 4016.00, 6257.00);

SELECT * FROM Spend;
SELECT * FROM Clients;

ALTER TABLE clients
ADD COLUMN date_new DATE,
ADD COLUMN account_created_new DATE;
UPDATE clients
SET date_new = STR_TO_DATE(`date`, '%m/%d/%Y'),
account_created_new = STR_TO_DATE(account_created, '%m/%d/%Y');

SELECT date, date_new,
    account_created,
    account_created_new
FROM clients
LIMIT 10;

ALTER TABLE clients
DROP COLUMN date,
DROP COLUMN account_created;

ALTER TABLE clients
RENAME COLUMN date_new TO activity_date;
ALTER TABLE clients
RENAME COLUMN account_created_new TO account_created;

DESCRIBE clients;

-- Total Customers
-- Purpose: Total acquired customers.
SELECT COUNT(DISTINCT client) AS total_customers
FROM clients;

-- Customers by Channel
-- Purpose: Compare Direct vs Partner acquisition.
SELECT channel, COUNT(DISTINCT client) AS customers
FROM clients
GROUP BY channel;

-- Customers by Sub-channel
-- Purpose: Identify which acquisition source brings in the most customers.
SELECT sub_channel, COUNT(DISTINCT client) AS customers
FROM clients
GROUP BY sub_channel
ORDER BY customers DESC;

-- Total Gross Profit by Channel
SELECT channel, ROUND(SUM(gross_profit),2) AS total_gross_profit
FROM clients
GROUP BY channel
ORDER BY total_gross_profit DESC;

-- Total Gross Profit by Sub-channel
SELECT sub_channel, ROUND(SUM(gross_profit),2) AS total_gross_profit
FROM clients
GROUP BY sub_channel
ORDER BY total_gross_profit DESC;

-- Average Gross Profit per Customer
SELECT sub_channel,
    COUNT(DISTINCT client) AS customers,
    ROUND(SUM(gross_profit),2) AS total_gross_profit,
    ROUND(SUM(gross_profit) / COUNT(DISTINCT client),2) AS avg_gp_per_customer
FROM clients
GROUP BY sub_channel
ORDER BY avg_gp_per_customer DESC;

-- Monthly Gross Profit Trend
SELECT YEAR(activity_date) AS year,
    MONTH(activity_date) AS month,
    MONTHNAME(activity_date) AS month_name,
    ROUND(SUM(gross_profit),2) AS total_gross_profit
FROM clients
GROUP BY YEAR(activity_date), MONTH(activity_date), MONTHNAME(activity_date)
ORDER BY year, month;

-- Daily Gross Profit Trend
SELECT activity_date,
    ROUND(SUM(gross_profit),2) AS total_gross_profit
FROM clients
GROUP BY activity_date;

-- Customer Lifetime Gross Profit
SELECT client, sub_channel,
    ROUND(SUM(gross_profit),2) AS lifetime_gp
FROM clients
GROUP BY client, sub_channel
ORDER BY lifetime_gp DESC;

-- DESCRIPTIVE ANALYSIS

-- CAC by Sub-channel
SELECT s.sub_channel,
    COUNT(DISTINCT c.client) AS customers,
    ROUND(s.january + s.february + s.march,2) AS total_spend,
    ROUND((s.january + s.february + s.march)/COUNT(DISTINCT c.client),2) AS CAC
FROM Spend s
JOIN clients c
ON s.sub_channel = c.sub_channel
GROUP BY s.sub_channel, s.january, s.february, s.march
ORDER BY CAC DESC;

-- CAC vs Average Gross Profit
SELECT s.channel, s.sub_channel,
    COUNT(DISTINCT c.client) AS customers,
    ROUND(s.january + s.february + s.march,2) AS total_spend,
    ROUND((s.january + s.february + s.march) / COUNT(DISTINCT c.client),2) AS CAC,
    ROUND(SUM(c.gross_profit),2) AS total_gp,
    ROUND(SUM(c.gross_profit) / COUNT(DISTINCT c.client),2) AS avg_gp_per_customer,
    ROUND((SUM(c.gross_profit) / COUNT(DISTINCT c.client)) /
    ((s.january + s.february + s.march) / COUNT(DISTINCT c.client)),2) AS payback_ratio
FROM clients c
JOIN Spend s
ON c.sub_channel = s.sub_channel
GROUP BY s.channel, s.sub_channel, s.january, s.february, s.march
ORDER BY payback_ratio DESC;

-- PREDICTIVE ANALYSIS

-- Monthly Gross Profit by Sub-channel
SELECT sub_channel,
    YEAR(activity_date) AS year,
    MONTHNAME(activity_date) AS month,
    ROUND(SUM(gross_profit),2) AS monthly_gp
FROM clients
GROUP BY sub_channel, YEAR(activity_date), MONTH(activity_date), MONTHNAME(activity_date)
ORDER BY sub_channel, year;

-- Monthly Growth
SELECT sub_channel,
    MONTHNAME(activity_date) AS month,
    ROUND(SUM(gross_profit),2) AS monthly_gp,
    ROUND(SUM(gross_profit)-LAG(SUM(gross_profit))
        OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date)),2) AS monthly_growth
FROM clients
GROUP BY sub_channel, MONTH(activity_date), MONTHNAME(activity_date)
ORDER BY sub_channel;

-- Monthly Growth Percentage
SELECT sub_channel,
    MONTHNAME(activity_date) AS month,
    ROUND(SUM(gross_profit),2) AS monthly_gp,
    ROUND(LAG(SUM(gross_profit)) OVER(PARTITION BY sub_channel
            ORDER BY MONTH(activity_date)),2) AS previous_month_gp,
    ROUND(SUM(gross_profit) - LAG(SUM(gross_profit))
        OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date)),2) AS gp_change,
    ROUND((SUM(gross_profit)-LAG(SUM(gross_profit))
            OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date))) / LAG(SUM(gross_profit))
        OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date)) * 100,2) AS growth_percent,

    CASE WHEN LAG(SUM(gross_profit))
             OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date)) IS NULL
        THEN 'Initial Month'

        WHEN SUM(gross_profit) > LAG(SUM(gross_profit))
             OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date))
        THEN 'Increasing'

        WHEN SUM(gross_profit) < LAG(SUM(gross_profit))
             OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date))
        THEN 'Decreasing'

        ELSE 'Stable'
    END AS trend
FROM clients

GROUP BY sub_channel, MONTH(activity_date), MONTHNAME(activity_date)
ORDER BY sub_channel, MONTH(activity_date);

-- Zero-profit customers
SELECT sub_channel,
    COUNT(DISTINCT client) AS total_clients,
    COUNT(DISTINCT CASE WHEN gross_profit > 0 THEN client END) AS profit_clients,
    COUNT(DISTINCT CASE WHEN client NOT IN (
        SELECT DISTINCT client
        FROM clients
        WHERE gross_profit > 0
    ) THEN client END) AS zero_profit_clients
FROM clients
GROUP BY sub_channel;

-- Average Monthly GP
SELECT
    sub_channel,
    ROUND(AVG(gp_change),2) AS avg_monthly_gp_increase
FROM (
    SELECT
        sub_channel,
        MONTH(activity_date) AS month_no,
        SUM(gross_profit)
        - LAG(SUM(gross_profit))
          OVER(PARTITION BY sub_channel ORDER BY MONTH(activity_date))
        AS gp_change
    FROM clients
    GROUP BY sub_channel, MONTH(activity_date)
) t
WHERE gp_change IS NOT NULL
GROUP BY sub_channel
ORDER BY sub_channel;

