# flutter-w

A CLI wrapper for Flutter that provides automatic hot reload and hot restart on file changes, making Flutter development easier in any text editor or terminal.

## Features

- **Automatic Hot Reload**: Watches Dart files and triggers hot reload when changes are detected
- **Automatic Hot Restart**: Watches configuration files (like `pubspec.yaml`) and triggers hot restart when modified
- **Editor Agnostic**: Works with any text editor or IDE - no Flutter plugin required
- **Flexible File Watching**: Configure which paths to watch for reload or restart
- **Pass-through Arguments**: Supports all Flutter run arguments
- **Debouncing**: Prevents excessive reloads with configurable debounce timing

## Installation

### Prerequisites

1. **Flutter SDK** installed and in your PATH
2. **Dart SDK** (comes with Flutter)
3. **Xcode** and Command Line Tools (for iOS development on macOS)

### Install via Dart pub

```bash
dart pub global activate --source path /path/to/flutter-watch-cli
```

Or if you have the package published:

```bash
dart pub global activate flutter_w
```

Make sure your Dart global packages are in your PATH:
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

## Usage

### Basic Usage

Start Flutter with auto hot-reload on file changes:

```bash
flutter-w run
```

### Specify Device

Run on a specific device:

```bash
flutter-w run -d ios
flutter-w run -d "iPhone 15"
flutter-w run -d chrome
```

### Custom Watch Paths

Watch specific directories or files:

```bash
# Watch lib and assets for hot reload
flutter-w run -w lib -w assets

# Watch pubspec.yaml and config files for hot restart
flutter-w run -W pubspec.yaml -W config/
```

### Pass Arguments to Flutter

Pass additional arguments to Flutter run using `--`:

```bash
flutter-w run -d ios -- --flavor staging
flutter-w run -d chrome -- --web-renderer canvaskit
```

### All Options

```
OPTIONS:
  -d, --device <id>         Device id/name (passes through to flutter run -d)
  -w, --watch <path>        Paths/globs to hot reload on change (repeatable)
                            (default: lib)
  -W, --restart-watch <p>   Paths/globs to hot restart on change (repeatable)
                            (default: pubspec.yaml)
  -b, --debounce <ms>       Debounce milliseconds (default: 200)
  -v, --verbose             Verbose logging
      --no-run              Only print the flutter command, don't execute
  -h, --help                Show help
```

## How It Works

1. **Process Management**: Spawns `flutter run` as a child process
2. **File Watching**: Uses Dart's `watcher` package to monitor file system changes
3. **Hot Reload/Restart**: Sends keyboard commands (`r` for reload, `R` for restart) to the Flutter process
4. **Debouncing**: Groups rapid file changes together to avoid excessive reloads

## Examples

### Development with Hot Reload

```bash
# Basic development
flutter-w run

# iOS Simulator with verbose logging
flutter-w run -d ios -v

# Web development with custom renderer
flutter-w run -d chrome -- --web-renderer html
```

### Custom Watch Configuration

```bash
# Watch multiple directories
flutter-w run -w lib -w assets -w test

# Different debounce timing (500ms)
flutter-w run -b 500

# Watch everything in src/ for reload, config files for restart
flutter-w run -w src/ -W "*.yaml" -W "*.json"
```

## Environment Variables

- `FLUTTER_BIN`: Override the Flutter executable path (default: `flutter`)

```bash
FLUTTER_BIN=/custom/path/to/flutter flutter-w run
```

## Troubleshooting

### Flutter command not found
Make sure Flutter is in your PATH:
```bash
export PATH="$PATH:/path/to/flutter/bin"
```

### Permission denied
Make the script executable:
```bash
chmod +x ~/.pub-cache/bin/flutter-w
```

### Hot reload not working
- Ensure you're running in debug mode (not release)
- Check that the files you're editing are in watched paths
- Use `-v` flag for verbose logging to see what's being watched

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

Created to solve the issue of Flutter hot reload not working automatically in terminal/non-IDE environments, especially after dealing with CocoaPods installation issues on macOS.