---
description: Build and Run TalkLess Application
---

# Build and Run Workflow

This workflow guides you through building and running the TalkLess application using CMake and the Visual Studio compiler.

## Prerequisites
- Windows OS
- Visual Studio (MSVC)
- CMake
- Qt 6.x

## Steps

// turbo
1. Create build directory
```powershell
if (!(Test-Path build)) { New-Item -ItemType Directory -Force -Path build }
```

// turbo
2. Configure project with CMake
```powershell
cmake -B build -S . -G "Visual Studio 17 2022" -A x64
```

// turbo
3. Build the application
```powershell
cmake --build build --config Release
```

// turbo
4. Run the application
```powershell
./build/Release/TalkLess.exe
```
