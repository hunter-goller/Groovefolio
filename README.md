# Vinyl App 🎵

Vinyl App is a Flutter application for vinyl collectors that combines collection management, listening analytics, and music discovery into one experience.

Unlike traditional collection managers, Vinyl App focuses on **how you listen**, not just what you own. It helps you rediscover forgotten albums, visualize your listening habits, and build a deeper connection with your collection.

---

## Features

### Collection Management
- Add, edit, and remove albums
- Search and filter your collection
- View detailed album pages
- Track purchase information and condition
- Optional Discogs integration

### Play Tracking
- Manual play logging
- NFC tap-to-log support
- Play history timeline
- Track listening sessions over time

### Statistics
- Most played albums
- Listening trends
- Genre breakdowns
- Artist statistics
- Monthly and yearly insights

### Discover
- Rediscover forgotten albums
- Personalized recommendations
- Similar albums
- Listening suggestions based on play history

### Album Wrapped *(planned signature feature)*
Each album includes its own personalized listening summary inspired by Spotify Wrapped.

Examples include:
- First played
- Total listens
- Listening timeline
- Favorite listening periods
- Rediscovery insights
- Similar albums
- Personal milestones

---

# Technology Stack

- Flutter
- Dart
- Riverpod
- Drift (SQLite)
- go_router
- Material 3

---

# Project Architecture

The project follows a feature-first architecture.

```
lib/
├── app/
├── db/
├── features/
├── providers/
├── repositories/
├── services/
├── theme/
├── utils/
└── widgets/
```

Each feature owns its own:
- UI
- providers
- widgets
- models

This keeps the project modular and scalable as new features are added.

---

# Roadmap

## Phase 1 – Foundation
- [x] Flutter project setup
- [x] Git repository
- [x] CI/CD
- [ ] App routing
- [ ] Theme system
- [ ] Riverpod setup

## Phase 2 – Data Layer
- [ ] SQLite database
- [ ] Drift ORM
- [ ] Repository pattern
- [ ] Local persistence

## Phase 3 – Core Features
- [ ] Collection
- [ ] Album Details
- [ ] Add/Edit Albums
- [ ] Search
- [ ] Filtering

## Phase 4 – Listening
- [ ] Play logging
- [ ] NFC integration
- [ ] Listening history
- [ ] Statistics

## Phase 5 – Discovery
- [ ] Recommendations
- [ ] Rediscover albums
- [ ] Album Wrapped
- [ ] Smart insights

---

# Current Status

🚧 Early development.

The project recently migrated from an earlier React Native prototype to Flutter.

---

# Getting Started

```bash
flutter pub get

flutter pub run build_runner build

flutter run
```

---

# Vision

Vinyl App aims to become more than a collection tracker.

The goal is to create a companion app that encourages people to listen to and rediscover the records they already own, while providing meaningful insights into their listening habits through beautiful visualizations and personalized recommendations.
