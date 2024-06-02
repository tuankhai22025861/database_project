# database_project
This are the procedure for our database project</br>
1.insert_new_customer(</br>
  IN address TEXT,
  IN fullname VARCHAR,
  IN dob DATE,
  IN gender CHAR, 
  IN pass_word TEXT)
  RETURNS text; //success or fail</br>
2.find_product_by_categorys(</br>
  IN category_id_input INT
)
  	RETURNS TABLE(
		product_id INT,
		product_name VARCHAR(255),
		price MONEY,
		shop_id INT,
		address TEXT
	)</br>
