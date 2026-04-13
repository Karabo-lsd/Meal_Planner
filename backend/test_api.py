#!/usr/bin/env python3
"""
Simple test script to verify the meal planning API is working
"""
import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_health():
    """Test health endpoint"""
    response = requests.get(f"{BASE_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    print("✓ Health check passed")

def test_root():
    """Test root endpoint"""
    response = requests.get(f"{BASE_URL}/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    print("✓ Root endpoint passed")

def test_docs():
    """Test API docs endpoint"""
    response = requests.get(f"{BASE_URL}/docs")
    assert response.status_code == 200
    print("✓ API docs accessible")

def test_openapi():
    """Test OpenAPI schema"""
    response = requests.get(f"{BASE_URL}/openapi.json")
    assert response.status_code == 200
    schema = response.json()
    assert "paths" in schema
    assert "/auth/login" in schema["paths"]
    assert "/users/me" in schema["paths"]
    assert "/meals/" in schema["paths"]
    print("✓ OpenAPI schema valid")

if __name__ == "__main__":
    print("Testing Meal Planning API...")
    try:
        test_health()
        test_root()
        test_docs()
        test_openapi()
        print("\n🎉 All tests passed! The API is ready to run.")
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        exit(1)