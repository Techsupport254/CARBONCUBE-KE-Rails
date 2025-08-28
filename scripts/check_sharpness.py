import cv2
import sys

def is_blurry(image_path, threshold=400):  
    image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    if image is None:
        print("Error: Image not found.")
        return

    laplacian = cv2.Laplacian(image, cv2.CV_64F)
    variance = laplacian.var()

    print(f"Laplacian Variance: {variance}")
    print("Blurry" if variance < threshold else "Sharp")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 check_sharpness.py <image_path>")
        sys.exit(1)

    is_blurry(sys.argv[1])
    