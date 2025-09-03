import cv2
import sys
import os


def is_blurry(image_path, threshold=400):  
    try:
        # Debug: Print current working directory and image path
        print(f"Current working directory: {os.getcwd()}")
        print(f"Image path: {image_path}")
        print(f"Image exists: {os.path.exists(image_path)}")
        
        image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
        if image is None:
            print("Error: Image not found.")
            return "Blurry"

        laplacian = cv2.Laplacian(image, cv2.CV_64F)
        variance = laplacian.var()

        print(f"Laplacian Variance: {variance}")
        result = "Blurry" if variance < threshold else "Sharp"
        print(result)
        return result
    except Exception as e:
        print(f"Error processing image: {e}")
        import traceback
        traceback.print_exc()
        return "Blurry"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 check_sharpness.py <image_path>")
        sys.exit(1)

    is_blurry(sys.argv[1])
    