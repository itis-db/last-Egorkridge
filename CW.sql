DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price NUMERIC(10, 2) CHECK (price > 0)
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    order_date DATE NOT NULL,
    customer_id INTEGER NOT NULL
);

CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER CHECK (quantity > 0),
    amount NUMERIC(10, 2) CHECK (amount >= 0),
    CONSTRAINT fk_order FOREIGN KEY(order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_product FOREIGN KEY(product_id) REFERENCES products(product_id)
);

INSERT INTO products (product_name, category, price)
VALUES 
    ('Ноутбук Lenovo', 'Электроника', 45000.00),
    ('Смартфон Xiaomi', 'Электроника', 22000.50),
    ('Кофеварка Bosch', 'Бытовая техника', 15000.00),
    ('Футболка мужская', 'Одежда', 1500.00),
    ('Джинсы женские', 'Одежда', 3500.99),
    ('Шампунь Head&Shoulders', 'Косметика', 450.50),
    ('Книга "SQL для всех"', 'Книги', 1200.00),
    ('Монитор Samsung', 'Электроника', 18000.00),
    ('Чайник электрический', 'Бытовая техника', 2500.00),
    ('Кроссовки Nike', 'Одежда', 7500.00),
    ('Планшет Huawei', 'Электроника', 32000.00),
    ('Блендер Philips', 'Бытовая техника', 6500.00);

INSERT INTO orders (order_date, customer_id)
VALUES 
    ('2025-05-01', 101),
    ('2025-05-03', 102),
    ('2025-05-05', 103),
    ('2025-05-10', 104),
    ('2025-05-15', 101),
    ('2025-05-20', 105),
    ('2025-06-01', 102),
    ('2025-06-02', 103),
    ('2024-05-01', 104),
    ('2024-05-15', 105),
    ('2024-06-01', 101);

INSERT INTO order_items (order_id, product_id, quantity, amount)
VALUES 
    (1, 1, 1, 45000.00),
    (1, 8, 1, 18000.00),
    (2, 2, 1, 22000.50),
    (2, 4, 2, 3000.00),
    (3, 5, 1, 3500.99),
    (3, 10, 1, 7500.00),
    (3, 6, 3, 1351.50),
    (4, 3, 1, 15000.00),
    (4, 9, 1, 2500.00),
    (5, 11, 1, 32000.00),
    (5, 12, 1, 6500.00),
    (6, 7, 5, 6000.00),
    (7, 1, 1, 45000.00),
    (7, 2, 1, 22000.50),
    (8, 5, 2, 7001.98),
    (9, 3, 1, 15000.00),
    (9, 6, 2, 901.00),
    (10, 4, 3, 4500.00),
    (10, 10, 1, 7500.00),
    (11, 7, 2, 2400.00),
    (11, 11, 1, 32000.00);

WITH sales_data AS (
    SELECT 
        p.category,
        SUM(oi.amount) AS total_sales,
        COUNT(DISTINCT oi.order_id) AS order_count
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.category
)
SELECT 
    category AS "Категория",
    total_sales AS "Общий объем продаж",
    ROUND(total_sales / order_count, 2) AS "Средний чек по категории",
    ROUND(total_sales * 100.0 / (SELECT SUM(amount) FROM order_items), 2) AS "Доля категории, %"
FROM sales_data
ORDER BY total_sales DESC;

WITH customer_orders AS (
    SELECT
        o.customer_id,
        o.order_id,
        o.order_date,
        SUM(oi.amount) AS order_total,
        COUNT(oi.item_id) AS items_count
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id
),
customer_stats AS (
    SELECT
        customer_id,
        SUM(order_total) AS total_spent,
        COUNT(order_id) AS orders_count,
        ROUND(AVG(order_total), 2) AS avg_order_amount,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date
    FROM customer_orders
    GROUP BY customer_id
)
SELECT
    co.customer_id AS "ID клиента",
    co.order_id AS "ID заказа",
    co.order_date AS "Дата заказа",
    co.order_total AS "Сумма заказа",
    co.items_count AS "Кол-во позиций",
    cs.total_spent AS "Общая сумма покупок",
    cs.avg_order_amount AS "Средний чек",
    ROUND((co.order_total - cs.avg_order_amount)::NUMERIC, 2) AS "Отклонение от среднего",
    cs.orders_count AS "Всего заказов",
    cs.first_order_date AS "Первый заказ",
    cs.last_order_date AS "Последний заказ"
FROM customer_orders co
JOIN customer_stats cs ON co.customer_id = cs.customer_id
ORDER BY co.customer_id, co.order_date;

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        EXTRACT(YEAR FROM order_date) AS year,
        EXTRACT(MONTH FROM order_date) AS month_num,
        SUM(oi.amount) AS total_sales,
        COUNT(DISTINCT o.order_id) AS orders_count
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY DATE_TRUNC('month', order_date), EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
)
SELECT
    TO_CHAR(month, 'YYYY-MM') AS "Период",
    total_sales AS "Объем продаж",
    orders_count AS "Кол-во заказов",
    ROUND(total_sales / orders_count, 2) AS "Средний чек",
    LAG(total_sales) OVER (ORDER BY month) AS "Продажи пред. мес.",
    ROUND((total_sales - LAG(total_sales) OVER (ORDER BY month)) / 
          NULLIF(LAG(total_sales) OVER (ORDER BY month), 0) * 100, 2) AS "Изменение к пред. мес., %",
    LAG(total_sales) OVER (PARTITION BY month_num ORDER BY year) AS "Продажи год назад",
    ROUND((total_sales - LAG(total_sales) OVER (PARTITION BY month_num ORDER BY year)) / 
          NULLIF(LAG(total_sales) OVER (PARTITION BY month_num ORDER BY year), 0) * 100, 2) AS "Изменение к году назад, %"
FROM monthly_sales
ORDER BY month;