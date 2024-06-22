
INSERT INTO warehouse (in_date, out_date, address, sold)
SELECT
    CURRENT_DATE - INTERVAL '1 day' * floor(random() * 365) AS in_date,
    CASE 
        WHEN random() < 0.7 THEN CURRENT_DATE  -- 70% probability of having an out_date
        ELSE NULL
    END AS out_date,
    'Address ' || floor(random() * 1000) + 1 AS address,
    floor(random() * 100) AS sold
FROM generate_series(1, 100);
