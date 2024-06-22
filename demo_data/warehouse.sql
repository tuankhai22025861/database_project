INSERT INTO warehouse (in_date, out_date, address, sold)
SELECT
    CURRENT_DATE - INTERVAL '1 day' * floor(random() * 365) AS in_date,
    CASE 
        WHEN random() < 0.7 THEN CURRENT_DATE  -- 70% probability of having an out_date
        ELSE NULL
    END AS out_date,
    CASE floor(random() * 20)
        WHEN 0 THEN '123 Main Street'
        WHEN 1 THEN '456 Elm Avenue'
        WHEN 2 THEN '789 Oak Lane'
        WHEN 3 THEN '101 Pine Road'
        WHEN 4 THEN '222 Maple Court'
        WHEN 5 THEN '333 Cedar Street'
        WHEN 6 THEN '444 Birch Drive'
        WHEN 7 THEN '555 Willow Lane'
        WHEN 8 THEN '666 Spruce Avenue'
        WHEN 9 THEN '777 Juniper Road'
        WHEN 10 THEN '888 Sycamore Lane'
        WHEN 11 THEN '999 Ash Street'
        WHEN 12 THEN '111 Pinecrest Drive'
        WHEN 13 THEN '222 Redwood Avenue'
        WHEN 14 THEN '333 Magnolia Lane'
        WHEN 15 THEN '444 Cypress Road'
        WHEN 16 THEN '555 Birchwood Drive'
        WHEN 17 THEN '666 Hawthorn Lane'
        WHEN 18 THEN '777 Oakwood Avenue'
        WHEN 19 THEN '888 Cedar Lane'
    END AS address,
    floor(random() * 100) AS sold
FROM generate_series(1, 10000);
