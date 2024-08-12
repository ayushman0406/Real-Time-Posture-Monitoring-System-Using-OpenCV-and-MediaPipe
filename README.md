# Slouching-Detector
Motivation and Objective:
This project was inspired by a proffesor at my college who once caught me slouching on my chair in a lab. He mentioned that one of his friends had gotten back pain due to his bad posture. This prompted me to start developing this software.  
Project Overview:

Developed an innovative system to monitor and correct posture in real-time, addressing the growing need for ergonomic awareness in remote work environments.
Utilizes computer vision and machine learning to detect slouching and provide instant feedback.
Technical Implementation:

MediaPipe Pose Estimation: Accurately tracks key body landmarks, with a focus on shoulder positions.
OpenCV: Captures live video feed and processes the data in real-time.
Python: The primary programming language used to integrate the system and ensure efficient processing.
How It Works:

Reference Capture: The system captures a baseline image of the user in optimal posture, focusing on the y coordinates of the shoulders.
Real-Time Monitoring: Continuously tracks shoulder height. If a shoulder drops more than 7 cm from the reference, an alert is triggered, indicating slouching.
Key Features:

Customizable Sensitivity: Fine-tuned to avoid false positives while accurately detecting slouching.
User-Friendly Interface: Provides immediate visual feedback on posture status.
Impact:

Enhances workplace ergonomics by preventing poor posture habits.
Potential applications in corporate settings, home offices, and health-focused tech products.
Next Steps:

Expand monitoring to additional body landmarks.
Integrate with feedback mechanisms like vibration alerts or posture suggestions.
Consider developing a mobile or desktop application for broader use.
