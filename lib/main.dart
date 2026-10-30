import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final WhisperController _whisper = WhisperController();
  final TextEditingController _text = TextEditingController();
  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;

  File? _audio;
  String _displayName = '';
  String _modelSize = 'base';
  String _language = 'auto';
  bool _modelReady = false;
  bool _busy = false;
  int _progress = 0;
  String _status = 'Choose an audio file or share one from WhatsApp.';

  WhisperModel get _model => switch (_modelSize) {
        'tiny' => WhisperModel.tiny,
        'small' => WhisperModel.small,
        _ => WhisperModel.base,
      };

  String get _modelFile => 'ggml-$_modelSize.bin';

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
    // Only the first audio item is processed; shared links/text are ignored.
    for (final item in files) {
      final incoming = item.path;
      final extension = path.extension(incoming).toLowerCase();
      if (incoming.isNotEmpty &&
          (_audioExtensions.contains(extension) ||
              (item.type == SharedMediaType.file && extension.isEmpty))) {
        await _importAudio(incoming);
        return;
      }
    }
    _showError('Share an audio file from WhatsApp, not a link or text.');
  }

  static const _audioExtensions = {
    '.opus', '.ogg', '.oga', '.m4a', '.mp3', '.wav',
    '.aac', '.amr', '.3gp', '.mp4', '.flac', '.webm',
  };

  Future<void> _pickAudio() async {
    if (_busy) return;
    try {
      // "any" deliberately includes .opus and .ogg, which some OS audio
      // filters do not include.
      final choice = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
      if (choice == null || choice.files.isEmpty) return;
      final selected = choice.files.single;
      if (selected.path == null) {
        _showError('Could not read the selected file. Save it locally first.');
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
          'The sharing app supplied a content URI instead of a local file. '
          'Save the audio to Files and use Pick audio.',
        );
      }
      final original = File(sourcePath);
      if (!await original.exists()) {
        throw const FileSystemException('Shared audio is not accessible.');
      }
      final temp = await getTemporaryDirectory();
      final ext = path.extension(name ?? sourcePath).toLowerCase();
      final safeExt = RegExp(r'^\.[a-z0-9]{1,7}$').hasMatch(ext) ? ext : '.audio';
      final copyPath = path.join(
        temp.path,
        'voicenote_${DateTime.now().microsecondsSinceEpoch}$safeExt',
      );
      final copy = await original.copy(copyPath);
      if (!mounted) return;
      setState(() {
        _audio = copy;
        _displayName = name ?? path.basename(sourcePath);
        _text.clear();
        _progress = 0;
        _status = 'Audio ready. Transcription stays on your phone.';
      });
    } catch (error) {
      _showError('Could not import this audio file: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Models can be bundled at build time for zero-network first launch.
  // Otherwise the user can download once or import the model from Files.
  Future<bool> _copyBundledModelIfPresent(WhisperModel selected, String fileName) async {
    final destination = File(await _whisper.getPath(selected));
    if (await destination.exists() && await destination.length() > 1000000) {
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
      return false; // No bundled model; normal for the small source ZIP.
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
      _status = 'Downloading the free model once. Use Wi-Fi if possible…';
    });
    try {
      final modelPath = await _whisper.downloadModel(selected);
      if (!await File(modelPath).exists()) {
        throw const FileSystemException('Model download did not complete.');
      }
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _status = 'Offline model installed. Internet is no longer required.';
      });
    } catch (error) {
      _showError('Model download failed. Connect once or import the model: $error');
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
      if (chosen.path == null) throw const FileSystemException('No local model path.');
      if (chosen.name.toLowerCase() != _modelFile) {
        throw FormatException('Select the official $_modelFile model file.');
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
      // Copy into app-owned storage so external files can be removed.
      await source.copy(target.path);
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _status = 'Offline model imported. No internet required.';
      });
    } catch (error) {
      _showError('Could not import model: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transcribe() async {
    if (_busy || _audio == null) return;
    if (!_modelReady) {
      _showError('Install an offline model first using the buttons above.');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Transcribing locally. No audio is uploaded.';
    });
    try {
      final result = await _whisper.transcribe(
        model: _model,
        audioPath: _audio!.path,
        lang: _language,
        noContext: true,
        onProgress: (int percent) {
          if (!mounted) return;
          setState(() => _progress = percent.clamp(0, 100).toInt());
        },
      );
      final transcript = result?.transcription.text.trim() ?? '';
      if (!mounted) return;
      setState(() {
        _text.text = transcript;
        _progress = 100;
        _status = transcript.isEmpty
            ? 'No intelligible speech detected. Try a different model.'
            : 'Done! You can edit, copy, or share the transcript.';
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
      const SnackBar(content: Text('Transcript copied to clipboard.')),
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
    unawaited(_whisper.releaseModel());
    super.dispose();
  }

  Widget _sectionTitle(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF45D7C0)),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF45D7C0);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1017),
        title: const Text('VoiceNote Offline', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.lock_outline_rounded, color: accent),
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(22),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 42, color: accent),
                  SizedBox(height: 10),
                  Text('Voice notes → text',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('Unlimited. Private. Offline after installing a model.\nNo account, API key, or tokens.',
                      style: TextStyle(color: Color(0xFFB8C7CD), height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(Icons.memory_rounded, '1. Offline speech model'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _modelSize,
                      decoration: const InputDecoration(labelText: 'Model size'),
                      items: const [
                        DropdownMenuItem(value: 'tiny', child: Text('Tiny • fastest • ~75 MB')),
                        DropdownMenuItem(value: 'base', child: Text('Base • balanced • ~142 MB')),
                        DropdownMenuItem(value: 'small', child: Text('Small • more accurate • ~466 MB')),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(_modelReady ? Icons.check_circle_rounded : Icons.download_for_offline_outlined,
                            color: _modelReady ? accent : const Color(0xFFFFCC7A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_modelReady ? 'Installed — works fully offline' : 'Not installed — one-time free setup')),
                      ],
                    ),
                    if (!_modelReady) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _downloadFreeModel,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download free model once'),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _importModel,
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text('Or import a model from Files (no internet)'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(Icons.audio_file_rounded, '2. Select WhatsApp audio'),
            const SizedBox(height: 10),
            const Text('From WhatsApp, use Share → VoiceNote Offline. Or save the voice note and choose it below.',
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
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF142B2C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack_rounded, color: accent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_displayName, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.check_rounded, color: accent),
                  ],
                ),
              ),
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
            const SizedBox(height: 15),
            SizedBox(
              height: 55,
              child: FilledButton.icon(
                onPressed: _busy || _audio == null || !_modelReady ? null : _transcribe,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Transcribe on this device', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: _progress > 0 ? _progress / 100 : null),
            ],
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(color: Color(0xFFACBBC4), height: 1.35)),
            const SizedBox(height: 25),
            _sectionTitle(Icons.text_snippet_outlined, '3. Transcript'),
            const SizedBox(height: 11),
            TextField(
              controller: _text,
              minLines: 7,
              maxLines: 16,
              decoration: const InputDecoration(
                hintText: 'Your transcription will appear here. You can edit it before sharing.',
                contentPadding: EdgeInsets.all(16),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyText,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy text'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(builder: (buttonContext) => OutlinedButton.icon(
                    onPressed: () => _shareText(buttonContext),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share text'),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('Transcription uses local AI only. Model setup may require an initial download.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF778891), fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
