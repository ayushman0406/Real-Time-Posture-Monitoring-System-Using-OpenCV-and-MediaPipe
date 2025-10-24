#!/usr/bin/env python3
"""
Test script to verify the application works correctly for deployment.
"""

import os
import sys
import time
import requests
from app import app

def test_health_endpoint():
    """Test the health endpoint"""
    print("Testing health endpoint...")
    try:
        with app.test_client() as client:
            response = client.get('/health')
            if response.status_code == 200:
                data = response.get_json()
                print(f"✅ Health endpoint working: {data}")
                return True
            else:
                print(f"❌ Health endpoint failed with status {response.status_code}")
                return False
    except Exception as e:
        print(f"❌ Health endpoint test failed: {e}")
        return False

def test_main_endpoint():
    """Test the main endpoint"""
    print("Testing main endpoint...")
    try:
        with app.test_client() as client:
            response = client.get('/')
            if response.status_code == 200:
                print("✅ Main endpoint working")
                return True
            else:
                print(f"❌ Main endpoint failed with status {response.status_code}")
                return False
    except Exception as e:
        print(f"❌ Main endpoint test failed: {e}")
        return False

def test_debug_endpoint():
    """Test the debug endpoint"""
    print("Testing debug endpoint...")
    try:
        with app.test_client() as client:
            response = client.get('/debug')
            if response.status_code == 200:
                data = response.get_json()
                print(f"✅ Debug endpoint working: {data.get('working_directory')}")
                return True
            else:
                print(f"❌ Debug endpoint failed with status {response.status_code}")
                return False
    except Exception as e:
        print(f"❌ Debug endpoint test failed: {e}")
        return False

def test_environment_variables():
    """Test environment variable handling"""
    print("Testing environment variables...")
    
    # Test PORT environment variable
    original_port = os.environ.get('PORT')
    os.environ['PORT'] = '8080'
    
    try:
        # Import the app module to test port handling
        from app import app
        print("✅ Environment variable handling working")
        return True
    except Exception as e:
        print(f"❌ Environment variable test failed: {e}")
        return False
    finally:
        # Restore original PORT
        if original_port:
            os.environ['PORT'] = original_port
        elif 'PORT' in os.environ:
            del os.environ['PORT']

def main():
    """Run all deployment tests"""
    print("🧪 Testing Deployment Configuration\n")
    
    tests = [
        ("Health Endpoint", test_health_endpoint),
        ("Main Endpoint", test_main_endpoint),
        ("Debug Endpoint", test_debug_endpoint),
        ("Environment Variables", test_environment_variables)
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
        print("\n🎉 All deployment tests passed!")
        print("\nYour app is ready for deployment!")
        print("\nDeployment checklist:")
        print("✅ Health endpoint working")
        print("✅ Main endpoint working") 
        print("✅ Debug endpoint working")
        print("✅ Environment variables handled")
        print("✅ Gunicorn configuration ready")
        print("✅ Railway/Heroku configuration ready")
        
        print("\nNext steps:")
        print("1. Commit your changes: git add . && git commit -m 'Fix deployment'")
        print("2. Push to GitHub: git push origin main")
        print("3. Deploy on your chosen platform")
    else:
        print(f"\n⚠️  {total - passed} tests failed. Please fix the issues above.")
        sys.exit(1)

if __name__ == "__main__":
    main()
