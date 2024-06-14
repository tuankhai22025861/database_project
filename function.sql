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
