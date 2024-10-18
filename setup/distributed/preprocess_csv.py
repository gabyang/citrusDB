import pandas as pd

''' Preprocess District Data '''
# district_data = pd.read_csv('district.csv')

# # Make district_2.5 only have d_w_id, d_id and d_next_o_id
# district_2_5 = district_data[['D_W_ID', 'D_ID', 'D_NEXT_O_ID']]

# base_district = district_data.drop(columns=['D_NEXT_O_ID'])

# district_2_5.to_csv('district_2-5.csv', index=False)
# base_district.to_csv('base_district.csv', index=False)

''' Preprocess Customer Data '''
# customer_data = pd.read_csv('customer.csv')

# customer_2_7 = customer_data[['C_W_ID', 'C_D_ID', 'C_ID', 'C_FIRST', 'C_MIDDLE', 'C_LAST', 'C_BALANCE']]
# customer_2_8 = customer_data[['C_W_ID', 'C_D_ID', 'C_ID', 'C_STATE']]
# base_customer = customer_data.drop(columns=['C_FIRST', 'C_MIDDLE', 'C_LAST', 'C_STATE', 'C_BALANCE'])

# base_customer.to_csv('base_customer.csv', index=False)
# customer_2_7.to_csv('customer_2-7.csv', index=False)
# customer_2_8.to_csv('customer_2-8.csv', index=False)

''' Preprocess Order-Line Data '''
# order_line_data = pd.read_csv('order-line.csv')

# order_line_item_constraint = order_line_data[['OL_W_ID', 'OL_D_ID', 'OL_O_ID', 'OL_NUMBER', 'OL_I_ID']]
# order_line_item_constraint.to_csv('order_line_item_constraint.csv', index=False)

# ''' Preprocess Stock Data '''
# stock_data = pd.read_csv('stock.csv')

# stock_2_5 = stock_data[['S_W_ID', 'S_I_ID', 'S_QUANTITY']]
# stock_2_5.to_csv('stock_2-5.csv', index=False)

