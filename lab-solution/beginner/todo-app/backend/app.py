#!/usr/bin/env python3
"""
Todo Application Backend API
A simple Flask REST API for managing todos with PostgreSQL backend
"""

import os
import logging
import time
from datetime import datetime
from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
import psycopg2.extras
import redis
from werkzeug.exceptions import BadRequest, NotFound

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration from environment variables
class Config:
    # Database configuration
    DB_HOST = os.getenv('DB_HOST', 'postgres-service')
    DB_PORT = os.getenv('DB_PORT', '5432')
    DB_NAME = os.getenv('DB_NAME', 'todoapp')
    DB_USER = os.getenv('DB_USER', 'todouser')
    DB_PASSWORD = os.getenv('DB_PASSWORD', 'todopass')
    
    # Redis configuration
    REDIS_HOST = os.getenv('REDIS_HOST', 'redis-service')
    REDIS_PORT = os.getenv('REDIS_PORT', '6379')
    
    # App configuration
    DEBUG = os.getenv('DEBUG', 'false').lower() == 'true'
    PORT = int(os.getenv('PORT', '5000'))

config = Config()

# Database connection
def get_db_connection():
    """Get a database connection with retry logic"""
    try:
        conn = psycopg2.connect(
            host=config.DB_HOST,
            port=config.DB_PORT,
            database=config.DB_NAME,
            user=config.DB_USER,
            password=config.DB_PASSWORD,
            connect_timeout=10
        )
        return conn
    except psycopg2.Error as e:
        logger.error(f"Database connection failed: {e}")
        raise

# Redis connection
def get_redis_connection():
    """Get a Redis connection"""
    try:
        r = redis.Redis(
            host=config.REDIS_HOST,
            port=config.REDIS_PORT,
            decode_responses=True,
            socket_timeout=5
        )
        r.ping()  # Test connection
        return r
    except redis.RedisError as e:
        logger.warning(f"Redis connection failed: {e}")
        return None

# Initialize database
def init_db():
    """Initialize the database with required tables"""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Create todos table
            cur.execute('''
                CREATE TABLE IF NOT EXISTS todos (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    description TEXT,
                    completed BOOLEAN DEFAULT FALSE,
                    priority VARCHAR(10) DEFAULT 'medium',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Create index on completed status
            cur.execute('''
                CREATE INDEX IF NOT EXISTS idx_todos_completed 
                ON todos(completed)
            ''')
            
            # Insert sample data if table is empty
            cur.execute('SELECT COUNT(*) FROM todos')
            if cur.fetchone()[0] == 0:
                sample_todos = [
                    ('Learn Kubernetes', 'Complete the hands-on workshop', False, 'high'),
                    ('Deploy StatefulSet', 'Configure PostgreSQL with persistent storage', False, 'high'),
                    ('Implement RBAC', 'Set up service accounts and role bindings', False, 'medium'),
                    ('Configure Monitoring', 'Add Prometheus metrics to the application', False, 'medium'),
                    ('Write Documentation', 'Document the deployment process', False, 'low'),
                ]
                
                cur.executemany('''
                    INSERT INTO todos (title, description, completed, priority)
                    VALUES (%s, %s, %s, %s)
                ''', sample_todos)
                logger.info("Inserted sample todos")
            
        conn.commit()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()

# Health check endpoints
@app.route('/health')
def health_check():
    """Basic health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })

@app.route('/health/ready')
def readiness_check():
    """Readiness probe - check database connectivity"""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute('SELECT 1')
        conn.close()
        
        return jsonify({
            'status': 'ready',
            'database': 'connected',
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return jsonify({
            'status': 'not ready',
            'database': 'disconnected',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503

@app.route('/health/live')
def liveness_check():
    """Liveness probe - basic application health"""
    return jsonify({
        'status': 'alive',
        'timestamp': datetime.utcnow().isoformat()
    })

# API endpoints
@app.route('/api/todos', methods=['GET'])
def get_todos():
    """Get all todos with optional filtering"""
    try:
        # Check cache first
        redis_client = get_redis_connection()
        cache_key = 'todos:all'
        
        if redis_client:
            cached_todos = redis_client.get(cache_key)
            if cached_todos:
                logger.info("Returning cached todos")
                import json
                return jsonify(json.loads(cached_todos))
        
        # Get from database
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Optional filtering
            completed = request.args.get('completed')
            priority = request.args.get('priority')
            
            query = 'SELECT * FROM todos WHERE 1=1'
            params = []
            
            if completed is not None:
                query += ' AND completed = %s'
                params.append(completed.lower() == 'true')
            
            if priority:
                query += ' AND priority = %s'
                params.append(priority)
            
            query += ' ORDER BY created_at DESC'
            
            cur.execute(query, params)
            todos = cur.fetchall()
        
        conn.close()
        
        # Convert to list of dicts for JSON serialization
        todos_list = [dict(todo) for todo in todos]
        
        # Cache the result
        if redis_client:
            import json
            redis_client.setex(cache_key, 60, json.dumps(todos_list, default=str))
        
        return jsonify(todos_list)
        
    except Exception as e:
        logger.error(f"Failed to get todos: {e}")
        return jsonify({'error': 'Failed to retrieve todos'}), 500

@app.route('/api/todos', methods=['POST'])
def create_todo():
    """Create a new todo"""
    try:
        data = request.get_json()
        
        if not data or 'title' not in data:
            raise BadRequest('Title is required')
        
        title = data['title']
        description = data.get('description', '')
        priority = data.get('priority', 'medium')
        
        if priority not in ['low', 'medium', 'high']:
            priority = 'medium'
        
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute('''
                INSERT INTO todos (title, description, priority)
                VALUES (%s, %s, %s)
                RETURNING *
            ''', (title, description, priority))
            new_todo = cur.fetchone()
        
        conn.commit()
        conn.close()
        
        # Invalidate cache
        redis_client = get_redis_connection()
        if redis_client:
            redis_client.delete('todos:all')
        
        logger.info(f"Created new todo: {title}")
        return jsonify(dict(new_todo)), 201
        
    except BadRequest as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logger.error(f"Failed to create todo: {e}")
        return jsonify({'error': 'Failed to create todo'}), 500

@app.route('/api/todos/<int:todo_id>', methods=['GET'])
def get_todo(todo_id):
    """Get a specific todo by ID"""
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute('SELECT * FROM todos WHERE id = %s', (todo_id,))
            todo = cur.fetchone()
        
        conn.close()
        
        if not todo:
            raise NotFound('Todo not found')
        
        return jsonify(dict(todo))
        
    except NotFound as e:
        return jsonify({'error': str(e)}), 404
    except Exception as e:
        logger.error(f"Failed to get todo {todo_id}: {e}")
        return jsonify({'error': 'Failed to retrieve todo'}), 500

@app.route('/api/todos/<int:todo_id>', methods=['PUT'])
def update_todo(todo_id):
    """Update a specific todo"""
    try:
        data = request.get_json()
        
        if not data:
            raise BadRequest('No data provided')
        
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Check if todo exists
            cur.execute('SELECT id FROM todos WHERE id = %s', (todo_id,))
            if not cur.fetchone():
                raise NotFound('Todo not found')
            
            # Build update query dynamically
            update_fields = []
            params = []
            
            if 'title' in data:
                update_fields.append('title = %s')
                params.append(data['title'])
            
            if 'description' in data:
                update_fields.append('description = %s')
                params.append(data['description'])
            
            if 'completed' in data:
                update_fields.append('completed = %s')
                params.append(data['completed'])
            
            if 'priority' in data and data['priority'] in ['low', 'medium', 'high']:
                update_fields.append('priority = %s')
                params.append(data['priority'])
            
            if not update_fields:
                raise BadRequest('No valid fields to update')
            
            update_fields.append('updated_at = CURRENT_TIMESTAMP')
            params.append(todo_id)
            
            query = f'''
                UPDATE todos 
                SET {', '.join(update_fields)}
                WHERE id = %s
                RETURNING *
            '''
            
            cur.execute(query, params)
            updated_todo = cur.fetchone()
        
        conn.commit()
        conn.close()
        
        # Invalidate cache
        redis_client = get_redis_connection()
        if redis_client:
            redis_client.delete('todos:all')
        
        logger.info(f"Updated todo {todo_id}")
        return jsonify(dict(updated_todo))
        
    except (BadRequest, NotFound) as e:
        return jsonify({'error': str(e)}), 400 if isinstance(e, BadRequest) else 404
    except Exception as e:
        logger.error(f"Failed to update todo {todo_id}: {e}")
        return jsonify({'error': 'Failed to update todo'}), 500

@app.route('/api/todos/<int:todo_id>', methods=['DELETE'])
def delete_todo(todo_id):
    """Delete a specific todo"""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute('DELETE FROM todos WHERE id = %s RETURNING id', (todo_id,))
            deleted_id = cur.fetchone()
        
        conn.commit()
        conn.close()
        
        if not deleted_id:
            raise NotFound('Todo not found')
        
        # Invalidate cache
        redis_client = get_redis_connection()
        if redis_client:
            redis_client.delete('todos:all')
        
        logger.info(f"Deleted todo {todo_id}")
        return jsonify({'message': 'Todo deleted successfully'})
        
    except NotFound as e:
        return jsonify({'error': str(e)}), 404
    except Exception as e:
        logger.error(f"Failed to delete todo {todo_id}: {e}")
        return jsonify({'error': 'Failed to delete todo'}), 500

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get todo statistics"""
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute('''
                SELECT 
                    COUNT(*) as total,
                    COUNT(CASE WHEN completed = true THEN 1 END) as completed,
                    COUNT(CASE WHEN completed = false THEN 1 END) as pending,
                    COUNT(CASE WHEN priority = 'high' THEN 1 END) as high_priority,
                    COUNT(CASE WHEN priority = 'medium' THEN 1 END) as medium_priority,
                    COUNT(CASE WHEN priority = 'low' THEN 1 END) as low_priority
                FROM todos
            ''')
            stats = cur.fetchone()
        
        conn.close()
        return jsonify(dict(stats))
        
    except Exception as e:
        logger.error(f"Failed to get stats: {e}")
        return jsonify({'error': 'Failed to retrieve statistics'}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

def _init_db_with_retry(attempts=5, delay=3):
    for attempt in range(1, attempts + 1):
        try:
            init_db()
            return
        except Exception as e:
            logger.warning(f"Database not ready yet (attempt {attempt}/{attempts}): {e}")
            if attempt < attempts:
                time.sleep(delay)
    logger.error("Database initialization did not succeed after retries")

_init_db_with_retry()

if __name__ == '__main__':
    # Start the Flask application
    logger.info(f"Starting Todo API server on port {config.PORT}")
    app.run(
        host='0.0.0.0',
        port=config.PORT,
        debug=config.DEBUG
    )