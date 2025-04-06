CREATE DATABASE final_project1;
USE final_project1;

UPDATE customers
SET Gender = NULL
WHERE Gender = '';

UPDATE customers
SET Age = NULL
WHERE Age = '';

ALTER TABLE customers CHANGE Age Age INT NULL;

SELECT * FROM transactions;

CREATE TABLE transactions(
date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2)
);

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW VARIABLES LIKE 'secure_file_priv';

SELECT * FROM transactions;
SELECT * FROM customers;

#1 список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, 
#средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц, количество всех операций по клиенту за период;
SELECT ID_client, 
    ROUND(AVG(Sum_payment), 2) AS avg_check,
    ROUND(SUM(Sum_payment) / 13, 2) AS avg_monthly_sum,
    COUNT(Id_check) AS tr_count
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY ID_client
HAVING COUNT(DISTINCT date_new)=13;

#2
#a средняя сумма чека в месяц;
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month_y,
        ROUND(AVG(Sum_payment),2) AS monthly_avg
FROM transactions
GROUP BY month_y
ORDER BY month_y;

#b среднее количество операций в месяц;
SELECT SUM(a.monthly_tr)/13 as avg_count_tr
FROM(
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month_y,
        COUNT(Sum_payment) AS monthly_tr
FROM transactions
GROUP BY month_y
ORDER BY month_y) a;

#c среднее количество клиентов, которые совершали операции;
SELECT AVG(a.monthly_cl) as avg_count_cl
FROM(
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month_y,
        COUNT(DISTINCT ID_client) AS monthly_cl
FROM transactions
GROUP BY month_y
ORDER BY month_y) a;

#d долю от общего количества операций за год и долю в месяц от общей суммы операций;
SELECT a.month_y, (a.monthly_ch/(SELECT COUNT(Id_check) FROM transactions)) * 100
FROM(
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month_y,
        COUNT(Id_check) AS monthly_ch
FROM transactions
GROUP BY month_y
ORDER BY month_y) a;

#f вывести % соотношение M/F/NA в каждом месяце с их долей затрат;
SELECT DATE_FORMAT(t.date_new, '%Y-%m') AS month_y, c.Gender,
        COUNT(DISTINCT t.ID_client) AS client_count,
        SUM(t.Sum_payment) AS gender_spent,
        (COUNT(DISTINCT t.ID_client) / SUM(COUNT(DISTINCT t.ID_client)) OVER(PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m'))) * 100 AS gender_ratio,
        (SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER(PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m'))) * 100 AS gender_spent_share 
FROM transactions as t
JOIN customers as c
ON t.ID_client = c.Id_client
GROUP BY month_y, c.Gender;

#3 возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
#с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.
WITH Age_Groups AS (
    SELECT Id_client,
        CASE 
            WHEN Age IS NULL THEN 'Неизвестно'
            WHEN Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN Age BETWEEN 50 AND 59 THEN '50-59'
            ELSE '60+'
        END AS age_group
    FROM customers),
    
Total_Stats AS (
SELECT ag.age_group,
    SUM(t.Sum_payment) AS total_sum,
    COUNT(t.Id_check) AS total_operations
FROM transactions t
JOIN Age_Groups ag ON t.ID_client = ag.Id_client
GROUP BY ag.age_group),

Quarterly_Stats AS (
    SELECT ag.age_group,
        YEAR(t.date_new) AS year,
        QUARTER(t.date_new) AS quarter,
        COUNT(t.ID_check) AS total_operations_q,
        SUM(t.Sum_payment) AS total_sum_q,
        AVG(t.Sum_payment) AS avg_check_q,
        (SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER (PARTITION BY YEAR(t.date_new), QUARTER(t.date_new))) * 100 AS revenue_share_q
    FROM transactions t
    JOIN Age_Groups ag ON t.ID_client = ag.Id_client
    GROUP BY ag.age_group, YEAR(t.date_new), QUARTER(t.date_new))
    
SELECT 
    t.age_group,
    t.total_sum,
    t.total_operations,
    q.year,
    q.quarter,
    q.total_operations_q,
    q.total_sum_q,
    q.avg_check_q,
    q.revenue_share_q
FROM Total_Stats t
LEFT JOIN Quarterly_Stats q ON t.age_group = q.age_group
ORDER BY q.year, q.quarter, t.age_group;

