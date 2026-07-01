import socket
import json
import os
import sys

# Define path to the QGIS script to execute
script_path = r"c:\Users\12907\Desktop\2025-2026大三下学期\数据库原理及应用\数据库期末作业\scripts\generate_noise_map.py"

if not os.path.exists(script_path):
    print(f"Error: Script file not found: {script_path}")
    sys.exit(1)

with open(script_path, 'r', encoding='utf-8') as f:
    code = f.read()

# Connect to the QGIS MCP socket server
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    print("Connecting to QGIS MCP server on localhost:9876...")
    s.connect(('localhost', 9876))
    print("Connected successfully!")
    
    # Create the execute_code command
    cmd = {
        "type": "execute_code",
        "params": {
            "code": code
        }
    }
    
    print("Sending map generation script to QGIS...")
    s.sendall(json.dumps(cmd).encode('utf-8'))
    print("Script sent. Waiting for execution results from QGIS...")
    
    # Receive response
    response_data = b''
    while True:
        chunk = s.recv(8192)
        if not chunk:
            break
        response_data += chunk
        
        # Try to parse as JSON to see if complete
        try:
            res = json.loads(response_data.decode('utf-8'))
            break
        except json.JSONDecodeError:
            continue
            
    result = json.loads(response_data.decode('utf-8'))
    
    print("\n--- Execution Result ---")
    if result.get("status") == "success":
        exec_res = result.get("result", {})
        if exec_res.get("executed"):
            print("Status: EXECUTED SUCCESSFUL")
            stdout = exec_res.get("stdout", "").strip()
            stderr = exec_res.get("stderr", "").strip()
            if stdout:
                print("\nQGIS Python Output:")
                print(stdout)
            if stderr:
                print("\nQGIS Python Warnings/Errors:")
                print(stderr)
        else:
            print("Status: EXECUTION FAILED")
            print("Error:", exec_res.get("error"))
            print("Traceback:")
            print(exec_res.get("traceback"))
    else:
        print("Status: SERVER ERROR")
        print("Message:", result.get("message"))
        
except Exception as e:
    print("\nConnection or Communication Error:", e)
    print("If QGIS is open, please try resetting the QGIS MCP server inside QGIS:")
    print("  Go to menu: Plugins -> QGIS MCP -> QGIS MCP")
    print("  Click 'Stop Server', then click 'Start Server' to reset the port 9876 listener.")
finally:
    s.close()
