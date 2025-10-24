from flask import Flask, render_template, request, jsonify, Response
from flask_cors import CORS
import cv2
import mediapipe as mp
import json
import os
import base64
import numpy as np
from slouching_detector import SlouchingDetector
import threading
import time

app = Flask(__name__)
CORS(app)

# Global variables for posture monitoring
detector = SlouchingDetector()
monitoring_active = False
current_posture_status = "No monitoring"
reference_saved = False

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/capture_reference', methods=['POST'])
def capture_reference():
    """Capture reference posture from uploaded image"""
    global detector, reference_saved
    
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image provided'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'error': 'No image selected'}), 400
        
        # Read and process the image
        image_data = file.read()
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Process with MediaPipe
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = detector.pose.process(image_rgb)
        
        if results.pose_landmarks:
            landmarks = results.pose_landmarks.landmark
            
            # Extract shoulder coordinates
            left_shoulder_y = landmarks[detector.mp_pose.PoseLandmark.LEFT_SHOULDER.value].y
            right_shoulder_y = landmarks[detector.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].y
            left_shoulder_z = landmarks[detector.mp_pose.PoseLandmark.LEFT_SHOULDER.value].z
            right_shoulder_z = landmarks[detector.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].z
            
            # Save reference coordinates
            detector.reference_coords = (left_shoulder_y, right_shoulder_y, left_shoulder_z, right_shoulder_z)
            if detector.save_reference_to_file():
                reference_saved = True
            else:
                return jsonify({'error': 'Failed to save reference coordinates'}), 500
            
            # Draw landmarks on image for visualization
            annotated_image = image.copy()
            detector.mp_drawing.draw_landmarks(
                annotated_image, results.pose_landmarks, detector.mp_pose.POSE_CONNECTIONS)
            
            # Encode image for response
            _, buffer = cv2.imencode('.jpg', annotated_image)
            image_base64 = base64.b64encode(buffer).decode('utf-8')
            
            return jsonify({
                'success': True,
                'message': 'Reference posture captured successfully',
                'image': image_base64,
                'coordinates': {
                    'left_shoulder_y': left_shoulder_y,
                    'right_shoulder_y': right_shoulder_y,
                    'left_shoulder_z': left_shoulder_z,
                    'right_shoulder_z': right_shoulder_z
                }
            })
        else:
            return jsonify({'error': 'No pose detected in image. Please ensure you are visible in the frame.'}), 400
            
    except Exception as e:
        return jsonify({'error': f'Error processing image: {str(e)}'}), 500

@app.route('/start_monitoring', methods=['POST'])
def start_monitoring():
    """Start posture monitoring"""
    global monitoring_active, detector, reference_saved
    
    # Check if reference coordinates exist
    if not os.path.exists('reference_coords.json'):
        return jsonify({'error': 'No reference posture saved. Please capture reference first.'}), 400
    
    # Try to load reference coordinates
    if not detector.load_reference_from_file():
        return jsonify({'error': 'Failed to load reference coordinates'}), 400
    
    # Check if reference coordinates are valid
    if detector.reference_coords is None:
        return jsonify({'error': 'Invalid reference coordinates'}), 400
    
    # Stop any existing monitoring
    if monitoring_active:
        monitoring_active = False
        time.sleep(0.5)  # Give time for previous monitoring to stop
    
    monitoring_active = True
    reference_saved = True
    
    # Start monitoring in a separate thread
    monitoring_thread = threading.Thread(target=monitor_posture)
    monitoring_thread.daemon = True
    monitoring_thread.start()
    
    return jsonify({'success': True, 'message': 'Posture monitoring started'})

@app.route('/stop_monitoring', methods=['POST'])
def stop_monitoring():
    """Stop posture monitoring"""
    global monitoring_active
    monitoring_active = False
    return jsonify({'success': True, 'message': 'Posture monitoring stopped'})

@app.route('/get_status', methods=['GET'])
def get_status():
    """Get current posture status"""
    global current_posture_status, monitoring_active, reference_saved, detector
    
    # Check if reference file exists
    reference_file_exists = os.path.exists('reference_coords.json')
    
    return jsonify({
        'status': current_posture_status,
        'monitoring_active': monitoring_active,
        'reference_saved': reference_saved,
        'reference_file_exists': reference_file_exists,
        'reference_coords': detector.reference_coords if detector.reference_coords else None
    })

@app.route('/debug', methods=['GET'])
def debug():
    """Debug endpoint to check application state"""
    global current_posture_status, monitoring_active, reference_saved, detector
    
    return jsonify({
        'status': current_posture_status,
        'monitoring_active': monitoring_active,
        'reference_saved': reference_saved,
        'reference_file_exists': os.path.exists('reference_coords.json'),
        'reference_coords': detector.reference_coords,
        'working_directory': os.getcwd(),
        'files_in_directory': os.listdir('.')
    })

def monitor_posture():
    """Background posture monitoring function"""
    global monitoring_active, current_posture_status, detector
    
    print("Starting posture monitoring...")
    
    # Check if reference coordinates are available
    if detector.reference_coords is None:
        current_posture_status = "Error: No reference coordinates"
        print("Error: No reference coordinates available")
        return
    
    cap = cv2.VideoCapture(0)
    tolerance = 0.05
    
    if not cap.isOpened():
        current_posture_status = "Error: Cannot access camera"
        print("Error: Cannot access camera")
        return
    
    ref_left_shoulder_y, ref_right_shoulder_y, ref_left_shoulder_z, ref_right_shoulder_z = detector.reference_coords
    print(f"Reference coordinates loaded: {detector.reference_coords}")
    
    frame_count = 0
    while monitoring_active and cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            print("Failed to read frame from camera")
            break
        
        frame_count += 1
        
        try:
            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = detector.pose.process(image_rgb)
            
            if results.pose_landmarks:
                landmarks = results.pose_landmarks.landmark
                
                current_left_shoulder_y = landmarks[detector.mp_pose.PoseLandmark.LEFT_SHOULDER.value].y
                current_right_shoulder_y = landmarks[detector.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].y
                current_left_shoulder_z = landmarks[detector.mp_pose.PoseLandmark.LEFT_SHOULDER.value].z
                current_right_shoulder_z = landmarks[detector.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].z
                
                # Apply adjustment based on z-coordinate
                adjusted_left_shoulder_y = detector.slight_adjustment_y_based_on_z(
                    current_left_shoulder_y, current_left_shoulder_z, ref_left_shoulder_y, ref_left_shoulder_z)
                adjusted_right_shoulder_y = detector.slight_adjustment_y_based_on_z(
                    current_right_shoulder_y, current_right_shoulder_z, ref_right_shoulder_y, ref_right_shoulder_z)
                
                # Check if slouching
                is_slouching = (adjusted_left_shoulder_y > ref_left_shoulder_y + tolerance or
                               adjusted_right_shoulder_y > ref_right_shoulder_y + tolerance)
                
                current_posture_status = "Slouching detected!" if is_slouching else "Good posture"
                
                # Log every 30 frames (about once per second)
                if frame_count % 30 == 0:
                    print(f"Frame {frame_count}: {current_posture_status}")
            else:
                current_posture_status = "No pose detected"
                if frame_count % 30 == 0:
                    print(f"Frame {frame_count}: No pose detected")
                
        except Exception as e:
            current_posture_status = f"Error: {str(e)}"
            print(f"Error in monitoring: {str(e)}")
            break
        
        time.sleep(0.1)  # Small delay to prevent excessive CPU usage
    
    print("Posture monitoring stopped")
    cap.release()

if __name__ == '__main__':
    # Create uploads directory if it doesn't exist
    os.makedirs('uploads', exist_ok=True)
    os.makedirs('static', exist_ok=True)
    os.makedirs('templates', exist_ok=True)
    
    app.run(debug=True, host='0.0.0.0', port=5000)
