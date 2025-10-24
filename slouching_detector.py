import cv2
import mediapipe as mp
import json
import os

class SlouchingDetector:
    def __init__(self):
        self.mp_pose = mp.solutions.pose
        self.pose = self.mp_pose.Pose()
        self.mp_drawing = mp.solutions.drawing_utils
        self.reference_coords = None
        
    def capture_reference_coordinates(self):
        """Capture reference posture coordinates from webcam"""
        cap = cv2.VideoCapture(0)
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = self.pose.process(image_rgb)

            if results.pose_landmarks:
                self.mp_drawing.draw_landmarks(frame, results.pose_landmarks, self.mp_pose.POSE_CONNECTIONS)

                landmarks = results.pose_landmarks.landmark

                # Capture the y and z coordinates for the shoulders
                left_shoulder_y = landmarks[self.mp_pose.PoseLandmark.LEFT_SHOULDER.value].y
                right_shoulder_y = landmarks[self.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].y
                left_shoulder_z = landmarks[self.mp_pose.PoseLandmark.LEFT_SHOULDER.value].z
                right_shoulder_z = landmarks[self.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].z

                cv2.putText(frame, "Press 's' to save reference position", (10, 30), 
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2, cv2.LINE_AA)

                cv2.imshow('Capture Reference Posture', frame)

                if cv2.waitKey(1) & 0xFF == ord('s'):
                    cv2.imwrite('reference_posture_coordinates.png', frame)
                    cv2.destroyAllWindows()
                    cap.release()
                    self.reference_coords = (left_shoulder_y, right_shoulder_y, left_shoulder_z, right_shoulder_z)
                    return self.reference_coords

            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

        cap.release()
        cv2.destroyAllWindows()
        return None

    def slight_adjustment_y_based_on_z(self, current_y, current_z, ref_y, ref_z):
        """Apply a small adjustment to y based on the z coordinate"""
        adjustment_factor = 0.1  # Adjust this factor for sensitivity
        adjusted_y = current_y + adjustment_factor * (current_z - ref_z)
        return adjusted_y

    def check_posture(self, tolerance=0.05):
        """Monitor posture in real-time"""
        if self.reference_coords is None:
            print("No reference coordinates found. Please capture reference posture first.")
            return
            
        ref_left_shoulder_y, ref_right_shoulder_y, ref_left_shoulder_z, ref_right_shoulder_z = self.reference_coords
        
        cap = cv2.VideoCapture(0)
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = self.pose.process(image_rgb)

            if results.pose_landmarks:
                self.mp_drawing.draw_landmarks(frame, results.pose_landmarks, self.mp_pose.POSE_CONNECTIONS)

                landmarks = results.pose_landmarks.landmark

                current_left_shoulder_y = landmarks[self.mp_pose.PoseLandmark.LEFT_SHOULDER.value].y
                current_right_shoulder_y = landmarks[self.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].y
                current_left_shoulder_z = landmarks[self.mp_pose.PoseLandmark.LEFT_SHOULDER.value].z
                current_right_shoulder_z = landmarks[self.mp_pose.PoseLandmark.RIGHT_SHOULDER.value].z

                # Slightly adjust the y coordinates based on the current z coordinates
                adjusted_left_shoulder_y = self.slight_adjustment_y_based_on_z(
                    current_left_shoulder_y, current_left_shoulder_z, ref_left_shoulder_y, ref_left_shoulder_z)
                adjusted_right_shoulder_y = self.slight_adjustment_y_based_on_z(
                    current_right_shoulder_y, current_right_shoulder_z, ref_right_shoulder_y, ref_right_shoulder_z)

                # Check if slouching based on adjusted y-coordinate
                is_slouching = (adjusted_left_shoulder_y > ref_left_shoulder_y + tolerance or
                               adjusted_right_shoulder_y > ref_right_shoulder_y + tolerance)
                
                if is_slouching:
                    cv2.putText(frame, "You are slouching!", (50, 50), 
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2, cv2.LINE_AA)
                else:
                    cv2.putText(frame, "Good Posture", (50, 50), 
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2, cv2.LINE_AA)

                # Display current and adjusted y-coordinates on the frame
                cv2.putText(frame, f"Adj Left Shoulder Y: {round(adjusted_left_shoulder_y, 4)}", (10, 70), 
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2, cv2.LINE_AA)
                cv2.putText(frame, f"Adj Right Shoulder Y: {round(adjusted_right_shoulder_y, 4)}", (10, 110), 
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2, cv2.LINE_AA)

            cv2.imshow('Posture Monitoring', frame)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

        cap.release()
        cv2.destroyAllWindows()

    def save_reference_to_file(self, filename='reference_coords.json'):
        """Save reference coordinates to a JSON file"""
        if self.reference_coords:
            coords_dict = {
                'left_shoulder_y': self.reference_coords[0],
                'right_shoulder_y': self.reference_coords[1],
                'left_shoulder_z': self.reference_coords[2],
                'right_shoulder_z': self.reference_coords[3]
            }
            with open(filename, 'w') as f:
                json.dump(coords_dict, f)
            return True
        return False

    def load_reference_from_file(self, filename='reference_coords.json'):
        """Load reference coordinates from a JSON file"""
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                coords_dict = json.load(f)
            self.reference_coords = (
                coords_dict['left_shoulder_y'],
                coords_dict['right_shoulder_y'],
                coords_dict['left_shoulder_z'],
                coords_dict['right_shoulder_z']
            )
            return True
        return False

# Example usage
if __name__ == "__main__":
    detector = SlouchingDetector()
    
    # Try to load existing reference coordinates
    if not detector.load_reference_from_file():
        print("No existing reference found. Please capture reference posture.")
        detector.capture_reference_coordinates()
        detector.save_reference_to_file()
    
    # Start posture monitoring
    detector.check_posture()
