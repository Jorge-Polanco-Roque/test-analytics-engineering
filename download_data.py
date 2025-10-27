from ucimlrepo import fetch_ucirepo
import pandas as pd

# fetch dataset
bank_marketing = fetch_ucirepo(id=222)

# data (as pandas dataframes)
X = bank_marketing.data.features
y = bank_marketing.data.targets

# Combinar features y target
df = pd.concat([X, y], axis=1)

# metadata
print("=" * 80)
print("METADATA")
print("=" * 80)
print(bank_marketing.metadata)
print("\n")

# variable information
print("=" * 80)
print("VARIABLE INFORMATION")
print("=" * 80)
print(bank_marketing.variables)
print("\n")

# Información del dataframe
print("=" * 80)
print("DATAFRAME INFO")
print("=" * 80)
print(f"Shape: {df.shape}")
print(f"\nColumns: {df.columns.tolist()}")
print(f"\nData types:\n{df.dtypes}")
print(f"\nFirst 5 rows:\n{df.head()}")
print(f"\nNull values:\n{df.isnull().sum()}")
print(f"\nTarget distribution:\n{y.value_counts()}")

# Guardar a CSV
csv_filename = "bank_marketing_data.csv"
df.to_csv(csv_filename, index=False)
print(f"\n{'=' * 80}")
print(f"Data saved to: {csv_filename}")
print(f"{'=' * 80}")
