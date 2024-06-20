--1.INSERT NEW CUSTOMER
create or replace function insert_new_customer(
	p_address text,
	p_fullname text,
	p_dob date,
	p_gender char(1),
	p_pass_word text
)returns text
as $$
begin 
	insert into customer(address,fullname,dob,gender,pass_word)
	values(p_address,p_fullname,p_dob,p_gender,p_pass_word);
	return 'Insert successfully';

exception
	when others then
	return 'Insert failed: '||SQLERRM;
end;
$$ language plpgsql;
select * from insert_new_customer('123 Ngo','Quang','1999-9-9','M','quincy')
select * from customer
--2.FIND PRODUCT 
create or replace function find_product(
	p_category_id int,
	p_product_name text
)returns table(
	product_id int,
	product_name text,
	description text,
	price money,
	category_id int
)as $$
begin 
	return query
	select * from product p
	where p.product_name = p_product_name and p.category_id = p_category_id;
end;
$$ language plpgsql;
--3.CHECK FOR SUFFICIENT STOCKS
create type ret_check as(
	status int,
	product_shop_id int 
);

create or replace function check_stocks(
	p_product_id int,
	p_shop_id int,
	p_quantity int
)returns ret_check
as $$ 
declare 
	v_a ret_check;
	v_quantity int;
begin
	v_a.status := 0;
	v_a.product_shop_id := null;
	select ps.quantity,ps.product_shop_id
	into v_quantity,v_a.product_shop_id from product_shop ps
	where ps.product_id = p_product_id 
	and ps.shop_id = p_shop_id
	and ps.quantity > 0;
--Neu khong du hang
	if v_quantity < p_quantity then
	v_a.status := 2;
--Neu du hang
	elseif v_quantity > p_quantity then
	v_a.status := 1;
--Neu khong co hang		
	else 	
	v_a.status := 0;
	end if;
	return v_a;
end;
$$ language plpgsql;
select * from check_stocks(1,1,10);
--4.MAKE ORDER
CREATE OR REPLACE FUNCTION make_order_2(
    customer_id INT,
    shop_id INT,
    product_id INT,
    order_quantity INT
) RETURNS TABLE (
    order_id INT,
    success BOOLEAN,
    message TEXT
) AS
$$
DECLARE
    v_check_result RECORD;
    v_order_id INT;
    v_price NUMERIC;
    v_total_wo_tax NUMERIC;
    v_total_w_tax NUMERIC;
BEGIN
    -- Check product availability in the specified shop using check_stocks function
    SELECT * INTO v_check_result FROM check_stocks(product_id, shop_id, order_quantity);

    -- If not enough quantity is available
    IF v_check_result.status = 2 THEN
        RETURN QUERY SELECT NULL::INT, FALSE, 'Not enough quantity in stock'::TEXT;
        RETURN;
    ELSIF v_check_result.status = 0 THEN
        RETURN QUERY SELECT NULL::INT, FALSE, 'Product not available in the shop'::TEXT;
        RETURN;
    END IF;

    -- Get the product price
    SELECT p.price INTO v_price
    FROM product p
    WHERE p.product_id = product_id;

    -- Calculate total prices
    v_total_wo_tax := v_price * order_quantity;
    v_total_w_tax := v_total_wo_tax; -- Assuming no tax for simplicity, adjust as needed

    -- Create a new order
    INSERT INTO orders (status, total_with_tax, total_with_out_tax, order_date, cash, card, voucher, customer_id, product_id)
    VALUES ('pending', v_total_w_tax, v_total_wo_tax, CURRENT_DATE, FALSE, FALSE, 0, customer_id, product_id)
    RETURNING orders.order_id INTO v_order_id;

    -- Reduce the quantity in the product_shop table
    UPDATE product_shop
    SET quantity = quantity - order_quantity
    WHERE product_shop_id = v_check_result.product_shop_id;

    -- Return the success message
    RETURN QUERY SELECT v_order_id, TRUE, 'Order created successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;
-- select * from make_order(1,1,1,10000)
-- select * from make_order(1,1,1,10)
--5.CHECK FOR CUSTOMER ORDER
CREATE OR REPLACE FUNCTION check_order(
    p_customer_id INT
) RETURNS TABLE(
    customer_id INT,
    order_id INT,
    total_with_out_tax MONEY,
    total_with_tax MONEY,
    order_date DATE,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.customer_id,
        o.order_id,
        o.total_with_out_tax,
        o.total_with_tax,
        o.order_date,
        o.status
    FROM orders AS o
    WHERE o.customer_id = p_customer_id
	ORDER BY o.order_date DESC;
END;
$$ LANGUAGE plpgsql;
select * from check_order(1);
--6.TRIGGER FOR UPDATE SHOP RATING
CREATE OR REPLACE FUNCTION update_shop_rating()
RETURNS TRIGGER AS $$
DECLARE
    total_star NUMERIC(3,2);
BEGIN
    -- Calculate the average rating for the shop
    SELECT AVG(star) INTO total_star
    FROM review
    WHERE shop_id = NEW.shop_id;

    -- Update the shop table with the new average rating
    UPDATE shop
    SET rating = total_star
    WHERE shop_id = NEW.shop_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_update_shop_rating
AFTER INSERT OR UPDATE ON review
FOR EACH ROW
EXECUTE FUNCTION update_shop_rating();
INSERT INTO review (star, description, customer_id, product_id, shop_id)
VALUES (4.5, 'Great product!', 1, 1, 1);
select * from review;
select * from shop;

--7.CHECK CUSTOMER PASSWORD
create or replace function check_password(
	p_customer_id int,
	p_password text
)returns bool
as $$
	declare pwd text;
begin 
	select pass_word into pwd
	from customer
	where customer_id = p_customer_id;

	if pwd is null then return false;
	elseif pwd = p_password then return true;
	else return false;
	end if;
end;
$$ language plpgsql;

--8.UPDATE CUSTOMER INFO
create or replace function update_customer_info(
	p_customer_id int,
	p_old_password text,
	p_address text,
	p_fullname text,
	p_dob date,
	p_gender char,
	p_new_password text
)returns text
as $$
declare
    passed BOOL;
begin
    -- Check if the old password is correct
    select check_password(p_customer_id, p_old_password) INTO passed;
    
	   if passed = FALSE then
        return 'Invalid username or password';
    else
        -- Update customer information using COALESCE to retain old values if new values are NULL
        update customer
        set 
            address = coalesce(p_address, address),
            fullname = coalesce(p_fullname, fullname),
            dob = coalesce(p_dob, dob),
            gender = coalesce(p_gender, gender),
            pass_word = coalesce(p_new_password, pass_word)
        where customer_id = p_customer_id;
        return 'updated';
    end if;
end;
$$ language plpgsql;

--9.CHECK ORDER PAYMENT
CREATE OR REPLACE FUNCTION check_order_payment(
	p_id int,
	form varchar(10)
)
RETURNS TABLE(
 order_id INT,
    total_wo_tax MONEY,
    total_w_tax MONEY,
    status TEXT,
    order_date DATE
) AS $$
BEGIN
    -- Update the payment method in the orders table
    IF form = 'card' THEN
        UPDATE orders
        SET card = TRUE
        WHERE orders.order_id = p_id;
    ELSE 
        UPDATE orders
        SET cash = TRUE
        WHERE orders.order_id = p_id;
    END IF;

    -- Update the order status to 'delivering'
    UPDATE orders
    SET status = 'delivering'
    WHERE orders.order_id = p_id;

    -- Return the updated order details
    RETURN QUERY
    SELECT o.order_id::INT, 
           o.total_with_out_tax::MONEY, 
           o.total_with_tax::MONEY, 
           o.status::TEXT, 
           o.order_date::DATE
    FROM orders o
    WHERE o.order_id = p_id;
END;
$$ LANGUAGE plpgsql;
--10. TRIGGER TO DELETE SHOP
CREATE OR REPLACE FUNCTION set_shop_permission_false()
RETURNS TRIGGER AS $$
BEGIN
    -- Check the rating of the shop associated with the new review
    IF (SELECT rating FROM shop WHERE shop_id = NEW.shop_id) < 3 THEN
        -- Set the shop's permission to false
        UPDATE shop
        SET permission = FALSE
        WHERE shop_id = NEW.shop_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_set_shop_permission_false
AFTER INSERT ON review
FOR EACH ROW
EXECUTE FUNCTION set_shop_permission_false();
--11. GET TOP SELLING PRODUCT BY YEAR
CREATE OR REPLACE FUNCTION top_selling_products_by_year(p_shop_id INT, p_year INT)
RETURNS TABLE (
    product_id INT,
    product_name TEXT,
    total_quantity int
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT 
        p.product_id,
        p.product_name,
        SUM(ps.quantity)::INT AS total_quantity
    FROM 
        product p
    JOIN 
        product_shop ps ON p.product_id = ps.product_id
    JOIN 
        orders o ON ps.product_id = o.product_id
    WHERE 
        ps.shop_id = p_shop_id
        AND EXTRACT(YEAR FROM o.order_date) = p_year
    GROUP BY 
        p.product_id, p.product_name
    ORDER BY 
        total_quantity DESC
    LIMIT 10;  -- Limit to top 10 selling products
END;
$$
LANGUAGE plpgsql;
--12. GET TOTAL NUMBER OF STROCK IN EACH WAREHOUSE
CREATE OR REPLACE FUNCTION check_tong_sl_sp ()
RETURNS TABLE (id_warehouse int, sl_sp int)
AS
$$
BEGIN
    RETURN QUERY
    SELECT 
        ps.warehouse_id AS id_warehouse, 
        SUM(ps.quantity)::int AS sl_sp 
    FROM 
        product_shop ps
    GROUP BY 
        ps.warehouse_id;
END;
$$
LANGUAGE plpgsql;
select * from check_tong_sl_sp()
--13.GET PRODUCT SHOP ID
CREATE OR REPLACE FUNCTION get_product_shop_id(
    p_product_id INT,
    p_shop_id INT,
    p_warehouse_id INT
) RETURNS INT AS $$
DECLARE
    v_product_shop_id INT;
BEGIN
    -- Find the product_shop_id using the product_id, shop_id, and customer_id
    SELECT ps.product_shop_id
    INTO v_product_shop_id
    FROM product_shop ps
    WHERE ps.product_id = p_product_id 
      AND ps.shop_id = p_shop_id 
      AND ps.warehouse_id = p_warehouse_id ;

    -- If no match is found, return -1
    IF NOT FOUND THEN
        RETURN -1;
    END IF;

    -- Return the found product_shop_id
    RETURN v_product_shop_id;
END;
$$ LANGUAGE plpgsql;
--14. CHECK WAREHOUSE FULL
CREATE OR REPLACE FUNCTION check_ware_full(
    p_warehouse_id int
) RETURNS int
AS $$
DECLARE
    total_quantity bigint;
BEGIN
	
    SELECT COALESCE(SUM(ps.quantity), 0)::int
    INTO total_quantity
    FROM product_shop ps
	where ps.warehouse_id = p_warehouse_id;
    RETURN total_quantity;
END;
$$ LANGUAGE plpgsql;
--15. UPDATE NEW PRODUCT
CREATE OR REPLACE FUNCTION add_product_to_shop(
    p_shop_id INT,
    p_product_name TEXT,
    p_category_id INT,
    p_price MONEY,
    p_description TEXT,
    p_quantity INT,
    p_warehouse_id INT
) RETURNS TEXT AS $$
DECLARE 
    v_product_id INT;
    v_product_shop_id INT;
BEGIN
    -- Kiem tra xem product da co trong bang Product chua
    SELECT product_id INTO v_product_id 
    FROM product
    WHERE product_name = p_product_name AND category_id = p_category_id;

    IF v_product_id IS NULL THEN
        INSERT INTO product (price, product_name, category_id, description)
        VALUES (p_price, p_product_name, p_category_id, p_description)
        RETURNING product_id INTO v_product_id;
    END IF;

    -- Kiem tra xem da co product_shop_id cua san phan chua
    SELECT get_product_shop_id(v_product_id, p_shop_id, p_warehouse_id) INTO v_product_shop_id;

    -- Kiem tra xem co du cho chua trong kho khong
    IF v_product_shop_id > 0 THEN
        -- Neu product_shop_id co roi thi chi tang so luong
        IF check_ware_full(p_warehouse_id) + p_quantity <= 100000 THEN
            UPDATE product_shop
            SET quantity = quantity + p_quantity
            WHERE product_shop_id = v_product_shop_id;
            RETURN 'UPDATED';
        ELSE
            RETURN 'WAREHOUSE NOT SUFFICIENT';
        END IF;
    ELSE
        -- Neu chua co thi insert vao 
        IF check_ware_full(p_warehouse_id) + p_quantity <= 100000 THEN
            INSERT INTO product_shop (quantity, warehouse_id, shop_id, product_id)
            VALUES (p_quantity, p_warehouse_id, p_shop_id, v_product_id)
            RETURNING product_shop_id INTO v_product_shop_id;
            RETURN 'UPDATED';
        ELSE
            RETURN 'WAREHOUSE NOT SUFFICIENT';
        END IF;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Insert failed: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;
--16.ADD NEW SHOP 
CREATE OR REPLACE FUNCTION insert_new_shop(
    p_address text,
    p_rating numeric(3,2)
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    s1 TEXT;
BEGIN
    INSERT INTO shop (permission, address, rating)
    VALUES (true, p_address, p_rating);

    s1 := 'Insert successfully';
    RETURN s1;
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'Insert failed: duplicate key value violates unique constraint';
    WHEN OTHERS THEN
        RETURN 'Insert failed: ' || SQLERRM;
END;
$$;
--17.CANCEL ORDER
CREATE OR REPLACE FUNCTION confirmed_or_cancel(
    id_order INT, 
    new_status TEXT,
	p_product_shop_id INT
) 
RETURNS TABLE (
    order_id INT,
    total_wo_tax MONEY,
    total_w_tax MONEY,
    order_date DATE,
    status TEXT
)
AS $$
DECLARE
    quan INT;
BEGIN
    -- Update the status of the order
    UPDATE orders
    SET status = new_status
    WHERE orders.order_id = id_order;

    -- Check if the new_status is 'cancelled'
    IF new_status = 'cancel' THEN
        -- Get the quantity
        SELECT quantity INTO quan
        FROM orders o
        WHERE o.order_id = id_order;

		
        -- Update the quantity in the product_shop table
        UPDATE Product_Shop
        SET quantity = quantity + quan
        WHERE product_shop_id = p_product_shop_id;
    END IF;

    -- Return the updated order details
    RETURN QUERY 
    SELECT 
        o.order_id, 
        o.total_with_out_tax, 
        o.total_with_tax, 
        o.order_date, 
        o.status 
    FROM orders o 
    WHERE o.order_id = id_order;
END;
$$ LANGUAGE plpgsql;
--INSERT INTO orders (status, total_with_tax, total_with_out_tax, order_date, cash, card, voucher, customer_id, product_id,quantity)
--VALUES ('pending', 120.50, 100.00, CURRENT_DATE, TRUE, FALSE, 10, 1, 2,100);
--select * from confirmed_or_cancel(10,'cancel',2)
--18.CHECK REVENUE BY MONTH
CREATE OR REPLACE FUNCTION revenue_by_month(id_ INT)
RETURNS TABLE (
   	shop_id INT,
    year_month TEXT,
    total_revenue MONEY
)
AS
$$
BEGIN
    RETURN QUERY
	select ps.shop_id, 
	TO_CHAR(o.order_date, 'YYYY-MM') AS year_month,
    SUM(o.total_with_tax) AS total_revenue
	from orders o 
	join product p on p.product_id = o.product_id
	join product_shop ps on ps.product_id = p.product_id
	where ps.shop_id = id_
	group by ps.shop_id,TO_CHAR(o.order_date, 'YYYY-MM')
	order by year_month;
END;
$$
LANGUAGE plpgsql;
