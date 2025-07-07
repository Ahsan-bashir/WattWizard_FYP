import pandas as pd
import numpy as np
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.optimizers import Adam

# Load the dataset
df = pd.read_csv('energy_data_updated.csv')

# Extract features and target columns
features = ['Year', 'Month', 'Day', 'Hour', 'Minute', 'Temperature', 'Humidity', 'Voltage', 'Current', 'Power']
target = ['Fan', 'Bulb1', 'Bulb2', 'AC']  # Devices to predict

# Prepare input (X) and output (y) datasets
X = df[features].values
y = df[target].values

# Normalize the features using MinMaxScaler
scaler = MinMaxScaler()
X_scaled = scaler.fit_transform(X)

# Reshape X to be 3D for LSTM input (samples, timesteps, features)
X_scaled = X_scaled.reshape(X_scaled.shape[0], 1, X_scaled.shape[1])

# Build the LSTM model
model = Sequential()

# LSTM layer with 50 units
model.add(LSTM(units=50, return_sequences=False, input_shape=(X_scaled.shape[1], X_scaled.shape[2])))

# Dense layer for output
model.add(Dense(units=4, activation='sigmoid'))  # Output layer: 4 devices (Fan, Bulb1, Bulb2, AC)

# Compile the model
model.compile(optimizer=Adam(learning_rate=0.001), loss='binary_crossentropy', metrics=['accuracy'])

# Train the model
model.fit(X_scaled, y, epochs=150, batch_size=8, validation_split=0.2)

# Save the trained model
model.save('energy_load_predictor_model.h5')

print("Model trained and saved successfully.")
