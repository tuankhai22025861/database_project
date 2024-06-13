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
