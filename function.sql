------------------------ 1.hàm này để thêm tài khoản khách hàng vào -------------------------
CREATE OR REPLACE FUNCTION insert_new_customer(
    IN address_in TEXT,
    IN fullName_in VARCHAR(40),
    IN dob_in DATE,
    IN gender_in CHAR(1),
    IN pass_word_in TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
	declare s1 text;
begin 
insert into customer(fullName,address,dob,gender,pass_word)
	values(fullname_in,address_in,dob_in,gender_in,pass_word_in);
	s1 := 'Insert succesfully';
	return s1;
exception
	when others then
	return 'Insert falied:'||SQLERRM;
end;
$$;

--------------------------2.Hàm này để tìm sản phẩm theo product_name---------------------------

CREATE OR REPLACE FUNCTION find_product(search_name TEXT)
RETURNS TABLE (
    product_name VARCHAR(255),
    price MONEY,
    shop_id INT,
    address TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT p.product_name, p.price, s.shop_id, s.address
    FROM shop s
    JOIN a_shop sa ON sa.shop_id = s.shop_id
    JOIN product_shop ps ON ps.product_shop_id = sa.product_shop_id
    JOIN product p ON p.product_id = ps.product_id
    WHERE (p.product_name ILIKE '%' || search_name || '%' 
           OR p.description ILIKE '%' || search_name || '%')
      AND s.permission = TRUE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            'not_found'::VARCHAR(255) AS product_name, 
            NULL::MONEY AS price, 
            NULL::INT AS shop_id, 
            'not_found'::TEXT AS address;
    END IF;
END;
$$ LANGUAGE plpgsql;
select * from find_product('phone')


------------------3.Hàm này để kiểm tra xem trong shop có còn sản phẩm cần tìm không--------------------------

	CREATE OR REPLACE FUNCTION check_stocks(
    IN product_id_in INT, 
    IN shop_id_in INT, 
    IN quantity INT
)
RETURNS my_type
AS $$
DECLARE
    result my_type;
    quantity_aval INT;
BEGIN
    result.status := 0;
    result.product_shop_id := NULL;


 	 SELECT product_shop.quantity, product_shop.product_shop_id 
	INTO quantity_aval, result.product_shop_id
	FROM product_shop
	WHERE product_shop.product_id = product_id_in
	AND EXISTS (
    SELECT 1
    FROM a_shop
    WHERE a_shop.product_shop_id = product_shop.product_shop_id
    AND a_shop.shop_id = shop_id_in
);

    -- Check stock status
    IF quantity_aval < quantity THEN 
        result.status := 2;
    ELSIF quantity_aval >= quantity THEN 
        result.status := 1;
    ELSE 
        result.status := 0;
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;



------------------------------------4. Hàm này để đặt hàng----------------------------------------------------------------------

create or replace function make_order(in product_id_in int,in shop_id_in int,in quantity_in int)
returns text
as $$
		declare 
			result my_type;
			price money;
begin 	
-- 	láy status,product_shop_id từ hàm check_stock
	select status,product_shop_id from check_stocks(product_id_in, shop_id_in,quantity_in)
	into result.status, result.product_shop_id;
	
	if result.status = 0 then return 'out_of_stock';
	elseif result.status = 2 then return 'stock not sufficient';
	else 
	--giảm số lượng hàng trong kho đi 
		update a
		set quantity = quantity - quantity_in
		where product_shop_id = result.product_shop_id;
	-- tìm giá sản phẩm 
		select p.price from  a
		into price
		join a_product ap on ap.product_shop_id = a.product_shop_id
		join product p on p.product_id = ap.product_id
		where a.product_shop_id = result.product_shop_id 
		and p.product_id = product_id_in;
	--thêm 1 order vào bảng order_
		insert into order_(total_wo_tax, total_w_tax,status,order_date)
		values(price, price*1.05, 'pending',current_timestamp);

		return 'ordered';
	end if;
end;
$$ language plpgsql;

-----------------------------------------5.Hàm để kiểm tra tài khoản và mật khẩu--------------------------------------------------

create or replace function check_password(in customer_id_in int,in pass_word_in text)
returns bool
as $$
	declare pwd text;
begin
	--Lấy mật khẩu từ customer_id
	select pass_word into pwd
	from customer
	where customer_id = customer_id_in;

	--Nếu customer_id không tồn tại thì pass_word = null
	if pwd is null then return false;
	--Nếu mật khẩu đúng thì return true
	elseif pwd = pass_word_in then return true;
	--Nếu mật khẩu sai thì return false
	else return false;
	end if;
end;
$$ language plpgsql;

--Hàm để update thông tin cá nhân
create or replace function update_customer_info(
	in customer_id_in int,
	in old_password text,
	in address_in text,
	in fullname_in varchar(40),
	in dob_in date,
	in gender_in char,
	in new_password text)
	returns text
as $$
	declare id_ int;
			passed bool;
begin 
	select check_password($1,$2) into passed;
	
	if passed = false then return 'Invalid username or password';
	else
	   update customer
        set 
            fullname = coalesce(fullname_in,fullname),
            dob = coalesce(dob_in,dob),
            gender = coalesce(gender_in,gender),
            pass_word = coalesce(new_password,pass_word),
            address = coalesce(address_in,address)
        where customer_id = customer_id_in;
		return 'updated';
	end if;
end;
$$ language plpgsql;

-----------------------------------------------------------6.Hàm để check order của khách----------------------------------------------
create or replace function check_order(
	in customer_id_in int
)
returns table(
		order_id int,
		customer_id int,
		total_wo_tax money,
		total_w_tax money,
		status varchar(20),
		order_date date
)
language plpgsql
as $$
	begin 
		return query
		select * from order_ o
		where o.customer_id = 2
		order by o.order_date desc;
	end;
$$;
----------------------------------------------7.Hàm để đánh giá shop------------------------------------------------------------------

create or replace function update_shop_rating()
returns trigger 
language plpgsql
as $$
declare total_star numeric(3,2);
begin 
		select avg(star) from review
		into total_star
		where shop_id = new.shop_id;

		update shop
		set rating = total_star
		where shop_id = new.shop_id;

		return null;
end;
$$;
create trigger trg_update_shop_rating
after insert or delete on review
for each row
execute function update_shop_rating();

insert into review(star, description,customer_id,product_id,shop_id)
values(5,'Nice',2,2,2);
select * from review
where shop_id = 2;


select * from shop
where shop_id = 2;

-----------------------------------------------------------------


--ham xac nhan don hang cua mot don hang dang cho
+y tuong: khi khach hang xac nhan phuong thuc thanh toan thi se chuyen trang thai tu pending sang delivering
+ ghi order_id va hinh thuc thanh toan vao ham (cash hoac card);
CREATE OR REPLACE FUNCTION xac_nhan_don_hang(id_ INT, form VARCHAR(40))
RETURNS TABLE (
    order_id INT,
    total_wo_tax MONEY,
    total_w_tax MONEY,
    status VARCHAR(40),
    order_date DATE
)
AS
$$
BEGIN
    IF form = 'card' THEN
        UPDATE payment
        SET card = 'true'
        WHERE payment.order_id = id_;
    ELSE 
        UPDATE payment
        SET cash = 'true'
        WHERE payment.order_id = id_;
    END IF;

    UPDATE order_
    SET status = 'delivering'
    WHERE order_.order_id = id_;

    RETURN QUERY
    SELECT * from order_
	where order_.order_id = id_;
  
END;
$$
LANGUAGE plpgsql;

select * from xac_nhan_don_hang(1,'cash');
----------------------------------------------
hàm hủy shop khi shop có sao quá thấp
CREATE OR REPLACE FUNCTION thay_doi_trang_thai_shop(IN status_in )
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
	
    DELETE FROM shop
    WHERE rating < 2 AND permission = false;
    RETURN 'finish';
END;
$$;
-----------------------------------------------
hàm tạo shop mới
CREATE OR REPLACE FUNCTION insert_new_shop(
    IN address text,
    IN rating numeric(3,2)
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    s1 TEXT;
BEGIN
    INSERT INTO shop (permission, address, rating)
    VALUES (true, address, rating);

    s1 := 'Insert successfully';
    RETURN s1;
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'Insert failed: duplicate key value violates unique constraint';
    WHEN OTHERS THEN
        RETURN 'Insert failed: ' || SQLERRM;
END;
$$;

select * from insert_new_shop('789 Trade St',5)
-----------------------------------------------------
hàm check xem shop có sản phẩm hay chưa

CREATE OR REPLACE FUNCTION check_sp_shop_co (
    id_product INT, 
    id_shop INT
)
RETURNS TABLE (
    shop_id INT,
    product_id INT,
    product_shop_id INT
)
AS
$$
BEGIN
    RETURN QUERY
    SELECT shop.shop_id, product.product_id, product_shop.product_shop_id
    FROM product
    JOIN product_shop ON product_shop.product_id = product.product_id
    JOIN a_shop ON a_shop.product_shop_id = product_shop.product_shop_id
    JOIN shop ON shop.shop_id = a_shop.shop_id
    WHERE product.product_id = id_product AND shop.shop_id = id_shop;
END;
$$
LANGUAGE plpgsql;

-- Execute the function
SELECT * FROM check_sp_shop_co(1, 1);
--------------------------------------------
hàm thêm sản phẩm đã có trong shop khi da dung hàm check san pham ơ ben tren de lay thong tin
CREATE OR REPLACE FUNCTION them_sp_da_co (
    quantity_ INT, 
    id_product_shop INT, 
    id_product INT
)
RETURNS TEXT
AS
$$
BEGIN 
    UPDATE product_shop
    SET quantity = product_shop.quantity + quantity_
    WHERE product_shop.product_shop_id = id_product_shop AND product_shop.product_id = id_product;
    RETURN 'finish';
END;
$$
LANGUAGE plpgsql;

select * from them_sp_da_co(100,1,1)














