VoiceNoteOffline 🎙️

Free WhatsApp Voice Note Transcription — Offline & Online

VoiceNoteOffline is a Flutter-based mobile application that converts WhatsApp voice notes and audio recordings into text using Whisper speech recognition models.

The application focuses on privacy, accessibility, and improved transcription of different English accents, including Trinidadian and Caribbean speech.

📥 Download VoiceNoteOffline for Android

"⬇️ DOWNLOAD VOICENOTEOFFLINE APK" (https://github.com/DeathScythe911/VoiceNoteOffline/actions/runs/41159281998/artifacts/13025524553)

Version: 1.1.0+2

Platform: Android

Cost: Free

Build Status: Successfully compiled using GitHub Actions

Installation

1. Click the download link above while signed into GitHub.
2. Download the APK artifact ZIP.
3. Extract the downloaded file.
4. Open "app-release.apk".
5. Follow the Android installation prompts.
6. Launch VoiceNoteOffline and begin transcribing.

Note: This direct GitHub Actions artifact link expires on November 14, 2026. If the download is unavailable, visit the "GitHub Actions page" (https://github.com/DeathScythe911/VoiceNoteOffline/actions) to find a newer successful Android build.

✨ Features

- 100% offline transcription after installing a Whisper model.
- Optional online transcription using Groq's free API tier.
- Multiple offline AI models: Tiny, Base, Small, Medium and Large V3.
- Online Whisper Large V3 Turbo and Large V3 for higher-capability transcription.
- Trinidadian English vocabulary hints to assist recognition of local expressions.
- Custom vocabulary hints for personal names and unfamiliar words.
- WhatsApp voice-note support through file sharing or importing.
- Editable transcripts that can be copied and shared.
- No paid subscription required for offline transcription.

🧠 Transcription Modes

Mode| AI Model| Internet Required
Offline Fast| Tiny / Base| No
Offline Balanced| Small| No
Offline Advanced| Medium / Large V3| No
Online Fast| Large V3 Turbo| Yes
Online Advanced| Large V3| Yes

Offline models must first be downloaded or imported. Larger models generally require more RAM, storage and processing power.

Groq's online free tier has rate limits and usage restrictions. Unlimited free cloud transcription is not guaranteed.

📱 How to Use

Offline Mode

1. Open VoiceNoteOffline.
2. Select Offline.
3. Choose your preferred Whisper model.
4. Download or import the model if necessary.
5. Import a WhatsApp voice note.
6. Choose the spoken language.
7. Select Transcribe on this device.

Your recording remains on your device during offline transcription.

Online Mode

1. Visit "Groq Console" (https://console.groq.com/keys).
2. Create a free account and generate an API key.
3. Select Online in VoiceNoteOffline.
4. Choose Whisper Large V3 Turbo or Large V3.
5. Enter your API key.
6. Select an audio recording.
7. Approve uploading the recording to Groq.
8. Tap Transcribe online.

Your recording is uploaded to Groq for processing when you use online mode.

🇹🇹 Trinidadian and Caribbean Speech Recognition

VoiceNoteOffline offers optional Trinidad and Tobago English vocabulary hints.

Examples include:

- Allyuh
- Doh
- Cyah
- Buss out
- Lime
- Vex

Users can also enter custom names and expressions.

These hints provide context to Whisper but do not guarantee accurate recognition of Caribbean dialects. Rapid speech, laughter, overlapping voices and poor audio quality can still cause transcription errors.

🎧 Supported Audio Formats

Common supported formats include:

- OPUS / OGG
- MP3
- M4A
- WAV
- FLAC
- WebM

Format compatibility may vary depending on the selected processing mode.

🔒 Privacy

Offline transcription is performed locally on the phone.

Online processing requires the user to select Online mode, enter an API key and approve uploading the selected audio.

The application does not automatically access private WhatsApp conversations.

API keys are retained in application memory during the session rather than permanently stored.

🍎 iOS Compatibility

The Flutter project includes iOS source support and Share Extension starter templates.

An iOS application must be compiled using Xcode on macOS. Native iOS building and testing are still pending.

Android APK files cannot be installed on iPhones.

⚙️ Technologies Used

- Flutter and Dart
- Whisper / whisper.cpp
- Groq Speech-to-Text API
- GitHub Actions
- Android and iOS platform integrations

⚠️ Limitations

- Transcription accuracy depends on model choice and recording quality.
- Larger offline models may be slow or exceed available phone RAM.
- Online transcription requires internet access and is subject to Groq's limits.
- Supported formats may vary by provider.
- Successful APK compilation does not guarantee every feature has been tested on a physical device.

📌 Project Status

Current version: 1.1.0+2

Android: APK successfully built through GitHub Actions.

iOS: Development source available; native build and testing pending.

Future improvements: Better Caribbean dialect recognition, transcription benchmarking, and improved handling of laughter and background noise.

---

VoiceNoteOffline — Making voice-note transcription more accessible, private and flexible.
