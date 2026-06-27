import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'command_runner.dart';
import 'voice_settings.dart';

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
  RenderClient({
    CommandRunner runner = const SystemCommandRunner(),
    VoiceSettings? voiceSettings,
  }) : _runner = runner,
       _voices = voiceSettings ?? VoiceSettings();

  final CommandRunner _runner;
  final VoiceSettings _voices;

  static const _bg = '0x0F172A';
  static const _headlineColor = '0xE2E8F0';
  static const _subtitleColor = '0x94A3B8';
  static const _w = 1920;
  static const _h = 1080;
  static const _fps = 30;

  String get _font {
    final candidates = Platform.isWindows
        ? const [
            r'C:\Windows\Fonts\arial.ttf',
            r'C:\Windows\Fonts\segoeui.ttf',
            r'C:\Windows\Fonts\tahoma.ttf',
          ]
        : Platform.isMacOS
        ? const [
            '/System/Library/Fonts/Supplemental/Arial.ttf',
            '/System/Library/Fonts/Helvetica.ttc',
            '/Library/Fonts/Arial.ttf',
          ]
        : const [
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
            '/usr/share/fonts/TTF/DejaVuSans.ttf',
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
    // Prefer Remotion (cinematic) when available — it leads the list so the
    // studio defaults to it; ffmpeg remains the fast, always-available fallback.
    if (await _remotionAvailable()) return const ['remotion', 'ffmpeg'];
    return const ['ffmpeg'];
  }

  /// Renders [scenes] to an MP4 using [runtime] ("ffmpeg" or "remotion"),
  /// narrated with [voice]. When [branding] is true (the default for the free
  /// tier), a short "Made with OpenMontage Studio" end card is appended — so
  /// every shared video carries the product, which is the core growth loop.
  Future<RenderResult> render(
    List<Map<String, dynamic>> scenes, {
    String? voice,
    String? runtime,
    bool branding = true,
  }) async {
    final v = voice ?? '';
    final toRender = branding ? [...scenes, _brandingScene()] : scenes;
    if (runtime == 'remotion' && await _remotionAvailable()) {
      return _renderRemotion(toRender, v);
    }
    return _renderFfmpeg(toRender, v);
  }

  /// The branded end card appended to every free-tier render. Flagged
  /// `noNarration` so it is rendered silently by both runtimes. The personal
  /// "Made on my …" line is platform-aware so it reads true on every host.
  Map<String, dynamic> _brandingScene() {
    final made = Platform.isMacOS
        ? 'Made on my Mac'
        : Platform.isWindows
        ? 'Made on my PC'
        : 'Made locally';
    return {
      'type': 'hero_title',
      'headline': 'OpenMontage Studio',
      'subtitle': '$made · get.opencli.ai',
      'seconds': 1.8,
      'accent': '22D3EE',
      'noNarration': true,
    };
  }

  /// Opens a finished clip in the default player. Best-effort.
  Future<void> open(String path) async {
    if (Platform.isMacOS) {
      _runner.spawn('open', [path]);
    } else if (Platform.isWindows) {
      _runner.spawn('cmd', ['/c', 'start', '', path]);
    } else {
      _runner.spawn('xdg-open', [path]);
    }
  }

  /// Reveals a finished clip in the OS file manager. Best-effort.
  Future<void> reveal(String path) async {
    if (Platform.isMacOS) {
      _runner.spawn('open', ['-R', path]);
    } else if (Platform.isWindows) {
      _runner.spawn('explorer', ['/select,', path]);
    } else {
      // Most Linux file managers lack a reliable "reveal"; open the folder.
      _runner.spawn('xdg-open', [File(path).parent.path]);
    }
  }

  /// Extracts a poster frame from [videoPath] (~0.5s in) so an uploaded clip
  /// shows a thumbnail in the editor without a video-playback dependency.
  /// Returns the PNG path, or null on failure.
  Future<String?> extractThumbnail(String videoPath) async {
    final dir = Directory('${Directory.systemTemp.path}/openmontage-media/thumbs')
      ..createSync(recursive: true);
    final out = '${dir.path}/thumb_${videoPath.hashCode}.png';
    final r = await _runner.run('ffmpeg', [
      '-hide_banner', '-y', '-ss', '0.5', '-i', videoPath,
      '-frames:v', '1', '-vf', 'scale=640:-2', out,
    ], timeout: const Duration(seconds: 30));
    return r.ok && File(out).existsSync() ? out : null;
  }

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
      final footage = ((sc['clipPath'] ?? '') as String).trim();

      final narration = sc['noNarration'] == true
          ? ''
          : [headline, subtitle].where((s) => s.isNotEmpty).join('. ');
      String? narrPath;
      var adur = 0.0;
      if (narration.isNotEmpty) {
        final clip = await _voices.synthesize(
          _runner,
          narration,
          outPathBase: '${work.path}/narr_$i',
          voice: voice,
        );
        if (clip != null) {
          narrPath = clip.path;
          adur = clip.seconds;
        }
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
      // Visual input: an uploaded clip (looped + cover-cropped to frame) for UGC
      // scenes, otherwise a solid card. Text/accent overlays apply on top of
      // both, so captions burn onto real footage.
      final hasFootage = footage.isNotEmpty && File(footage).existsSync();
      final vf = hasFootage
          ? [
              'scale=$_w:$_h:force_original_aspect_ratio=increase',
              'crop=$_w:$_h',
              'setsar=1',
              ...filters,
            ]
          : filters;
      final cmd = <String>['-hide_banner', '-y'];
      if (hasFootage) {
        cmd.addAll(['-stream_loop', '-1', '-i', footage]);
      } else {
        cmd.addAll([
          '-f', 'lavfi',
          '-i', 'color=c=$_bg:s=${_w}x$_h:rate=$_fps:duration=$duration',
        ]);
      }
      if (narrPath != null) {
        cmd.addAll(['-i', narrPath]);
      } else {
        cmd.addAll([
          '-f', 'lavfi',
          '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
        ]);
      }
      cmd.addAll([
        '-vf', vf.join(','),
        '-map', '0:v:0', '-map', '1:a:0',
        '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
        '-pix_fmt', 'yuv420p', '-r', '$_fps', '-c:a', 'aac',
        '-t', '$duration', clip,
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
    final exeDir = File(Platform.resolvedExecutable).parent;
    final roots = <String>{Directory.current.path};
    // Bundled location inside a packaged app: the engine ships next to the
    // executable under Resources (macOS: Contents/Resources, where exeDir is
    // Contents/MacOS) so a plain install renders cinematic without system Node.
    roots.add('${exeDir.parent.path}/Resources');
    roots.add(exeDir.path);
    var d = exeDir;
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

  /// A Node runtime bundled with the app, if present — searched next to the
  /// composer and under the app's Resources. Lets the cinematic runtime work on
  /// a machine with no system Node. Returns the absolute `node` path or null.
  String? _bundledNode(Directory composer) {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final rel = Platform.isWindows ? 'node/node.exe' : 'node/bin/node';
    final candidates = [
      '${composer.parent.path}/$rel',
      '${exeDir.parent.path}/Resources/$rel',
      '${exeDir.path}/$rel',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  /// Cinematic is available when the composer is present AND we can run Node —
  /// either a bundled runtime (packaged app) or system `npx` (dev machine).
  Future<bool> _remotionAvailable() async {
    final composer = _findComposer();
    if (composer == null) return false;
    return _bundledNode(composer) != null || await _runner.exists('npx');
  }

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
    // A user-uploaded clip plays behind the scene (UGC / real footage). The
    // composer's backgroundVideo takes priority over backgroundImage.
    final clip = (sc['clipPath'] as String?) ?? '';
    if (clip.isNotEmpty) {
      cut['backgroundVideo'] = clip;
      cut['backgroundOverlay'] = 0.35;
    }
    // A resolved background image (stock/AI) sits behind the scene, dimmed so
    // the headline stays readable.
    final image = (sc['imageUrl'] as String?) ?? '';
    if (clip.isEmpty && image.isNotEmpty) {
      cut['backgroundImage'] = image;
      cut['backgroundOverlay'] = 0.55;
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
      final narration = sc['noNarration'] == true
          ? ''
          : [headline, subtitle].where((s) => s.isNotEmpty).join('. ');
      String? raw;
      var adur = 0.0;
      if (narration.isNotEmpty) {
        final clip = await _voices.synthesize(
          _runner,
          narration,
          outPathBase: '${work.path}/rm_narr_$i',
          voice: voice,
        );
        if (clip != null) {
          raw = clip.path;
          adur = clip.seconds;
        }
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
        // A bundled, royalty-free cinematic bed, kept low and auto-ducked under
        // narration, plus a transition whoosh at each cut. These elevate the
        // perceived production value more than any single visual change.
        'music': {
          'src': 'audio/cinematic-bed.mp3',
          'volume': 0.12,
          'fadeInSeconds': 1.5,
          'fadeOutSeconds': 2.5,
          'loop': true,
        },
        'sfxTransition': {'src': 'audio/whoosh.mp3', 'volume': 0.4},
      },
    };
    final propsPath = '${work.path}/rm_props.json';
    File(propsPath).writeAsStringSync(jsonEncode(props));

    final finalPath = '${work.path}/render.mp4';
    // Prefer the bundled Node runtime (packaged app); fall back to system npx
    // (dev machine). Running the local Remotion CLI directly avoids any reliance
    // on a globally installed npx.
    final node = _bundledNode(composer);
    final (String exe, List<String> args) = node != null
        ? (
            node,
            [
              '${composer.path}/node_modules/.bin/remotion', 'render',
              '${composer.path}/src/index.tsx', 'Explainer', finalPath,
              '--props', propsPath,
            ],
          )
        : (
            'npx',
            [
              'remotion', 'render',
              '${composer.path}/src/index.tsx', 'Explainer', finalPath,
              '--props', propsPath,
            ],
          );
    final r = await _runner.run(
      exe,
      args,
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
