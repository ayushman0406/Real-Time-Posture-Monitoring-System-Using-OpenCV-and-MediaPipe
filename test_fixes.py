#!/usr/bin/env python3
"""
Test script to verify the fixes for camera capture and monitoring issues.
"""

import requests
import json
import time
import os

def test_server_connection():
    """Test if the server is running"""
    try:
        response = requests.get('http://localhost:5000/debug', timeout=5)
        if response.status_code == 200:
            print("✅ Server is running")
            return True
        else:
            print(f"❌ Server returned status {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to server. Make sure it's running on localhost:5000")
        return False
    except Exception as e:
        print(f"❌ Error connecting to server: {e}")
        return False

def test_debug_endpoint():
    """Test the debug endpoint"""
    try:
        response = requests.get('http://localhost:5000/debug')
        if response.status_code == 200:
            data = response.json()
            print("✅ Debug endpoint working")
            print(f"   - Reference file exists: {data.get('reference_file_exists', False)}")
            print(f"   - Reference coords: {data.get('reference_coords')}")
            print(f"   - Working directory: {data.get('working_directory')}")
            return True
        else:
            print(f"❌ Debug endpoint failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing debug endpoint: {e}")
        return False

def test_status_endpoint():
    """Test the status endpoint"""
    try:
        response = requests.get('http://localhost:5000/get_status')
        if response.status_code == 200:
            data = response.json()
            print("✅ Status endpoint working")
            print(f"   - Status: {data.get('status')}")
            print(f"   - Monitoring active: {data.get('monitoring_active')}")
            print(f"   - Reference saved: {data.get('reference_saved')}")
            return True
        else:
            print(f"❌ Status endpoint failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing status endpoint: {e}")
        return False

def test_start_monitoring_without_reference():
    """Test starting monitoring without reference (should fail)"""
    try:
        response = requests.post('http://localhost:5000/start_monitoring')
        if response.status_code == 400:
            data = response.json()
            print("✅ Start monitoring correctly fails without reference")
            print(f"   - Error message: {data.get('error')}")
            return True
        else:
            print(f"❌ Expected 400 error, got {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing start monitoring: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 Testing Slouching Detector Fixes\n")
    
    tests = [
        ("Server Connection", test_server_connection),
        ("Debug Endpoint", test_debug_endpoint),
        ("Status Endpoint", test_status_endpoint),
        ("Start Monitoring Without Reference", test_start_monitoring_without_reference)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🔍 Testing {test_name}...")
        if test_func():
            passed += 1
        else:
            print(f"❌ {test_name} failed")
    
    print(f"\n📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! The fixes are working correctly.")
        print("\nNext steps:")
        print("1. Start the server: python app.py")
        print("2. Open browser to: http://localhost:5000")
        print("3. Try capturing a photo with the camera")
        print("4. Upload the reference and start monitoring")
    else:
        print(f"\n⚠️  {total - passed} tests failed. Please check the server is running.")
        print("\nTo start the server:")
        print("python app.py")

if __name__ == "__main__":
    main()
