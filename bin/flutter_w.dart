#!/usr/bin/env dart
import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

Future<int> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('run')
    ..addMultiOption('watch',
        abbr: 'w',
        help: 'Paths/globs to watch for hot reload.',
        defaultsTo: ['lib'])
    ..addMultiOption('restart-watch',
        abbr: 'W',
        help: 'Paths/globs to watch for hot restart.',
        defaultsTo: ['pubspec.yaml'])
    ..addOption('debounce',
        abbr: 'b',
        help: 'Debounce in milliseconds.',
        defaultsTo: '200')
    ..addOption('device',
        abbr: 'd',
        help:
            'Device id/name to pass to Flutter (same as flutter run -d <id>).')
    ..addFlag('verbose', abbr: 'v', help: 'Verbose logging.')
    ..addFlag('no-run', help: 'Do not spawn flutter; only print the command.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help.');

  // Split args at `--` to pass-through to flutter
  final sepIndex = arguments.indexOf('--');
  final selfArgs =
      sepIndex == -1 ? arguments : arguments.sublist(0, sepIndex);
  final passthrough =
      sepIndex == -1 ? const <String>[] : arguments.sublist(sepIndex + 1);

  ArgResults args;
  try {
    args = parser.parse(selfArgs);
  } catch (e) {
    _printUsage(parser, error: e.toString());
    return 64; // EX_USAGE
  }

  if (args['help'] == true || (args.command == null && !selfArgs.contains('run'))) {
    _printUsage(parser);
    return 0;
  }

  final isRun = args.command?.name == 'run' || selfArgs.contains('run');
  if (!isRun) {
    _printUsage(parser, error: 'Unknown command. Did you mean: flutter-w run ?');
    return 64;
  }

  final verbose = args['verbose'] == true;
  final watchPaths = (args['watch'] as List).cast<String>();
  final restartPaths = (args['restart-watch'] as List).cast<String>();
  final debounceMs = int.tryParse(args['debounce'] as String) ?? 200;
  final device = args['device'] as String?;

  // Compose flutter run command
  final flutterArgs = <String>['run'];
  if (device != null && device.isNotEmpty) {
    flutterArgs.addAll(['-d', device]);
  }
  flutterArgs.addAll(passthrough);

  if (args['no-run'] == true) {
    stdout.writeln('flutter ${flutterArgs.join(' ')}');
    return 0;
  }

  // Spawn flutter run
  final process = await Process.start(
    _flutterExecutable(),
    flutterArgs,
    runInShell: true,
    mode: ProcessStartMode.detachedWithStdio,
  );

  // Pipe stdout/stderr
  unawaited(stdout.addStream(process.stdout));
  unawaited(stderr.addStream(process.stderr));

  // Exit handling: if user hits Ctrl+C, forward to child then exit
  ProcessSignal.sigint.watch().listen((_) async {
    if (verbose) stderr.writeln('[flutter-w] SIGINT -> forwarding to flutter');
    process.stdin.writeln('q'); // graceful quit in flutter run
  });

  // Watchers
  final reload = _Debouncer(Duration(milliseconds: debounceMs), () {
    if (verbose) stderr.writeln('[flutter-w] hot reload (r)');
    process.stdin.write('r'); // no newline needed; but safe either way
  });
  final restart = _Debouncer(Duration(milliseconds: debounceMs), () {
    if (verbose) stderr.writeln('[flutter-w] hot restart (R)');
    process.stdin.write('R');
  });

  final subs = <StreamSubscription>[];

  void watchPath(String path, void Function() onEvent) {
    final entity = File(path);
    if (entity.existsSync()) {
      // File watcher
      final w = FileWatcher(p.normalize(path));
      subs.add(w.events.listen((_) => onEvent()));
      if (verbose) stderr.writeln('[flutter-w] watching file: $path');
      return;
    }
    // Directory watcher (recursive)
    final dir = Directory(path);
    if (dir.existsSync()) {
      final w = DirectoryWatcher(p.normalize(path));
      subs.add(w.events.listen((event) {
        final fp = event.path;
        // Limit to Dart by default for reload set, unless user gave custom path
        if (watchPaths.contains(path)) {
          if (fp.endsWith('.dart')) onEvent();
        } else {
          onEvent();
        }
      }));
      if (verbose) stderr.writeln('[flutter-w] watching dir: $path (recursive)');
      return;
    }
    // Glob (best-effort): split into parent + pattern
    final parent = Directory(p.dirname(path));
    final pattern = p.basename(path);
    if (parent.existsSync()) {
      final w = DirectoryWatcher(p.normalize(parent.path));
      subs.add(w.events.listen((event) {
        if (_matchesBasename(event.path, pattern)) onEvent();
      }));
      if (verbose) {
        stderr.writeln('[flutter-w] watching glob-like: $parent/$pattern');
      }
      return;
    }
    if (verbose) {
      stderr.writeln('[flutter-w] skip missing path: $path');
    }
  }

  for (final pth in watchPaths) {
    watchPath(pth, reload.call);
  }
  for (final pth in restartPaths) {
    watchPath(pth, restart.call);
  }

  // Exit when flutter run exits
  final code = await process.exitCode;

  // Cleanup
  for (final s in subs) {
    await s.cancel();
  }
  reload.dispose();
  restart.dispose();

  if (verbose) stderr.writeln('[flutter-w] flutter exited with code $code');
  return code;
}

String _flutterExecutable() {
  // Allow FLUTTER_BIN override
  final env = Platform.environment['FLUTTER_BIN'];
  if (env != null && env.isNotEmpty) return env;
  return 'flutter';
}

bool _matchesBasename(String filePath, String pattern) {
  // very small glob: *.yaml / *.dart
  if (pattern.startsWith('*.')) {
    return p.basename(filePath).endsWith(pattern.substring(1));
  }
  return p.basename(filePath) == pattern;
}

void _printUsage(ArgParser parser, {String? error}) {
  if (error != null) {
    stderr.writeln('Error: $error\n');
  }
  stdout.writeln('''
flutter-w — run Flutter with editor-agnostic auto reload/restart

USAGE:
  flutter-w run [options] [-- <args passed to flutter run>]

OPTIONS:
  -d, --device <id>         Device id/name (passes through to flutter run -d)
  -w, --watch <path>        Paths/globs to hot reload on change (repeatable)
                            (default: lib)
  -W, --restart-watch <p>   Paths/globs to hot restart on change (repeatable)
                            (default: pubspec.yaml)
  -b, --debounce <ms>       Debounce milliseconds (default: 200)
  -v, --verbose             Verbose logging
      --no-run              Only print the flutter command, don’t execute
  -h, --help                Show help

EXAMPLES:
  flutter-w run -d ios
  flutter-w run -d "iPhone 15" -- --flavor staging
  flutter-w run -w lib -w assets -W pubspec.yaml -d chrome -- --web-renderer canvaskit
''');
}

class _Debouncer {
  _Debouncer(this.duration, this.fn);
  final Duration duration;
  final void Function() fn;
  Timer? _t;
  void call() {
    _t?.cancel();
    _t = Timer(duration, fn);
  }

  void dispose() => _t?.cancel();
}