INSERT INTO orders (customer_id, product_id, status, total_with_tax, total_with_out_tax, order_date, cash, card, voucher, quantity)
SELECT
    floor(random() * 70) + 1 AS customer_id,
    floor(random() * 900) + 1 AS product_id,
    CASE floor(random() * 5)
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'confirmed'
        WHEN 2 THEN 'delivering'
        WHEN 3 THEN 'delivered'
        ELSE 'cancel'
    END AS status,
    CAST(random() * 50 + 50 AS numeric(10,2)) AS total_with_tax,  -- random value between 50 and 100
    CAST(random() * 50 + 45 AS numeric(10,2)) AS total_with_out_tax,  -- random value between 45 and 95
    CURRENT_DATE - INTERVAL '1 day' * floor(random() * 365) AS order_date,
    CASE WHEN random() < 0.5 THEN true ELSE false END AS cash,
    CASE WHEN random() < 0.5 THEN true ELSE false END AS card,
    CASE WHEN random() < 0.3 THEN null ELSE floor(random() * 6) + 5 END AS voucher,  -- 30% chance of null, otherwise 5 to 10
    floor(random() * 50) + 1 AS quantity
FROM generate_series(1, 10000);  -- insert 10000 rows to ensure we get 100 valid rows based on probability
