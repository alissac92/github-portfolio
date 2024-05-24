""" 
Alissa Crist
Description of Problem:
This program takes a fictional, anonymized dataset of credit
card transactions and implements various classification models
to predict whether a transaction will be fraud or not. Methods
used include logistic regression, k-NN, Naive Bayes, Decision Tree
and clustering with k-means.
"""

import pandas as pd
import random
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.naive_bayes import GaussianNB
from sklearn.tree import DecisionTreeClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix

# --- PROJECT SETUP --- #

# read csv into df and print head
fraud_df = pd.read_csv("creditcard_2023.csv", sep=",")
print(fraud_df.head())

# describe data
print(fraud_df.describe().T)

# check for null values
print(fraud_df.isnull().sum())

# create subset of fraud_df for class = 0 (Not Fraud)
fraud_df_0 = fraud_df[fraud_df['Class'] == 0]
print(fraud_df_0)

# create subset of fraud_df for class = 1 (Fraud)
fraud_df_1 = fraud_df[fraud_df['Class'] == 1]
print(fraud_df_1)

# print mean and sd for all classes
print("\nMean and SD for all classes:\n")
print("Mean\n")
print(fraud_df.mean(axis=0, numeric_only=True))
print("\nSD\n")
print(fraud_df.std(axis=0, numeric_only=True))

# print mean and sd for class = 0 (Not Fraud)
print("\nMean and SD for Class = 0:\n")
print("Mean\n")
print(fraud_df_0.mean(axis=0, numeric_only=True))
print("\nSD\n")
print(fraud_df_0.std(axis=0, numeric_only=True))

# print mean and sd for class = 1 (Fraud)
print("\nMean and SD for class = 1:\n")
print("Mean\n")
print(fraud_df_1.mean(axis=0, numeric_only=True))
print("\nSD\n")
print(fraud_df_1.std(axis=0, numeric_only=True))

# drop 'id' column for corr matrix
fraud_df2 = fraud_df.drop(columns=['id'])

# create corr matrix for features/target class in sorted order (highest first)
correlation_matrix = fraud_df2.corr()
correlation_with_target = correlation_matrix['Class'].sort_values(ascending=False)

# select top 10 features based on corr with the target variable
top_features = correlation_with_target.index[:11]
# create corr matrix for top features
correlation_matrix_top = fraud_df2[top_features].corr()

# create and plot heatmap
plt.figure(figsize=(10, 8))
sns.heatmap(correlation_matrix_top, annot=True, cmap='coolwarm', fmt=".2f", linewidths=.5)
plt.title('Correlation Heatmap of Features to Target Class')
plt.show()

# V4, 11, 2, 19, 27 are top correlated features

# create labels for classes
class_labels = {0: 'Class 0: No Fraud', 1: 'Class 1: Fraud'}

# calc class distribution
class_counts = fraud_df['Class'].value_counts()

# create and show pie chart
plt.figure(figsize=(10, 8))
plt.pie(class_counts, labels=[class_labels[idx] for idx in class_counts.index], autopct='%1.1f%%',
        startangle=90, colors=sns.color_palette('icefire'))
plt.title('Class Distribution')
plt.show()

# feature scaling
fraud_df_fts = fraud_df.drop('Class', axis=1)
scaler = StandardScaler()
fraud_df_scaled = scaler.fit_transform(fraud_df_fts)
fraud_df_scaled = pd.DataFrame(fraud_df_scaled, columns=fraud_df_fts.columns)

# initialize features (X) and target class (y)
X = fraud_df_scaled[['V4', 'V11', 'V2', 'V19', 'V27']]
y = fraud_df['Class'].ravel()

# split testing and training data with a 70/30 ratio
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, stratify=y, random_state=92)

# -- LOGISTIC REGRESSION -- #

# create and fit logistic regression model
log_rgsn_mdl = LogisticRegression()
log_rgsn_mdl.fit(X_train, y_train)

# predict class
y_pred = log_rgsn_mdl.predict(X_test)

# evaluate accuracy
lr_accuracy = accuracy_score(y_test, y_pred)
print(f"\nLogistic Regression Accuracy: {lr_accuracy:.2f}")

# create and plot confusion matrix
lr_mtx = confusion_matrix(y_test,y_pred)
sns.heatmap(lr_mtx.T, square=True, annot=True, fmt='d', cbar=True)
plt.title('Logistic Regression')
plt.xlabel('true label')
plt.ylabel('predicted label')
plt.show()

# Extract TP, FP, TN, FN from the confusion matrix
TP = lr_mtx[1, 1]
FP = lr_mtx[0, 1]
TN = lr_mtx[0, 0]
FN = lr_mtx[1, 0]

# Print TP, FP, TN, FN, TPR, TNR
print(f"True Positives (TP): {TP}")
print(f"False Positives (FP): {FP}")
print(f"True Negatives (TN): {TN}")
print(f"False Negatives (FN): {FN}")
print(f"TPR: {TP/(TP+FP):.2f}")
print(f"TNR: {TN/(TN+FN):.2f}")

# -- k-NN -- #

# feature scaling for kNN
scaler = StandardScaler()
X_train_sc = scaler.fit_transform(X_train)
X_test_sc = scaler.transform(X_test)

# find optimal value for k
k_values = range(1, 10)
accuracies = []

for k in k_values:
    knn = KNeighborsClassifier(n_neighbors=k)
    knn.fit(X_train, y_train)
    y_pred = knn.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    accuracies.append(accuracy)

plt.plot(k_values, accuracies, marker='o')
plt.xlabel('Number of Neighbors (k)')
plt.ylabel('Accuracy')
plt.title('kNN: Accuracy vs. k')
plt.show()

# optimal k value is 3
classifier = KNeighborsClassifier(n_neighbors=3)
classifier.fit(X_train_sc, y_train)

# make predictions
y_pred = classifier.predict(X_test_sc)

# create and plot confusion matrix
knn_mtx = confusion_matrix(y_test, y_pred)
sns.heatmap(knn_mtx.T, square=True, annot=True, fmt='d', cbar=True)
plt.title('K-NN (k=3)')
plt.xlabel('true label')
plt.ylabel('predicted label')
plt.show()

# Extract TP, FP, TN, FN from the confusion matrix
TP = knn_mtx[1, 1]
FP = knn_mtx[0, 1]
TN = knn_mtx[0, 0]
FN = knn_mtx[1, 0]

# evaluate accuracy
knn_accuracy = accuracy_score(y_test, y_pred)
print(f"\nkNN Accuracy (k=3): {knn_accuracy:.2f}")

# Print TP, FP, TN, FN, TPR, TNR
print(f"True Positives (TP): {TP}")
print(f"False Positives (FP): {FP}")
print(f"True Negatives (TN): {TN}")
print(f"False Negatives (FN): {FN}")
print(f"TPR: {TP/(TP+FP):.2f}")
print(f"TNR: {TN/(TN+FN):.2f}")

# -- NAIVE BAYES -- #

# create and fit NB model
gnb_model = GaussianNB()
gnb_model.fit(X_train, y_train)

# predict labels on test set
y_pred = gnb_model.predict(X_test)

# create and plot confusion matrix
gnb_mtx = confusion_matrix(y_test, y_pred)
sns.heatmap(gnb_mtx.T, square=True, annot=True, fmt='d', cbar=True)
plt.title('Naive Bayes')
plt.xlabel('true label')
plt.ylabel('predicted label')
plt.show()

# Extract TP, FP, TN, FN from the confusion matrix
TP = gnb_mtx[1, 1]
FP = gnb_mtx[0, 1]
TN = gnb_mtx[0, 0]
FN = gnb_mtx[1, 0]

# evaluate accuracy
gnb_accuracy = accuracy_score(y_test, y_pred)
print(f"\nGaussian Naive Bayes' Accuracy: {gnb_accuracy:.2f}")

# Print TP, FP, TN, FN, TPR, TNR
print(f"True Positives (TP): {TP}")
print(f"False Positives (FP): {FP}")
print(f"True Negatives (TN): {TN}")
print(f"False Negatives (FN): {FN}")
print(f"TPR: {TP/(TP+FP):.2f}")
print(f"TNR: {TN/(TN+FN):.2f}")

# --- DECISION TREE ---

# create and fit decision tree classifier
dt = DecisionTreeClassifier(random_state=92)
dt = dt.fit(X_train, y_train)

# predict labels on test set
y_pred = dt.predict(X_test)

# create and plot confusion matrix
dt_mtx = confusion_matrix(y_test, y_pred)
sns.heatmap(dt_mtx.T, square=True, annot=True, fmt='d', cbar=True)
plt.title('Decision Tree')
plt.xlabel('true label')
plt.ylabel('predicted label')
plt.show()

# Extract TP, FP, TN, FN from the confusion matrix
TP = dt_mtx[1, 1]
FP = dt_mtx[0, 1]
TN = dt_mtx[0, 0]
FN = dt_mtx[1, 0]

# evaluate accuracy
dt_accuracy = accuracy_score(y_test, y_pred)
print(f"\nDecision Tree Accuracy: {dt_accuracy:.2f}")

# Print TP, FP, TN, FN, TPR, TNR
print(f"True Positives (TP): {TP}")
print(f"False Positives (FP): {FP}")
print(f"True Negatives (TN): {TN}")
print(f"False Negatives (FN): {FN}")
print(f"TPR: {TP/(TP+FP):.2f}")
print(f"TNR: {TN/(TN+FN):.2f}")

# --- k-Means Clustering --- #

# create feature and target arrays from original dataset
X = fraud_df[['V4', 'V11', 'V2', 'V19', 'V27']]
y = fraud_df['Class'].ravel()

# scale data
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# create_knee_plot analyzes k-value vs. SSE to find optimal k
def create_knee_plot(X, max_k):
    sse = []
    for i in range(1, max_k + 1):
        kmeans = KMeans(n_clusters=i, init='random', n_init=10)
        kmeans.fit(X)
        sse.append(kmeans.inertia_)
    plt.plot(range(1, max_k + 1), sse, '-b')
    plt.xlabel('k')
    plt.ylabel('Inertia (SSE)')
    plt.title('Knee Plot')

create_knee_plot(X_scaled, 8)
plt.show()

# create a sample of 50k for better runtime
sample_size = 50000
random_indices = random.sample(range(len(fraud_df)), sample_size)
sample_df = fraud_df.iloc[random_indices, :].copy()

# features for clustering
features = ['V4', 'V11', 'V2', 'V19', 'V27']
X_sample = sample_df[features]

# standardize features
scaler = StandardScaler()
X_sample_scaled = scaler.fit_transform(X_sample)

# create the k-means clusters (clusters = 2)
kmeans = KMeans(n_clusters=2, init='random', n_init=10, random_state=92)
sample_df['KMeans_Cluster'] = kmeans.fit_predict(X_sample_scaled)

# plot k-means clusters
plt.scatter(X_sample_scaled[:, 0], X_sample_scaled[:, 1],
            c=sample_df['KMeans_Cluster'], cmap='viridis', s=50)
plt.xlabel(f'V4 (Scaled)')
plt.ylabel(f'V11 (Scaled)')
plt.title('k-Means Clustering')
plt.show()
