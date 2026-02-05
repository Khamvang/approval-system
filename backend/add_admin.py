from werkzeug.security import generate_password_hash
import sqlite3
import os

p = os.path.join(os.path.dirname(__file__), 'users.db')
con = sqlite3.connect(p)
cur = con.cursor()

# Ensure expected columns exist (role, department)
cur.execute("PRAGMA table_info('users')")
cols = {r[1] for r in cur.fetchall()}
if 'role' not in cols:
    try:
        cur.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'User'")
    except Exception:
        pass
if 'department' not in cols:
    try:
        cur.execute("ALTER TABLE users ADD COLUMN department TEXT")
    except Exception:
        pass
con.commit()

cur.execute('SELECT id FROM users WHERE email=?', ('admin@example.com',))
if cur.fetchone():
    print('admin already exists')
else:
    cur.execute('INSERT INTO users (email,password_hash,role,department,staff_no,first_name,last_name,nickname,under_manager,last_login,status) VALUES (?,?,?,?,?,?,?,?,?,?,?)', (
        'admin@example.com', generate_password_hash('admin123'), 'Admin', 'IT', 'STAFF_ADMIN', 'Administrator', '', '', None, None, 'active'
    ))
    con.commit()
    print('Inserted admin@example.com')
con.close()
