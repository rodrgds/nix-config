#!/usr/bin/env python3
"""
CS2 Arduino Bridge
Reads K/D score from /tmp/cs2_score and sends to Arduino via serial
"""

import serial
import time
import os
import sys
import glob

SERIAL_PORT = "/dev/ttyUSB0"  # or /dev/ttyACM0, check with `ls /dev/tty*`
BAUD_RATE = 9600
SCORE_FILE = "/tmp/cs2_score"


def find_arduino_port():
    """Auto-detect Arduino port"""
    ports = glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*')
    return ports[0] if ports else None


def main():
    port = find_arduino_port() or SERIAL_PORT
    
    try:
        ser = serial.Serial(port, BAUD_RATE, timeout=1)
        time.sleep(2)  # Wait for Arduino reset
        print(f"Connected to Arduino on {port}", file=sys.stderr)
    except Exception as e:
        print(f"Failed to connect: {e}", file=sys.stderr)
        return
    
    last_content = None
    
    while True:
        try:
            with open(SCORE_FILE, 'r') as f:
                content = f.readline().strip()
            
            # Only send if changed
            if content != last_content:
                ser.write(f"{content}\n".encode('utf-8'))
                last_content = content
                print(f"Sent: {content}", file=sys.stderr)
            
            time.sleep(1)  # Poll every second
            
        except FileNotFoundError:
            time.sleep(1)
        except KeyboardInterrupt:
            break
    
    ser.close()


if __name__ == "__main__":
    main()
