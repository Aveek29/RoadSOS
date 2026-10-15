from flask_socketio import SocketIO

# Global SocketIO instance shared across blueprints and app runner
socketio = SocketIO(cors_allowed_origins="*")
