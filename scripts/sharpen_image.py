import cv2
import sys
import numpy as np
import os

def sharpen_image(image_path, output_path):
    image = cv2.imread(image_path)
    if image is None:
        print("Error: Image not found.")
        return

    kernel = np.array([[0, -1, 0], 
                       [-1, 5, -1], 
                       [0, -1, 0]])  # Sharpening filter

    sharpened = cv2.filter2D(image, -1, kernel)
    cv2.imwrite(output_path, sharpened)
    print(f"Sharpened image saved: {output_path}")

    # Replace original image with sharpened version
    os.replace(output_path, image_path)  # Ensures the original is overwritten

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 sharpen_image.py <image_path> <output_path>")
        sys.exit(1)

    sharpen_image(sys.argv[1], sys.argv[2])
