import os
import sqlite3
from werkzeug.security import generate_password_hash
from dotenv import load_dotenv

load_dotenv()

DB_TYPE = os.getenv('DB_TYPE', 'sqlite')

def init_sqlite(db_path='users.db'):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'User',
        department TEXT,
        staff_no TEXT,
        first_name TEXT,
        last_name TEXT,
        nickname TEXT,
        under_manager TEXT,
        last_login TEXT,
        status TEXT NOT NULL DEFAULT 'active'
    )
    ''')

    # Migration: ensure any missing columns are added for existing tables
    cur.execute("PRAGMA table_info('users')")
    existing = {row[1] for row in cur.fetchall()}  # name is at index 1
    needed = {
        'staff_no': "TEXT",
        'first_name': "TEXT",
        'last_name': "TEXT",
        'nickname': "TEXT",
        'under_manager': "TEXT",
        'last_login': "TEXT",
        'status': "TEXT DEFAULT 'active'"
    }
    for col, col_def in needed.items():
        if col not in existing:
            cur.execute(f'ALTER TABLE users ADD COLUMN {col} {col_def}')
    # Migrate any legacy `full_name` values into first_name/last_name (if present)
    if 'full_name' in existing:
        cur.execute("SELECT id, full_name FROM users WHERE full_name IS NOT NULL AND (first_name IS NULL OR last_name IS NULL)")
        rows = cur.fetchall()
        for r in rows:
            uid = r[0]
            fn = r[1] or ''
            parts = fn.split()
            first = parts[0] if parts else ''
            last = ' '.join(parts[1:]) if len(parts) > 1 else ''
            cur.execute('UPDATE users SET first_name = ?, last_name = ? WHERE id = ?', (first, last, uid))
        # attempt to drop the legacy column by recreating table without it
        try:
            cur.execute("PRAGMA foreign_keys=off")
            cur.execute("BEGIN TRANSACTION")
            # create temp table without full_name
            cur.execute('''
                CREATE TABLE IF NOT EXISTS users_new (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    email TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    role TEXT NOT NULL DEFAULT 'User',
                    department TEXT,
                    staff_no TEXT,
                    first_name TEXT,
                    last_name TEXT,
                    under_manager TEXT,
                    last_login TEXT,
                    status TEXT NOT NULL DEFAULT 'active'
                )
            ''')
            cur.execute('INSERT OR IGNORE INTO users_new (id, email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status) SELECT id, email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status FROM users')
            cur.execute('DROP TABLE users')
            cur.execute('ALTER TABLE users_new RENAME TO users')
            cur.execute('COMMIT')
        except Exception:
            cur.execute('ROLLBACK')
        finally:
            cur.execute("PRAGMA foreign_keys=on")
    try:
        cur.execute('INSERT INTO users (email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', (
            'admin@example.com',
            generate_password_hash('admin123'),
            'Admin',
            'IT',
            'STAFF001',
            'Administrator',
            '',
            '',
            None,
            None,
            'active'
        ))
        conn.commit()
        print('Inserted sample admin: admin@example.com / admin123')
    except Exception:
        print('Sample user already exists or insertion failed')
    finally:
        conn.close()


def init_mysql(host, port, user, password, db_name):
    import mysql.connector
    # connect without database to create it if missing
    conn = mysql.connector.connect(host=host, port=port, user=user, password=password)
    cur = conn.cursor()
    cur.execute(f"CREATE DATABASE IF NOT EXISTS {db_name}")
    conn.commit()
    conn.close()

    # connect to the database and create table
    conn = mysql.connector.connect(host=host, port=port, user=user, password=password, database=db_name)
    cur = conn.cursor()
    cur.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(100) NOT NULL DEFAULT 'User',
        department VARCHAR(255),
        staff_no VARCHAR(100),
        first_name VARCHAR(255),
        last_name VARCHAR(255),
        nickname VARCHAR(255),
        under_manager VARCHAR(255),
        last_login DATETIME,
        status VARCHAR(50) NOT NULL DEFAULT 'active'
    )
    ''')
    # Migration for MySQL: add missing columns if necessary
    cur.execute("SHOW COLUMNS FROM users")
    existing_cols = {row[0] for row in cur.fetchall()}
    needed_mysql = {
        'staff_no': 'VARCHAR(100) NULL',
        'first_name': 'VARCHAR(255) NULL',
        'last_name': 'VARCHAR(255) NULL',
        'nickname': 'VARCHAR(255) NULL',
        'under_manager': 'VARCHAR(255) NULL',
        'last_login': 'DATETIME NULL',
        'status': "VARCHAR(50) NOT NULL DEFAULT 'active'"
    }
    for col, col_def in needed_mysql.items():
        if col not in existing_cols:
            try:
                cur.execute(f'ALTER TABLE users ADD COLUMN {col} {col_def}')
            except Exception:
                pass
    # Migrate existing full_name into first_name/last_name for MySQL, then drop legacy column if possible
    if 'full_name' in existing_cols:
        try:
            cur.execute('SELECT id, full_name FROM users WHERE full_name IS NOT NULL AND (first_name IS NULL OR last_name IS NULL)')
            rows = cur.fetchall()
            for r in rows:
                uid = r[0]
                fn = r[1] or ''
                parts = fn.split()
                first = parts[0] if parts else ''
                last = ' '.join(parts[1:]) if len(parts) > 1 else ''
                cur.execute('UPDATE users SET first_name = %s, last_name = %s WHERE id = %s', (first, last, uid))
            try:
                cur.execute('ALTER TABLE users DROP COLUMN full_name')
            except Exception:
                pass
            conn.commit()
        except Exception:
            pass
    try:
        cur.execute('INSERT INTO users (email, password_hash, role, department, staff_no, first_name, last_name, nickname, under_manager, last_login, status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)', (
            'admin@example.com',
            generate_password_hash('admin123'),
            'Admin',
            'IT',
            'STAFF001',
            'Administrator',
            '',
            '',
            None,
            None,
            'active'
        ))
        conn.commit()
        print('Inserted sample admin: admin@example.com / admin123')
    except Exception:
        print('Sample user already exists or insertion failed')
    finally:
        cur.close()
        conn.close()


def init_db():
    if DB_TYPE.lower() == 'mysql':
        host = os.getenv('DB_HOST', '127.0.0.1')
        port = int(os.getenv('DB_PORT', '3306'))
        user = os.getenv('DB_USER', 'root')
        password = os.getenv('DB_PASS', '')
        db_name = os.getenv('DB_NAME', 'approval_db')
        init_mysql(host, port, user, password, db_name)
        print(f'MySQL database {db_name} ready at {host}:{port}')
    else:
        db_path = os.getenv('SQLITE_PATH', 'users.db')
        init_sqlite(db_path)
        print('SQLite database initialized at', db_path)


if __name__ == '__main__':
    init_db()
