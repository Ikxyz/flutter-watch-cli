# Changelog

All notable changes to the flutter-w project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-08-30

### Added
- Initial release of flutter-w CLI tool
- Automatic hot reload on Dart file changes
- Automatic hot restart on configuration file changes
- Support for custom watch paths with `-w` and `-W` flags
- Device selection support with `-d` flag
- Configurable debounce timing with `-b` flag
- Pass-through arguments to Flutter run using `--` separator
- Verbose logging mode with `-v` flag
- Signal handling for graceful shutdown (SIGINT/Ctrl+C)
- Support for file, directory, and simple glob pattern watching
- Environment variable support for custom Flutter executable path (`FLUTTER_BIN`)
- Dry-run mode with `--no-run` flag to preview commands

### Technical Details
- Built with Dart using `watcher` package for file system monitoring
- Process management with stdin/stdout piping to Flutter process
- Debouncing mechanism to prevent excessive reloads
- Support for both file and directory watchers with recursive monitoring

### Background
This tool was created to solve the problem of Flutter hot reload not working automatically in terminal environments or text editors without Flutter IDE plugins. It emerged from troubleshooting CocoaPods installation issues on macOS, where using Homebrew-installed CocoaPods proved more reliable than gem-based installation with system Ruby.