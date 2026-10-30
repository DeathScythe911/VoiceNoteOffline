# Build an APK on GitHub (no Android Studio required)

This folder includes an automated build in `.github/workflows/build-android-apk.yml`.
The build runs in GitHub Actions, not on your computer or phone.

## One-time setup

1. Sign in to https://github.com and create a new **empty repository**, for example `VoiceNoteOffline`. Public repos may have more generous GitHub Actions free usage than private repos; check your plan's quotas.
2. Upload the **contents** of this extracted folder into the repository root, including the hidden `.github/workflows/build-android-apk.yml` file. On a computer, dragging the extracted folder's contents into **Add file > Upload files** should work, or use Git. Keep the `.github/` folder hierarchy. Commit the files to `main`.
3. The `Build offline Android APK` workflow should start on the commit. If Actions are disabled, enable them under the repository settings and then open **Actions > Build offline Android APK > Run workflow**.
4. After the workflow succeeds, select its run and download the `VoiceNoteOffline-Android-APK` artifact under **Artifacts**. GitHub downloads a ZIP; unzip it and install `app-release.apk` on your Android phone.

**The first build downloads and bundles the free multilingual Whisper *base* model (~142 MB).** This allows transcription on the phone with no internet connection even on first launch. The resulting APK will be substantially larger than a version without the bundled model.

To make a smaller APK: choose **Actions > Build offline Android APK > Run workflow**, uncheck the `bundle_offline_model` input, then run it. In that build, the model must be downloaded free once or imported from local storage before offline transcription works.

If the build fails, open the failed run and copy the red error step/log into ChatGPT; the code has **not been compiled or device-tested in this environment**.

### Installation safety

APK release builds from the example project may use Flutter's default development signing setup. This is suitable for personal sideload/testing, not Play Store publication. For store distribution, configure a secure production Android keystore and unique app ID. Install only APKs from builds you control, and review the app's requested permissions.

### iPhone support

An APK cannot run on an iPhone. The shared Flutter source and iOS Share Extension template are in this project, but compiling and signing the iOS app requires a macOS/Xcode build and additional iOS configuration. These GitHub instructions build Android only.

### Costs

The app uses local Whisper AI, not paid cloud transcription; no API key, tokens, or subscription required for transcribing. GitHub Actions build usage has account limits; check GitHub's current free quota for your repository before starting repeated builds.

## Compatibility fixes in this revision

- Pins `receive_sharing_intent` to `1.8.1` instead of `1.9.0`; v1.9 uses the much newer Kotlin/AGP 9 toolchain and can conflict with Flutter 3.38 Android defaults.
- Pins `share_plus` to `11.1.0` rather than `13.3.1`, avoiding the >=8.12.1 AGP requirement of v12+.
- Removes the workflow's forced Gradle/AGP replacements; `flutter create` supplies the Flutter-tested Android toolchain.
- Runs Python static configuration tests and Flutter analyzer before building the release APK.

These are **preventive compatibility fixes**, not corrections confirmed from a failed GitHub Actions log. No source files or workflow are presently in the linked GitHub repository, so no build has run.
