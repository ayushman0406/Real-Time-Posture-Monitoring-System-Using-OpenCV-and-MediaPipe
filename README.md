# 🫁 Slouching Detector - Full Stack Application

A real-time posture monitoring application that detects slouching using computer vision and MediaPipe. This full-stack application includes a Flask backend API and a modern web frontend.

## Features

- 📸 **Reference Posture Capture**: Take a photo of yourself in good posture as a reference
- 🔍 **Real-time Monitoring**: Continuously monitor your posture using your webcam
- ⚡ **Instant Alerts**: Get immediate feedback when slouching is detected
- 🎯 **Accurate Detection**: Uses advanced pose estimation with z-axis adjustments for better accuracy
- 🌐 **Web Interface**: Modern, responsive web interface that works on any device

## How It Works

1. **Capture Reference**: Take a photo of yourself in good posture
2. **Start Monitoring**: Begin real-time posture monitoring using your webcam
3. **Get Alerts**: Receive instant notifications when slouching is detected

The application uses MediaPipe's pose estimation to track shoulder positions and compares them against your reference posture to detect slouching.

## Local Development

### Prerequisites

- Python 3.8 or higher
- Webcam access
- Modern web browser

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd Slouching-Detector
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Run the application:
```bash
python app.py
```

5. Open your browser and go to `http://localhost:5000`

## Deployment to Free Platforms

### Option 1: Railway (Recommended)

Railway offers free hosting with generous limits and is perfect for this application.

1. **Create Railway Account**:
   - Go to [railway.app](https://railway.app)
   - Sign up with GitHub

2. **Deploy from GitHub**:
   - Connect your GitHub account
   - Select your repository
   - Railway will automatically detect the Python app and deploy it

3. **Configure Environment** (if needed):
   - Railway will automatically install dependencies from `requirements.txt`
   - The `railway.json` file contains deployment configuration

4. **Access Your App**:
   - Railway will provide a public URL for your application
   - Your app will be accessible worldwide!

### Option 2: Heroku

1. **Install Heroku CLI**:
   - Download from [heroku.com](https://devcenter.heroku.com/articles/heroku-cli)

2. **Login and Create App**:
```bash
heroku login
heroku create your-app-name
```

3. **Deploy**:
```bash
git add .
git commit -m "Initial commit"
git push heroku main
```

4. **Open Your App**:
```bash
heroku open
```

### Option 3: Render

1. **Create Account**:
   - Go to [render.com](https://render.com)
   - Sign up with GitHub

2. **Create New Web Service**:
   - Connect your GitHub repository
   - Select "Web Service"
   - Choose your repository

3. **Configure**:
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `gunicorn app:app`

4. **Deploy**:
   - Click "Create Web Service"
   - Render will automatically build and deploy your app

## File Structure

```
Slouching-Detector/
├── app.py                 # Flask backend application
├── slouching_detector.py  # Core posture detection logic
├── templates/
│   └── index.html        # Web frontend
├── requirements.txt      # Python dependencies
├── Procfile             # Heroku deployment config
├── railway.json         # Railway deployment config
├── runtime.txt          # Python version specification
└── README.md           # This file
```

## API Endpoints

- `GET /` - Main web interface
- `POST /capture_reference` - Capture reference posture from image
- `POST /start_monitoring` - Start real-time posture monitoring
- `POST /stop_monitoring` - Stop posture monitoring
- `GET /get_status` - Get current posture status

## Technical Details

- **Backend**: Flask with MediaPipe for pose estimation
- **Frontend**: HTML5, CSS3, JavaScript with modern responsive design
- **Computer Vision**: OpenCV and MediaPipe for pose detection
- **Real-time Processing**: WebSocket-like polling for status updates
- **Deployment**: Ready for Heroku, Railway, Render, and other platforms

## Browser Compatibility

- Chrome/Chromium (recommended)
- Firefox
- Safari
- Edge

## Troubleshooting

### Common Issues

1. **Camera Access**: Ensure your browser has permission to access the camera
2. **Pose Detection**: Make sure you're visible in the frame and well-lit
3. **Reference Capture**: Ensure you're in good posture when capturing the reference image

### Performance Tips

- Use good lighting for better pose detection
- Ensure stable internet connection for real-time monitoring
- Close other applications that might use the camera

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

If you encounter any issues:
1. Check the troubleshooting section above
2. Create an issue on GitHub
3. Ensure all dependencies are properly installed

---

**Note**: This application requires camera access and works best in well-lit environments. The accuracy of posture detection depends on the quality of the reference image and current lighting conditions.