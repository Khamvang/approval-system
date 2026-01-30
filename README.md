# Approval

Close Contract Approval Ringi flow with Flutter (frontend) and Flask (backend).

## Backend quick start
- `cd backend`
- `python -m venv .venv && .venv\Scripts\activate` (Windows)
- `pip install -r requirements.txt`
- Configure env (optional):
	- `DB_TYPE` (`sqlite` default)
	- `SQLITE_PATH` (default `users.db`)
	- `UPLOAD_DIR` (default `backend/uploads`)
- Run: `flask --app app run --debug`

Tables created automatically on start:
- `users` (existing)
- `close_contract_forms`
- `close_contract_actions`

Key endpoints
- `POST /api/close-contracts` create a request; accepts JSON or multipart (`attachment` file field)
- `GET /api/close-contracts` list requests (query: `role`, `created_by_email`, `status`, `include_actions=1`)
- `GET /api/close-contracts/<id>` request detail + actions
- `POST /api/close-contracts/<id>/action` body `{result: approve|reject|send_back, comment?, actor_email?, actor_id?, actor_name?, actor_role?}`
- Attachments served at `/uploads/<file>`

## Frontend quick start
- `flutter pub get`
- Run: `flutter run -d chrome` (uses `http://localhost:5000` API; Android emulator uses `10.0.2.2`).

How to use
- Go to Approvals → tap **Close Contract Approval Ringi** to open the full form.
- Fill Details, Payment history, Remaining/Willing amounts, add remark and attachment, then Submit (enters Credit Approval step).
- Right pane shows timeline, to-do items for your role, and print to PDF.
