# VoiceNote Offline (Flutter project)

A free, private, on-device Whisper transcription app for WhatsApp audio.

**This ZIP is corrected app source code, NOT an installable APK or iOS IPA.** This environment had no Flutter SDK / Android SDK / Xcode, so building or testing a native binary here was impossible. Follow the steps below to generate and compile both platform projects on a development computer. The Android dependency versions are now aligned with the Flutter 3.38-supported tooling, but compilation and device behavior still need validation.

## Features

- Share an audio file from WhatsApp into the app on Android (configured share intent)
- iPhone: choose audio via the Files picker immediately; enable direct WhatsApp sharing by completing the iOS Share Extension setup in Xcode
- Local transcription with Whisper / whisper.cpp (no cloud transcription, AI API key, token credits, ads, or subscription)
- `.opus`, `.ogg`, `.m4a`, `.mp3`, `.wav` and more supported using the Whisper plugin's bundled on-device FFmpeg conversion
- Tiny (~75 MB), Base (~142 MB), Small (~466 MB) multilingual models. Small is generally more accurate but requires more phone RAM and takes longer.
- Auto-detect language or choose English, Spanish, French, Hindi, Portuguese
- Edit, copy, or share transcribed text
- Download a *free* model once; reuse offline thereafter. Alternatively import an official model from local Files, or bundle a model in the build so the app starts working with no internet.

> Privacy: the app itself has no analytics or backend. It asks for Android INTERNET permission solely to download a speech model if you choose. No audio or text is uploaded by the app's transcription workflow. The user can keep the phone offline while transcribing.

## Build Android online without installing any SDK

See [BUILD_ON_GITHUB.md](BUILD_ON_GITHUB.md) for a GitHub Actions workflow that compiles a downloadable APK, optionally bundling the free Whisper base model. These builds have **not been run or tested** in this environment.

## Android — build an APK (Windows 11)

1. Install **Flutter 3.38.1 or newer**, **Android Studio / Android SDK**, **JDK 17**, and **Python 3**. Run `flutter doctor` and address Android warnings. If versions advance, check plugin compatibility.
2. Unzip this project, open PowerShell at its root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup_windows.ps1
powershell -ExecutionPolicy Bypass -File .\tools\build_android.ps1
```

3. Your release APK is at `build\app\outputs\flutter-apk\app-release.apk`.
4. Transfer the APK to your Android phone, allow installation from that source if prompted, and install. This is a local release build; to distribute publicly, set your own package name and production signing key.

If PowerShell cannot find `py`, replace `py -3` in `setup_windows.ps1` with `python`.

**Linux/Mac Android build**: install Flutter, Android SDK, JDK and Python; execute `bash tools/setup_mac.sh` (on macOS) or manually `flutter create --platforms=android,ios --org com.offlinevoice --project-name voice_note_offline .`, `python3 tools/configure_project.py`, `flutter pub get`. Then run `bash tools/build_android.sh`.

## iOS — separate app (Mac required)

1. Install Xcode, Flutter 3.38.1+, Python 3; open a terminal in project root and run `bash tools/setup_mac.sh`.
2. Set the iOS deployment target to **15.6 or higher**, run `flutter run` on a connected iPhone or open `ios/Runner.xcworkspace` in Xcode and choose your signing team.
3. The Files picker works even **without** a Share Extension. Direct **WhatsApp → Share → VoiceNote Offline** requires the following one-time Xcode setup:
   - In Xcode, **File → New → Target → Share Extension**, name it `Share Extension`. Set minimum iOS version 15.6.
   - Replace its `ShareViewController.swift` and `Info.plist` with the files under `templates/ios-share-extension/` (these are starter templates; ensure target build settings reference these files).
   - This project intentionally uses `receive_sharing_intent` **1.8.1** (CocoaPods integration, not the 1.9.0 Swift Package Manager-only version). Ensure the extension target is included as a nested target in `ios/Podfile` as shown below and run `cd ios && pod install` on the Mac.
   - Add **App Groups** capability in **both** Runner and Share Extension targets, using the SAME unique group identifier (for example `group.com.yourcompany.voice_note_offline`; replace the example with your own registered value).
   - In **both targets**: Build Settings → User-defined setting `CUSTOM_GROUP_ID` = that App Group ID. In the extension, the Info.plist uses `$(CUSTOM_GROUP_ID)` automatically. The setup script already adds the matching `AppGroupId` and `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)` URL scheme to Runner's Info.plist.
   - Check the `Embed Foundation Extension` build phase is above `Thin Binary` in the Runner target. Follow the 1.8.1 CocoaPods Share Extension instructions and check lifecycle behavior on the iOS version you test.
   - Verify that the Share Extension target links `receive_sharing_intent` using CocoaPods. Example target nesting inside the existing `target 'Runner' do` block in `ios/Podfile`:

```ruby
  target 'Share Extension' do
    inherit! :search_paths
  end
```

   - Test on a real iPhone. Apple signing / provisioning rules still apply; a paid developer membership may be required for some distribution/capabilities. No paid transcription API is needed.
4. Build an iOS archive/IPA from Xcode after signing. **An APK will not install on an iPhone.**

The iOS app cannot be compiled on Windows/Linux because Xcode is macOS-only.

## First use / model setup

**Easiest path:** Open the app → select `Base` → tap `Download free model once` while connected to the internet → afterwards turn on Airplane Mode if desired → share/pick audio → Transcribe. If you want higher accuracy, switch to `Small`, download it once, and use offline thereafter.

**No internet ever on the phone:** Download one of the following files on a separate computer from the [official whisper.cpp model repo](https://huggingface.co/ggerganov/whisper.cpp/tree/main), transfer it to your phone, then tap `Import a model from Files`:
- `ggml-tiny.bin`
- `ggml-base.bin`
- `ggml-small.bin`

The imported filename must match the selected model size. No cloud API or token billing is needed. Alternatively, place any of those files in `assets/models/` BEFORE building so it is bundled into the APK/IPA and loaded at first launch (the app copies the model to private app storage). Bundling models makes the application larger.

## How to transcribe WhatsApp audio

**Android:** WhatsApp → open a conversation → select/long-press the voice message or attached audio → use Share (if available in that version) → choose VoiceNote Offline. If WhatsApp doesn't offer Share for that message, save/export the audio and use the app's `Pick audio file` action instead. On-device WhatsApp UI actions can differ by version.

**iPhone:** If Xcode Share Extension setup is complete: WhatsApp → Share → VoiceNote Offline. Otherwise save/export the voice note to Files and use `Pick audio file`.

Choose the model, choose `Auto-detect` or a language, then `Transcribe on this device`. Copy or share the result. You can edit the transcript to fix names and accents.

## Limitations / notes

- **Native binaries have not been compiled or tested** in this environment. Run `flutter analyze`, `flutter build apk --release`, and real-device tests before distributing.
- The first use is only offline if a model was bundled in the build or imported locally. A one-time free model download requires connectivity.
- Transcription accuracy is not guaranteed. No model is perfectly accurate on noisy, soft-spoken, overlapping, or accented audio. Large models use considerable RAM. Older phones may work better with Tiny or Base.
- The audio app does not monitor or read private WhatsApp conversations automatically; only user-selected or user-shared audio is processed.
- The native package `whisper_ggml` includes local FFmpeg for common compressed formats on mobile according to package docs; test each WhatsApp file type on actual devices.
- Shared files are copied temporarily into the app cache; the imported audio and model remain local. Copying may need additional free storage for large files.
- The example iOS Share Extension is a template, not a generated Xcode target. A developer must add that target and configure signing in Xcode.

## Dependencies & source documentation

- [whisper_ggml 2.8.1](https://pub.dev/packages/whisper_ggml) — device Whisper transcription and FFmpeg conversion.
- [receive_sharing_intent 1.8.1](https://pub.dev/packages/receive_sharing_intent/versions/1.8.1) — Android/iOS share handling. Pinned for the Flutter 3.38 Android Gradle/Kotlin toolchain.
- [file_picker](https://pub.dev/packages/file_picker) — select local audio/models.
- [share_plus 11.1.0](https://pub.dev/packages/share_plus/versions/11.1.0) — share finished transcript. Pinned to avoid the higher Android Gradle requirements of v12+.

Whisper models have their own license and distribution considerations; inspect model upstream terms before public redistribution. Flutter packages are third-party software with their own licenses.
