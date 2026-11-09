# BP Log by EticaHub

A private blood pressure logbook for iPhone. Log a reading in two taps, see where it falls on the AHA chart, and hand your doctor a clean PDF.

- Everything stays on the phone (SwiftData + iCloud). No account, no server.
- Apple Health sync for blood pressure, heart rate, blood oxygen and weight.
- Scan the cuff screen with the camera; on-device OCR fills in the numbers.
- Medications with a one-tap "took it" log; readings tagged before/after meds, exercise, stress, posture.
- Family profiles (spouse, parent), each with their own readings and report. Free.
- Pick the guideline: AHA (US), ESC/ESH (Europe), WHO, JNC 7, or your doctor's target.
- Face ID / passcode lock. PDF and CSV export, share or email from the Report tab.
- Free with a banner ad. Monthly or yearly removes ads.
- Optional, off by default: donate anonymized weekly averages to EticaLabs research.

## Layout

- `BPCore/` platform-free Swift package: AHA classification, averages, report data. Tested on Linux and macOS.
- `BPLog/` the iOS app (SwiftUI, SwiftData, HealthKit, StoreKit 2, Google Mobile Ads).
- `project.yml` XcodeGen spec. Run `xcodegen generate` to produce `BPLog.xcodeproj`.

## Build

```
brew install xcodegen
xcodegen generate
open BPLog.xcodeproj
```

Core tests without Xcode:

```
cd BPCore && swift test
```

## Store products

| Product id | Price |
| --- | --- |
| `com.eticahub.bplog.monthly` | $3.99 / month, no ads |
| `com.eticahub.bplog.yearly` | $24.99 / year, no ads |

`BPLog/Resources/Products.storekit` mirrors these for simulator testing. The AdMob ids in `Info.plist` and `AdConfig.swift` are Google's public test ids; swap for the real ones before release.
