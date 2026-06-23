import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'command_runner.dart';
import 'tts_client.dart' show durationSeconds;

/// The result of a real render: a finished MP4 on disk.
class RenderResult {
  const RenderResult({
    required this.path,
    required this.scenes,
    required this.seconds,
    required this.bytes,
  });

  final String path;
  final int scenes;
  final double seconds;
  final int bytes;
}

/// Local video rendering, driven directly via ffmpeg (the fast designed-card
/// path) and Remotion (`npx remotion render`, the cinematic path) — no server
/// process. The app spawns the tools itself.
class RenderClient {
  RenderClient({CommandRunner runner = const SystemCommandRunner()})
    : _runner = runner;

  final CommandRunner _runner;

  static const _bg = '0x0F172A';
  static const _headlineColor = '0xE2E8F0';
  static const _subtitleColor = '0x94A3B8';
  static const _w = 1920;
  static const _h = 1080;
  static const _fps = 30;

  String get _font {
    const candidates = [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/System/Library/Fonts/Helvetica.ttc',
      '/Library/Fonts/Arial.ttf',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    return candidates.first;
  }

  Directory _renderDir() {
    final dir = Directory(
      '${Directory.systemTemp.path}/openmontage-media/render',
    );
    dir.createSync(recursive: true);
    return dir;
  }

  /// Render runtimes available here: ffmpeg always, Remotion when its composer
  /// (with installed deps) and `npx` are present.
  Future<List<String>> runtimes() async {
    final list = <String>['ffmpeg'];
    if (await _remotionAvailable()) list.add('remotion');
    return list;
  }

  /// Renders [scenes] to an MP4 using [runtime] ("ffmpeg" or "remotion"),
  /// narrated with [voice].
  Future<RenderResult> render(
    List<Map<String, dynamic>> scenes, {
    String? voice,
    String? runtime,
  }) async {
    final v = voice ?? 'Samantha';
    if (runtime == 'remotion' && await _remotionAvailable()) {
      return _renderRemotion(scenes, v);
    }
    return _renderFfmpeg(scenes, v);
  }

  /// Opens a finished clip in the default player. Best-effort.
  Future<void> open(String path) async => _runner.spawn('open', [path]);

  /// Reveals a finished clip in Finder. Best-effort.
  Future<void> reveal(String path) async => _runner.spawn('open', ['-R', path]);

  // --- ffmpeg runtime --------------------------------------------------------

  String _normHex(Object? value) {
    var v = (value as String?) ?? '22D3EE';
    v = v.replaceFirst('#', '');
    return v.startsWith('0x') ? v : '0x$v';
  }

  Future<RenderResult> _renderFfmpeg(
    List<Map<String, dynamic>> scenes,
    String voice,
  ) async {
    final work = _renderDir();
    final clips = <String>[];
    final durations = <double>[];

    for (var i = 0; i < scenes.length; i++) {
      final sc = scenes[i];
      final headline =
          ((sc['headline'] ?? sc['title'] ?? '') as String).trim();
      final subtitle = ((sc['subtitle'] ?? '') as String).trim();
      final title = ((sc['title'] ?? '') as String).trim();
      final stype = ((sc['type'] ?? '') as String).trim();
      final seconds = (sc['seconds'] as num?)?.toDouble() ?? 4;
      final accent = _normHex(sc['accent']);

      final narration = [
        headline,
        subtitle,
      ].where((s) => s.isNotEmpty).join('. ');
      final narrPath = '${work.path}/narr_$i.aiff';
      var adur = 0.0;
      if (narration.isNotEmpty) {
        final r = await _runner.run('say', ['-v', voice, '-o', narrPath, narration]);
        if (r.ok) adur = await durationSeconds(_runner, narrPath);
      }
      final duration = [seconds, adur + 0.3, 1.5].reduce(max);
      durations.add(duration);

      final int hsize;
      if (stype == 'stat_card') {
        hsize = 124;
      } else if (headline.length > 26) {
        hsize = 62;
      } else if (headline.length > 16) {
        hsize = 84;
      } else {
        hsize = 98;
      }
      final hcolor = stype == 'stat_card' ? accent : _headlineColor;

      final filters = <String>['vignette=PI/4.5'];
      if (headline.isNotEmpty) {
        filters.add(
          'drawbox=x=(iw-96)/2:y=${(_h * 0.40).round()}:w=96:h=6:color=$accent@1:t=fill',
        );
      }
      if (title.isNotEmpty) {
        final kf = File('${work.path}/kick_$i.txt')
          ..writeAsStringSync(title.toUpperCase());
        filters.add(
          'drawtext=fontfile=$_font:textfile=${kf.path}:fontcolor=$accent:fontsize=32:'
          "x=(w-text_w)/2:y=${(_h * 0.33).round()}:alpha='if(lt(t,0.3),t/0.3,1)'",
        );
      }
      if (headline.isNotEmpty) {
        final hf = File('${work.path}/head_$i.txt')
          ..writeAsStringSync(headline);
        filters.add(
          'drawtext=fontfile=$_font:textfile=${hf.path}:fontcolor=$hcolor:fontsize=$hsize:'
          "x=(w-text_w)/2:y=${(_h * 0.45).round()}:alpha='if(lt(t,0.45),t/0.45,1)':"
          'shadowcolor=black@0.6:shadowx=0:shadowy=3',
        );
      }
      if (subtitle.isNotEmpty) {
        final sf = File('${work.path}/sub_$i.txt')
          ..writeAsStringSync(subtitle);
        filters.add(
          'drawtext=fontfile=$_font:textfile=${sf.path}:fontcolor=$_subtitleColor:fontsize=44:'
          'x=(w-text_w)/2:y=${(_h * 0.45).round() + hsize + 30}:'
          "alpha='if(lt(t,0.35),0,if(lt(t,0.75),(t-0.35)/0.4,1))'",
        );
      }
      if (i == 0) filters.add('fade=t=in:st=0:d=0.5');
      if (i == scenes.length - 1) {
        filters.add(
          'fade=t=out:st=${max(0.0, duration - 0.6).toStringAsFixed(2)}:d=0.6',
        );
      }

      final clip = '${work.path}/clip_$i.mp4';
      final cmd = <String>[
        '-hide_banner', '-y',
        '-f', 'lavfi',
        '-i', 'color=c=$_bg:s=${_w}x$_h:rate=$_fps:duration=$duration',
      ];
      if (narration.isNotEmpty) {
        cmd.addAll(['-i', narrPath]);
      } else {
        cmd.addAll([
          '-f', 'lavfi',
          '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
        ]);
      }
      cmd.addAll([
        '-vf', filters.join(','),
        '-map', '0:v:0', '-map', '1:a:0',
        '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
        '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-t', '$duration', clip,
      ]);
      final r = await _runner.run('ffmpeg', cmd, timeout: const Duration(seconds: 180));
      if (!r.ok) {
        throw RenderException('ffmpeg failed: ${_tail(r.stderr)}');
      }
      clips.add(clip);
    }

    final result = await _assemble(clips, durations, work);
    final file = File(result.$1);
    return RenderResult(
      path: result.$1,
      scenes: clips.length,
      seconds: result.$2,
      bytes: file.existsSync() ? file.lengthSync() : 0,
    );
  }

  /// Joins per-scene clips with cross-fade transitions, falling back to a plain
  /// concat if the filter graph fails.
  Future<(String, double)> _assemble(
    List<String> clips,
    List<double> durations,
    Directory work,
  ) async {
    final finalPath = '${work.path}/render.mp4';
    if (clips.length == 1) {
      await _runner.run('ffmpeg', [
        '-hide_banner', '-y', '-i', clips[0], '-c', 'copy', finalPath,
      ]);
      return (finalPath, durations[0]);
    }
    final fade = max(0.1, min(0.5, durations.reduce(min) / 2 - 0.05));
    final inputs = <String>[];
    for (final c in clips) {
      inputs.addAll(['-i', c]);
    }
    final filt = <String>[];
    var prevV = '0:v';
    var prevA = '0:a';
    var merged = durations[0];
    for (var i = 1; i < clips.length; i++) {
      final offset = merged - fade;
      filt.add(
        '[$prevV][$i:v]xfade=transition=fade:'
        'duration=${fade.toStringAsFixed(3)}:offset=${offset.toStringAsFixed(3)}[v$i]',
      );
      filt.add('[$prevA][$i:a]acrossfade=d=${fade.toStringAsFixed(3)}[a$i]');
      prevV = 'v$i';
      prevA = 'a$i';
      merged = merged + durations[i] - fade;
    }
    final cmd = <String>[
      '-hide_banner', '-y', ...inputs,
      '-filter_complex', filt.join(';'),
      '-map', '[$prevV]', '-map', '[$prevA]',
      '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
      '-pix_fmt', 'yuv420p', '-c:a', 'aac', finalPath,
    ];
    final r = await _runner.run('ffmpeg', cmd, timeout: const Duration(seconds: 300));
    if (r.ok) return (finalPath, merged);

    final listFile = File('${work.path}/concat.txt')
      ..writeAsStringSync(clips.map((c) => "file '$c'\n").join());
    await _runner.run('ffmpeg', [
      '-hide_banner', '-y', '-f', 'concat', '-safe', '0',
      '-i', listFile.path, '-c', 'copy', finalPath,
    ]);
    return (finalPath, durations.reduce((a, b) => a + b));
  }

  // --- Remotion runtime ------------------------------------------------------

  Directory? _findComposer() {
    final roots = <String>{Directory.current.path};
    var d = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 12; i++) {
      roots.add(d.path);
      if (d.parent.path == d.path) break;
      d = d.parent;
    }
    for (final root in roots) {
      final c = Directory('$root/remotion-composer');
      if (Directory('${c.path}/node_modules').existsSync() &&
          File('${c.path}/src/index.tsx').existsSync()) {
        return c;
      }
    }
    return null;
  }

  Future<bool> _remotionAvailable() async =>
      _findComposer() != null && await _runner.exists('npx');

  List<Map<String, dynamic>>? _chartData(String subtitle) {
    final parts = subtitle.split(RegExp(r'[·,|/]|\s-\s'));
    final labels = [
      for (final p in parts)
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (labels.length < 2) return null;
    final trimmed = labels.take(6).toList();
    final n = trimmed.length;
    return [
      for (var i = 0; i < n; i++)
        {'label': trimmed[i], 'value': (100 * (n - i) / n).round()},
    ];
  }

  Map<String, dynamic> _sceneToCut(
    int i,
    Map<String, dynamic> sc,
    double cursor,
    double dur,
  ) {
    final headline = ((sc['headline'] ?? sc['title'] ?? '') as String).trim();
    final subtitle = ((sc['subtitle'] ?? '') as String).trim();
    final stype = ((sc['type'] ?? 'text_card') as String).trim();
    final hex = '#${_normHex(sc['accent']).replaceFirst('0x', '')}';
    final cut = <String, dynamic>{
      'id': 'cut_$i',
      'source': '',
      'in_seconds': double.parse(cursor.toStringAsFixed(3)),
      'out_seconds': double.parse((cursor + dur).toStringAsFixed(3)),
      'accentColor': hex,
    };
    if (stype == 'stat_card') {
      cut.addAll({'type': 'stat_card', 'stat': headline.isEmpty ? '—' : headline, 'subtitle': subtitle});
    } else if (stype == 'hero_title') {
      cut.addAll({'type': 'hero_title', 'text': headline, 'heroSubtitle': subtitle});
    } else if (stype == 'bar_chart' || stype == 'pie_chart') {
      // Prefer the scene's real data; synthesize from the subtitle only if none.
      final provided = sc['chartData'];
      final data = (provided is List && provided.isNotEmpty)
          ? provided
          : _chartData(subtitle);
      if (data != null && data.isNotEmpty) {
        cut.addAll({'type': stype, 'title': headline, 'chartData': data, 'showValues': true});
      } else {
        cut.addAll({'type': 'text_card', 'text': headline.isEmpty ? subtitle : headline});
      }
    } else {
      cut.addAll({'type': 'text_card', 'text': headline.isEmpty ? subtitle : headline});
    }
    return cut;
  }

  Future<RenderResult> _renderRemotion(
    List<Map<String, dynamic>> scenes,
    String voice,
  ) async {
    final composer = _findComposer();
    if (composer == null) {
      throw const RenderException('Remotion composer not available');
    }
    final work = _renderDir();

    final raws = <String?>[];
    final durations = <double>[];
    for (var i = 0; i < scenes.length; i++) {
      final sc = scenes[i];
      final headline = ((sc['headline'] ?? sc['title'] ?? '') as String).trim();
      final subtitle = ((sc['subtitle'] ?? '') as String).trim();
      final seconds = (sc['seconds'] as num?)?.toDouble() ?? 4;
      final narration = [headline, subtitle].where((s) => s.isNotEmpty).join('. ');
      String? raw;
      var adur = 0.0;
      if (narration.isNotEmpty) {
        raw = '${work.path}/rm_narr_$i.aiff';
        final r = await _runner.run('say', ['-v', voice, '-o', raw, narration]);
        if (r.ok) adur = await durationSeconds(_runner, raw);
      }
      raws.add(raw);
      durations.add([seconds, adur + 0.3, 1.5].reduce(max));
    }

    final cuts = <Map<String, dynamic>>[];
    final segs = <String>[];
    var cursor = 0.0;
    for (var i = 0; i < scenes.length; i++) {
      cuts.add(_sceneToCut(i, scenes[i], cursor, durations[i]));
      final seg = '${work.path}/rm_seg_$i.wav';
      if (raws[i] != null) {
        await _runner.run('ffmpeg', [
          '-hide_banner', '-y', '-i', raws[i]!, '-af', 'apad',
          '-t', '${durations[i]}', '-ar', '44100', '-ac', '2', seg,
        ]);
      } else {
        await _runner.run('ffmpeg', [
          '-hide_banner', '-y', '-f', 'lavfi',
          '-i', 'anullsrc=r=44100:cl=stereo', '-t', '${durations[i]}', seg,
        ]);
      }
      segs.add(seg);
      cursor += durations[i];
    }

    final public = Directory('${composer.path}/public')
      ..createSync(recursive: true);
    const narrName = 'studio_narration.wav';
    final listFile = File('${work.path}/rm_concat.txt')
      ..writeAsStringSync(segs.map((s) => "file '$s'\n").join());
    await _runner.run('ffmpeg', [
      '-hide_banner', '-y', '-f', 'concat', '-safe', '0',
      '-i', listFile.path, '-c', 'copy', '${public.path}/$narrName',
    ]);

    final props = {
      'cuts': cuts,
      'audio': {
        'narration': {'src': narrName},
      },
    };
    final propsPath = '${work.path}/rm_props.json';
    File(propsPath).writeAsStringSync(jsonEncode(props));

    final finalPath = '${work.path}/render.mp4';
    final r = await _runner.run(
      'npx',
      [
        'remotion', 'render',
        '${composer.path}/src/index.tsx', 'Explainer', finalPath,
        '--props', propsPath,
      ],
      workingDirectory: composer.path,
      timeout: const Duration(seconds: 600),
    );
    if (!r.ok) {
      throw RenderException('remotion failed: ${_tail(r.stderr)}');
    }
    final file = File(finalPath);
    return RenderResult(
      path: finalPath,
      scenes: cuts.length,
      seconds: double.parse(cursor.toStringAsFixed(2)),
      bytes: file.existsSync() ? file.lengthSync() : 0,
    );
  }

  String _tail(String s) {
    final lines = s.trim().split('\n');
    return lines.length <= 3 ? s.trim() : lines.sublist(lines.length - 3).join('\n');
  }
}

class RenderException implements Exception {
  const RenderException(this.message);
  final String message;
  @override
  String toString() => 'RenderException: $message';
}
