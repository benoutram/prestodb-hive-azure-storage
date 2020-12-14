import pandas as pd
df = pd.read_csv('data/absence_by_characteristic.csv', dtype=str)
df.to_parquet('data/absence_by_characteristic.parquet')
