-- 1.hàm này để thêm tài khoản khách hàng vào 
create or replace function ínsert_new_customer(
    IN address TEXT,
    IN fullName VARCHAR(40),
    IN dob DATE,
    IN gender CHAR(1),
    IN pass_word TEXT
)
returns TEXT
language plpgsql
as $$
declare
    s1 TEXT;
begin
    insert into customer (address, fullname, dob, gender, pass_word)
    values (address, fullName, dob, gender, pass_word);

    s1 := 'Insert successfully';
    return s1;
exception
    WHEN unique_violation THEN
        return 'Insert failed: duplicate key value violates unique constraint';
    WHEN OTHERS THEN
        return 'Insert failed: ' || SQLERRM;
end;
$$;

--2.Hàm này để tìm sản phẩm theo product_id
create function find_product_by_category(category_id_input int)
returns table (
	product_name varchar(40),
	price money,
	shop_id int,
	address text
)
as $func$
	begin
	return query
		select p.product_name,p.price,s.shop_id,s.address from shop s
		join a_shop sa
		on sa.shop_id = s.shop_id
		join a
		on a.product_shop_id = sa.product_shop_id
		join a_product ap
		on a.product_shop_id = ap.product_shop_id
		join product p
		on p.product_id = ap.product_id
		where p.category_id = category_id_input and s.permission = true;
	if not found then
		return query
		select 
            'not_found'::VARCHAR(255) as product_name, 
            null::MONEY as price, 
            null::INT as shop_id, 
            'not_found'::TEXT as shop_address;
	end if;
	end;
$func$ language plpgsql;
select * from find_product_by_category(13);

--3.Hàm này để kiểm tra xem trong shop có còn sản phẩm cần tìm không

create type my_type as(
	status int,
	product_shop_id int
);
create or replace function check_stocks(in product_id_in int, in shop_id_in int,in quantity int)
returns my_type
as $$
	declare result my_type;
			quantity_aval int;
	begin
		result.status :=0;
		result.product_shop_id := null;
--lấy số lượng và product_shop_id của sản phẩm cần tìm
		select a.quantity, a.product_shop_id 
		into quantity_aval, result.product_shop_id
		from shop s
		join a_shop sa on sa.shop_id = s.shop_id
		join a on a.product_shop_id = sa.product_shop_id
		join a_product ap on ap.product_shop_id = a.product_shop_id
		join a_ware aw on aw.product_shop_id = a.product_shop_id
		join warehouse w on w.warehouse_id = aw.warehouse_id
		where ap.product_id = product_id_in
		and	s.shop_id = shop_id_in
		and a.quantity > 0;

--nếu không đủ hàng 
	if quantity_aval < quantity then 
		result.status := 2;
--nếu đủ hàng
	elseif quantity_aval > quantity then 
		result.status := 1;
--nếu không có hàng
	else 
		result.status := 0;
	end if;
	return result;
	end;
$$ language plpgsql;
select * from check_stocks(676,541,100);
--4. Hàm này để đặt hàng
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
select make_order(676,541,3);
--5.Hàm để kiểm tra tài khoản và mật khẩu

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

--6.Hàm để update thông tin cá nhân
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

--7.Hàm xác nhận đơn hàng của 1 đơn hàng đang chờ
+y tuong: khi khach hang xac nhan phuong thuc thanh toan thi se chuyen trang thai tu pending sang delivering
+ ghi order_id va hinh thuc thanh toan vao ham (cash hoac card);
create or replace function xac_nhan_don_hang(id_ INT, form VARCHAR(40))
returns TABLE (
    order_id INT,
    total_wo_tax MONEY,
    total_w_tax MONEY,
    status VARCHAR(40),
    order_date DATE
)
as
$$
begin
    IF form = 'card' THEN
        UPDATE payment
        SET card = 'true'
        where payment.order_id = id_;
    ELSE 
        UPDATE payment
        SET cash = 'true'
        where payment.order_id = id_;
    end IF;

    UPDATE order_
    SET status = 'delivering'
    where order_.order_id = id_;

    return QUERY
    select * from order_
	where order_.order_id = id_;
  
end;
$$
language plpgsql;

select * from xac_nhan_don_hang(1,'cash');
----------------------------------------------
--8.Hàm hủy shop khi shop có sao quá thấp
create or replace function huy_shop()
returns text
language plpgsql
as $$
begin
    DELETE from shop
    where rating < 2 AND permission = false;
    return 'finish';
end;
$$;
-----------------------------------------------
--9.Hàm tạo shop mới
create or replace function insert_new_shop(
    IN address text,
    IN rating numeric(3,2)
)
returns TEXT
language plpgsql
as $$
declare
    s1 TEXT;
begin
    insert into shop (permission, address, rating)
    values (true, address, rating);

    s1 := 'Insert successfully';
    return s1;
exception
    WHEN unique_violation THEN
        return 'Insert failed: duplicate key value violates unique constraint';
    WHEN OTHERS THEN
        return 'Insert failed: ' || SQLERRM;
end;
$$;

select * from insert_new_shop('789 Trade St',5)
-----------------------------------------------------
--------------------------------------------
-----------------------------------------------
--10.Hàm kiểm tra tổng số lượng sản phẩm trong từng kho
create or replace function check_tong_sl_sp ()
returns TABLE (id_warehouse INT, sl_sp bigINT)
as
$$
begin
    return QUERY
    select 
        a_ware.warehouse_id as id_warehouse, 
        SUM(product_shop.quantity) as sl_sp 
    from 
        product_shop 
    join 
        a_ware 
    ON 
        product_shop.product_shop_id = a_ware.product_shop_id
    group by 
        a_ware.warehouse_id;
end;
$$
language plpgsql;

-- Execute the function to see the results
select * from check_tong_sl_sp();
----------------------------------------------------
--10.Hàm thêm sản phẩm với tất cả trường hợp ( không quan tâm kho đầy hay không)

--10.1Hàm phụ để trả về product_shop_id IN(product_id,shop_id) trả về -1 nếu không tìm được 

create or replace function get_product_shop_id(
    p_product_id INT,
    p_shop_id INT
) returns INT as $$
declare
    v_product_shop_id INT;
begin
    -- Find the product_shop_id using the product_id and shop_id
    select ps.product_shop_id
    into v_product_shop_id
    from Product_Shop ps
    join a_shop ashop ON ps.product_shop_id = ashop.product_shop_id
    where ps.product_id = p_product_id AND ashop.shop_id = p_shop_id;

    -- If no match is found, return NULL
    IF NOT FOUND THEN
        return -1;
    end IF;

    -- return the found product_shop_id
    return v_product_shop_id;
end;
$$ language plpgsql;
select get_product_shop_id(1,1)
----------------------------------------------------

--10.2Hàm thêm sản phẩm với tất cả trường hợp ( quan tâm kho đầy hay không) IN (shop_id ,warehouse_id,product_name,category_id,price,description,quantity)


create or replace function add_product_to_shop(
    p_shop_id int,
    p_product_name varchar(225),
    p_category_id int,
    p_price numeric,
    p_description text,
    p_quantity int
) returns return_ware as
$$
declare
    v_product_id INT;
    v_product_shop_id INT;
	v_val return_ware;
begin
    -- Kiem tra xem product co trong product table chua
   	select product_id into v_product_id
    from product
    where product_name = p_product_name and category_id = p_category_id;

    -- Neu product chua co ->insert vao
   	if v_product_id is null then
        insert into product (price, description, product_name, category_id)
        values (p_price, p_description, p_product_name, p_category_id)
        returning product_id into v_product_id;
    end if;

    -- Kiem tra xem da ton tai product_shop_id chua
    select get_product_shop_id(v_product_id,p_shop_id) into v_product_shop_id;

    -- Neu chua ton tai product_shop_id thi insert vao
    if v_product_shop_id < 0 then
        insert into product_shop (quantity, product_id)
        values (p_quantity, v_product_id)
        returning product_shop_id into v_product_shop_id;
    else
        --Neu ton tai roi thi chi cap nhat so luong
        update Product_Shop
        set quantity = quantity + p_quantity
       	where product_shop_id = v_product_shop_id;
    end if;

    -- Insert a_shop
    insert into a_shop (shop_id, product_shop_id)
   	values (p_shop_id, v_product_shop_id)
    on conflict (shop_id, product_shop_id) do nothing;

    -- Insert a_ware
	select loop_ware(p_quantity) into v_val.ware_id;
	
    insert into a_ware (warehouse_id, product_shop_id, in_date)
   	values (v_val.ware_id, v_product_shop_id, current_date)
    on conflict (warehouse_id, product_shop_id) do nothing;
	v_val.out_text := 'Insert success';
	return v_val;
exception
	when others then
	return 'Insert failed: '||SQLERRM;
end;
$$
language plpgsql;

select * from add_product_to_shop(4,'Time',1,100.0,'Good Time',100);
select * from product_shop
--10.3. Hàm tính số lượng sản phẩm của từng kho
create type ware as(
	id_ int;
	quantity int;
)
create or replace function check_ware_full(
	p_warehouse_id int
)returns numeric as $$
declare
		v ware;
		total numeric := 0;
begin 
	for v in 
		select ps.product_shop_id,ps.quantity
		from a_ware aw join product_shop ps on ps.product_shop_id = aw.product_shop_id
		where aw.warehouse_id = p_warehouse_id
	loop
		total := total + v.quantity;
end loop;
	return total;
end;
 $$ language plpgsql;
 --10.4 . Hàm để duyệt qua tất cả các kho 
 create or replace function loop_ware(
	in p_quantity int
)
returns numeric
as $$
declare 
	w int;
	total numeric;
begin 
	for w in
		select warehouse_id from a_ware aw
		order by warehouse_id desc;
	loop
		select check_ware_full(w)
		into total;
		if total + p_quantity < 10000 then
		return w;
		end if;
	end loop;
return -1;
end;
$$ language plpgsql;
select loop_ware(10000-400);

--------------------------------------------
--11.Viết hàm xác nhận đơn hàng hoặc hủy
Nếu hủy thì cập nhật lại vào số lượng trong kho
create or replace function confirmed_or_cancel(
    id_order INT, 
    new_status TEXT
) 
returns TABLE (
    order_id INT,
    total_wo_tax MONEY,
    total_w_tax MONEY,
    order_date DATE,
    status TEXT
)
as $$
declare
    quan INT;
begin
    -- Update the status of the order
    UPDATE "Order"
    SET status = new_status
    where "Order".order_id = id_order;

    -- Check if the new_status is 'cancelled'
    IF new_status = 'cancelled' THEN
        -- Get the quantity
        select quantity into quan
        from a_order
        where a_order.order_id = id_order;

        -- Update the quantity in the product_shop table
        UPDATE Product_Shop
        SET quantity = quantity + quan
        where product_shop_id IN (
            select product_shop_id 
            from a_order 
            where a_order.order_id = id_order
        );
    end IF;

    -- return the updated order details
    return QUERY 
    select 
        o.order_id, 
        o.total_wo_tax, 
        o.total_w_tax, 
        o.order_date, 
        o.status 
    from "Order" o 
    where o.order_id = id_order;
end;
$$ language plpgsql;
select * from confirmed_or_cancel (3,'cancelled')

--------------------------------------------------------------------
---------------12.Hàm để kiểm tra trong 1 kho có những mặt hàng gì----------
create or replace function check_warehouse(
	p_warehouse_id int
)returns table(
	product_name varchar(225),
	description text,
	quantity int
)
as $$
	begin 
	return query
	select p.product_name, p.description, ps.quantity 
	from product p 
	join product_shop ps on ps.product_id = p.product_id
	join a_ware aw on aw.product_shop_id = ps.product_shop_id
	where aw.warehouse_id = p_warehouse_id;
end;
$$ language plpgsql;
select * from check_warehouse(3);
--12.1. Hàm đưa ra sản phẩm của từng kho

create or replace function check_warehouse(
	p_warehouse_id int
)returns table(
	product_name varchar(225),
	description text,
	quantity int
)
as $$
	begin 
	return query
	select p.product_name, p.description, ps.quantity 
	from product p 
	join product_shop ps on ps.product_id = p.product_id
	join a_ware aw on aw.product_shop_id = ps.product_shop_id
	where aw.warehouse_id = p_warehouse_id;
end;
$$ language plpgsql;
select * from check_warehouse(1);
