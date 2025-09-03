#!/usr/bin/env python3
"""
Test script to verify Python dependencies are working correctly.
This script tests the same functionality used in the Rails app.
"""

import sys
import cv2
import numpy as np


def test_opencv():
    """Test OpenCV functionality"""
    try:
        # Create a simple test image
        test_image = np.zeros((100, 100, 3), dtype=np.uint8)
        test_image[25:75, 25:75] = [255, 255, 255]  # White square
        
        # Test basic OpenCV operations
        gray = cv2.cvtColor(test_image, cv2.COLOR_BGR2GRAY)
        laplacian = cv2.Laplacian(gray, cv2.CV_64F)
        variance = laplacian.var()
        
        print(f"OpenCV test passed. Laplacian variance: {variance}")
        return True
    except Exception as e:
        print(f"OpenCV test failed: {e}")
        return False


def test_numpy():
    """Test NumPy functionality"""
    try:
        # Test basic NumPy operations
        arr = np.array([1, 2, 3, 4, 5])
        mean = np.mean(arr)
        std = np.std(arr)
        
        print(f"NumPy test passed. Mean: {mean}, Std: {std}")
        return True
    except Exception as e:
        print(f"NumPy test failed: {e}")
        return False


def main():
    """Main test function"""
    print("Testing Python dependencies...")
    
    # Test functionality
    opencv_ok = test_opencv()
    numpy_ok = test_numpy()
    
    if opencv_ok and numpy_ok:
        print("✓ All tests passed!")
        return True
    else:
        print("✗ Some tests failed!")
        return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
