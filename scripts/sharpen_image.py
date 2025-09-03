import cv2
import sys
import numpy as np
import os


def sharpen_image(image_path):
    try:
        # Debug: Print current working directory and image path
        print(f"Current working directory: {os.getcwd()}")
        print(f"Image path: {image_path}")
        print(f"Image exists: {os.path.exists(image_path)}")
        
        image = cv2.imread(image_path)
        if image is None:
            print("Error: Image not found.")
            return

        kernel = np.array([[0, -1, 0], 
                           [-1, 5, -1], 
                           [0, -1, 0]])  # Sharpening filter

        sharpened = cv2.filter2D(image, -1, kernel)
        
        # Create a temporary output path
        output_path = image_path + "_sharpened"
        cv2.imwrite(output_path, sharpened)
        
        # Replace original image with sharpened version
        os.replace(output_path, image_path)  # Ensures the original is overwritten
        print(f"Sharpened image saved: {image_path}")
    except Exception as e:
        print(f"Error sharpening image: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 sharpen_image.py <image_path>")
        sys.exit(1)

    sharpen_image(sys.argv[1])
