# 🚗 Road Accident Severity Prediction & Risk Analysis 

![Hugging Face](https://img.shields.io/badge/%F0%9F%A4%97%20Hugging%20Face-Model-orange)
![Python](https://img.shields.io/badge/Python-3.8+-blue?logo=python&logoColor=white)
![scikit-learn](https://img.shields.io/badge/scikit--learn-ML-orange?logo=scikit-learn&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📌 Project Overview

This project focuses on identifying the **environmental and infrastructural drivers** behind road accident severity. Using a dataset of over **307,000 historical incidents**, I developed a machine learning pipeline to classify accidents as **Slight**, **Serious**, or **Fatal**.

The unique value of this project lies in its **Risk-Scoring System**, which identifies high-risk "profiles" even in scenarios where a slight accident is statistically more probable.

---

## 📊 Data Audit & Attributes

The dataset was initially provided as a **42MB Excel file** containing detailed logs of traffic incidents.

| Property | Value |
|---|---|
| Initial Records | 307,973 |
| Final Features | 62 (after One-Hot Encoding) |

**Core Attributes:**

- **Temporal:** Accident Date, Day of Week, Month, Hour
- **Environmental:** Weather Conditions, Light Conditions, Road Surface Conditions
- **Infrastructure:** Speed Limit, Road Type, Junction Control, Urban or Rural Area
- **Geospatial:** Latitude and Longitude

---

## 🛠️ Methodology (The A to Z Workflow)

### A. Data Preprocessing

- **Naming Standardization:** Reconciled inconsistent column naming (spaces vs. underscores)
- **Missing Value Strategy:**
  - Imputed Weather and Road Conditions using the **Mode**
  - Imputed Geospatial coordinates using the **Median**
  - Dropped `Carriageway_Hazards` due to extreme missingness (>98%)
- **Leakage Prevention:** Removed variables determined *after* the accident (e.g., Number of Casualties) to ensure a true predictive environment

### B. Feature Engineering

- **Temporal Extraction:** Extracted the Hour from timestamp strings using robust splitting to handle varied formats (`HH:MM` vs `HH:MM:SS`)
- **Categorical Transformation:** Implemented One-Hot Encoding for nominal data, expanding the feature space to capture non-linear relationships

### C. Exploratory Data Analysis (EDA)

> **Key Findings:**

- 🌤️ **The Weather Paradox:** 80% of accidents occur in *"Fine"* weather, suggesting driver complacency increases when conditions appear safe
- ⏰ **Diurnal Peak:** High-risk window identified between **15:00 – 17:00** (Evening Rush Hour)
- 🚀 **Speed Correlation:** While 30mph zones have the most accidents, **60–70mph zones show a significantly higher proportion of Fatal outcomes**

### D. Model Building — Random Forest

- **Algorithm Choice:** Random Forest was selected for its native multi-class support and ability to model complex feature interactions
- **Handling Imbalance (SMOTE):** Fatal incidents represent only **1.2%** of the data. SMOTE (Synthetic Minority Over-sampling) was used to balance the training set to **630,000+ samples**

---

## 📈 Performance & Validation

| Metric | Score |
|---|---|
| Baseline Accuracy | 85.4% *(biased toward majority "Slight" class)* |
| SMOTE-Balanced Accuracy | 80.03% *(improved Fatal & Serious detection)* |
| Cross-Validation (5-Fold) | Mean accuracy of **85.4%** across all folds |

> The SMOTE model sacrifices overall accuracy to significantly improve detection of high-severity incidents — a deliberate and critical tradeoff for real-world safety applications.

---

## ⚠️ Intelligent Warning System

Rather than outputting a binary label, the final system uses **Probability Thresholding**:

```
IF P(Fatal) > 2% → Trigger HIGH-RISK ALERT 🚨
```

This threshold is **double the historical baseline**, allowing traffic authorities to take preventive action — such as patrol deployment or speed reduction — based on risk *intensity* rather than just predicted class.

---

## 📦 Model & Data Storage

| Asset | Detail |
|---|---|
| Model Size | 1.97 GB (hosted on Hugging Face) |
| Dataset | Compressed to `.csv.gz` — 6MB |

> The model is hosted on [Hugging Face 🤗](https://huggingface.co/) due to GitHub's file size limits.

---

## ⚠️ Limitations & Bias

- **Human Factor:** The model does not account for driver behavioral data (distraction, alcohol, or fatigue) or demographics (age/experience)
- **Geography:** The model is optimized for specific regional infrastructure and may require **retraining** for different territories

---

## 👤 Author

**Hayam Wahdan**
*BI & Data Analyst*

[![GitHub](https://github.com/hayamwahdan)
[![LinkedIn](https://www.linkedin.com/in/hayamwahdan/)
[![Hugging Face]](https://huggingface.co/hayamwahdan/road-accident-severity-prediction)

### Prerequisites
```bash
pip install pandas numpy matplotlib seaborn scikit-learn imbalanced-learn joblib
