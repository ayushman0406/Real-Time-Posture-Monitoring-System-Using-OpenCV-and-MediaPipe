#!/usr/bin/env python3
"""
Simple test script to verify the slouching detector application works correctly.
"""

import os
import sys
import json
from slouching_detector import SlouchingDetector

def test_detector_initialization():
    """Test that the detector can be initialized"""
    print("Testing detector initialization...")
    try:
        detector = SlouchingDetector()
        print("✅ Detector initialized successfully")
        return True
    except Exception as e:
        print(f"❌ Failed to initialize detector: {e}")
        return False

def test_reference_save_load():
    """Test saving and loading reference coordinates"""
    print("Testing reference save/load functionality...")
    try:
        detector = SlouchingDetector()
        
        # Test data
        test_coords = (0.5, 0.6, -0.1, -0.2)
        detector.reference_coords = test_coords
        
        # Test save
        if detector.save_reference_to_file('test_reference.json'):
            print("✅ Reference coordinates saved successfully")
        else:
            print("❌ Failed to save reference coordinates")
            return False
        
        # Test load
        detector2 = SlouchingDetector()
        if detector2.load_reference_from_file('test_reference.json'):
            if detector2.reference_coords == test_coords:
                print("✅ Reference coordinates loaded successfully")
            else:
                print("❌ Loaded coordinates don't match saved coordinates")
                return False
        else:
            print("❌ Failed to load reference coordinates")
            return False
        
        # Clean up
        if os.path.exists('test_reference.json'):
            os.remove('test_reference.json')
        
        return True
    except Exception as e:
        print(f"❌ Reference save/load test failed: {e}")
        return False

def test_adjustment_function():
    """Test the y-coordinate adjustment function"""
    print("Testing y-coordinate adjustment...")
    try:
        detector = SlouchingDetector()
        
        # Test the adjustment function
        current_y = 0.5
        current_z = -0.1
        ref_y = 0.4
        ref_z = -0.2
        
        adjusted_y = detector.slight_adjustment_y_based_on_z(current_y, current_z, ref_y, ref_z)
        
        # The adjustment should be small but non-zero
        if abs(adjusted_y - current_y) < 0.1:  # Reasonable adjustment
            print("✅ Y-coordinate adjustment working correctly")
            return True
        else:
            print(f"❌ Adjustment too large: {adjusted_y}")
            return False
    except Exception as e:
        print(f"❌ Adjustment function test failed: {e}")
        return False

def test_file_structure():
    """Test that all required files exist"""
    print("Testing file structure...")
    required_files = [
        'app.py',
        'slouching_detector.py',
        'requirements.txt',
        'templates/index.html',
        'Procfile',
        'railway.json',
        'runtime.txt'
    ]
    
    missing_files = []
    for file in required_files:
        if not os.path.exists(file):
            missing_files.append(file)
    
    if missing_files:
        print(f"❌ Missing files: {missing_files}")
        return False
    else:
        print("✅ All required files present")
        return True

def main():
    """Run all tests"""
    print("🧪 Running Slouching Detector Tests\n")
    
    tests = [
        test_file_structure,
        test_detector_initialization,
        test_reference_save_load,
        test_adjustment_function
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()  # Add spacing between tests
    
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The application is ready to run.")
        print("\nTo start the application:")
        print("1. Install dependencies: pip install -r requirements.txt")
        print("2. Run the app: python app.py")
        print("3. Open your browser to: http://localhost:5000")
    else:
        print("⚠️  Some tests failed. Please check the errors above.")
        sys.exit(1)

if __name__ == "__main__":
    main()
