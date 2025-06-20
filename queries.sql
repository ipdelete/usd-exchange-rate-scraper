-- Total current exchange rates
SELECT COUNT(*) as total_current_rates FROM exchange_rate;

-- Total historical versions
SELECT COUNT(*) as total_versions FROM exchange_rate_version;

-- Unique currencies tracked
SELECT COUNT(DISTINCT currency_code) as unique_currencies 
FROM exchange_rate 
WHERE currency_code IS NOT NULL;

-- List all available tables
SELECT name FROM sqlite_master WHERE type='table';

-- See all commits and their timing
SELECT id, hash, commit_at, namespace FROM commits ORDER BY commit_at;

-- Current rates for major currencies
SELECT currency_code, base_code, rate, time_last_update_utc
FROM exchange_rate 
WHERE currency_code IN ('EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF')
ORDER BY currency_code;

-- Most expensive currencies (lowest rates - takes more USD to buy 1 unit)
SELECT currency_code, base_code, rate 
FROM exchange_rate 
WHERE currency_code IS NOT NULL 
ORDER BY rate ASC 
LIMIT 10;

-- Least expensive currencies (highest rates - takes less USD to buy 1 unit)
SELECT currency_code, base_code, rate 
FROM exchange_rate 
WHERE currency_code IS NOT NULL 
ORDER BY rate DESC 
LIMIT 10;

-- Currencies with version history
SELECT 
  currency_code,
  COUNT(*) as version_count,
  MIN(time_last_update_utc) as earliest_update,
  MAX(time_last_update_utc) as latest_update
FROM exchange_rate_version 
WHERE currency_code IS NOT NULL
GROUP BY currency_code
HAVING COUNT(*) > 1
ORDER BY version_count DESC;

-- Rate changes between versions
SELECT 
  erv1.currency_code,
  erv1.rate as old_rate,
  erv2.rate as new_rate,
  (erv2.rate - erv1.rate) as absolute_change,
  ROUND(((erv2.rate - erv1.rate) / erv1.rate) * 100, 4) as percent_change,
  c1.commit_at as old_date,
  c2.commit_at as new_date
FROM exchange_rate_version erv1
JOIN exchange_rate_version erv2 ON erv1._item = erv2._item 
  AND erv1._version = 1 AND erv2._version = 2
JOIN commits c1 ON erv1._commit = c1.id
JOIN commits c2 ON erv2._commit = c2.id
WHERE erv1.currency_code IS NOT NULL 
  AND erv1.rate != erv2.rate
ORDER BY ABS(percent_change) DESC;

-- Biggest gainers
SELECT 
  erv1.currency_code,
  erv1.rate as old_rate,
  erv2.rate as new_rate,
  ROUND(((erv2.rate - erv1.rate) / erv1.rate) * 100, 4) as percent_gain
FROM exchange_rate_version erv1
JOIN exchange_rate_version erv2 ON erv1._item = erv2._item 
  AND erv1._version = 1 AND erv2._version = 2
WHERE erv1.currency_code IS NOT NULL 
  AND erv2.rate > erv1.rate
ORDER BY percent_gain DESC
LIMIT 10;

-- Biggest losers
SELECT 
  erv1.currency_code,
  erv1.rate as old_rate,
  erv2.rate as new_rate,
  ROUND(((erv2.rate - erv1.rate) / erv1.rate) * 100, 4) as percent_loss
FROM exchange_rate_version erv1
JOIN exchange_rate_version erv2 ON erv1._item = erv2._item 
  AND erv1._version = 1 AND erv2._version = 2
WHERE erv1.currency_code IS NOT NULL 
  AND erv2.rate < erv1.rate
ORDER BY percent_loss ASC
LIMIT 10;

-- Most frequently changed columns
SELECT 
  c.name as column_name,
  COUNT(*) as change_frequency,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM exchange_rate_changed), 2) as percent_of_changes
FROM exchange_rate_changed erc
JOIN columns c ON erc.column = c.id
GROUP BY c.name
ORDER BY change_frequency DESC;

-- Most popular currencies by version count
SELECT 
  erv.currency_code,
  COUNT(DISTINCT erv._version) as version_count,
  COUNT(DISTINCT c.commit_at) as commit_count
FROM exchange_rate_version erv
JOIN commits c ON erv._commit = c.id
WHERE erv.currency_code IS NOT NULL
GROUP BY erv.currency_code
ORDER BY version_count DESC
LIMIT 15;

-- Currencies with no rate changes between versions
SELECT er.currency_code, er.rate, er.time_last_update_utc
FROM exchange_rate er
WHERE er.currency_code NOT IN (
  SELECT DISTINCT erv1.currency_code
  FROM exchange_rate_version erv1
  JOIN exchange_rate_version erv2 ON erv1._item = erv2._item 
    AND erv1._version = 1 AND erv2._version = 2
  WHERE erv1.rate != erv2.rate
)
AND er.currency_code IS NOT NULL
ORDER BY er.currency_code;

-- Volatility analysis between two versions
SELECT 
  erv1.currency_code,
  ABS(ROUND(((erv2.rate - erv1.rate) / erv1.rate) * 100, 4)) as volatility_percent,
  CASE 
    WHEN ABS(((erv2.rate - erv1.rate) / erv1.rate) * 100) > 2 THEN 'High'
    WHEN ABS(((erv2.rate - erv1.rate) / erv1.rate) * 100) > 0.5 THEN 'Medium'
    ELSE 'Low'
  END as volatility_category
FROM exchange_rate_version erv1
JOIN exchange_rate_version erv2 ON erv1._item = erv2._item 
  AND erv1._version = 1 AND erv2._version = 2
WHERE erv1.currency_code IS NOT NULL
ORDER BY volatility_percent DESC;

-- Daily updates of currencies
SELECT 
  DATE(commit_at) as update_date,
  COUNT(*) as currencies_updated,
  COUNT(DISTINCT currency_code) as unique_currencies
FROM commits c
JOIN exchange_rate_version erv ON c.id = erv._commit
WHERE erv.currency_code IS NOT NULL
GROUP BY DATE(commit_at)
ORDER BY update_date;

-- Recency of exchange rate updates
SELECT 
  currency_code,
  rate,
  time_last_update_utc,
  CASE 
    WHEN time_last_update_utc LIKE '%20 Jun 2025%' THEN 'Today'
    WHEN time_last_update_utc LIKE '%19 Jun 2025%' THEN 'Yesterday'
    ELSE 'Older'
  END as update_recency
FROM exchange_rate
WHERE currency_code IS NOT NULL
ORDER BY time_last_update_utc DESC;

-- Exchange rate for a specific currency
-- Replace 'EUR' with any currency you want to analyze
SELECT 
  currency_code,
  base_code,
  rate,
  time_last_update_utc,
  _commit
FROM exchange_rate 
WHERE currency_code = 'EUR';

-- Exchange rate strength categorization
SELECT 
  currency_code,
  rate,
  CASE 
    WHEN rate < 1 THEN 'Strong currency'
    WHEN rate BETWEEN 1 AND 10 THEN 'Moderate currency'
    ELSE 'Weak currency'
  END as strength_category
FROM exchange_rate 
WHERE currency_code IN ('EUR', 'GBP', 'JPY', 'CAD', 'AUD')
ORDER BY rate;