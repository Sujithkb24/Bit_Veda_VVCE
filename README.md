# Bit_Veda_VVCE 

## Intelligent Medication Management System

Bit_Veda is an innovative IoT-based healthcare application that combines a smart pill dispenser hardware device with a mobile application to ensure accurate, timely, and reliable medication management. The system is designed to help users manage their medications seamlessly, reducing medication errors and improving health outcomes.

---

## 📋 Table of Contents

- [Features](#features)
- [Hardware Specifications](#hardware-specifications)
- [System Architecture](#system-architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Technical Stack](#technical-stack)
- [Contributing](#contributing)
- [License](#license)

---

## ✨ Features

### Mobile Application Features

#### 📱 **Medication Management**
- **Prescription Tracking**: Add, edit, and manage multiple medications with detailed information
- **Schedule Management**: Set customizable medication schedules (daily, weekly, monthly patterns)
- **Dosage Tracking**: Track dosage amounts, frequency, and medication type
- **Medication History**: View complete medication history with timestamps and consumption records

#### 🔔 **Smart Notifications**
- Real-time push notifications for medication reminders
- Customizable notification preferences and sound settings
- Snooze and confirm medication intake directly from notifications
- Silent mode compliance with user preferences

#### 👥 **User Profile & Family Support**
- Multi-user support for family members or caregivers
- Caregiver dashboard to monitor medication adherence
- Emergency contact management
- Medical history and allergy information storage

#### 📊 **Analytics & Reporting**
- Medication adherence statistics and trends
- Visual graphs showing medication compliance rates
- Monthly and weekly adherence reports
- Health insights and recommendations

#### 🔐 **Security & Privacy**
- Secure authentication with encrypted credentials
- HIPAA-compliant data storage
- End-to-end encryption for sensitive health data
- Privacy controls and data access permissions

#### 🌙 **User Experience**
- Intuitive and user-friendly interface
- Dark mode support
- Multi-language support
- Accessibility features for elderly users

### Hardware Features

#### ⚙️ **Smart Pill Dispenser Hardware**
- **Multi-Compartment Design**: Holds up to 28 days of medication (4 compartments per day)
- **Automated Dispensing**: Motorized rotating carousel for accurate pill dispensing
- **Real-time Status**: LED indicators showing dispenser status and activity
- **Temperature Control**: Climate-controlled compartments to preserve medication integrity
- **Tamper Detection**: Security mechanisms to prevent unauthorized access

#### 🔋 **Connectivity & Power**
- **Wireless Connectivity**: Bluetooth 5.0 for seamless communication with mobile app
- **WiFi Integration**: Optional WiFi module for remote monitoring and updates
- **Battery Backup**: 7-day backup power with low battery alerts
- **USB-C Charging**: Fast charging capability with charging status indicator

#### 🛡️ **Safety Features**
- **Medication Verification**: RFID scanning for accurate pill identification
- **Child-Proof Locks**: Secure locking mechanism with dual-authentication
- **Spillage Detection**: Sensors to detect and alert on medication spillage
- **Overfill Prevention**: Capacity sensors to prevent compartment overfilling

#### 📡 **Smart Features**
- **Voice Activation**: Voice-controlled reminders (optional)
- **Motion Sensors**: Activity detection to notify caregivers
- **Environmental Monitoring**: Temperature and humidity tracking
- **Usage Analytics**: Tracks medication dispensing patterns

---

## 🔧 Hardware Specifications

### Physical Specifications
- **Dimensions**: 200mm (W) × 150mm (D) × 120mm (H)
- **Weight**: 850g (without medication)
- **Material**: Food-grade plastic with stainless steel components
- **Color Options**: White, Black, Blue

### Technical Specifications
- **Processing Unit**: ARM Cortex-M4 Microcontroller
- **Memory**: 256KB Flash, 64KB RAM
- **Bluetooth**: BLE 5.0 (range up to 100m)
- **WiFi**: Optional IEEE 802.11 b/g/n (2.4GHz)
- **Battery**: 3000mAh Li-ion rechargeable battery
- **Charging Time**: 2-3 hours via USB-C
- **Operating Temperature**: 5°C to 40°C
- **Storage Temperature**: -10°C to 60°C
- **Humidity**: 20% - 80% (non-condensing)

### Compartment Details
- **Total Compartments**: 28 (7 days × 4 daily compartments)
- **Compartment Capacity**: 15-20 pills per compartment
- **Rotation Mechanism**: Stepper motor with encoder feedback
- **Dispensing Accuracy**: ±99.5%

### Sensors & Actuators
- **Motion Sensor**: PIR for activity detection
- **Temperature Sensor**: DHT22 for environmental monitoring
- **RFID Reader**: For medication identification
- **Stepper Motor**: NEMA 17 for carousel rotation
- **LEDs**: RGB status indicators
- **Speaker**: 1W audio output for alerts

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile Application                    │
│                   (Flutter - Dart)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   UI Layer   │  │ State Mgmt   │  │ Local Storage│  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└────────────┬────────────────────────────────────────────┘
             │ Bluetooth / WiFi
             ↓
┌─────────────────────────────────────────────────────────┐
│              Smart Pill Dispenser                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Microcontroller (STM32)        │  │   Sensors    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Motor Control & Dispensing Logic         │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────────────────┐
│           Cloud Backend (Optional)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  User Auth   │  │  Data Storage│  │  Analytics   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Installation

### Prerequisites
- Flutter SDK (version 3.0 or higher)
- Dart SDK (included with Flutter)
- Android Studio or Xcode
- Git

### Mobile App Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Sujithkb24/Bit_Veda_VVCE.git
   cd Bit_Veda_VVCE
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the Application**
   ```bash
   flutter run
   ```

### Hardware Setup

1. **Assemble Components**
   - Install the microcontroller board in the main enclosure
   - Connect the stepper motor to the motor driver
   - Attach sensors (temperature, motion, RFID)
   - Connect Bluetooth module (HC-05 or BLE module)
   - Install battery and charging module

2. **Flash Firmware**
   ```bash
   # Using STM32CubeProgrammer
   st-flash write firmware.bin 0x08000000
   ```

3. **Calibration**
   - Run motor calibration routine
   - Test all sensors
   - Verify Bluetooth connectivity
   - Test dispensing mechanism with dummy pills

---

## 💡 Usage

### For End Users

#### First-Time Setup
1. Download and install the Bit_Veda app
2. Create an account or sign in
3. Add your medications with details (name, dosage, frequency)
4. Pair your pill dispenser via Bluetooth
5. Load medications into the dispenser compartments
6. Confirm setup and start receiving reminders

#### Daily Operations
1. Receive medication reminders at scheduled times
2. Open the dispenser compartment automatically (if applicable)
3. Confirm medication intake in the app
4. View your adherence dashboard


### For Healthcare Providers

- Access patient medication adherence reports
- Modify medication schedules remotely
- Receive alerts for missed medications
- Track medication compliance trends

---

## 🛠️ Technical Stack

### Frontend
- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Provider / Riverpod
- **Local Storage**: SQLite / Hive
- **Notifications**: Firebase Cloud Messaging

### Backend (Optional)
- **Server**: Node.js / Python Flask
- **Database**: PostgreSQL / MongoDB
- **Authentication**: JWT
- **API**: RESTful / GraphQL

### Hardware
- **Microcontroller**: STM32F4 Series
- **Wireless**: Bluetooth 5.0 / WiFi Module
- **Motor Control**: Stepper Driver (A4988)
- **Sensors**: DHT22, HC-SR501, MFRC522 RFID
- **Development**: STM32CubeIDE / Arduino IDE

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Dart style guide and best practices
- Write unit tests for new features
- Update documentation for significant changes
- Test on both Android and iOS platforms

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👨‍💻 About

**Bit_Veda** was developed at **VVCE (Vidyavardhaka College of Engineering)** as an innovative solution to improve medication adherence and reduce healthcare-related errors. The project combines IoT, mobile development, and healthcare technology to create a user-friendly medication management system.

---

## 📞 Support & Contact

For questions, bug reports, or feature requests:
- Open an issue on GitHub
- Contact: Sujithkb24@github

---

## 🙏 Acknowledgments

- Vidyavardhaka College of Engineering (VVCE)
- Flutter and Dart communities
- IoT and embedded systems enthusiasts
- Healthcare professionals who provided valuable insights

---

**Last Updated**: April 25, 2026
