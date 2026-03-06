import Vision
import Cocoa
import Foundation

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift extract_text.swift <directory_path>")
    exit(1)
}

let dirPath = CommandLine.arguments[1]
let fileManager = FileManager.default

do {
    let files = try fileManager.contentsOfDirectory(atPath: dirPath)
    let jpegFiles = files.filter { $0.hasSuffix(".jpeg") || $0.hasSuffix(".jpg") }.sorted()
    
    for file in jpegFiles {
        let fullPath = (dirPath as NSString).appendingPathComponent(file)
        let url = URL(fileURLWithPath: fullPath)
        
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("File: \(file) -> [Error loading image]")
            continue
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("File: \(file) -> [No text found]")
                return
            }
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            print("File: \(file) -> Text: \(text)")
        }
        // Use realistic language correction to avoid detecting random noise as text
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        try requestHandler.perform([request])
    }
} catch {
    print("Error: \(error)")
}
