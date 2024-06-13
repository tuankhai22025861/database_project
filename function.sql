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
