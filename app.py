from flask import Flask, render_template, send_from_directory
import os

app = Flask(__name__)
LOG_DIR = os.path.expanduser("~/honeypot_logs")

@app.route('/')
def index():
    sessions = sorted([f for f in os.listdir(LOG_DIR) if f.endswith(".log")], reverse=True)
    return render_template("index.html", sessions=sessions)

@app.route('/logs/<filename>')
def view_log(filename):
    return send_from_directory(LOG_DIR, filename)

@app.route('/cast/<filename>')
def view_cast(filename):
    return send_from_directory(LOG_DIR, filename)

if __name__ == '__main__':
    app.run(debug=True, port=8080)
