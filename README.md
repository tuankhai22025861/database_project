## Installation

1. Clone this repository to your local machine:

2. Connect to your PostgreSQL database.

3. Run each SQL script containing the PL/pgSQL functions in your database management tool or command-line interface.

## Functions Overview

1. **insert_new_customer**: This function is used to add a new customer to the database.

2. **find_product_by_category**: Finds products based on a given category ID.

3. **check_stocks**: Checks the availability of a product in a specific shop.

4. **make_order**: Places an order for a product from a shop.

5. **check_password**: Verifies the password for a given customer ID.

6. **update_customer_info**: Updates customer information in the database.

7. **xac_nhan_don_hang**: Confirms an order and updates its status to "delivering".

8. **huy_shop**: Deletes a shop with a low rating and no permission.

9. **insert_new_shop**: Adds a new shop to the database.

10. **check_tong_sl_sp**: Checks the total quantity of products in each warehouse.

11. **add_product_to_shop**: Adds a product to a shop, managing stock quantities.

12. **confirmed_or_cancel**: Updates the status of an order and manages stock quantities accordingly.

13. **check_warehouse**: Lists products available in a specific warehouse.

## Usage

Each function has its specific purpose and usage. Consult the function documentation provided in the SQL files for detailed information on parameters, return types, and usage examples.

## Contributions

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or create a pull request.

