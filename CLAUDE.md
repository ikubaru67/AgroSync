# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AgroSync — Flutter app (MVP v0.1) for home hydroponics: monitoring (pH, EC/TDS, water level, temperature, humidity), 4-pump status, manual control, watering log, alert center, plant cards. Follows the *AgroSync Rancangan Aplikasi Mobile* doc (modules M1–M8, E1). UI text and code comments are in Indonesian. The app only reads status and sends commands — watering decisions live on the server. This directory is the Flutter project root (pubspec.yaml here).

## Commands

```bash
flutter pub get
flutter analyze                                            # flutter_lints + prefer_const_constructors, avoid_print
flutter test                                               # all tests
flutter test test/models_test.dart --plain-name 'SensorReading'   # single test
flutter run -t lib/main_dummy.dart                         # dummy flavor, no Firebase needed
flutter run -t lib/main_firebase.dart                      # firebase flavor, needs android/app/google-services.json
```

`lib/main.dart` is an unused hello-world scaffold; the real entry points are `main_dummy.dart` and `main_firebase.dart` (one per flavor). Android requires `minSdk >= 23` plus `INTERNET` and `POST_NOTIFICATIONS` (Android 13+) permissions.

## Architecture

**Two flavors, one app.** The entry point picks the data source. Each `main_*.dart` injects implementations via `ProviderScope.overrides` on the repository providers in `providers.dart` (providers throw `UnimplementedError` until overridden — screens only work through a real entry point).

**Repository pattern, strictly enforced.** UI never imports Firebase or the dummy backend:
- `domain/repositories.dart` — abstract interfaces; the only data API the UI knows.
- `domain/models.dart` — models with defensive `fromMap` factories: missing/wrong-typed fields become null/defaults, unknown enum values become `unknown`, never crash. `test/models_test.dart` pins this contract — extend it when changing models.
- `data/dummy/dummy_backend.dart` — one class implements all 7 repositories; simulates server behavior (command validation, interlocks, delays, failure scenarios) with an 8s refresh timer.
- `data/firebase/firebase_repositories.dart` — the ONLY file that knows Firebase data shapes. If the backend contract changes, change only this file.

**Riverpod providers (`providers.dart`).** Stream providers are `autoDispose` and gate on `deviceIdProvider` (derived from the auth user) — null id → `Stream.empty()`. `CommandController` tracks one active command and marks it `kedaluwarsa` after 30s without server response. `unreadAlertsProvider` counts alerts newer than `alertDilihatSampai`. `isOfflineProvider` treats the device offline when sensor data is older than 2 minutes.

**Router (`core/router.dart`).** go_router redirect driven by auth state (refreshListenable): no session → `/login`; fresh session without notification-permission decision → `/izin`; else into the app. `ShellRoute` hosts the bottom-nav tabs `/beranda`, `/tanaman`, `/kontrol`, `/riwayat`; sensor detail is `/sensor/:key`.

**Dummy flavor extras.** `dummyBackendProvider` (non-null only in dummy) drives the simulation panel in Pengaturan: scenarios Normal/Waspada/Bahaya/Perangkat mati, empty log, perangkat tidak merespons. Rules to preserve: nutrient/dosing pumps rejected during the Bahaya scenario (water-level interlock); repeat command within 30s rejected. Dummy login: `sari@email.com` / `agrosync123`.

## Data contract

Firebase paths follow the contract in README §Menyambung Firebase (users/{uid}/deviceId, deviceMembers, devices/{deviceId}/...); `database.rules.json` mirrors it. Timestamps are epoch millis (`waktu`, `updatedAt`), never DateTime.
