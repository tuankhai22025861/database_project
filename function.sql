-- hàm này để thêm tài khoản khách hàng vào 
CREATE OR REPLACE FUNCTION ínsert_new_customer(
    IN address TEXT,
    IN fullName VARCHAR(40),
    IN dob DATE,
    IN gender CHAR(1),
    IN pass_word TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    s1 TEXT;
BEGIN
    INSERT INTO customer (address, fullname, dob, gender, pass_word)
    VALUES (address, fullName, dob, gender, pass_word);

    s1 := 'Insert successfully';
    RETURN s1;
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'Insert failed: duplicate key value violates unique constraint';
    WHEN OTHERS THEN
        RETURN 'Insert failed: ' || SQLERRM;
END;
$$;

--Hàm này để tìm sản phẩm theo product_id
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
            'not_found'::VARCHAR(255) AS product_name, 
            null::MONEY AS price, 
            null::INT AS shop_id, 
            'not_found'::TEXT AS shop_address;
	end if;
	end;
$func$ language plpgsql;
select * from find_product_by_category(13);

