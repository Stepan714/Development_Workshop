from flask import Flask, request, jsonify
import os

app = Flask(__name__)

log_file_path = "/app/logs/app.log"
port = os.getenv("APP_PORT", "8080")
welcome_msg = os.getenv("WELCOME_MESSAGE", "Welcome to the custom app")
log_level = os.getenv("LOG_LEVEL", "INFO")

@app.route('/')
def welcome():
    return welcome_msg

@app.route('/status', methods=['GET'])
def status():
    return jsonify({"status": "ok"}), 200

@app.route('/log', methods=['POST'])
def log_message():
    if request.method != 'POST':
        return 'Method not allowed', 405
    
    log_data = request.json
    try:
        with open(log_file_path, 'a') as log_file:
            log_file.write(log_data.get("message", "") + "\n")
        return jsonify({"status": "log created"}), 201
    except Exception as e:
        return str(e), 500

@app.route('/logs', methods=['GET'])
def get_logs():
    try:
        with open(log_file_path, 'r') as log_file:
            log_contents = log_file.read()
        return log_contents, 200
    except FileNotFoundError:
        return "", 200
    except Exception as e:
        return str(e), 500

if __name__ == '__main__':
    if not os.path.exists('/app/logs'):
        os.makedirs('/app/logs')
    app.run(host='0.0.0.0', port=int(port))
