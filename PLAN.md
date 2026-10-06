# Plan for SysdSafe

- Untrack sonar-project.properties from GitHub and add to .gitignore (Completed)
- Implement Changes & Backups Restoration Interface (Completed):
  - [x] Analyze codebase, database schema, and existing backup mechanisms
  - [x] Verify local SonarQube container, Snyk integration, and code-gate pipeline
  - [x] Add backup querying and management methods to `DatabaseHelper`
  - [x] Create `BackupService` (`lib/backup_service.dart`) for backup inspection and restoration
  - [x] Build `BackupsScreen` (`lib/ui/backups.dart`) with scrolling listing, search/filter, and restore controls
  - [x] Integrate into `MainScreen` (`lib/main.dart`) navigation and auto-increment version to 1.0.11
  - [x] Add unit tests in `test/backup_test.dart`
  - [x] Run `flutter analyze`, `flutter test`, and `code-gate.sh`
  - [x] Run local SonarQube quality gate scan
