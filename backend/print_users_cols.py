import sqlite3, os
p = os.path.join(os.path.dirname(__file__), 'users.db')
con = sqlite3.connect(p)
cur = con.cursor()
cur.execute("PRAGMA table_info('users')")
cols = cur.fetchall()
print('columns:', cols)
cur.execute("SELECT * FROM users LIMIT 1")
try:
    r = cur.fetchone()
    print('sample row:', r)
except Exception as e:
    print('select error', e)
con.close()
