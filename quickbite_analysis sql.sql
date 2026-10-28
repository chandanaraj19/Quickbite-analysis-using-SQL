-- Create the database -- 
CREATE database quickbite_analysis;
use quickbite_analysis;

-- Create Tables & Import Data -- 

-- Customers
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  customer_name VARCHAR(100),
  city VARCHAR(50),
  signup_date DATE,
  customer_segment VARCHAR(20)
);

-- Restaurants
CREATE TABLE restaurants (
  restaurant_id INT PRIMARY KEY,
  restaurant_name VARCHAR(100),
  city VARCHAR(50),
  cuisine VARCHAR(50),
  rating DECIMAL(2,1)
);

-- Menu Items
CREATE TABLE menu_items (
  item_id INT PRIMARY KEY,
  restaurant_id INT,
  item_name VARCHAR(100),
  category VARCHAR(50),
  price DECIMAL(10,2)
);

-- Orders
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  restaurant_id INT,
  order_date DATE,
  order_status VARCHAR(20),
  delivery_minutes DECIMAL(5,2),
  order_amount DECIMAL(10,2),
  discount DECIMAL(10,2)
);

-- Payments
CREATE TABLE payments (
  payment_id INT PRIMARY KEY,
  order_id INT,
  payment_method VARCHAR(20),
  payment_status VARCHAR(20),
  payment_date DATE
);

-- Step 3: Understand the Data
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM restaurants;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM payments;

-- Check Missing Values
-- Check for NULLs in customers
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN customer_name IS NULL OR customer_name='' THEN 1 END) AS missing_name,
  COUNT(CASE WHEN city IS NULL OR city='' THEN 1 END) AS missing_city,
  COUNT(CASE WHEN signup_date IS NULL OR signup_date='' THEN 1 END) AS missing_signup_date,
  COUNT(CASE WHEN customer_segment IS NULL OR customer_segment='' THEN 1 END) AS missing_segment
FROM customers;

-- order table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN order_status IS NULL OR order_status='' THEN 1 END) AS missing_status,
  COUNT(CASE WHEN delivery_minutes IS NULL OR delivery_minutes='' THEN 1 END) AS missing_delivery_time,
  COUNT(CASE WHEN order_amount IS NULL OR order_amount='' THEN 1 END) AS missing_amount,
  COUNT(CASE WHEN discount IS NULL OR discount='' THEN 1 END) AS missing_discount
FROM orders;

-- Payment Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN payment_method IS NULL OR payment_method='' THEN 1 END) AS missing_method,
  COUNT(CASE WHEN payment_status IS NULL OR payment_status='' THEN 1 END) AS missing_status,
  COUNT(CASE WHEN payment_date IS NULL OR payment_date='' THEN 1 END) AS missing_date
FROM payments;

-- Restaurants Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN restaurant_name IS NULL OR restaurant_name='' THEN 1 END) AS missing_name,
  COUNT(CASE WHEN city IS NULL OR city='' THEN 1 END) AS missing_city,
  COUNT(CASE WHEN cuisine IS NULL OR cuisine='' THEN 1 END) AS missing_cuisine,
  COUNT(CASE WHEN rating IS NULL OR rating='' THEN 1 END) AS missing_rating
FROM restaurants;

-- Menu Items Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN item_name IS NULL OR item_name='' THEN 1 END) AS missing_item,
  COUNT(CASE WHEN category IS NULL OR category='' THEN 1 END) AS missing_category,
  COUNT(CASE WHEN price IS NULL OR price='' THEN 1 END) AS missing_price
FROM menu_items;

-- Check Distinct Values - To spot inconsistencies:
-- Customer segments
SELECT DISTINCT customer_segment FROM customers;

-- Order statuses
SELECT DISTINCT order_status FROM orders;

-- Payment statuses
SELECT DISTINCT payment_status FROM payments;

-- Cuisine types
SELECT DISTINCT cuisine FROM restaurants;

DESCRIBE customers;
DESCRIBE restaurants;
DESCRIBE menu_items;
DESCRIBE orders;
DESCRIBE payments;

-- Data Cleanning
-- Convert signup_date from text to DATE
SET SQL_SAFE_UPDATES = 0;
-- Run your update
UPDATE customers
SET signup_date = STR_TO_DATE(signup_date, '%d-%m-%Y')
WHERE signup_date IS NOT NULL AND signup_date <> '';

-- Re-enable safe update mode (recommended)
SET SQL_SAFE_UPDATES = 1;

-- Fill missing customer_segment with 'Unknown'
UPDATE customers
SET customer_segment = 'Unknown'
WHERE customer_segment IS NULL OR customer_segment = '';

## Orders
-- Normalize order_status values
UPDATE orders
SET order_status = CASE 
  WHEN order_status IN ('Delivered','Cancelled','Pending') THEN order_status
  ELSE 'Unknown' END;

-- Ensure discount is not greater than order_amount
UPDATE orders
SET discount = order_amount
WHERE discount > order_amount OR discount IS NULL;

### Payments
-- Remove orphan payments (orders that don’t exist)
DELETE FROM payments
WHERE order_id NOT IN (SELECT order_id FROM orders);

-- Normalize payment_status values
UPDATE payments
SET payment_status = CASE 
  WHEN payment_status IN ('Paid','Pending','Failed') THEN payment_status
  ELSE 'Unknown' END;
  
  ### Clean Menu Items
-- Remove invalid prices
DELETE FROM menu_items
WHERE price IS NULL OR price <= 0;

-- Standardize category values
UPDATE menu_items
SET category = CASE 
  WHEN category IN ('Main Course','Starter','Beverage','Dessert') THEN category
  ELSE 'Other' END;
  
  ## Validation After Cleaning
-- Customers
SELECT DISTINCT customer_segment FROM customers;

-- Orders
SELECT DISTINCT order_status FROM orders;

-- Payments
SELECT DISTINCT payment_status FROM payments;

-- Restaurants
SELECT DISTINCT cuisine FROM restaurants;

-- Menu Items
SELECT DISTINCT category FROM menu_items;

## A. Gateway Settlement Overview
-- 1. Total number of transactions processed



-- 2. Transactions by payment status
SELECT payment_status, COUNT(*) AS count_transactions
FROM payments
GROUP BY payment_status;

-- 3. Percentage of failed transactions
SELECT 
  (COUNT(CASE WHEN payment_status='Failed' THEN 1 END) * 100.0 / COUNT(*)) AS failed_percentage
FROM payments;

-- 4. Total settled revenue (Paid)
SELECT SUM(o.order_amount - o.discount) AS settled_revenue
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
WHERE p.payment_status='Paid';

-- 5. Total leaked revenue from failed payments
SELECT SUM(o.order_amount - o.discount) AS leaked_revenue
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
WHERE p.payment_status='Failed';

-- 6. Total pending cash flow at risk
SELECT SUM(o.order_amount - o.discount) AS pending_cash_flow
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
WHERE p.payment_status='Pending';

-- 7. Payment method generating highest settled revenue
SELECT p.payment_method, SUM(o.order_amount - o.discount) AS total_settled
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
WHERE p.payment_status='Paid'
GROUP BY p.payment_method
ORDER BY total_settled DESC
LIMIT 1;

## B. Payment Channel Analytics
-- 8. Most popular payment method by volume
SELECT payment_method, COUNT(*) AS usage_count
FROM payments
GROUP BY payment_method
ORDER BY usage_count DESC
LIMIT 1;

-- 9. Payment method with highest failure rate
SELECT payment_method,
       COUNT(CASE WHEN payment_status='Failed' THEN 1 END) * 100.0 / COUNT(*) AS failure_rate
FROM payments
GROUP BY payment_method
ORDER BY failure_rate DESC;

-- 10. Payment method with highest success rate
SELECT payment_method,
       COUNT(CASE WHEN payment_status='Paid' THEN 1 END) * 100.0 / COUNT(*) AS success_rate
FROM payments
GROUP BY payment_method
ORDER BY success_rate DESC;

-- 11. Payment methods with failure rate above overall average
WITH overall AS (
  SELECT COUNT(CASE WHEN payment_status='Failed' THEN 1 END) * 100.0 / COUNT(*) AS avg_fail_pct 
  FROM payments
)
SELECT payment_method, 
       COUNT(CASE WHEN payment_status='Failed' THEN 1 END) * 100.0 / COUNT(*) AS fail_rate
FROM payments, overall
GROUP BY payment_method, overall.avg_fail_pct
HAVING fail_rate > overall.avg_fail_pct;

-- 12. Classify payment methods into High/Medium/Low Reliability
SELECT payment_method,
       CASE 
         WHEN COUNT(CASE WHEN payment_status='Failed' THEN 1 END) = 0 THEN 'High Reliability'
         WHEN COUNT(CASE WHEN payment_status='Failed' THEN 1 END) * 100.0 / COUNT(*) <= 8.0 THEN 'Medium Reliability'
         ELSE 'Low Reliability'
       END AS gateway_reliability_tier
FROM payments
GROUP BY payment_method;

## C. Operational & Fulfillment Discrepancies
-- 13. Delivered orders with pending or failed payments
SELECT o.order_id, o.order_status, p.payment_method, p.payment_status, 
       (o.order_amount - o.discount) AS uncollected_amount
FROM orders o 
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status='Delivered' AND p.payment_status != 'Paid';

-- 14. Total uncollected revenue on delivered food
SELECT SUM(o.order_amount - o.discount) AS uncollected_delivered_revenue
FROM orders o 
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status='Delivered' AND p.payment_status != 'Paid';

-- 15. Payment methods with pending payments on delivered orders
SELECT p.payment_method, COUNT(*) AS pending_delivered_count
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
WHERE o.order_status='Delivered' AND p.payment_status='Pending'
GROUP BY p.payment_method;

-- 16. Average value of failed transactions
SELECT AVG(o.order_amount - o.discount) AS avg_failed_order_value
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
WHERE p.payment_status='Failed';

## D. Customer & City Revenue Slippage
-- 17. City with highest leaked revenue
SELECT c.city, SUM(o.order_amount - o.discount) AS leaked_city_revenue
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.payment_status='Failed'
GROUP BY c.city
ORDER BY leaked_city_revenue DESC
LIMIT 1;

-- 18. Revenue leakage by customer segment
SELECT c.customer_segment, SUM(o.order_amount - o.discount) AS segment_leaked_revenue
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.payment_status='Failed'
GROUP BY c.customer_segment;

-- 19. Customers impacted by failed payments
SELECT DISTINCT c.customer_name, c.city, p.payment_method
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.payment_status='Failed';

-- 20. High-value orders that failed (above average order value)
WITH avg_order AS (
  SELECT AVG(order_amount - discount) AS avg_val 
  FROM orders
)
SELECT p.order_id, p.payment_method, (o.order_amount - o.discount) AS failed_amount
FROM payments p 
JOIN orders o ON p.order_id = o.order_id, avg_order a
WHERE p.payment_status='Failed' 
  AND (o.order_amount - o.discount) > a.avg_val;

## E. Gateway Rankings & Summary
-- 21. Rank payment channels by volume
SELECT payment_method, COUNT(*) AS total_orders,
       RANK() OVER (ORDER BY COUNT(*) DESC) AS volume_rank
FROM payments
GROUP BY payment_method;

-- 22. Rank payment channels by realized revenue
SELECT p.payment_method, SUM(o.order_amount - o.discount) AS settled_revenue,
       DENSE_RANK() OVER (ORDER BY SUM(o.order_amount - o.discount) DESC) AS revenue_rank
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
WHERE p.payment_status='Paid'
GROUP BY p.payment_method;

-- 23. Total number of failed payments
SELECT COUNT(*) AS failed_payments
FROM payments
WHERE payment_status='Failed';
















  
  






