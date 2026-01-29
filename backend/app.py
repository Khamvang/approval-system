from flask import Flask, request, jsonify
import logging
from flask_cors import CORS
import os
import sqlite3
from werkzeug.security import check_password_hash
from werkzeug.security import generate_password_hash
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)

DB_TYPE = os.getenv('DB_TYPE', 'sqlite')

def get_sqlite_conn():
    db_path = os.getenv('SQLITE_PATH', 'users.db')
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn

def get_mysql_conn():
    import mysql.connector
    host = os.getenv('DB_HOST', '127.0.0.1')
    port = int(os.getenv('DB_PORT', '3306'))
    user = os.getenv('DB_USER', 'root')
    password = os.getenv('DB_PASS', '')
    db_name = os.getenv('DB_NAME', 'approval_db')
    conn = mysql.connector.connect(host=host, port=port, user=user, password=password, database=db_name)
    return conn

def query_user(email):
    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor(dictionary=True)
        cur.execute('SELECT * FROM users WHERE email = %s', (email,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        return row
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute('SELECT * FROM users WHERE email = ?', (email,))
        row = cur.fetchone()
        conn.close()
        # convert sqlite3.Row to dict for consistent access
        return dict(row) if row is not None else None


def query_all_users():
    select_cols = 'id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status'
    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor(dictionary=True)
        cur.execute(f'SELECT {select_cols} FROM users')
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return rows
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute(f'SELECT {select_cols} FROM users')
        rows = cur.fetchall()
        conn.close()
        return [dict(r) for r in rows]


def get_user_by_id(user_id):
    if DB_TYPE.lower() == 'mysql':
        conn = get_mysql_conn()
        cur = conn.cursor(dictionary=True)
        cur.execute('SELECT id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status FROM users WHERE id = %s', (user_id,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        return row
    else:
        conn = get_sqlite_conn()
        cur = conn.cursor()
        cur.execute('SELECT id, email, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status FROM users WHERE id = ?', (user_id,))
        row = cur.fetchone()
        conn.close()
        return dict(row) if row is not None else None


app = Flask(__name__)
CORS(app)


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
    password_hash = row.get('password_hash')

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
        cur = conn.cursor(dictionary=True)
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


if __name__ == '__main__':
    port = int(os.getenv('FLASK_RUN_PORT', '5000'))
    app.run(host='0.0.0.0', port=port, debug=(os.getenv('FLASK_ENV') == 'development'))
