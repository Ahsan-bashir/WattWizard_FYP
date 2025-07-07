import numpy as np
import pandas as pd
from tensorflow.keras.models import load_model
from sklearn.preprocessing import MinMaxScaler
from datetime import datetime

units_consumption_limit_in_a_month = 300

high_temp_limit = 35 # if rooms temp goes above 35, and it is not peak hour, turn ac on
high_current_limit = 10
high_voltage_limit = 240
low_voltage_limit = 200

peak_hour_start_time = 18 #6PM
peak_hour_end_time = 22 #10pm

high_temperatur_buzzer_warning = False
low_moisture_warning = False
low_voltage_buzzer_warning = False # buzzer beeps
high_voltage_buzzer_warning = False # buzzer beeps
high_curren_buzzer_warning = False
units_consumption_buzzer_warning = False #if units are about to complete, give beep to alert user

# Load the trained model
model = load_model('energy_load_predictor_model.h5')

# Load the scaler used during training
scaler = MinMaxScaler()
data = pd.read_csv('energy_data_updated.csv')
features = data[['Year', 'Month', 'Day', 'Hour', 'Minute', 'Temperature', 'Humidity','Voltage', 'Current', 'Power']]
scaler.fit(features)

# Get current date and time
now = datetime.now()
year = now.year
month = now.month
day = now.day
hour = now.hour
minute = now.minute

temperature = float(input('Enter current temperature (°C): '))
humidity = float(input('Enter current humidity (%): '))

wapda_voltage = float(input('Enter wapda voltage from sensor (V): '))
current_being_used = float(input('Enter current consumption from sensor (A): '))
power_usage_calculated = float(wapda_voltage * current_being_used)

# Prepare the input for prediction
sample_input = pd.DataFrame({
    'Year': [year],
    'Month': [month],
    'Day': [day],
    'Hour': [hour],
    'Minute': [minute],
    'Temperature': [temperature],
    'Humidity': [humidity],
    'Voltage': [wapda_voltage], 
    'Current': [current_being_used], 
    'Power': [power_usage_calculated]
})

# Scale the input
scaled_input = scaler.transform(sample_input)

# Reshape for LSTM input (1 sample, 1 time step, 10 features)
scaled_input = np.reshape(scaled_input, (1, 1, 10))  # Shape: (1, 1, 10)

# Make the prediction
prediction = model.predict(scaled_input)

# Convert prediction to binary (on/off)
prediction_binary = (prediction > 0.5).astype(int)

# Map the prediction to device names
devices = ['Fan', 'Bulb1', 'Bulb2', 'AC']

print("\nPrediction for current datetime:")
print(sample_input)
print()

for device, state in zip(devices, prediction_binary[0]):
    status = 'ON' if state == 1 else 'OFF'
    print(f"{device}: {status}")
