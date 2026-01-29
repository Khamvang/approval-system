# PR: Split full_name into first_name / last_name

## Summary
This change removes the legacy `full_name` usage and replaces it with separate `first_name` and `last_name` fields across the frontend, backend API, and database.

## Files changed
- backend/init_db.py  — added `first_name` and `last_name` columns, migrated legacy `full_name` values, attempted to remove legacy column.
- backend/app.py      — API updated to accept and return `first_name`/`last_name`; create/update endpoints and user listing adjusted.
- lib/screens/admin_users_widget.dart — UI updated to show separate First/Last Name in table and in Create/Edit dialogs; sends `first_name`/`last_name` in payloads.

## Migration notes
- Run the DB migration script to apply changes (this script is idempotent and will attempt to migrate any `full_name` values into the new columns):

```bash
# from repo root
python backend/init_db.py
```

- The migration for SQLite recreates the `users` table without the `full_name` column. For MySQL the script attempts to `ALTER TABLE DROP COLUMN full_name` where permitted.

## How to test locally
1. Start the backend:

```bash
# use the repo's venv python if available
./.venv/Scripts/python.exe backend/app.py
# or
python backend/app.py
```

2. Run the Flutter app (choose your target):

```bash
# web
flutter run -d chrome
# windows
flutter run -d windows
# android emulator
flutter run -d emulator-5554
```

3. Create a new user via the UI or curl/postman. The backend will hash passwords automatically.

4. Verify users API returns `first_name` and `last_name`:

```bash
curl http://127.0.0.1:5000/api/users
```

## Notes / Next steps
- I initialized a local git branch `feature/split-first-last-name` and committed the changes.
- If you'd like, I can push this branch to your remote and open a PR (I will need permission/credentials for push), or you can run:

```bash
git push origin feature/split-first-last-name
```

Would you like me to push the branch and open the PR on your remote now?