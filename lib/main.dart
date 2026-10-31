import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoiceNoteApp());
}

class VoiceNoteApp extends StatelessWidget {
  const VoiceNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF45D7C0);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VoiceNote Offline',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C1017),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF17202B),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF17202B),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1620),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const TranscriptionScreen(),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  static const _accent = Color(0xFF45D7C0);
  static const _supportedAudioExtensions = <String>{
    '.opus', '.ogg', '.oga', '.m4a', '.mp3', '.wav',
    '.aac', '.amr', '.3gp', '.mp4', '.flac', '.webm',
  };
  static const _onlineAudioExtensions = <String>{
    '.opus', '.ogg', '.oga', '.m4a', '.mp3', '.wav',
    '.mp4', '.flac', '.webm',
  };

  final WhisperController _whisper = WhisperController();
  final TextEditingController _text = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _vocabulary = TextEditingController();
  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;

  File? _audio;
  String _displayName = '';
  String _mode = 'offline';
  String _modelSize = 'base';
  String _onlineModel = 'whisper-large-v3-turbo';
  String _language = 'auto';
  bool _modelReady = false;
  bool _busy = false;
  bool _allowUpload = false;
  bool _triniHints = false;
  bool _showKey = false;
  int _progress = 0;
  String _status = 'Choose an audio file or share one from WhatsApp.';

  WhisperModel get _model => switch (_modelSize) {
        'tiny' => WhisperModel.tiny,
        'small' => WhisperModel.small,
        'medium' => WhisperModel.medium,
        'large' => WhisperModel.large,
        _ => WhisperModel.base,
      };

  String get _modelFile =>
      _modelSize == 'large' ? 'ggml-large-v3.bin' : 'ggml-$_modelSize.bin';

  String get _prompt {
    final hints = <String>[];
    if (_triniHints) {
      hints.add('Trinidad and Tobago English dialect; words may include '
          'doh, allyuh, cyah, lime, buss out, vex, nah. '
          'Keep the speaker\'s original wording.');
    }
    final userHints = _vocabulary.text.trim();
    if (userHints.isNotEmpty) hints.add(userHints);
    return hints.join(' ');
  }

  @override
  void initState() {
    super.initState();
    _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) unawaited(_acceptSharedAudio(files));
      },
      onError: (Object error) => _showError('Unable to receive shared audio: $error'),
    );
    unawaited(_loadInitialShare());
    unawaited(_refreshModel());
  }

  Future<void> _loadInitialShare() async {
    try {
      final files = await ReceiveSharingIntent.instance.getInitialMedia();
      if (files.isNotEmpty) await _acceptSharedAudio(files);
    } catch (error) {
      _showError('Unable to open WhatsApp audio: $error');
    } finally {
      ReceiveSharingIntent.instance.reset();
    }
  }

  Future<void> _acceptSharedAudio(List<SharedMediaFile> files) async {
    for (final item in files) {
      final incoming = item.path;
      final extension = path.extension(incoming).toLowerCase();
      if (incoming.isNotEmpty &&
          (_supportedAudioExtensions.contains(extension) ||
              (item.type == SharedMediaType.file && extension.isEmpty))) {
        await _importAudio(incoming);
        return;
      }
    }
    _showError('Share an audio file from WhatsApp, not a link or text.');
  }

  Future<void> _pickAudio() async {
    if (_busy) return;
    try {
      final choice = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
      if (choice == null || choice.files.isEmpty) return;
      final selected = choice.files.single;
      if (selected.path == null) {
        _showError('Could not read that file. Save it locally first.');
        return;
      }
      await _importAudio(selected.path!, name: selected.name);
    } catch (error) {
      _showError('Could not open audio: $error');
    }
  }

  Future<void> _importAudio(String source, {String? name}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Opening audio locally…';
    });
    try {
      final sourcePath = source.startsWith('file://')
          ? Uri.parse(source).toFilePath()
          : source;
      if (sourcePath.startsWith('content://')) {
        throw const FormatException(
          'The sharing app supplied a content URI. Save audio to Files, '
          'then use Pick audio.',
        );
      }
      final original = File(sourcePath);
      if (!await original.exists()) {
        throw const FileSystemException('Shared audio is not accessible.');
      }
      final temp = await getTemporaryDirectory();
      final ext = path.extension(name ?? sourcePath).toLowerCase();
      final safeExt = RegExp(r'^\.[a-z0-9]{1,7}$').hasMatch(ext)
          ? ext
          : '.audio';
      final copyPath = path.join(temp.path,
          'voicenote_${DateTime.now().microsecondsSinceEpoch}$safeExt');
      final copy = await original.copy(copyPath);
      if (!mounted) return;
      setState(() {
        _audio = copy;
        _displayName = name ?? path.basename(sourcePath);
        _text.clear();
        _progress = 0;
        _status = _mode == 'offline'
            ? 'Audio ready. Transcription will stay on your phone.'
            : 'Audio ready. Online upload requires your permission.';
      });
    } catch (error) {
      _showError('Could not import audio: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _copyBundledModelIfPresent(
      WhisperModel selected, String fileName) async {
    final destination = File(await _whisper.getPath(selected));
    if (await destination.exists() &&
        await destination.length() > 1000000) {
      return true;
    }
    try {
      final bytes = await rootBundle.load('assets/models/$fileName');
      if (bytes.lengthInBytes < 1000000) return false;
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      return true;
    } on FlutterError {
      return false;
    }
  }

  Future<void> _refreshModel() async {
    final selected = _model;
    final name = _modelFile;
    try {
      final installed = await _copyBundledModelIfPresent(selected, name);
      if (!mounted || selected != _model) return;
      setState(() => _modelReady = installed);
    } catch (error) {
      if (!mounted) return;
      setState(() => _modelReady = false);
      _showError('Could not check offline model: $error');
    }
  }

  Future<void> _downloadFreeModel() async {
    if (_busy || _modelReady) return;
    final selected = _model;
    setState(() {
      _busy = true;
      _status = 'Downloading model. Use Wi-Fi and keep enough free storage…';
    });
    try {
      final modelPath = await _whisper.downloadModel(selected);
      if (!await File(modelPath).exists() ||
          await File(modelPath).length() < 1000000) {
        throw const FileSystemException('Model download did not complete.');
      }
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _status = 'Offline model installed. Audio stays on your phone.';
      });
    } catch (error) {
      _showError('Model download failed. Try Wi-Fi or import a model: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importModel() async {
    if (_busy) return;
    try {
      final selection = await FilePicker.platform.pickFiles(type: FileType.any);
      if (selection == null || selection.files.isEmpty) return;
      final chosen = selection.files.single;
      if (chosen.path == null) {
        throw const FileSystemException('No local model path.');
      }
      if (chosen.name.toLowerCase() != _modelFile) {
        throw FormatException('Select $_modelFile from whisper.cpp.');
      }
      setState(() {
        _busy = true;
        _status = 'Importing model from local storage…';
      });
      final source = File(chosen.path!);
      if (!await source.exists() || await source.length() < 1000000) {
        throw const FormatException('The model file appears incomplete.');
      }
      final target = File(await _whisper.getPath(_model));
      await target.parent.create(recursive: true);
      await source.copy(target.path);
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _status = 'Offline model imported.';
      });
    } catch (error) {
      _showError('Could not import model: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _transcribeOnline(File audio) async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      throw const FormatException('Enter your free Groq API key first.');
    }
    if (!_allowUpload) {
      throw const FormatException('Allow this audio to be uploaded first.');
    }
    final ext = path.extension(audio.path).toLowerCase();
    if (!_onlineAudioExtensions.contains(ext)) {
      throw const FormatException(
          'This format is not supported online. Export as OGG, M4A, MP3 or WAV.');
    }
    if (await audio.length() > 25000000) {
      throw const FormatException(
          'The free Groq tier accepts files up to 25 MB. '
          'Choose a smaller recording.');
    }
    final mediaType = switch (ext) {
      '.opus' || '.ogg' || '.oga' => MediaType('audio', 'ogg'),
      '.m4a' || '.mp4' => MediaType('audio', 'mp4'),
      '.flac' => MediaType('audio', 'flac'),
      '.webm' => MediaType('audio', 'webm'),
      '.wav' => MediaType('audio', 'wav'),
      _ => MediaType('audio', 'mpeg'),
    };
    // Some providers accept Ogg/Opus audio but not the .opus extension.
    final uploadName = ext == '.opus'
        ? '${path.basenameWithoutExtension(audio.path)}.ogg'
        : ext == '.oga'
            ? '${path.basenameWithoutExtension(audio.path)}.ogg'
            : path.basename(audio.path);
    final client = http.Client();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.https('api.groq.com', '/openai/v1/audio/transcriptions'),
      );
      request.headers['Authorization'] = 'Bearer $key';
      request.fields['model'] = _onlineModel;
      request.fields['response_format'] = 'json';
      if (_language != 'auto') request.fields['language'] = _language;
      if (_prompt.isNotEmpty) request.fields['prompt'] = _prompt;
      request.files.add(await http.MultipartFile.fromPath(
        'file', audio.path, filename: uploadName, contentType: mediaType,
      ));
      final streamed = await client.send(request).timeout(
        const Duration(minutes: 4),
      );
      final body = await streamed.stream.bytesToString().timeout(
        const Duration(minutes: 4),
      );
      if (streamed.statusCode != 200) {
        if (streamed.statusCode == 401 || streamed.statusCode == 403) {
          throw const FormatException('Groq rejected the API key. Check your free key.');
        }
        if (streamed.statusCode == 429) {
          throw const FormatException('Free online rate limit reached. '
              'Try later or use the offline model.');
        }
        if (streamed.statusCode == 413) {
          throw const FormatException('Audio too large for the online service.');
        }
        throw FormatException('Online service returned HTTP '
            '${streamed.statusCode}. Check the audio format and try again.');
      }
      final result = jsonDecode(body);
      if (result is! Map || result['text'] is! String) {
        throw const FormatException('Online service returned an invalid transcript.');
      }
      return (result['text'] as String).trim();
    } finally {
      client.close();
    }
  }

  Future<void> _transcribe() async {
    if (_busy || _audio == null) return;
    if (_mode == 'offline' && !_modelReady) {
      _showError('Install an offline model first.');
      return;
    }
    if (_mode == 'online' && (!_allowUpload || _apiKey.text.trim().isEmpty)) {
      _showError('Enter your free Groq key and allow this upload first.');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _status = _mode == 'offline'
          ? 'Transcribing locally. No audio is uploaded.'
          : 'Uploading the selected audio to Groq over HTTPS…';
    });
    try {
      String transcript;
      if (_mode == 'online') {
        transcript = await _transcribeOnline(_audio!);
      } else {
        final result = await _whisper.transcribe(
          model: _model,
          audioPath: _audio!.path,
          lang: _language,
          initialPrompt: _prompt.isEmpty ? null : _prompt,
          noContext: true,
          onProgress: (int percent) {
            if (!mounted) return;
            setState(() => _progress = percent.clamp(0, 100).toInt());
          },
        );
        transcript = result?.transcription.text.trim() ?? '';
      }
      if (!mounted) return;
      setState(() {
        _text.text = transcript;
        _progress = 100;
        _status = transcript.isEmpty
            ? 'No intelligible speech detected. Try another model.'
            : 'Done. Edit, copy or share your transcript.';
      });
    } catch (error) {
      _showError('Transcription failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _status = message);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _copyText() async {
    if (_text.text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript copied.')),
    );
  }

  Future<void> _shareText(BuildContext buttonContext) async {
    if (_text.text.trim().isEmpty) return;
    final renderBox = buttonContext.findRenderObject();
    final box = renderBox is RenderBox ? renderBox : null;
    await SharePlus.instance.share(
      ShareParams(
        text: _text.text,
        sharePositionOrigin: box == null
            ? null
            : (box.localToGlobal(Offset.zero) & box.size),
      ),
    );
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _text.dispose();
    _apiKey.clear();
    _apiKey.dispose();
    _vocabulary.dispose();
    unawaited(_whisper.releaseModel());
    super.dispose();
  }

  Widget _sectionTitle(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 19, color: _accent),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1017),
        title: const Text('VoiceNote Offline',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(_mode == 'offline'
                ? Icons.lock_outline_rounded
                : Icons.cloud_outlined, color: _accent),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 35),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF183B39), Color(0xFF14212D)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(22),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 42, color: _accent),
                  SizedBox(height: 10),
                  Text('Voice notes → text', style: TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('Private offline transcription, plus optional '
                      'free-tier online Whisper for better accuracy.',
                      style: TextStyle(color: Color(0xFFB8C7CD), height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(Icons.tune_rounded, '1. Choose transcription mode'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Processing mode'),
              items: const [
                DropdownMenuItem(value: 'offline',
                    child: Text('Offline • private • no API key')),
                DropdownMenuItem(value: 'online',
                    child: Text('Online • Groq free tier')),
              ],
              onChanged: _busy ? null : (value) {
                if (value != null) setState(() {
                  _mode = value;
                  _status = value == 'offline'
                      ? 'Offline selected. No audio is uploaded.'
                      : 'Online selected. Audio is only sent when you tap Transcribe.';
                });
              },
            ),
            const SizedBox(height: 14),
            if (_mode == 'offline') ...[
              DropdownButtonFormField<String>(
                initialValue: _modelSize,
                decoration: const InputDecoration(labelText: 'Offline Whisper model'),
                items: const [
                  DropdownMenuItem(value: 'tiny',
                      child: Text('Tiny • fastest • ~75 MB')),
                  DropdownMenuItem(value: 'base',
                      child: Text('Base • ~142 MB')),
                  DropdownMenuItem(value: 'small',
                      child: Text('Small • ~466 MB')),
                  DropdownMenuItem(value: 'medium',
                      child: Text('Medium • ~1.5 GB')),
                  DropdownMenuItem(value: 'large',
                      child: Text('Large V3 • ~3 GB • high RAM')),
                ],
                onChanged: _busy ? null : (value) {
                  if (value == null || value == _modelSize) return;
                  setState(() {
                    _modelSize = value;
                    _modelReady = false;
                  });
                  unawaited(_refreshModel());
                },
              ),
              const SizedBox(height: 10),
              Text(_modelReady
                  ? 'Installed — works fully offline.'
                  : 'Not installed — download once on Wi-Fi or import from Files.',
                  style: const TextStyle(color: Color(0xFFB8C7CD))),
              if (_modelSize == 'medium' || _modelSize == 'large') ...[
                const SizedBox(height: 7),
                const Text('Large offline models may be very slow or crash '
                    'on phones with insufficient RAM. Try Small first.',
                    style: TextStyle(color: Color(0xFFFFCC7A))),
              ],
              if (!_modelReady) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _downloadFreeModel,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download free offline model'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _importModel,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Or import model from Files'),
                ),
              ],
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _onlineModel,
                decoration: const InputDecoration(labelText: 'Online Whisper model'),
                items: const [
                  DropdownMenuItem(value: 'whisper-large-v3-turbo',
                      child: Text('Large V3 Turbo • faster')),
                  DropdownMenuItem(value: 'whisper-large-v3',
                      child: Text('Large V3 • accuracy priority')),
                ],
                onChanged: _busy ? null : (value) {
                  if (value != null) setState(() => _onlineModel = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKey,
                obscureText: !_showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Your free Groq API key',
                  hintText: 'gsk_…',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showKey = !_showKey),
                    icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Free tier has rate and file-size limits. Your key '
                  'is kept in memory only, not saved or included in transcripts. '
                  'No paid subscription is required for free-tier use.',
                  style: TextStyle(color: Color(0xFFB8C7CD), fontSize: 12)),
              const SizedBox(height: 7),
              TextButton(
                onPressed: () => launchGroqInfo(),
                child: const Text('How to get a free Groq key'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowUpload,
                onChanged: _busy ? null : (value) {
                  setState(() => _allowUpload = value ?? false);
                },
                title: const Text('I agree to upload my selected audio to Groq'),
                subtitle: const Text('Online processing sends the audio '
                    'to a third-party service over HTTPS. Offline mode never uploads.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            const SizedBox(height: 22),
            _sectionTitle(Icons.audio_file_rounded, '2. Select WhatsApp audio'),
            const SizedBox(height: 10),
            const Text('From WhatsApp use Share → VoiceNote Offline, '
                'or save the voice note and select it below.',
                style: TextStyle(color: Color(0xFFACBCC5), height: 1.45)),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _pickAudio,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Pick audio file'),
              ),
            ),
            if (_audio != null) ...[
              const SizedBox(height: 10),
              Text('Selected: $_displayName',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Spoken language'),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Auto-detect')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Spanish')),
                DropdownMenuItem(value: 'fr', child: Text('French')),
                DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
              ],
              onChanged: _busy ? null : (value) {
                if (value != null) setState(() => _language = value);
              },
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _triniHints,
              title: const Text('Trinidad & Tobago English vocabulary hints'),
              subtitle: const Text('Optional dialect context for Whisper; '
                  'may help with local expressions.'),
              onChanged: _busy ? null : (value) {
                setState(() => _triniHints = value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TextField(
              controller: _vocabulary,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Names or vocabulary hints (optional)',
                hintText: 'e.g. Emi, Fahaz, Richard, Darren, Dimitri',
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 55,
              child: FilledButton.icon(
                onPressed: _busy || _audio == null ||
                    (_mode == 'offline' && !_modelReady)
                    ? null : _transcribe,
                icon: Icon(_mode == 'offline'
                    ? Icons.lock_outline_rounded
                    : Icons.cloud_upload_outlined),
                label: Text(_mode == 'offline'
                    ? 'Transcribe on this device'
                    : 'Transcribe online (upload audio)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null),
            ],
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(
                color: Color(0xFFACBBC4), height: 1.35)),
            const SizedBox(height: 25),
            _sectionTitle(Icons.text_snippet_outlined, '3. Transcript'),
            const SizedBox(height: 11),
            TextField(
              controller: _text,
              minLines: 7,
              maxLines: 16,
              decoration: const InputDecoration(
                hintText: 'Your transcription will appear here. '
                    'You can edit it before sharing.',
                contentPadding: EdgeInsets.all(16),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _copyText,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy text'),
                )),
                const SizedBox(width: 10),
                Expanded(child: Builder(builder: (buttonContext) =>
                    OutlinedButton.icon(
                  onPressed: () => _shareText(buttonContext),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share text'),
                ))),
              ],
            ),
            const SizedBox(height: 20),
            Center(child: Text(_mode == 'offline'
                ? 'Offline selected: transcription uses local AI only.'
                : 'Online selected: Groq processes audio only when you approve and tap Transcribe.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF778891), fontSize: 12))),
          ],
        ),
      ),
    );
  }

  void launchGroqInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Free online transcription'),
        content: const Text('Open https://console.groq.com/keys in your browser, '
            'create a free Groq account and an API key, and paste the key here. '
            'The free tier has usage limits, and future terms can change. '
            'Audio uploaded online is processed by Groq. Never share your key.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }
}
