import pandas as pd
import random
from datetime import datetime

data = []

for _ in range(50):
    year = random.randint(2024, 2024)
    month = random.randint(1, 12)
    day = random.randint(1, 28)
    hour = random.randint(0, 23)
    minute = random.randint(0, 59)
    temperature = round(random.uniform(20, 40), 2)  # Round temperature to 2 decimals
    humidity = round(random.uniform(30, 70), 2)     # Round humidity to 2 decimals
    fan = random.choice([0, 1])           # Fan on/off (0 or 1)
    bulb1 = random.choice([0, 1])         # Bulb1 on/off (0 or 1)
    bulb2 = random.choice([0, 1])         # Bulb2 on/off (0 or 1)
    ac = random.choice([0, 1])            # AC on/off (0 or 1)
    voltage = round(random.uniform(200, 240), 2)  # Round voltage to 2 decimals
    current = round(random.uniform(0.5, 10), 2)  # Round current to 2 decimals
    power = round(voltage * current, 2)  # Power in Watts, rounded to 2 decimals

    data.append([year, month, day, hour, minute, temperature, humidity, fan, bulb1, bulb2, ac, voltage, current, power])

# Create and save DataFrame
columns = ['Year', 'Month', 'Day', 'Hour', 'Minute', 'Temperature', 'Humidity', 'Fan', 'Bulb1', 'Bulb2', 'AC', 'Voltage', 'Current', 'Power']
df = pd.DataFrame(data, columns=columns)

# Save to CSV
df.to_csv('energy_data_updated.csv', index=False)

