VoiceNoteOffline 🎙️

Free WhatsApp Voice Note Transcription — Offline & Online

VoiceNoteOffline is a Flutter-based mobile application designed to convert WhatsApp voice notes and audio recordings into text using OpenAI's open-source Whisper speech recognition models.

The app prioritizes privacy, accessibility, and improved recognition of different English accents, including Trinidadian and Caribbean speech.

Features

- Offline transcription: Transcribe recordings privately without an internet connection after installing a Whisper model.
- Online transcription: Optionally use Groq's cloud-hosted Whisper models through its free API tier.
- Multiple Whisper models: Choose Tiny, Base, Small, Medium, or Large V3 for offline recognition.
- High-accuracy online models: Whisper Large V3 Turbo and Large V3.
- Trinidadian vocabulary hints: Optional context for local expressions and accents.
- Custom vocabulary: Add names and words to help recognition.
- WhatsApp audio support: Import shared or saved voice notes.
- Editable transcripts: Copy, edit, and share transcribed text.
- No paid transcription subscription required: Offline transcription has no API charges; online free-tier use is subject to limits.

Transcription Modes

Mode| Model| Internet
Offline Fast| Tiny / Base| No
Offline Balanced| Small| No
Offline Advanced| Medium / Large V3| No
Online Fast| Large V3 Turbo| Yes
Online Advanced| Large V3| Yes

Offline models must be downloaded or imported before they can be used without internet.

Larger models may improve transcription but require more processing power, storage, and memory. Performance varies between devices.

Installing on Android

1. Visit the "GitHub Actions page" (https://github.com/DeathScythe911/VoiceNoteOffline/actions).
2. Open a successful Repair project and build Android APK run.
3. Find the Artifacts section.
4. Download "VoiceNoteOffline-Android-APK".
5. Extract the ZIP file.
6. Install "app-release.apk" on your Android phone.

The Android APK has compiled successfully through GitHub Actions. Actual device functionality should still be tested.

Using Offline Mode

1. Open VoiceNoteOffline.
2. Select Offline.
3. Choose a Whisper model.
4. Download or import the model if needed.
5. Select a WhatsApp voice note or other audio file.
6. Choose the spoken language.
7. Tap Transcribe on this device.

Your audio is processed locally and is not uploaded for offline transcription.

Using Online Mode

1. Create a free account at "Groq Console" (https://console.groq.com/keys).
2. Generate an API key.
3. Select Online in the application.
4. Choose Whisper Large V3 Turbo or Large V3.
5. Enter your API key.
6. Select an audio recording.
7. Approve the audio upload.
8. Tap Transcribe online.

Important: Groq's free tier has usage limits and may change. Online transcription requires internet access and uploads the selected audio to Groq. Keep your API key private.

Trinidadian and Caribbean Speech

VoiceNoteOffline includes optional Trinidad and Tobago English vocabulary hints to assist Whisper with local expressions.

Examples include:

- Allyuh
- Doh
- Cyah
- Buss out
- Lime
- Vex

Users can also provide personal names and other vocabulary as transcription hints.

These features provide additional context to Whisper; they do not guarantee accurate transcription of Trinidadian dialect. Rapid speech, background noise, laughter, and overlapping voices can reduce accuracy.

Supported Audio

Common supported formats include:

- OPUS / OGG
- MP3
- M4A
- WAV
- FLAC
- WebM

Supported formats may differ between offline and online processing.

Privacy

Offline mode processes voice recordings directly on the device.

Online mode sends the selected recording to Groq only after the user selects online processing and provides upload consent.

The app does not automatically access WhatsApp conversations. Users must explicitly share or select recordings.

API keys entered for online transcription are held in app memory rather than permanently stored.

iOS Compatibility

The Flutter project includes iOS source support and Share Extension starter templates. An iOS version must be compiled and configured using Xcode on macOS.

The iOS application has not yet been built and fully tested.

Android APK files cannot be installed on iPhones.

Limitations

Speech recognition accuracy depends on the selected Whisper model, audio quality, accent, and recording conditions.

Large offline models can consume several gigabytes of storage and may not run reliably on devices with insufficient memory.

Online transcription is subject to provider availability, quotas, and supported file formats.

Technologies

- Flutter and Dart
- Whisper / whisper.cpp
- Groq Speech-to-Text API
- GitHub Actions
- Android and iOS platform integrations

Project Status

Version: 1.1.0+2

Android: APK compiled successfully through GitHub Actions.

iOS: Source available; native build and testing pending.

Future improvements: Better Caribbean accent recognition, transcription accuracy benchmarking, and improved handling of laughter and noisy recordings.

---

Developed as a free and accessible voice-note transcription solution with an emphasis on privacy and multilingual speech recognition.
