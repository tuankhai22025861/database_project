# database_project
This are the procedure for our database project
1.insert_new_customer(</br>
  IN address TEXT,</br>
  IN fullname VARCHAR,
  IN dob DATE,
  IN gender CHAR, 
  IN pass_word TEXT)
  RETURNS text; //success or fail
2.find_product_by_categorys(
  IN category_id_input int
)
  	RETURNS TABLE(
		product_id int,
		product_name varchar(255),
		price money,
		shop_id int,
		address text
	)
