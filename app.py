from flask import Flask, render_template, jsonify, send_from_directory, abort, safe_join, request, Response, send_file
import os
import zipfile
import io
import json

app = Flask(__name__)
LOG_DIR = os.environ.get("HONEYPOT_LOG_DIR", os.path.expanduser("~/honeypot_logs"))
USERNAME = os.environ.get("HONEYPOT_USER", "admin")
PASSWORD = os.environ.get("HONEYPOT_PASS", "honeypot")

# Ensure log directory exists
os.makedirs(LOG_DIR, exist_ok=True)

# --- Basic Auth Decorator ---
def check_auth(username, password):
    return username == USERNAME and password == PASSWORD

def authenticate():
    return Response(
        "Unauthorized access.\nPlease provide valid credentials.",
        401,
        {"WWW-Authenticate": 'Basic realm="Login Required"'}
    )

def requires_auth(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            return authenticate()
        return f(*args, **kwargs)
    return decorated

# --- Session Statistics Simulation ---
def get_session_statistics():
    """
    Example function to simulate session statistics.
    Replace this with real logic to gather stats from logs.
    """
    successful_logins = 10  # Replace with dynamic logic
    failed_logins = 5  # Replace with dynamic logic
    return successful_logins, failed_logins

# --- Routes ---

@app.route('/')
@requires_auth
def index():
    try:
        # Get the list of sessions (log files)
        sessions = sorted(
            [f for f in os.listdir(LOG_DIR) if f.endswith(".log")],
            reverse=True
        )
    except Exception as e:
        sessions = []
        print(f"Error loading sessions: {e}")
    return render_template("index.html", sessions=sessions)

@app.route('/logs/<path:filename>')
@requires_auth
def view_log(filename):
    file_path = safe_join(LOG_DIR, filename)
    if not os.path.isfile(file_path):
        abort(404)
    return send_from_directory(LOG_DIR, filename)

@app.route('/cast/<path:filename>')
@requires_auth
def view_cast(filename):
    file_path = safe_join(LOG_DIR, filename)
    if not os.path.isfile(file_path):
        abort(404)
    return send_from_directory(LOG_DIR, filename)

@app.route('/latest_logs')
@requires_auth
def latest_logs():
    # Get the latest log files (in reverse order)
    sessions = sorted(
        [f for f in os.listdir(LOG_DIR) if f.endswith(".log")],
        reverse=True
    )
    return jsonify({"logs": sessions})

@app.route('/session_data')
@requires_auth
def session_data():
    # Get the session statistics (e.g., successful and failed logins)
    successful_logins, failed_logins = get_session_statistics()

    # Return the session stats in JSON format
    return jsonify({
        "successfulLogins": successful_logins,
        "failedLogins": failed_logins
    })

@app.route('/download/all')
@requires_auth
def download_all_logs():
    mem_zip = io.BytesIO()
    with zipfile.ZipFile(mem_zip, "w", zipfile.ZIP_DEFLATED) as zipf:
        for filename in os.listdir(LOG_DIR):
            file_path = os.path.join(LOG_DIR, filename)
            if os.path.isfile(file_path):
                zipf.write(file_path, arcname=filename)
    mem_zip.seek(0)
    return send_file(mem_zip, mimetype='application/zip', download_name='honeypot_logs.zip', as_attachment=True)

if __name__ == '__main__':
    port = int(os.environ.get("HONEYPOT_PORT", 8080))
    print("="*50)
    print(" 🛡️ Honeypot Dashboard is running.")
    print(" 🔒 To change the login credentials:")
    print("    export HONEYPOT_USER=your_username")
    print("    export HONEYPOT_PASS=your_password")
    print(" 📂 Logs directory:", LOG_DIR)
    print(" 🌐 Access at: http://localhost:%d" % port)
    print("="*50)
    app.run(debug=False, host="0.0.0.0", port=port)
