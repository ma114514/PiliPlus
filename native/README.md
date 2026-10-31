# Capture-capable media libraries

The application uses the five local `packages/media_kit_libs_*` packages. They
consume `native/artifacts/<platform>`; they never download the old decoder-only
bundles. Do not substitute system libmpv for the Linux artifact.

Run `python3 native/build.py android|ios|macos|windows|linux` on the matching
builder, then `python3 native/verify.py <platform>` before building the Flutter
application. The `capture-native.yml` reusable workflow produces artifacts for
application workflows. It does not publish releases. Source commits are pinned
in `sources.json`; the Apple WebP archive and Linux FFmpeg archive are checked
against fixed SHA256 digests. Output artifacts include `SHA256SUMS`.

Builders:

- Android: Linux, Android SDK (`ANDROID_HOME`), NDK 27.1.12297006, Java 21,
  Gradle and Flutter; follows the pinned upstream bundle script.
- Apple: macOS/Xcode, `brew install go meson ninja nasm make`.
- Windows: the upstream `ghcr.io/shinchiro/archlinux` cross-build container.
- Linux: Ubuntu 24.04; dependencies are listed in `capture-native.yml`.

Retain upstream LICENSE files when distributing binaries. The local plugin
sources retain the media-kit MIT license; native components retain their own
licenses.

## Runtime verification

Create a 320x180, three-second sample (for example with FFmpeg `testsrc2`), then:

```
CAPTURE_TEST_LIBMPV=/absolute/path/to/bundled/libmpv.so.2 \
CAPTURE_TEST_VIDEO=/absolute/path/to/sample.mp4 \
flutter test test/player/animation_export_integration_test.dart
```

The integration test calls the actual exporter, starts at one second, checks the
cropped preview and animated GIF/WebP frame sizes, and rejects single-frame
output. Run this against each platform's actual library with its matching test
runner; building or listing codecs alone is insufficient. Also check rotated
and non-square-pixel video, first/last frames, looping, cancellation, gallery
animation preservation, save permissions, and ordinary playback on devices.

## Validation status in the implementation workspace

- Four isolated Flutter behavior tests passed (endpoint steps and bounds,
  pixel mapping, resolution changes, drag selection and reset).
- Targeted Dart analysis of the changed capture, settings, saving and test
  code passed. Python compilation, shell syntax, workflow YAML parsing and
  `git diff --check` passed.
- Full application analysis requires the project's existing Flutter patches;
  the pristine SDK reports existing missing patched APIs. Full application
  tests are also blocked here by missing GTK/X11 development packages used by
  the cnativeapi build hook. The isolated tests do not bypass these checks for
  a release build.
- Android arm64 native compilation and a signed release-mode development APK
  now pass. The packaged libmpv SHA256 matches the newly compiled capture
  library; APK signature and ZIP integrity checks pass. The artifact is
  `dist/PiliPlus-dev-arm64-v8a.apk` (application ID `com.example.piliplus.dev`).
- The Android build used an isolated patched Flutter 3.47.9 SDK and a patched
  build-local material_ui package. Full analysis has no errors or warnings;
  existing informational lints remain. Native compilation used installed NDK
  28.2.13676358 with the pinned recipe versions and enabled capture filters.
- Android device save/playback checks and the other four native builds remain
  unverified. Run the runtime checks above before treating those as verified.

### Preview timeout correction

The headless metadata probe must explicitly set `vid=auto`: the pinned media-kit
fork otherwise defaults to `vid=no` until a VideoController attaches. Its
`videoParams` stream observes VO output, so original orientation is read from
`video-dec-params/rotate` after decoding starts. Probe errors and cancellation
now terminate the wait and subscriptions are cleaned up.

Five native regression cases pass using an extracted Linux libmpv 0.41.0 and the
same exporter/media-kit source (test mode remains false): nonzero-start cropped
preview plus animated WebP/GIF export, missing source, cancelling a stalled HTTP
request, rotated source, and non-square pixels. This verifies the shared
pipeline; Android device testing is still manual. The replacement arm64 APK is
`dist/PiliPlus-dev-arm64-v8a-preview-fix.apk`, versionCode 2, with the same
signing certificate as the first test build.

### Fixed crop aspect ratios

The crop editor offers free selection and 14 fixed presets in a scrollable left
rail. Selection state includes the preset; resetting clears both. Corner drags
anchor the opposite corner, and moving the rectangle preserves its size.
Geometry uses the oriented, square-pixel source frame. Preview and export share
the reduced integer-ratio crop calculation, including when source quality changes.

The fixed-ratio change passed 93 geometry and widget tests and 16 native exporter
cases using Linux libmpv. Native cases include GIF/WebP, nonzero start times,
rotation, non-square pixels and source resolution changes. The Android arm64
test artifact is `dist/PiliPlus-dev-arm64-v8a-aspect-ratios.apk`, versionCode 4.
Android device interaction and gallery checks remain manual.
