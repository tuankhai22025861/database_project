
INSERT INTO product_shop (quantity, product_id, warehouse_id, shop_id)
SELECT
    floor(random() * 100) + 1 AS quantity,
    floor(random() * 900) + 1 AS product_id,
    floor(random() * 100) + 1 AS warehouse_id,
    floor(random() * 100) + 1 AS shop_id
FROM generate_series(1, 100) AS gs
WHERE EXISTS (
    SELECT 1 FROM product WHERE product_id = floor(random() * 900) + 1
) AND EXISTS (
    SELECT 1 FROM warehouse WHERE warehouse_id = floor(random() * 100) + 1
) AND EXISTS (
    SELECT 1 FROM shop WHERE shop_id = floor(random() * 100) + 1
);
