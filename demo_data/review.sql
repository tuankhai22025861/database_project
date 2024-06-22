INSERT INTO review (star, description, customer_id, product_id, shop_id)
SELECT 
    CASE 
        WHEN random() < 0.6 THEN random() * (5 - 4) + 4  -- Good review (60% probability), star from 4 to 5
        WHEN random() < 0.9 THEN random() * (3.9 - 3) + 3  -- Neutral review (30% probability), star from 3 to 3.9
        ELSE random() * 3  -- Bad review (10% probability), star from 0 to 3
    END AS star,
    CASE 
        WHEN random() < 0.6 THEN 
            CASE 
                WHEN random() < 0.5 THEN 'Excellent'
                ELSE 'Very Good'
            END
        WHEN random() < 0.9 THEN 
            CASE 
                WHEN random() < 0.5 THEN 'Good'
                ELSE 'OK'
            END
        ELSE 
            CASE 
                WHEN random() < 0.5 THEN 'This is not OK'
                ELSE 'I want my money back'
            END
    END AS description,
    floor(random() * 70) + 1 AS customer_id,
    floor(random() * 900) + 1 AS product_id,
    floor(random() * 100) + 1 AS shop_id
FROM generate_series(1, 10000);
