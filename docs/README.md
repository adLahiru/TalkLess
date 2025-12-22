# Documentation

## Table of Contents

1. [Architecture](./architecture.md)
2. [Component Guide](./components.md)
3. [Styling Guide](./styling.md)
4. [Development Guidelines](./development.md)

## Quick Start

Refer to the main [README.md](../README.md) for project overview and build instructions.

## Architecture

The application follows a clean MVC architecture with a focus on modularity and reusability.

### Folder Structure

- **qml/components/** - Reusable UI components
- **qml/pages/** - Complete page views
- **qml/styles/** - Centralized styling system
- **qml/utils/** - Utility functions and helpers

### Styling System

All colors, typography, and theme values are centralized in singleton QML objects:
- `Colors.qml` - Color palette
- `Typography.qml` - Font settings
- `Theme.qml` - Spacing, dimensions, animations

## Component Development

When creating new components:
1. Place in `qml/components/`
2. Use the centralized styling system
3. Make components reusable and configurable
4. Document properties and signals

## Best Practices

- Use singleton styles instead of hardcoded values
- Keep components small and focused
- Follow Qt/QML naming conventions
- Use proper signal/slot connections
