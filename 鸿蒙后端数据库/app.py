from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
import bcrypt
from datetime import datetime
import re
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app)

DATABASE_PATH = 'health_app.db'

def init_database():
    """初始化数据库"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT UNIQUE NOT NULL,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # 家庭成员关系表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS family_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            member_id INTEGER NOT NULL,
            relationship_name TEXT DEFAULT '家庭成员',
            added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            status INTEGER DEFAULT 1,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (member_id) REFERENCES users (id),
            UNIQUE(user_id, member_id)
        )
    ''')

    # 面对面加好友临时表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS friend_radar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            radar_code TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')

    # 在现有的users表创建语句后添加
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS health_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            record_date TEXT NOT NULL,
            steps INTEGER DEFAULT 0,
            steps_goal INTEGER DEFAULT 10000,
            distance REAL DEFAULT 0,
            calories_burned REAL DEFAULT 0,
            current_heart_rate INTEGER DEFAULT 0,
            resting_heart_rate INTEGER DEFAULT 0,
            min_heart_rate INTEGER DEFAULT 0,
            avg_heart_rate INTEGER DEFAULT 0,
            max_heart_rate INTEGER DEFAULT 0,
            current_blood_oxygen INTEGER DEFAULT 0,
            min_blood_oxygen INTEGER DEFAULT 0,
            avg_blood_oxygen INTEGER DEFAULT 0,
            max_blood_oxygen INTEGER DEFAULT 0,
            sleep_score INTEGER DEFAULT 0,
            sleep_duration INTEGER DEFAULT 0,
            sleep_start_time TEXT DEFAULT '',
            sleep_end_time TEXT DEFAULT '',
            deep_sleep_duration INTEGER DEFAULT 0,
            light_sleep_duration INTEGER DEFAULT 0,
            rem_sleep_duration INTEGER DEFAULT 0,
            awake_duration INTEGER DEFAULT 0,
            active_calories REAL DEFAULT 0,
            calories_goal REAL DEFAULT 8000,
            activity_calories REAL DEFAULT 0,
            basic_metabolism_calories REAL DEFAULT 0,
            current_mood INTEGER DEFAULT -1,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id),
            UNIQUE(user_id, record_date)
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS realtime_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            record_date TEXT NOT NULL,
            time_stamp TEXT NOT NULL,
            data_type TEXT NOT NULL,
            value REAL NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id),
            UNIQUE(user_id, record_date, time_stamp, data_type)
        )
    ''')

    # 在 init_database() 函数中添加以下表创建语句：

    # 用户积分表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            total_points INTEGER DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id),
            UNIQUE(user_id)
        )
    ''')

    # 积分记录表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS points_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            points INTEGER NOT NULL,
            source_type TEXT NOT NULL,
            source_data TEXT,
            record_date TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')

    # 步数记录表（专门用于步数和积分）
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS steps_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            steps INTEGER NOT NULL,
            points_earned INTEGER NOT NULL,
            record_date TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id),
            UNIQUE(user_id, record_date)
        )
    ''')
        
    conn.commit()
    conn.close()
    print(f"[{datetime.now()}] 数据库初始化完成")

def get_db_connection():
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def validate_phone(phone: str) -> bool:
    """验证手机号格式"""
    pattern = r'^1[3-9]\d{9}$'
    return re.match(pattern, phone) is not None

@app.route('/api/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        phone = data.get('phone', '').strip()
        username = data.get('username', '').strip()
        password = data.get('password', '').strip()
        
        print(f"[{datetime.now()}] 注册请求: 手机号={phone}, 用户名={username}")
        
        # 参数验证
        if not phone or not username or not password:
            return jsonify({
                'success': False,
                'message': '手机号、用户名和密码不能为空'
            }), 400
        
        if not validate_phone(phone):
            return jsonify({
                'success': False,
                'message': '手机号格式不正确'
            }), 400
        
        if len(username) < 2 or len(username) > 20:
            return jsonify({
                'success': False,
                'message': '用户名长度应在2-20个字符之间'
            }), 400
        
        if len(password) < 6:
            return jsonify({
                'success': False,
                'message': '密码长度不能少于6位'
            }), 400
        
        # 密码加密
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 检查手机号是否已存在
        existing_phone = cursor.execute(
            'SELECT id FROM users WHERE phone = ?', (phone,)
        ).fetchone()
        
        if existing_phone:
            conn.close()
            return jsonify({
                'success': False,
                'message': '该手机号已被注册'
            }), 400
        
        # 检查用户名是否已存在
        existing_username = cursor.execute(
            'SELECT id FROM users WHERE username = ?', (username,)
        ).fetchone()
        
        if existing_username:
            conn.close()
            return jsonify({
                'success': False,
                'message': '该用户名已被使用'
            }), 400
        
        # 插入新用户
        cursor.execute(
            'INSERT INTO users (phone, username, password_hash) VALUES (?, ?, ?)',
            (phone, username, password_hash)
        )
        
        user_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        print(f"[{datetime.now()}] 注册成功: ID={user_id}, 用户名={username}")
        
        return jsonify({
            'success': True,
            'message': '注册成功',
            'user_id': user_id,
            'username': username,
            'phone': phone
        })
        
    except Exception as e:
        print(f"[{datetime.now()}] 注册异常: {e}")
        return jsonify({
            'success': False,
            'message': f'注册失败: {str(e)}'
        }), 500
    
@app.route('/api/reset-password', methods=['POST'])
def reset_password():
    try:
        data = request.get_json()
        username = data.get('username', '').strip()
        new_password = data.get('new_password', '').strip()
        
        if not username or not new_password:
            return jsonify({
                'success': False,
                'message': '用户名和新密码不能为空'
            }), 400
        
        if len(new_password) < 6:
            return jsonify({
                'success': False,
                'message': '密码长度不能少于6位'
            }), 400
        
        new_password_hash = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        user = cursor.execute(
            'SELECT id FROM users WHERE username = ?', (username,)
        ).fetchone()
        
        if not user:
            conn.close()
            return jsonify({
                'success': False,
                'message': '用户名不存在'
            }), 404
        
        cursor.execute(
            'UPDATE users SET password_hash = ? WHERE username = ?',
            (new_password_hash, username)
        )
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': '密码重置成功'
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'重置密码失败: {str(e)}'
        }), 500

@app.route('/api/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        login_field = data.get('login_field', '').strip()
        password = data.get('password', '').strip()
        
        print(f"[{datetime.now()}] 登录请求: {login_field}")
        
        if not login_field or not password:
            return jsonify({
                'success': False,
                'message': '登录信息不能为空'
            }), 400
        
        conn = get_db_connection()
        
        # 判断是手机号还是用户名
        if validate_phone(login_field):
            user = conn.execute(
                'SELECT * FROM users WHERE phone = ?', (login_field,)
            ).fetchone()
        else:
            user = conn.execute(
                'SELECT * FROM users WHERE username = ?', (login_field,)
            ).fetchone()
        
        conn.close()
        
        if user and bcrypt.checkpw(password.encode('utf-8'), user['password_hash']):
            print(f"[{datetime.now()}] 登录成功: ID={user['id']}, 用户名={user['username']}")
            
            return jsonify({
                'success': True,
                'message': '登录成功',
                'user_id': user['id'],
                'username': user['username'],
                'phone': user['phone'],
                'avatar_path': ''  # 暂时为空，后续可添加头像功能
            })
        else:
            print(f"[{datetime.now()}] 登录失败: {login_field}")
            return jsonify({
                'success': False,
                'message': '手机号/用户名或密码错误'
            }), 401
            
    except Exception as e:
        print(f"[{datetime.now()}] 登录异常: {e}")
        return jsonify({
            'success': False,
            'message': f'登录失败: {str(e)}'
        }), 500

@app.route('/api/check-username', methods=['GET'])
def check_username():
    try:
        username = request.args.get('username', '').strip()
        
        if not username:
            return jsonify({'exists': False})
        
        conn = get_db_connection()
        existing_user = conn.execute(
            'SELECT id FROM users WHERE username = ?', (username,)
        ).fetchone()
        conn.close()
        
        return jsonify({
            'exists': existing_user is not None
        })
        
    except Exception as e:
        print(f"[{datetime.now()}] 检查用户名异常: {e}")
        return jsonify({'exists': False})

@app.route('/api/check-phone', methods=['GET'])
def check_phone():
    try:
        phone = request.args.get('phone', '').strip()
        
        if not phone:
            return jsonify({'exists': False})
        
        conn = get_db_connection()
        existing_user = conn.execute(
            'SELECT id FROM users WHERE phone = ?', (phone,)
        ).fetchone()
        conn.close()
        
        return jsonify({
            'exists': existing_user is not None
        })
        
    except Exception as e:
        print(f"[{datetime.now()}] 检查手机号异常: {e}")
        return jsonify({'exists': False})

@app.route('/api/health-check', methods=['GET'])
def health_check():
    return jsonify({
        'success': True,
        'message': '服务器运行正常',
        'timestamp': datetime.now().isoformat()
    })
@app.route('/api/health-data', methods=['POST'])
def save_health_data():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        record_date = data.get('record_date', datetime.now().strftime('%Y-%m-%d'))
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        update_fields = []
        values = []
        
        health_fields = [
        'steps', 'steps_goal', 'distance', 'calories_burned',
        'current_heart_rate', 'resting_heart_rate', 'min_heart_rate', 'avg_heart_rate', 'max_heart_rate',
        'current_blood_oxygen', 'min_blood_oxygen', 'avg_blood_oxygen', 'max_blood_oxygen',
        'sleep_score', 'sleep_duration', 'sleep_start_time', 'sleep_end_time',
        'deep_sleep_duration', 'light_sleep_duration', 'rem_sleep_duration', 'awake_duration',
        'active_calories', 'calories_goal', 'activity_calories', 'basic_metabolism_calories',
        'current_mood'
        ]
        
        for field in health_fields:
            if field in data:
                update_fields.append(f"{field} = ?")
                values.append(data[field])
        
        if update_fields:
            update_fields.append("updated_at = CURRENT_TIMESTAMP")
            sql = f"INSERT OR REPLACE INTO health_data (user_id, record_date, {', '.join([f for f in health_fields if f in data])}, updated_at) VALUES (?, ?, {', '.join(['?' for f in health_fields if f in data])}, CURRENT_TIMESTAMP)"
            cursor.execute(sql, [user_id, record_date] + [data[f] for f in health_fields if f in data])
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': '健康数据保存成功'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'保存失败: {str(e)}'}), 500

@app.route('/api/realtime-data', methods=['POST'])
def save_realtime_data():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        record_date = data.get('record_date', datetime.now().strftime('%Y-%m-%d'))
        time_stamp = data.get('time_stamp')
        data_type = data.get('data_type')
        value = data.get('value')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT OR REPLACE INTO realtime_data (user_id, record_date, time_stamp, data_type, value)
            VALUES (?, ?, ?, ?, ?)
        ''', (user_id, record_date, time_stamp, data_type, value))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': '实时数据保存成功'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'保存失败: {str(e)}'}), 500

@app.route('/api/health-data/<int:user_id>', methods=['GET'])
def get_health_data(user_id):
    try:
        days = int(request.args.get('days', 7))
        
        conn = get_db_connection()
        
        health_data = conn.execute('''
            SELECT * FROM health_data 
            WHERE user_id = ? 
            ORDER BY record_date DESC 
            LIMIT ?
        ''', (user_id, days)).fetchall()
        
        conn.close()
        
        result = []
        for row in health_data:
            result.append(dict(row))
        
        return jsonify({'success': True, 'data': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500

@app.route('/api/realtime-data/<int:user_id>', methods=['GET'])
def get_realtime_data(user_id):
    try:
        record_date = request.args.get('date', datetime.now().strftime('%Y-%m-%d'))
        data_type = request.args.get('type')
        days = int(request.args.get('days', 1))
        
        conn = get_db_connection()
        
        if days > 1:
            end_date = datetime.now().date()
            start_date = end_date - timedelta(days=days-1)
            query = 'SELECT * FROM realtime_data WHERE user_id = ? AND record_date BETWEEN ? AND ?'
            params = [user_id, start_date.isoformat(), end_date.isoformat()]
        else:
            query = 'SELECT * FROM realtime_data WHERE user_id = ? AND record_date = ?'
            params = [user_id, record_date]
        
        if data_type:
            query += ' AND data_type = ?'
            params.append(data_type)
        
        query += ' ORDER BY time_stamp DESC'
        
        realtime_data = conn.execute(query, params).fetchall()
        conn.close()
        
        result = []
        for row in realtime_data:
            result.append(dict(row))
        
        return jsonify({'success': True, 'data': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500

@app.route('/api/steps-ranking', methods=['GET'])
def get_steps_ranking():
    try:
        today = datetime.now().strftime('%Y-%m-%d')
        print(f"[{datetime.now()}] 获取步数排行榜请求，日期: {today}")
        
        conn = get_db_connection()
        
        # 添加调试：查看今日所有health_data记录，使用TRIM和字符串比较
        debug_data = conn.execute('''
            SELECT user_id, username, record_date, steps 
            FROM health_data h
            JOIN users u ON h.user_id = u.id
            WHERE TRIM(h.record_date, "'") = ?
        ''', (today,)).fetchall()
            
        print(f"[{datetime.now()}] 今日health_data记录:")
        for row in debug_data:
            print(f"  用户ID: {row['user_id']}, 用户名: {row['username']}, 日期: {row['record_date']}, 步数: {row['steps']}")
        
        # 使用LEFT JOIN确保显示所有用户
        ranking = conn.execute('''
            SELECT u.username, COALESCE(h.steps, 0) as steps
            FROM users u
            LEFT JOIN health_data h ON u.id = h.user_id AND TRIM(h.record_date, "'") = ?
            ORDER BY COALESCE(h.steps, 0) DESC, u.username ASC
            LIMIT 50
        ''', (today,)).fetchall()
        
        conn.close()
        
        result = []
        for i, row in enumerate(ranking):
            result.append({
                'rank': i + 1,
                'username': row['username'],
                'steps': row['steps']
            })
            print(f"[{datetime.now()}] 排行榜第{i+1}名: {row['username']}, {row['steps']}步")
        
        print(f"[{datetime.now()}] 排行榜查询完成，共{len(result)}名用户")
        
        return jsonify({'success': True, 'ranking': result})
        
    except Exception as e:
        print(f"[{datetime.now()}] 获取排行榜异常: {e}")
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500

@app.route('/api/overview/<int:user_id>', methods=['GET'])
def get_overview(user_id):
    try:
        today = datetime.now().strftime('%Y-%m-%d')
        print(f"[{datetime.now()}] 获取用户{user_id}的健康概览数据，日期: {today}")
        
        conn = get_db_connection()
        
        # 修复：添加current_mood字段和TRIM处理
        overview = conn.execute('''
            SELECT steps, avg_heart_rate, sleep_score, active_calories, current_blood_oxygen, current_mood
            FROM health_data 
            WHERE user_id = ? AND TRIM(record_date, "'") = ?
        ''', (user_id, today)).fetchone()
        
        conn.close()
        
        if overview:
            result = {
                'steps': overview['steps'] or 0,
                'avg_heart_rate': overview['avg_heart_rate'] or 0,
                'sleep_score': overview['sleep_score'] or 0,
                'active_calories': overview['active_calories'] or 0,
                'blood_oxygen': overview['current_blood_oxygen'] or 0,
                'current_mood': overview['current_mood'] or 5
            }
            print(f"[{datetime.now()}] 健康概览数据查询成功: {result}")
        else:
            result = {
                'steps': 0,
                'avg_heart_rate': 0,
                'sleep_score': 0,
                'active_calories': 0,
                'blood_oxygen': 0,
                'current_mood': -1
            }
            print(f"[{datetime.now()}] 用户{user_id}今日无健康数据，返回默认值")
        
        return jsonify({'success': True, 'data': result})
        
    except Exception as e:
        print(f"[{datetime.now()}] 获取健康概览异常: {e}")
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500

# 在现有接口后添加
@app.route('/api/weekly-steps/<int:user_id>', methods=['GET'])
def get_weekly_steps(user_id):
    try:
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=6)
        
        conn = get_db_connection()
        
        weekly_data = conn.execute('''
            SELECT record_date, steps FROM health_data 
            WHERE user_id = ? AND record_date BETWEEN ? AND ?
            ORDER BY record_date
        ''', (user_id, start_date.isoformat(), end_date.isoformat())).fetchall()
        
        conn.close()
        
        result = []
        for row in weekly_data:
            result.append({'date': row['record_date'], 'steps': row['steps'] or 0})
        
        return jsonify({'success': True, 'data': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500

@app.route('/api/weekly-sleep/<int:user_id>', methods=['GET'])
def get_weekly_sleep(user_id):
    try:
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=6)
        
        conn = get_db_connection()
        
        weekly_data = conn.execute('''
            SELECT record_date, sleep_score, sleep_duration FROM health_data 
            WHERE user_id = ? AND record_date BETWEEN ? AND ?
            ORDER BY record_date
        ''', (user_id, start_date.isoformat(), end_date.isoformat())).fetchall()
        
        conn.close()
        
        result = []
        for row in weekly_data:
            result.append({
                'date': row['record_date'], 
                'sleep_score': row['sleep_score'] or 0,
                'sleep_duration': row['sleep_duration'] or 0
            })
        
        return jsonify({'success': True, 'data': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500


@app.route('/api/search-users', methods=['GET'])
def search_users():
    try:
        phone = request.args.get('phone', '').strip()
        current_user_id = int(request.args.get('current_user_id', 0))
        
        if not phone or not current_user_id:
            return jsonify({'success': False, 'message': '参数缺失'}), 400
        
        conn = get_db_connection()
        user = conn.execute('''
            SELECT id, username, phone FROM users 
            WHERE phone = ? AND id != ?
        ''', (phone, current_user_id)).fetchone()
        
        conn.close()
        
        if user:
            return jsonify({
                'success': True,
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'phone': user['phone']
                }
            })
        else:
            return jsonify({'success': False, 'message': '用户不存在'})
            
    except Exception as e:
        return jsonify({'success': False, 'message': f'搜索失败: {str(e)}'}), 500

@app.route('/api/add-family-member', methods=['POST'])
def add_family_member():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        member_id = data.get('member_id')
        relationship_name = data.get('relationship_name', '家庭成员')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 双向添加家庭成员关系
        cursor.execute('''
            INSERT OR IGNORE INTO family_members (user_id, member_id, relationship_name)
            VALUES (?, ?, ?)
        ''', (user_id, member_id, relationship_name))
        
        cursor.execute('''
            INSERT OR IGNORE INTO family_members (user_id, member_id, relationship_name)
            VALUES (?, ?, ?)
        ''', (member_id, user_id, relationship_name))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': '添加家庭成员成功'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'添加失败: {str(e)}'}), 500

@app.route('/api/steps-record', methods=['POST'])
def save_steps_record():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        steps = data.get('steps')
        record_date = data.get('record_date', datetime.now().strftime('%Y-%m-%d'))
        
        print(f"[{datetime.now()}] 保存步数记录: 用户{user_id}, 步数{steps}, 日期{record_date}")
        
        # 计算积分 (每500步=1积分)
        points_earned = int(steps // 500)
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 检查今日是否已有记录
        existing = cursor.execute('''
            SELECT steps, points_earned FROM steps_records 
            WHERE user_id = ? AND record_date = ?
        ''', (user_id, record_date)).fetchone()
        
        if existing:
            # 更新现有记录
            old_points = existing['points_earned']
            cursor.execute('''
                UPDATE steps_records 
                SET steps = ?, points_earned = ? 
                WHERE user_id = ? AND record_date = ?
            ''', (steps, points_earned, user_id, record_date))
            
            # 更新积分差额
            points_diff = points_earned - old_points
        else:
            # 创建新记录
            cursor.execute('''
                INSERT INTO steps_records (user_id, steps, points_earned, record_date)
                VALUES (?, ?, ?, ?)
            ''', (user_id, steps, points_earned, record_date))
            points_diff = points_earned
        
        # 更新用户总积分
        cursor.execute('''
            INSERT OR REPLACE INTO user_points (user_id, total_points, updated_at)
            VALUES (?, COALESCE((SELECT total_points FROM user_points WHERE user_id = ?), 0) + ?, CURRENT_TIMESTAMP)
        ''', (user_id, user_id, points_diff))
        
        # 记录积分历史
        if points_diff != 0:
            cursor.execute('''
                INSERT INTO points_history (user_id, points, source_type, source_data, record_date)
                VALUES (?, ?, 'steps', ?, ?)
            ''', (user_id, points_diff, f'步数: {steps}', record_date))
        
        # 同时更新health_data表的步数
        cursor.execute('''
            INSERT OR REPLACE INTO health_data (user_id, record_date, steps, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ''', (user_id, record_date, steps))
        
        # 获取总积分
        total_points_row = cursor.execute('''
            SELECT total_points FROM user_points WHERE user_id = ?
        ''', (user_id,)).fetchone()
        total_points = total_points_row['total_points'] if total_points_row else 0
        
        conn.commit()
        conn.close()
        
        print(f"[{datetime.now()}] 步数保存成功: 获得积分{points_earned}, 总积分{total_points}")
        
        return jsonify({
            'success': True,
            'message': '步数保存成功',
            'points_earned': points_earned,
            'total_points': total_points
        })
        
    except Exception as e:
        print(f"[{datetime.now()}] 保存步数异常: {e}")
        return jsonify({'success': False, 'message': f'保存失败: {str(e)}'}), 500

@app.route('/api/steps-history/<int:user_id>', methods=['GET'])
def get_steps_history(user_id):
    try:
        days = int(request.args.get('days', 30))
        
        conn = get_db_connection()
        
        records = conn.execute('''
            SELECT * FROM steps_records 
            WHERE user_id = ? 
            ORDER BY record_date DESC 
            LIMIT ?
        ''', (user_id, days)).fetchall()
        
        conn.close()
        
        result = []
        for row in records:
            result.append({
                'id': row['id'],
                'steps': row['steps'],
                'points_earned': row['points_earned'],
                'record_date': row['record_date'],
                'created_at': row['created_at']
            })
        
        return jsonify({'success': True, 'records': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500

@app.route('/api/user-points/<int:user_id>', methods=['GET'])
def get_user_points(user_id):
    try:
        conn = get_db_connection()
        
        points_info = conn.execute('''
            SELECT * FROM user_points WHERE user_id = ?
        ''', (user_id,)).fetchone()
        
        conn.close()
        
        if points_info:
            result = {
                'user_id': points_info['user_id'],
                'total_points': points_info['total_points'],
                'updated_at': points_info['updated_at']
            }
        else:
            result = {
                'user_id': user_id,
                'total_points': 0,
                'updated_at': datetime.now().isoformat()
            }
        
        return jsonify({'success': True, 'data': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500


@app.route('/api/radar-friends', methods=['POST'])
def create_radar_session():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        radar_code = data.get('radar_code')
        
        expires_at = (datetime.now() + timedelta(minutes=5)).isoformat()
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 清理过期记录
        cursor.execute('DELETE FROM friend_radar WHERE expires_at < ?', (datetime.now().isoformat(),))
        
        # 检查是否有匹配的雷达码
        existing = cursor.execute('''
            SELECT user_id FROM friend_radar 
            WHERE radar_code = ? AND user_id != ?
        ''', (radar_code, user_id)).fetchone()
        
        if existing:
            # 找到匹配，添加为家庭成员
            other_user_id = existing['user_id']
            
            cursor.execute('''
                INSERT OR IGNORE INTO family_members (user_id, member_id)
                VALUES (?, ?), (?, ?)
            ''', (user_id, other_user_id, other_user_id, user_id))
            
            # 清理雷达记录
            cursor.execute('DELETE FROM friend_radar WHERE radar_code = ?', (radar_code,))
            
            conn.commit()
            conn.close()
            
            return jsonify({'success': True, 'message': '添加家庭成员成功', 'matched': True})
        else:
            # 没有匹配，创建新记录
            cursor.execute('''
                INSERT OR REPLACE INTO friend_radar (user_id, radar_code, expires_at)
                VALUES (?, ?, ?)
            ''', (user_id, radar_code, expires_at))
            
            conn.commit()
            conn.close()
            
            return jsonify({'success': True, 'message': '等待匹配中...', 'matched': False})
            
    except Exception as e:
        return jsonify({'success': False, 'message': f'操作失败: {str(e)}'}), 500

@app.route('/api/family-members/<int:user_id>', methods=['GET'])
def get_family_members(user_id):
    try:
        conn = get_db_connection()
        
        members = conn.execute('''
            SELECT u.id, u.username, u.phone, fm.relationship_name, fm.added_at
            FROM family_members fm
            JOIN users u ON fm.member_id = u.id
            WHERE fm.user_id = ? AND fm.status = 1
            ORDER BY fm.added_at DESC
        ''', (user_id,)).fetchall()
        
        conn.close()
        
        result = []
        for member in members:
            result.append({
                'id': member['id'],
                'username': member['username'],
                'phone': member['phone'],
                'relationship_name': member['relationship_name'],
                'added_at': member['added_at']
            })
        
        return jsonify({'success': True, 'members': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500

@app.route('/api/weekly-calories/<int:user_id>', methods=['GET'])
def get_weekly_calories(user_id):
    try:
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=6)
        
        conn = get_db_connection()
        
        weekly_data = conn.execute('''
            SELECT record_date, active_calories FROM health_data 
            WHERE user_id = ? AND record_date BETWEEN ? AND ?
            ORDER BY record_date
        ''', (user_id, start_date.isoformat(), end_date.isoformat())).fetchall()
        
        conn.close()
        
        result = []
        for row in weekly_data:
            result.append({
                'date': row['record_date'], 
                'calories': row['active_calories'] or 0
            })
        
        return jsonify({'success': True, 'data': result})
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'获取失败: {str(e)}'}), 500



if __name__ == '__main__':
    init_database()
    print("=" * 50)
    print("🚀 用户注册登录后端服务")
    print(f"📊 数据库: SQLite ({DATABASE_PATH})")
    print(f"🌐 服务地址: http://localhost:5000")
    print(f"👤 开发用户: gadz2021")
    print(f"📅 启动时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=True)