# TalkLess

A professional QML-based desktop application for audio management.

## Project Structure

```
TalkLess/
├── src/                      # Source code
│   ├── controllers/          # Business logic controllers
│   ├── models/              # Data models
│   └── main.cpp             # Application entry point
├── qml/                     # QML files
│   ├── components/          # Reusable UI components
│   ├── pages/               # Application pages/views
│   ├── styles/              # Theme, colors, typography
│   └── utils/               # QML utility functions
├── resources/               # Application resources
│   ├── images/             # Image assets
│   └── fonts/              # Font files
├── config/                  # Configuration files
├── docs/                    # Documentation
└── build/                   # Build output (excluded from git)
```

## Features

- System Settings Management
- Audio Device Configuration
- Global Hotkey Mapping
- Feature Toggles
- UI Customization
- Auto-Update System

## Development

Built with:
- Qt 6.10.1
- QML
- CMake

## Build Instructions

1. Open the project in Qt Creator
2. Configure with Qt 6.10.1 MinGW 64-bit
3. Build and Run

## Architecture

This project follows the MVC (Model-View-Controller) pattern:
- **Models**: Data structures and business logic (in `src/models/`)
- **Views**: QML UI components (in `qml/`)
- **Controllers**: Application logic (in `src/controllers/`)

Currently, only the View layer is implemented.
