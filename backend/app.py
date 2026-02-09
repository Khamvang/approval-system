from flask import Flask, request, jsonify, send_from_directory
import logging
from flask_cors import CORS
import os
import sqlite3
import json
from typing import Any, Dict, List, Optional, Tuple, cast
from werkzeug.security import check_password_hash
from werkzeug.security import generate_password_hash
from dotenv import load_dotenv
from werkzeug.utils import secure_filename
from datetime import datetime
from uuid import uuid4

load_dotenv(override=True)
logging.basicConfig(level=logging.INFO)

DB_TYPE = os.getenv('DB_TYPE', 'sqlite')
UPLOAD_DIR = os.getenv('UPLOAD_DIR', os.path.join(os.path.dirname(__file__), 'uploads'))
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Approval step configuration for Close Contract Approval Ringi
CLOSE_STEPS = [
    {'key': 'submit', 'label': 'Submit', 'role': 'Submitter'},
    {'key': 'credit', 'label': 'Credit Approval', 'role': 'Credit Approval'},
    {'key': 'system', 'label': 'System Approval', 'role': 'System Approval'},
    {'key': 'coo', 'label': 'COO & Admin Approval', 'role': 'COO & Admin Approval'},
    {'key': 'lms', 'label': 'LMS Void Approval', 'role': 'LMS Void Approval'},
]

def now_iso():
    return datetime.utcnow().isoformat() + 'Z'

def get_sqlite_conn():
    db_path = os.getenv('SQLITE_PATH', 'users.db')
    # If a relative path is provided, resolve it relative to this file (backend folder)
    if not os.path.isabs(db_path):
        db_path = os.path.join(os.path.dirname(__file__), db_path)
    # ensure directory exists
    db_dir = os.path.dirname(db_path)
    if db_dir and not os.path.exists(db_dir):
        try:
            os.makedirs(db_dir, exist_ok=True)
        except Exception:
            pass
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn

def get_mysql_conn():
    import mysql.connector
    host = os.getenv('DB_HOST', '127.0.0.1')
    port = int(os.getenv('DB_PORT', '3308'))
    user = os.getenv('DB_USER', 'root')
    password = os.getenv('DB_PASS', '')
    db_name = os.getenv('DB_NAME', 'approval_db')
    conn = mysql.connector.connect(host=host, port=port, user=user, password=password, database=db_name)
    return conn


def ensure_close_contract_tables():
    """Create tables for close contract approvals if they do not exist."""
    if DB_TYPE.lower() == 'mysql':
        import mysql.connector
        conn = get_mysql_conn()
        cur = conn.cursor()
        cur.execute('''
        CREATE TABLE IF NOT EXISTS close_contract_forms (
            id INT AUTO_INCREMENT PRIMARY KEY,
            collection_type VARCHAR(255),
            contract_no VARCHAR(255) NOT NULL,
            person_in_charge VARCHAR(255),
            manager_in_charge VARCHAR(255),
            last_contract_info TEXT,
            paid_term INT,
            total_term INT,
            full_paid_date VARCHAR(64),
            s_count INT,
            a_count INT,
            b_count INT,
            c_count INT,
            f_count INT,
            principal_remaining DECIMAL(18,2),
            interest_remaining DECIMAL(18,2),
            penalty_remaining DECIMAL(18,2),
            others_remaining DECIMAL(18,2),
            principal_willing DECIMAL(18,2),
            interest_willing DECIMAL(18,2),
            interest_months INT,
            penalty_willing DECIMAL(18,2),
            others_willing DECIMAL(18,2),
            remark TEXT,
            attachment_url TEXT,
            status VARCHAR(64),
            current_step VARCHAR(64),
            created_by_email VARCHAR(255),
            created_by_id INT,
            created_at VARCHAR(64),
            updated_at VARCHAR(64)
        )
        ''')
        cur.execute('''
        CREATE TABLE IF NOT EXISTS close_contract_actions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            request_id INT NOT NULL,
            step_key VARCHAR(64) NOT NULL,
            step_label VARCHAR(255) NOT NULL,
            role VARCHAR(255),
            result VARCHAR(64) NOT NULL,
            comment TEXT,
            actor_email VARCHAR(255),
            actor_id INT,
            actor_name VARCHAR(255),
            acted_at VARCHAR(64),
            attachments TEXT,
            FOREIGN KEY (request_id) REFERENCES close_contract_forms(id)
        )
        ''')
        # add attachments column if missing (MySQL)
        try:
            cur.execute('ALTER TABLE close_contract_actions ADD COLUMN attachments TEXT')
        except Exception:
            pass
        # comments table for free-form user comments on a request
        cur.execute('''
        CREATE TABLE IF NOT EXISTS close_contract_comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            request_id INT NOT NULL,
            user_id INT,
            user_email VARCHAR(255),
            user_name VARCHAR(255),
            text TEXT NOT NULL,
            created_at VARCHAR(64),
            FOREIGN KEY (request_id) REFERENCES close_contract_forms(id)
        )
        ''')
        conn.commit()
        cur.close()
        conn.close()
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute('''
        CREATE TABLE IF NOT EXISTS close_contract_forms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            collection_type TEXT,
            contract_no TEXT NOT NULL,
            person_in_charge TEXT,
            manager_in_charge TEXT,
            last_contract_info TEXT,
            paid_term INTEGER,
            total_term INTEGER,
            full_paid_date TEXT,
            s_count INTEGER,
            a_count INTEGER,
            b_count INTEGER,
            c_count INTEGER,
            f_count INTEGER,
            principal_remaining REAL,
            interest_remaining REAL,
            penalty_remaining REAL,
            others_remaining REAL,
            principal_willing REAL,
            interest_willing REAL,
            interest_months INTEGER,
            penalty_willing REAL,
            others_willing REAL,
            remark TEXT,
            attachment_url TEXT,
            status TEXT,
            current_step TEXT,
            created_by_email TEXT,
            created_by_id INTEGER,
            created_at TEXT,
            updated_at TEXT
        )
        ''')
        cur.execute('''
        CREATE TABLE IF NOT EXISTS close_contract_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            request_id INTEGER NOT NULL,
            step_key TEXT NOT NULL,
            step_label TEXT NOT NULL,
            role TEXT,
            result TEXT NOT NULL,
            comment TEXT,
            actor_email TEXT,
            actor_id INTEGER,
            actor_name TEXT,
            acted_at TEXT,
            attachments TEXT,
            FOREIGN KEY (request_id) REFERENCES close_contract_forms(id)
        )
        ''')
        # add attachments column if missing (SQLite)
        try:
            cur.execute('ALTER TABLE close_contract_actions ADD COLUMN attachments TEXT')
        except Exception:
            pass
        # comments table for free-form user comments on a request
        cur.execute('''
        CREATE TABLE IF NOT EXISTS close_contract_comments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            request_id INTEGER NOT NULL,
            user_id INTEGER,
            user_email TEXT,
            user_name TEXT,
            text TEXT NOT NULL,
            created_at TEXT,
            FOREIGN KEY (request_id) REFERENCES close_contract_forms(id)
        )
        ''')
        conn.commit()
        conn.close()


def _step_by_key(key: Optional[str]) -> Optional[Dict[str, Any]]:
    for s in CLOSE_STEPS:
        if s['key'] == key:
            return s
    return None


def _next_step_key(current: Optional[str]) -> Optional[str]:
    keys = [s['key'] for s in CLOSE_STEPS]
    if current is None:
        return 'submit'
    if current not in keys:
        return None
    idx = keys.index(current)
    return keys[idx + 1] if idx + 1 < len(keys) else None


def _step_key_for_role(role: str | None):
    if not role:
        return None
    role_lower = role.lower()
    for s in CLOSE_STEPS:
        if s.get('role', '').lower() == role_lower:
            return s.get('key')
    return None


def close_contract_row_to_dict(row):
    d = dict(row)
    numeric_fields = ['paid_term', 'total_term', 's_count', 'a_count', 'b_count', 'c_count', 'f_count', 'interest_months']
    money_fields = [
        'principal_remaining', 'interest_remaining', 'penalty_remaining', 'others_remaining',
        'principal_willing', 'interest_willing', 'penalty_willing', 'others_willing'
    ]
    for f in numeric_fields:
        if f in d and d[f] is not None:
            try:
                d[f] = int(d[f])
            except Exception:
                pass
    for f in money_fields:
        if f in d and d[f] is not None:
            try:
                d[f] = float(d[f])
            except Exception:
                pass
    return d

def query_user(email: str) -> Optional[Dict[str, Any]]:
    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute('SELECT * FROM users WHERE email = %s', (email,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        return cast(Optional[Dict[str, Any]], row)
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute('SELECT * FROM users WHERE email = ?', (email,))
        row = cur.fetchone()
        conn.close()
        # convert sqlite3.Row to dict for consistent access
        return dict(row) if row is not None else None


def query_all_users() -> List[Dict[str, Any]]:
    select_cols = 'id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status'
    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute(f'SELECT {select_cols} FROM users')
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return cast(List[Dict[str, Any]], rows)
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute(f'SELECT {select_cols} FROM users')
        rows = cur.fetchall()
        conn.close()
        return [dict(r) for r in rows]


def get_user_by_id(user_id: int) -> Optional[Dict[str, Any]]:
    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute('SELECT id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status FROM users WHERE id = %s', (user_id,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        return cast(Optional[Dict[str, Any]], row)
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute('SELECT id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status FROM users WHERE id = ?', (user_id,))
        row = cur.fetchone()
        conn.close()
        return dict(row) if row is not None else None


app = Flask(__name__)
CORS(app)
ensure_close_contract_tables()


@app.route('/uploads/<path:filename>')
def serve_upload(filename):
    return send_from_directory(UPLOAD_DIR, filename)


@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    email = data.get('email')
    password = data.get('password')
    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400

    row = query_user(email)
    if not row:
        logging.warning('Login attempt for unknown email: %s', email)
        return jsonify({'error': 'Invalid credentials'}), 401

    # row is a dict (converted for sqlite) when present
    password_hash = str(row.get('password_hash', ''))

    if not check_password_hash(password_hash, password):
        logging.warning('Failed password for email: %s', email)
        return jsonify({'error': 'Invalid credentials'}), 401

    # Authentication successful — return basic user info
    user_info = {
        'id': row.get('id'),
        'email': row.get('email'),
        'role': row.get('role', 'User'),
        'department': row.get('department')
    }
    return jsonify({'ok': True, 'user': user_info})


@app.route('/api/debug/users', methods=['GET'])
def debug_users():
    # Only allow in development or when explicitly enabled
    if os.getenv('ENABLE_DEV_ENDPOINTS') != '1' and os.getenv('FLASK_ENV') != 'development':
        return jsonify({'error': 'Not allowed'}), 403

    select_cols = 'id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status'
    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute(f'SELECT {select_cols} FROM users')
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify({'users': rows})
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute(f'SELECT {select_cols} FROM users')
        rows = cur.fetchall()
        conn.close()
        return jsonify({'users': [dict(r) for r in rows]})



@app.route('/api/users', methods=['GET', 'POST'])
def users_collection():
    # Basic endpoints for listing and creating users.
    if request.method == 'GET':
        # support query params: search, department, status
        search = (request.args.get('search') or '').strip()
        department = request.args.get('department')
        status = request.args.get('status')

        where = []
        params = []
        if search:
            # search in email, first_name, last_name, staff_no
            if DB_TYPE.lower() == 'mysql':
                where.append('(email LIKE %s OR first_name LIKE %s OR last_name LIKE %s OR staff_no LIKE %s)')
                like = f'%{search}%'
                params.extend([like, like, like, like])
            else:
                where.append('(email LIKE ? OR first_name LIKE ? OR last_name LIKE ? OR staff_no LIKE ?)')
                like = f'%{search}%'
                params.extend([like, like, like, like])
        if department:
            if DB_TYPE.lower() == 'mysql':
                where.append('department = %s')
                params.append(department)
            else:
                where.append('department = ?')
                params.append(department)
        if status:
            if DB_TYPE.lower() == 'mysql':
                where.append('status = %s')
                params.append(status)
            else:
                where.append('status = ?')
                params.append(status)

        select_cols = 'id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status'
        if DB_TYPE.lower() == 'mysql':
            conn = get_mysql_conn()
            cur = conn.cursor(dictionary=True)
            q = f'SELECT {select_cols} FROM users'
            if where:
                q += ' WHERE ' + ' AND '.join(where)
            cur.execute(q, tuple(params))
            rows = cur.fetchall()
            cur.close()
            conn.close()
            return jsonify({'users': rows})
        else:
            conn = get_sqlite_conn()
            cur = conn.cursor()
            q = f'SELECT {select_cols} FROM users'
            if where:
                q += ' WHERE ' + ' AND '.join(where)
            cur.execute(q, tuple(params))
            rows = cur.fetchall()
            conn.close()
            return jsonify({'users': [dict(r) for r in rows]})

    # POST -> create user
    data = request.get_json() or {}
    email = (data.get('email') or '').strip()
    password = data.get('password')
    role = data.get('role') or 'User'
    department = data.get('department')
    staff_no = data.get('staff_no')
    # require or accept first_name and last_name separately
    first_name = data.get('first_name') or ''
    last_name = data.get('last_name') or ''
    under_manager = data.get('under_manager')
    status = data.get('status') or 'active'

    if not email or not password:
        return jsonify({'error': 'email and password required'}), 400

    password_hash = generate_password_hash(password)

    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor()
        try:
            nickname = data.get('nickname')
            cur.execute('INSERT INTO users (email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)', (email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, status))
            conn.commit()
            user_id = cur.lastrowid
        except Exception as e:
            conn.rollback()
            return jsonify({'error': 'Could not create user', 'detail': str(e)}), 400
        finally:
            cur.close()
            conn.close()
        return jsonify({'ok': True, 'id': user_id}), 201
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        try:
            nickname = data.get('nickname')
            cur.execute('INSERT INTO users (email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', (email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, status))
            conn.commit()
            user_id = cur.lastrowid
        except Exception as e:
            conn.rollback()
            return jsonify({'error': 'Could not create user', 'detail': str(e)}), 400
        finally:
            conn.close()
        return jsonify({'ok': True, 'id': user_id}), 201


@app.route('/api/users/<int:user_id>', methods=['GET', 'PATCH', 'DELETE'])
def users_item(user_id):
    if request.method == 'GET':
        u = get_user_by_id(user_id)
        if not u:
            return jsonify({'error': 'Not found'}), 404
        return jsonify({'user': u})

    if request.method == 'DELETE':
        if DB_TYPE.lower() == 'mysql':
            conn = get_mysql_conn()
            cur = conn.cursor()
            cur.execute('DELETE FROM users WHERE id = %s', (user_id,))
            conn.commit()
            cur.close()
            conn.close()
        else:
            conn = get_sqlite_conn()
            cur = conn.cursor()
            cur.execute('DELETE FROM users WHERE id = ?', (user_id,))
            conn.commit()
            conn.close()
        return jsonify({'ok': True})

    # PATCH -> update several user fields
    data = request.get_json() or {}
    role = data.get('role')
    department = data.get('department')
    password = data.get('password')
    staff_no = data.get('staff_no')
    # accept only first_name/last_name in PATCH
    first_name = data.get('first_name')
    last_name = data.get('last_name')
    nickname = data.get('nickname')
    under_manager = data.get('under_manager')
    status = data.get('status')
    email = data.get('email')

    updates = []
    params = []
    if email is not None:
        updates.append('email = ?')
        params.append(email)
    if role is not None:
        updates.append('role = ?')
        params.append(role)
    if department is not None:
        updates.append('department = ?')
        params.append(department)
    if staff_no is not None:
        updates.append('staff_no = ?')
        params.append(staff_no)
    if first_name is not None:
        updates.append('first_name = ?')
        params.append(first_name)
    if last_name is not None:
        updates.append('last_name = ?')
        params.append(last_name)
    if nickname is not None:
        updates.append('nickname = ?')
        params.append(nickname)
    if under_manager is not None:
        updates.append('under_manager = ?')
        params.append(under_manager)
    if status is not None:
        updates.append('status = ?')
        params.append(status)
    if password is not None:
        updates.append('password_hash = ?')
        params.append(generate_password_hash(password))

    if not updates:
        return jsonify({'error': 'Nothing to update'}), 400

    if DB_TYPE.lower() == 'mysql':
        # adapt param placeholders
        q = ', '.join([u.replace('?', '%s') for u in updates])
        conn = get_mysql_conn()
        cur = conn.cursor()
        try:
            cur.execute(f'UPDATE users SET {q} WHERE id = %s', (*params, user_id))
            conn.commit()
        except Exception as e:
            conn.rollback()
            return jsonify({'error': 'Update failed', 'detail': str(e)}), 400
        finally:
            cur.close()
            conn.close()
    else:
        q = ', '.join(updates)
        conn = get_sqlite_conn()
        cur = conn.cursor()
        try:
            cur.execute(f'UPDATE users SET {q} WHERE id = ?', (*params, user_id))
            conn.commit()
        except Exception as e:
            conn.rollback()
            return jsonify({'error': 'Update failed', 'detail': str(e)}), 400
        finally:
            conn.close()

    return jsonify({'ok': True})


def _save_attachment_if_any(file_storage):
    if not file_storage or not getattr(file_storage, 'filename', ''):
        return None
    try:
        fname = secure_filename(file_storage.filename or 'attachment')
        fname = f"{uuid4().hex}_{fname}"
        target = os.path.join(UPLOAD_DIR, fname)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        file_storage.save(target)
        return f"/uploads/{fname}"
    except Exception as e:
        logging.error('Failed to save attachment: %s', e)
        return None


def _fetch_actions_for_request(conn, request_id: int) -> List[Dict[str, Any]]:
    if DB_TYPE.lower() == 'mysql':
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute('SELECT * FROM close_contract_actions WHERE request_id = %s ORDER BY acted_at ASC, id ASC', (request_id,))
        rows = cur.fetchall()
        cur.close()
        return cast(List[Dict[str, Any]], rows)
    cur = conn.cursor()
    cur.execute('SELECT * FROM close_contract_actions WHERE request_id = ? ORDER BY acted_at ASC, id ASC', (request_id,))
    rows = cur.fetchall()
    cur.close()
    return [dict(r) for r in rows]


def _fetch_comments_for_request(conn, request_id: int) -> List[Dict[str, Any]]:
    if DB_TYPE.lower() == 'mysql':
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute('SELECT id, request_id, user_id, user_email, user_name, text, created_at FROM close_contract_comments WHERE request_id = %s ORDER BY created_at ASC, id ASC', (request_id,))
        rows = cur.fetchall()
        cur.close()
        return cast(List[Dict[str, Any]], rows)
    cur = conn.cursor()
    cur.execute('SELECT id, request_id, user_id, user_email, user_name, text, created_at FROM close_contract_comments WHERE request_id = ? ORDER BY created_at ASC, id ASC', (request_id,))
    rows = cur.fetchall()
    cur.close()
    return [dict(r) for r in rows]


def _load_request(conn, request_id: int) -> Optional[Dict[str, Any]]:
    if DB_TYPE.lower() == 'mysql':
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute('SELECT * FROM close_contract_forms WHERE id = %s', (request_id,))
        row = cur.fetchone()
        cur.close()
        return cast(Optional[Dict[str, Any]], row)
    cur = conn.cursor()
    cur.execute('SELECT * FROM close_contract_forms WHERE id = ?', (request_id,))
    row = cur.fetchone()
    cur.close()
    return dict(row) if row else None


@app.route('/api/close-contracts', methods=['GET', 'POST'])
def close_contracts():
    if request.method == 'GET':
        role = request.args.get('role')
        created_by = request.args.get('created_by_email')
        status = request.args.get('status')
        include_actions = request.args.get('include_actions') == '1'
        step_key = _step_key_for_role(role)

        where = []
        params = []

        if role:
            if step_key:
                where.append('(current_step = %s OR current_step = %s)' if DB_TYPE.lower() == 'mysql' else '(current_step = ? OR current_step = ?)')
                params.extend([role, step_key])
            else:
                where.append('current_step = %s' if DB_TYPE.lower() == 'mysql' else 'current_step = ?')
                params.append(role)
        if created_by:
            where.append('created_by_email = %s' if DB_TYPE.lower() == 'mysql' else 'created_by_email = ?')
            params.append(created_by)
        if status:
            where.append('status = %s' if DB_TYPE.lower() == 'mysql' else 'status = ?')
            params.append(status)

        if DB_TYPE.lower() == 'mysql':
            conn = get_mysql_conn()
            cur = conn.cursor(dictionary=True)
            q = 'SELECT * FROM close_contract_forms'
            if where:
                q += ' WHERE ' + ' AND '.join(where)
            q += ' ORDER BY created_at DESC'
            cur.execute(q, tuple(params))
            rows = cur.fetchall()
            cur.close()
            result = [close_contract_row_to_dict(r) for r in rows]
            if include_actions:
                for r in result:
                    r['actions'] = _fetch_actions_for_request(conn, r['id'])
            conn.close()
            return jsonify({'items': result})
        else:
            conn = get_sqlite_conn()
            cur = conn.cursor()
            q = 'SELECT * FROM close_contract_forms'
            if where:
                q += ' WHERE ' + ' AND '.join(where)
            q += ' ORDER BY created_at DESC'
            cur.execute(q, tuple(params))
            rows = cur.fetchall()
            cur.close()
            result = [close_contract_row_to_dict(dict(r)) for r in rows]
            if include_actions:
                for r in result:
                    r['actions'] = _fetch_actions_for_request(conn, r['id'])
            conn.close()
            return jsonify({'items': result})

    # POST -> create new close contract request
    logging.info('POST /api/close-contracts incoming; content_type=%s', request.content_type)
    try:
        payload = request.get_json(silent=True) or {}
    except Exception as e:
        logging.exception('Failed to parse JSON payload: %s', e)
        payload = {}
    is_multipart = request.content_type and 'multipart/form-data' in request.content_type
    if is_multipart:
        payload = request.form.to_dict()
        logging.info('Multipart form keys: %s', list(payload.keys()))

    # ensure numbers become int/float where appropriate
    def _to_int(v):
        try:
            return int(v) if v not in (None, '') else None
        except Exception:
            return None

    def _to_float(v):
        try:
            return float(v) if v not in (None, '') else None
        except Exception:
            return None

    attachment_url = None
    if is_multipart and 'attachment' in request.files:
        attachment_url = _save_attachment_if_any(request.files['attachment'])
    else:
        attachment_url = payload.get('attachment_url')

    current_step_key = 'credit'
    now = now_iso()

    base_fields = (
        payload.get('collection_type'),
        payload.get('contract_no'),
        payload.get('person_in_charge'),
        payload.get('manager_in_charge'),
        payload.get('last_contract_info'),
        _to_int(payload.get('paid_term')),
        _to_int(payload.get('total_term')),
        payload.get('full_paid_date'),
        _to_int(payload.get('s_count')),
        _to_int(payload.get('a_count')),
        _to_int(payload.get('b_count')),
        _to_int(payload.get('c_count')),
        _to_int(payload.get('f_count')),
        _to_float(payload.get('principal_remaining')),
        _to_float(payload.get('interest_remaining')),
        _to_float(payload.get('penalty_remaining')),
        _to_float(payload.get('others_remaining')),
        _to_float(payload.get('principal_willing')),
        _to_float(payload.get('interest_willing')),
        _to_int(payload.get('interest_months')),
        _to_float(payload.get('penalty_willing')),
        _to_float(payload.get('others_willing')),
        payload.get('remark'),
        attachment_url,
        'under_review',
        current_step_key,
        payload.get('created_by_email'),
        _to_int(payload.get('created_by_id')),
        now,
        now
    )

    if not payload.get('contract_no'):
        return jsonify({'error': 'contract_no is required'}), 400

    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor()
        try:
            cols = (
                'collection_type, contract_no, person_in_charge, manager_in_charge, last_contract_info, '
                'paid_term, total_term, full_paid_date, s_count, a_count, b_count, c_count, f_count, '
                'principal_remaining, interest_remaining, penalty_remaining, others_remaining, '
                'principal_willing, interest_willing, interest_months, penalty_willing, others_willing, '
                'remark, attachment_url, status, current_step, created_by_email, created_by_id, created_at, updated_at'
            )
            placeholders = ', '.join(['%s'] * len(base_fields))
            cur.execute(f'INSERT INTO close_contract_forms ({cols}) VALUES ({placeholders})', base_fields)
            raw_request_id = cur.lastrowid
            if raw_request_id is None:
                raise ValueError('Failed to obtain request id after insert')
            request_id_int = int(raw_request_id)
            conn.commit()
            # add submit action
            act_placeholders = ', '.join(['%s'] * 10)
            cur.execute(f'INSERT INTO close_contract_actions (request_id, step_key, step_label, role, result, comment, actor_email, actor_id, actor_name, acted_at) VALUES ({act_placeholders})', (request_id_int, 'submit', 'Submit', 'Submitter', 'submitted', payload.get('remark') or '', payload.get('created_by_email'), _to_int(payload.get('created_by_id')), payload.get('created_by_name'), now))
            conn.commit()
            row = _load_request(conn, request_id_int)
            row = close_contract_row_to_dict(row)
            row['actions'] = _fetch_actions_for_request(conn, request_id_int)
            cur.close()
            conn.close()
            logging.info('Created close_contract id=%s by %s', request_id_int, payload.get('created_by_email'))
            return jsonify({'ok': True, 'item': row}), 201
        except Exception as e:
            conn.rollback()
            logging.exception('Failed to insert close_contract (mysql): %s; payload keys: %s', e, list(payload.keys()))
            cur.close()
            conn.close()
            return jsonify({'error': 'Insert failed', 'detail': str(e)}), 500
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        try:
            cols = (
                'collection_type, contract_no, person_in_charge, manager_in_charge, last_contract_info, '
                'paid_term, total_term, full_paid_date, s_count, a_count, b_count, c_count, f_count, '
                'principal_remaining, interest_remaining, penalty_remaining, others_remaining, '
                'principal_willing, interest_willing, interest_months, penalty_willing, others_willing, '
                'remark, attachment_url, status, current_step, created_by_email, created_by_id, created_at, updated_at'
            )
            placeholders = ', '.join(['?'] * len(base_fields))
            cur.execute(f'INSERT INTO close_contract_forms ({cols}) VALUES ({placeholders})', base_fields)
            raw_request_id = cur.lastrowid
            if raw_request_id is None:
                raise ValueError('Failed to obtain request id after insert')
            request_id_int = int(raw_request_id)
            conn.commit()
            act_placeholders = ', '.join(['?'] * 10)
            cur.execute(f'INSERT INTO close_contract_actions (request_id, step_key, step_label, role, result, comment, actor_email, actor_id, actor_name, acted_at) VALUES ({act_placeholders})', (request_id_int, 'submit', 'Submit', 'Submitter', 'submitted', payload.get('remark') or '', payload.get('created_by_email'), _to_int(payload.get('created_by_id')), payload.get('created_by_name'), now))
            conn.commit()
            row = _load_request(conn, request_id_int)
            row = close_contract_row_to_dict(row)
            row['actions'] = _fetch_actions_for_request(conn, request_id_int)
            cur.close()
            conn.close()
            logging.info('Created close_contract id=%s by %s', request_id_int, payload.get('created_by_email'))
            return jsonify({'ok': True, 'item': row}), 201
        except Exception as e:
            conn.rollback()
            logging.exception('Failed to insert close_contract (sqlite): %s; payload keys: %s', e, list(payload.keys()))
            cur.close()
            conn.close()
            return jsonify({'error': 'Insert failed', 'detail': str(e)}), 500


@app.route('/api/close-contracts/<int:request_id>', methods=['GET'])
def close_contract_detail(request_id):
    conn = get_mysql_conn() if DB_TYPE.lower() == 'mysql' else get_sqlite_conn()
    row = _load_request(conn, request_id)
    if not row:
        conn.close()
        return jsonify({'error': 'Not found'}), 404
    row = close_contract_row_to_dict(row)
    row['actions'] = _fetch_actions_for_request(conn, request_id)
    # include free-form comments
    try:
        row['comments'] = _fetch_comments_for_request(conn, request_id)
    except Exception:
        row['comments'] = []
    conn.close()
    return jsonify({'item': row})


@app.route('/api/close-contracts/<int:request_id>', methods=['PATCH'])
def close_contract_update(request_id):
    # allow updating an existing request (used for resubmit/edit)
    conn = get_mysql_conn() if DB_TYPE.lower() == 'mysql' else get_sqlite_conn()
    row = _load_request(conn, request_id)
    if not row:
        conn.close()
        return jsonify({'error': 'Not found'}), 404

    try:
        payload = request.get_json(silent=True) or {}
    except Exception:
        payload = {}
    is_multipart = request.content_type and 'multipart/form-data' in request.content_type
    if is_multipart:
        payload = request.form.to_dict()

    # allow caller to bypass status/current_step reset (used for attachment-only patch)
    skip_reset = str(payload.get('skip_reset', '')).lower() in ('1', 'true', 'yes')

    def _to_int(v):
        try:
            return int(v) if v not in (None, '') else None
        except Exception:
            return None

    def _to_float(v):
        try:
            return float(v) if v not in (None, '') else None
        except Exception:
            return None

    attachment_url = None
    if is_multipart and 'attachment' in request.files:
        attachment_url = _save_attachment_if_any(request.files['attachment'])
    else:
        # allow clearing or keeping existing
        if 'attachment_url' in payload:
            attachment_url = payload.get('attachment_url')

    updates = []
    params = []
    fields = [
        'collection_type','contract_no','person_in_charge','manager_in_charge','last_contract_info',
        'paid_term','total_term','full_paid_date','s_count','a_count','b_count','c_count','f_count',
        'principal_remaining','interest_remaining','penalty_remaining','others_remaining',
        'principal_willing','interest_willing','interest_months','penalty_willing','others_willing','remark'
    ]
    for f in fields:
        if f in payload:
            updates.append(f + (' = %s' if DB_TYPE.lower() == 'mysql' else ' = ?'))
            val = payload.get(f)
            if f in ('paid_term','total_term','s_count','a_count','b_count','c_count','f_count','interest_months'):
                params.append(_to_int(val))
            elif f in ('principal_remaining','interest_remaining','penalty_remaining','others_remaining','principal_willing','interest_willing','penalty_willing','others_willing'):
                params.append(_to_float(val))
            else:
                params.append(val)

    # attachment_url update handling
    if attachment_url is not None:
        updates.append('attachment_url' + (' = %s' if DB_TYPE.lower() == 'mysql' else ' = ?'))
        params.append(attachment_url)

    # always update updated_at
    updates.append('updated_at' + (' = %s' if DB_TYPE.lower() == 'mysql' else ' = ?'))
    params.append(now_iso())

    # when resubmitting, reset status/current_step to restart approval flow (unless explicitly skipped)
    if not skip_reset:
        updates.append('status' + (' = %s' if DB_TYPE.lower() == 'mysql' else ' = ?'))
        params.append('under_review')
        updates.append('current_step' + (' = %s' if DB_TYPE.lower() == 'mysql' else ' = ?'))
        params.append('credit')

    if not updates:
        conn.close()
        return jsonify({'error': 'Nothing to update'}), 400

    cur = None
    try:
        if DB_TYPE.lower() == 'mysql':
            q = ', '.join([u.replace(' = %s', ' = %s') for u in updates])
            cur = conn.cursor()
            cur.execute(f'UPDATE close_contract_forms SET {q} WHERE id = %s', (*params, request_id))
            conn.commit()
            # add resubmit action record only when not skipping reset
            if not skip_reset:
                acted_at = now_iso()
                cur.execute('INSERT INTO close_contract_actions (request_id, step_key, step_label, role, result, comment, actor_email, actor_id, actor_name, acted_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)', (request_id, 'submit', 'Submit', 'Submitter', 'resubmitted', payload.get('remark') or '', payload.get('created_by_email'), _to_int(payload.get('created_by_id')), payload.get('created_by_name'), acted_at))
                conn.commit()
            updated = _load_request(conn, request_id)
            updated = close_contract_row_to_dict(updated)
            updated['actions'] = _fetch_actions_for_request(conn, request_id)
            cur.close()
            conn.close()
            return jsonify({'ok': True, 'item': updated})
        else:
            q = ', '.join(updates)
            cur = conn.cursor()
            cur.execute(f'UPDATE close_contract_forms SET {q} WHERE id = ?', (*params, request_id))
            conn.commit()
            if not skip_reset:
                acted_at = now_iso()
                cur.execute('INSERT INTO close_contract_actions (request_id, step_key, step_label, role, result, comment, actor_email, actor_id, actor_name, acted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', (request_id, 'submit', 'Submit', 'Submitter', 'resubmitted', payload.get('remark') or '', payload.get('created_by_email'), _to_int(payload.get('created_by_id')), payload.get('created_by_name'), acted_at))
                conn.commit()
            updated = _load_request(conn, request_id)
            updated = close_contract_row_to_dict(updated)
            updated['actions'] = _fetch_actions_for_request(conn, request_id)
            cur.close()
            conn.close()
            return jsonify({'ok': True, 'item': updated})
    except Exception as e:
        conn.rollback()
        if cur:
            cur.close()
        conn.close()
        logging.exception('Failed to update close_contract: %s', e)
        return jsonify({'error': 'Update failed', 'detail': str(e)}), 500


@app.route('/api/close-contracts/<int:request_id>/comments', methods=['GET', 'POST'])
def close_contract_comments(request_id):
    conn = get_mysql_conn() if DB_TYPE.lower() == 'mysql' else get_sqlite_conn()
    # ensure request exists
    req = _load_request(conn, request_id)
    if not req:
        conn.close()
        return jsonify({'error': 'Not found'}), 404

    if request.method == 'GET':
        comments = _fetch_comments_for_request(conn, request_id)
        conn.close()
        return jsonify({'comments': comments})

    # POST -> create a comment
    data = request.get_json() or {}
    text = (data.get('text') or '').strip()
    if not text:
        conn.close()
        return jsonify({'error': 'text is required'}), 400
    user_email = data.get('user_email')
    user_id = data.get('user_id')
    user_name = data.get('user_name')
    created_at = now_iso()

    if DB_TYPE.lower() == 'mysql':
        cur = conn.cursor()
        cur.execute('INSERT INTO close_contract_comments (request_id, user_id, user_email, user_name, text, created_at) VALUES (%s, %s, %s, %s, %s, %s)', (request_id, user_id, user_email, user_name, text, created_at))
        conn.commit()
        comment_id = cur.lastrowid
        cur.close()
        # fetch inserted
        cur = conn.cursor(dictionary=True)  # type: ignore[arg-type]
        cur.execute('SELECT id, request_id, user_id, user_email, user_name, text, created_at FROM close_contract_comments WHERE id = %s', (comment_id,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        return jsonify({'ok': True, 'comment': row}), 201
    else:
        cur = conn.cursor()
        cur.execute('INSERT INTO close_contract_comments (request_id, user_id, user_email, user_name, text, created_at) VALUES (?, ?, ?, ?, ?, ?)', (request_id, user_id, user_email, user_name, text, created_at))
        conn.commit()
        comment_id = cur.lastrowid
        cur.close()
        cur = conn.cursor()
        cur.execute('SELECT id, request_id, user_id, user_email, user_name, text, created_at FROM close_contract_comments WHERE id = ?', (comment_id,))
        r = cur.fetchone()
        conn.close()
        comment_row = dict(r) if r else None  # type: ignore[arg-type]
        return jsonify({'ok': True, 'comment': comment_row}), 201


@app.route('/api/close-contracts/<int:request_id>/action', methods=['POST'])
def close_contract_action(request_id):
    data = request.get_json() or {}
    result = (data.get('result') or '').lower()
    if result not in ('approve', 'reject', 'send_back'):
        return jsonify({'error': 'result must be approve, reject, or send_back'}), 400

    conn = get_mysql_conn() if DB_TYPE.lower() == 'mysql' else get_sqlite_conn()
    row = _load_request(conn, request_id)
    if not row:
        conn.close()
        return jsonify({'error': 'Not found'}), 404

    current_status = row.get('status')
    current_step_key = row.get('current_step')
    if current_status in ('approved', 'rejected'):
        conn.close()
        return jsonify({'error': 'Request already finalized'}), 400

    step_key_str = current_step_key if isinstance(current_step_key, str) else (str(current_step_key) if current_step_key is not None else None)
    step = _step_by_key(step_key_str)
    if not step:
        conn.close()
        return jsonify({'error': 'Invalid current step'}), 400

    acted_at = now_iso()
    actor_email = data.get('actor_email')
    actor_id = data.get('actor_id')
    actor_name = data.get('actor_name')
    actor_role = data.get('actor_role') or step['role']
    comment = data.get('comment')
    attachments = data.get('attachment_urls') or []
    if isinstance(attachments, str):
        try:
            parsed = json.loads(attachments)
            if isinstance(parsed, list):
                attachments = parsed
        except Exception:
            attachments = [a.strip() for a in attachments.split(',') if a.strip()]
    attachments_json = json.dumps(attachments) if attachments else None

    if DB_TYPE.lower() == 'mysql':
        cur = conn.cursor()
        cur.execute('''
            INSERT INTO close_contract_actions (request_id, step_key, step_label, role, result, comment, actor_email, actor_id, actor_name, acted_at, attachments)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ''', (request_id, current_step_key, step['label'], actor_role, result, comment, actor_email, actor_id, actor_name, acted_at, attachments_json))  # type: ignore[arg-type]
    else:
        cur = conn.cursor()
        cur.execute('''
            INSERT INTO close_contract_actions (request_id, step_key, step_label, role, result, comment, actor_email, actor_id, actor_name, acted_at, attachments)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (request_id, current_step_key, step['label'], actor_role, result, comment, actor_email, actor_id, actor_name, acted_at, attachments_json))

    new_status = 'under_review'
    new_step_key = step_key_str
    if result == 'approve':
        nxt = _next_step_key(step_key_str)
        if nxt:
            new_step_key = nxt
            new_status = 'under_review'
        else:
            new_status = 'approved'
    elif result == 'reject':
        new_status = 'rejected'
    elif result == 'send_back':
        new_status = 'sent_back'
        new_step_key = 'submit'

    if DB_TYPE.lower() == 'mysql':
        cur.execute('UPDATE close_contract_forms SET status = %s, current_step = %s, updated_at = %s WHERE id = %s', (new_status, new_step_key, acted_at, request_id))  # type: ignore[arg-type]
        conn.commit()
        cur.close()
        updated = _load_request(conn, request_id)
        updated = close_contract_row_to_dict(updated)
        updated['actions'] = _fetch_actions_for_request(conn, request_id)
        conn.close()
        return jsonify({'ok': True, 'item': updated})
    else:
        cur.execute('UPDATE close_contract_forms SET status = ?, current_step = ?, updated_at = ? WHERE id = ?', (new_status, new_step_key, acted_at, request_id))
        conn.commit()
        cur.close()
        updated = _load_request(conn, request_id)
        updated = close_contract_row_to_dict(updated)
        updated['actions'] = _fetch_actions_for_request(conn, request_id)
        conn.close()
        return jsonify({'ok': True, 'item': updated})


if __name__ == '__main__':
    port = int(os.getenv('FLASK_RUN_PORT', '5000'))
    app.run(host='0.0.0.0', port=port, debug=(os.getenv('FLASK_ENV') == 'development'))
