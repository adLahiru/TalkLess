# TalkLess Project Architecture

## Directory Structure

```
TalkLess/
├── src/                          # C++ Source Code
│   ├── controllers/              # Business logic controllers (future)
│   ├── models/                   # Data models (future)
│   └── main.cpp                  # Application entry point
│
├── qml/                          # QML User Interface
│   ├── components/               # Reusable UI Components
│   │   ├── ActionButton.qml      # Custom button with brackets styling
│   │   ├── DropdownSelect.qml    # Dropdown selection component
│   │   ├── FeatureToggleItem.qml # Feature row with toggle switch
│   │   ├── HeaderBar.qml         # Top header with search and user
│   │   ├── HotkeyItem.qml        # Hotkey mapping row component
│   │   ├── SettingsHeader.qml    # Page header with background
│   │   ├── SettingsTabBar.qml    # Pill-style tab navigation
│   │   ├── Sidebar.qml           # Left navigation sidebar
│   │   ├── SidebarItem.qml       # Individual sidebar menu item
│   │   └── ToggleSwitch.qml      # Custom toggle switch
│   │
│   ├── pages/                    # Application Pages/Views
│   │   ├── SystemSettingsPage.qml # Main settings container
│   │   ├── AudioDevicesTab.qml    # Audio device configuration
│   │   ├── HotkeysTab.qml        # Hotkey mapping interface
│   │   ├── FeaturesTab.qml       # Feature toggles
│   │   ├── UIDisplayTab.qml      # UI customization
│   │   └── UpdatesTab.qml        # Auto-update settings
│   │
│   ├── styles/                   # Centralized Styling System
│   │   ├── Colors.qml            # Color palette (singleton)
│   │   ├── Typography.qml        # Font styles (singleton)
│   │   ├── Theme.qml             # Spacing & dimensions (singleton)
│   │   └── qmldir                # Module definition
│   │
│   └── utils/                    # Utility Functions
│       ├── Functions.qml         # Helper functions (singleton)
│       └── qmldir                # Module definition
│
├── resources/                    # Application Assets
│   ├── images/                   # Image resources
│   │   ├── background-51.png
│   │   ├── background-52.png
│   │   └── background-53.png
│   └── fonts/                    # Custom fonts (future)
│
├── config/                       # Configuration Files
│   └── README.md                 # Config documentation
│
├── docs/                         # Documentation
│   └── README.md                 # Documentation index
│
├── build/                        # Build Output (gitignored)
│
├── .gitignore                    # Git ignore rules
├── CMakeLists.txt                # CMake build configuration
├── Main.qml                      # Application root window
└── README.md                     # Project overview
```

## Architecture Overview

### MVC Pattern

**Model (Data Layer)**
- Location: `src/models/`
- Purpose: Data structures, business entities
- Status: Prepared for future implementation

**View (Presentation Layer)**
- Location: `qml/`
- Purpose: User interface components and pages
- Status: ✅ Fully implemented

**Controller (Logic Layer)**
- Location: `src/controllers/`
- Purpose: Application logic, data flow control
- Status: Prepared for future implementation

### Component Hierarchy

```
ApplicationWindow (Main.qml)
├── Sidebar
│   └── SidebarItem (×9)
└── MainContent
    ├── HeaderBar
    └── SystemSettingsPage
        ├── SettingsHeader
        ├── SettingsTabBar
        └── TabContent (Stack)
            ├── AudioDevicesTab
            ├── HotkeysTab
            ├── FeaturesTab
            ├── UIDisplayTab
            └── UpdatesTab
```

## Styling System

### Centralized Theme Management

All styling values are managed through singleton QML objects:

**Colors.qml**
- Primary/secondary colors
- Background colors
- Text colors
- State colors (success, warning, error)
- Borders

**Typography.qml**
- Font families
- Font sizes (XXL → Tiny)
- Font weights
- Line heights
- Letter spacing

**Theme.qml**
- Spacing system (XXS → Huge)
- Border radius
- Component dimensions
- Animation durations
- Z-index layers

### Usage Example

```qml
import "../styles"

Rectangle {
    color: Colors.background
    radius: Theme.radiusLarge
    
    Text {
        font.pixelSize: Typography.fontSizeMedium
        color: Colors.textPrimary
    }
}
```

## Best Practices

### Component Development
1. Keep components focused and reusable
2. Use property aliases for customization
3. Emit signals for user interactions
4. Import centralized styles, not hardcode values

### File Organization
- Components: Generic, reusable UI elements
- Pages: Complete views that compose components
- Styles: Never hardcode colors/sizes
- Utils: Pure functions without UI

### Naming Conventions
- Files: PascalCase (e.g., `HeaderBar.qml`)
- Properties: camelCase (e.g., `userName`)
- Signals: camelCase (e.g., `onClicked`)
- Constants: UPPER_CASE (in styles)

## Build System

### CMake Configuration
- Auto-generated MOC files
- Resource compilation
- QML module system
- Import path configuration

### Qt 6.10.1 Features
- Modern QML module syntax
- Improved type safety
- Better tooling support
- Enhanced performance

## Future Enhancements

### Planned Features
- [ ] Implement data models
- [ ] Add controller logic
- [ ] Database integration
- [ ] API client services
- [ ] Unit tests
- [ ] Integration tests
- [ ] Localization support
- [ ] Custom fonts
- [ ] Icon system
- [ ] Animation library

### Architecture Improvements
- [ ] Service layer for business logic
- [ ] Repository pattern for data access
- [ ] Dependency injection
- [ ] State management system
- [ ] Error handling framework
- [ ] Logging system
