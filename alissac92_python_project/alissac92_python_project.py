""" 
Alissa Crist
Date: 10/3/2023
Description of Problem: 
This program takes stock data from COSTCO and S&P-500 and 
creates training and testing data frames to create a predictive model 
for return performance
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import math


# read $SPY and $COST .csv files and store into pandas dataframes
spy_df = pd.read_csv('SPY.csv')
cost_df = pd.read_csv('COST.csv')

# define function 'tru_lbl' that creates col 'True Return' based on pos or neg return
def tru_lbl(df):
    df['True Return'] = np.where(df['Return'] >= 0, '+', '-')
    return df

tru_lbl(spy_df)
tru_lbl(cost_df)

# create 'training data' subsets for 2016 - 2018
spy_train_df = spy_df[spy_df['Year'] < 2019]
cost_train_df = cost_df[cost_df['Year'] < 2019]

# create 'testing data' subsets for 2019 - 2020
spy_test_df = spy_df[spy_df['Year'] >= 2019]
cost_test_df = cost_df[cost_df['Year'] >= 2019]

# define function 'rtrn_prob' that returns the ratio of '+' and '-' days 
def rtrn_prob(df):
    return(df.value_counts(df['True Return'] == '+', normalize=True))

print("SPY Return Probability: \n",rtrn_prob(spy_train_df))
print("COST Return Probability: \n",rtrn_prob(cost_train_df))

# declare variables for positive and negative return patterns
k1_neg_n = '--'
k1_neg_p = '-+'
k2_neg_n = '---'
k2_neg_p = '--+'
k3_neg_n = '----'
k3_neg_p = '---+'
k1_pos_n = '+-'
k1_pos_p = '++'
k2_pos_n = '++-'
k2_pos_p = '+++'
k3_pos_n = '+++-'
k3_pos_p = '++++'

# 'rtrn_pattern' counts how many times a given pattern appears in the string
def rtrn_pattern(df, n1, n2):
    tr_as_str = df['True Return'].tolist()
    tr_as_str = ''.join(map(str, tr_as_str))
    count_n1 = tr_as_str.count(n1)
    count_n2 = tr_as_str.count(n2)
    print((n1, count_n1, n2, count_n2))
    if (count_n1 + count_n2) == 0:
        return_prob = 0.0
    else:
        return_prob = count_n1 / (count_n1 + count_n2)
    print("Return Probability of '"+n1+"' is: {:0.2f}\n".format(return_prob))
    return return_prob if not math.isnan(return_prob) else 0.0

# compute probabilities of UP day(s) after DOWN day(s) for k = 1,2,3 for $SPY and $COST

# $SPY, k1
print("\n$SPY: Prob. of '+' day after k=1 '-' day:")
rtrn_pattern(spy_train_df, k1_neg_p, k1_neg_n)
# $SPY, k2
print("\n$SPY: Prob. of '+' day after k=2 '-' days:")
rtrn_pattern(spy_train_df, k2_neg_p, k2_neg_n)
# $SPY, k3
print("\n$SPY: Prob. of '+' day after k=3 '-' days:")
rtrn_pattern(spy_train_df, k3_neg_p, k3_neg_n)

# $COST, k1
print("\n$COST: Prob. of '+' day after k=1 '-' day:")
rtrn_pattern(cost_train_df, k1_neg_p, k1_neg_n)
# $SPY, k2
print("\n$COST: Prob. of '+' day after k=2 '-' days:")
rtrn_pattern(cost_train_df, k2_neg_p, k2_neg_n)
# $SPY, k3
print("\n$COST: Prob. of '+' day after k=3 '-' days:")
rtrn_pattern(cost_train_df, k3_neg_p, k3_neg_n)

# compute probabilities of DOWN day(s) after UP day(s) for k = 1,2,3 for $SPY and $COST

# $SPY, k1
print("\n$SPY: Prob. of '-' day after k=1 '+' day:")
rtrn_pattern(spy_train_df, k1_pos_n, k1_pos_p)
# $SPY, k2
print("\n$SPY: Prob. of '-' day after k=2 '+' days:")
rtrn_pattern(spy_train_df, k2_pos_n, k2_pos_p)
# $SPY, k3
print("\n$SPY: Prob. of '-' day after k=3 '+' days:")
rtrn_pattern(spy_train_df, k3_pos_n, k3_pos_p)

# $COST, k1
print("\n$COST: Prob. of '-' day after k=1 '+' day:")
rtrn_pattern(cost_train_df, k1_pos_n, k1_pos_p)
# $SPY, k2
print("\n$COST: Prob. of '-' day after k=2 '+' days:")
rtrn_pattern(cost_train_df, k2_pos_n, k2_pos_p)
# $SPY, k3
print("\n$COST: Prob. of '-' day after k=3 '+' days:")
rtrn_pattern(cost_train_df, k3_pos_n, k3_pos_p)

# 'predict_next_rturn' searches test data for patterns to predict +/- rtn for next day
def predict_next_rtrn(df, w):
    row = df.index[df['Date'] == "2019-01-02"][0] # starting at 1st trading day 2019
    k = w # base value for W (2, 3, or 4)
    w_values = [] # empty list to store + or - predictions

    # Determine the range of rows to update in dataframe
    start_row = row 

    # Iterate over each row from start of 2019 to end of 2020
    for row_idx in range(row, len(df)):
        s = "" # empty string to be filled with our series to search in train data
        while w >= 1:
            d = df.iloc[row_idx-w]['True Return']
            s += str(d)
            w = w-1 # decrement w until w is 1
        print('Pattern to search: '+s)
        # call the rtrn_pattern function to get simple probabilities
        return_prob = rtrn_pattern(df, (s + '+'), (s + '-'))
        if return_prob is not None and return_prob > 0.50:
            print(return_prob)
            w_values.append('+') # add '+' to list if prob is >0.50
        else:
            w_values.append('-') # add '-' to list if not
        row_idx += 1 # increment row index
        w = k # reset w

    print(w_values) # print the populated list

    start_row = (start_row+1) # update start_row so predicted values print in d+1 spot
    end_row = start_row + len(w_values) # calculate end index
    # Create a new column 'W(w)' and populate it with w_values for the specified range
    column_name = 'W{}'.format(w)
    df[column_name] = pd.Series(w_values, index=range(start_row, end_row))

predict_next_rtrn(spy_df, 2)
predict_next_rtrn(spy_df, 3)
predict_next_rtrn(spy_df, 4)
predict_next_rtrn(cost_df, 2)
predict_next_rtrn(cost_df, 3)
predict_next_rtrn(cost_df, 4)

# create 'ensemble' subsets for $SPY and $COST
# first, reduce just to the test years
spy_ens_df = spy_df[spy_df['Year'] >= 2019]
cost_ens_df = cost_df[cost_df['Year'] >= 2019]

# then, take out the columns we need
spy_ens_df = spy_ens_df[['Date','Year','Return','True Return','W2','W3','W4']]
cost_ens_df = cost_ens_df[['Date','Year','Return','True Return','W2','W3','W4']]
print(spy_ens_df)
print(cost_ens_df)

# reset indices of new ensemble datasets
spy_ens_df = spy_ens_df.reset_index(drop=True)
cost_ens_df = cost_ens_df.reset_index(drop=True)

# 'calc_ensemble' calulcates ensemble return labels based on W2, W3, W4
def calc_ensemble(df):
    row = 0
    e_values = [] # empty list to store ensemble values
    for row in range(1,len(df)):
        wp = df.values[row,4:6] # take return values for current row and cols 4-6 (W2-W4)
        pos_count = sum(1 for val in wp if val == '+')
        if pos_count >= 2: # if two or more '+'
            e_values.append('+') # then ensemble label is '+'
        else: # if not two or more '+'
            e_values.append('-') # then ensemble lable is '-'
        row += 1
    # Create a new column 'Ensemble' and populate it with e_values for the specified range
    df['Ensemble'] = pd.Series(e_values, index=range(1,len(df)))
    print(df)

# Print the updated data frames with Ensemble populated
calc_ensemble(spy_ens_df)
calc_ensemble(cost_ens_df)

# 'prediction_accy' calculates overall accuracy and precision for each predictor variable
def prediction_accy(df, colnum):
    true_positives = 0 # initialize counters for TP, TN, FP, FN
    true_negatives = 0
    false_positives = 0
    false_negatives = 0

    for row in range(len(df)):
        true_return = df['True Return'].iloc[row]
        predicted_return = df.iloc[row, colnum]
        # increment counters based on conditions
        if true_return == '+' and predicted_return == '+':
            true_positives += 1
        elif true_return == '-' and predicted_return == '-':
            true_negatives += 1
        elif true_return == '+' and predicted_return == '-':
            false_negatives += 1
        elif true_return == '-' and predicted_return == '+':
            false_positives += 1
    # calculate accuracy and precision percentages
    accuracy = ((true_positives + true_negatives) / len(df)) * 100
    precision_pos = (true_positives / (true_positives + false_positives)) * 100
    tpr = (true_positives / (true_positives + false_negatives)) * 100
    tnr = (true_negatives / (true_negatives + false_positives)) * 100
    precision_neg = (true_negatives / (true_negatives + false_negatives)) * 100
    # print results
    print("TP: "+(str(true_positives)))
    print("FP: "+(str(false_positives)))
    print("TN: "+(str(true_negatives)))
    print("FN: "+(str(false_negatives)))
    print(f"Overall Accuracy: {accuracy:.2f}%")
    print(f"Positive Precision: {precision_pos:.2f}%")
    print(f"Negative Precision: {precision_neg:.2f}%")
    print(f"TPR: {tpr:.2f}%")
    print(f"TNR: {tnr:.2f}%")

# Print the accuracy and precision for each variable in SPY & COST 
print("\n$SPY Summary for W2:")
prediction_accy(spy_ens_df, 4)
print("\n$SPY Summary for W3:")
prediction_accy(spy_ens_df, 5)
print("\n$SPY Summary for W4:")
prediction_accy(spy_ens_df, 6)
print("\n$SPY Summary for Ensemble:")
prediction_accy(spy_ens_df, 7)

print("\n$COST Summary for W2:")
prediction_accy(cost_ens_df, 4)
print("\n$COST Summary for W3:")
prediction_accy(cost_ens_df, 5)
print("\n$COST Summary for W4:")
prediction_accy(cost_ens_df, 6)
print("\n$COST Summary for Ensemble:")
prediction_accy(cost_ens_df, 7)

# 'buy_stock' purchases stock on positive return days of a given prediction variable
def buy_stock(df, colnum):
    invest = 100
    invest_values = [invest]  # list to store investment values
    for row in range(1, len(df)):
        predicted_return = df.iloc[row, colnum]
        if predicted_return == '+':
            invest = invest+(invest * df['Return'].iloc[row])
        invest_values.append(invest)  # add the value for the day to the list
    return invest_values  # return the list of investment values

# 'buy_and_hold' tracks the performance of $100 worth of a given stock over time
def buy_and_hold(df):
    invest = 100
    invest_values = [invest]  # list to store investment values
    for row in range(1, len(df)):
        invest = invest + (invest * df['Return'].iloc[row])
        invest_values.append(invest)  # add the value for the day to the list
    return invest_values  # return the list of investment values

iv_spy_w2 = buy_stock(spy_ens_df, 4)
iv_spy_ens = buy_stock(spy_ens_df, 7)
iv_cost_w3 = buy_stock(cost_ens_df, 5)
iv_cost_ens = buy_stock(cost_ens_df, 7)

iv_spy_hold = buy_and_hold(spy_ens_df)
iv_cost_hold = buy_and_hold(cost_ens_df)

# plot investment values over time
plt.plot(spy_ens_df['Date'],iv_spy_w2, color='darkgreen', label='$SPY Investment: W2')
plt.plot(spy_ens_df['Date'],iv_spy_ens, color='green', label='$SPY Investment: Ensemble')
plt.plot(spy_ens_df['Date'],iv_cost_w3, color='darkblue', label='$COST Investment: W3')
plt.plot(spy_ens_df['Date'],iv_cost_ens, color='blue', label='$COST Investment: Ensemble')
plt.plot(spy_ens_df['Date'],iv_spy_hold, color='lightgreen', label='$SPY Investment: Buy & Hold')
plt.plot(spy_ens_df['Date'],iv_cost_hold, color='lightblue', label='$COST Investment: Buy & Hold')
plt.xlabel('Date')
plt.ylabel('Investment Value ($USD)')
plt.title('Investment Returns Based on Prediction Models')
plt.legend()
plt.grid(True)
plt.show()