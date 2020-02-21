from flask import Flask
import socket
app = Flask(__name__)

@app.route("/")
def do_work():
    return "Hello from the worker service!"

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=80)
