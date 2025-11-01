🫁 Slouching Detector - Full Stack Application

A real-time posture monitoring application that detects slouching using computer vision and MediaPipe. This full-stack application includes a Flask backend API and a modern web frontend.

✨ Features

📸 Reference Posture Capture – Take a photo of yourself in good posture

🔍 Real-time Monitoring – Detect posture via webcam instantly

⚡ Instant Alerts when slouching is detected

🎯 Accurate Pose Estimation with z-axis consideration

🌐 Responsive Web Interface

🛠 How It Works

Capture a good posture reference image

Start live monitoring through your webcam

Receive instant notifications if slouching

Powered by MediaPipe Pose tracking to monitor shoulder alignment over time.

🧩 Local Development
✅ Prerequisites

Python 3.8+

Webcam

Modern web browser

🚀 Setup Instructions
# 1️⃣ Clone the repository
git clone <your-repo-url>
cd Slouching-Detector

# 2️⃣ Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 3️⃣ Install dependencies
pip install -r requirements.txt

# 4️⃣ Start Application
python app.py


➡️ Open your browser at: http://localhost:5000

📁 File Structure
Slouching-Detector/
├── app.py                 # Flask backend server
├── slouching_detector.py  # Posture detection logic
├── templates/
│   └── index.html         # Web UI
├── requirements.txt       # Dependencies
└── README.md              # Project documentation

🔌 API Endpoints
Endpoint	Method	Description
/	GET	Main UI
/capture_reference	POST	Save reference posture
/start_monitoring	POST	Begin posture detection
/stop_monitoring	POST	Stop detection
/get_status	GET	Check slouching status
🔍 Technical Overview

Backend: Flask

Computer Vision: OpenCV + MediaPipe

Frontend: HTML5, CSS3, JavaScript

Real-time polling for status updates

🌐 Browser Compatibility

✅ Chrome/Chromium (Best)
✅ Firefox
✅ Safari
✅ Edge

🛟 Troubleshooting
Issue	Fix
Camera not working	Allow browser camera permission
Detection inaccurate	Ensure bright lighting & full upper body visible
Reference posture incorrect	Retake reference in good posture
🤝 Contributing

Fork the repo

Create a branch

Make improvements

Submit PR

📄 License

MIT License
