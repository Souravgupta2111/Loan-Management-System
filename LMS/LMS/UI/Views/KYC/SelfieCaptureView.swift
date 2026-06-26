import SwiftUI
import AVFoundation
import Combine
import UIKit

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: Data? = nil
    
    private var output = AVCapturePhotoOutput()
    
    func checkPermissions() {
        #if targetEnvironment(simulator)
        // No-op on simulator to avoid crash
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        default:
            break
        }
        #endif
    }
    
    private func setupCamera() {
        do {
            session.beginConfiguration()
            
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
            }
            
            session.commitConfiguration()
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            print("Failed to setup camera: \(error.localizedDescription)")
        }
    }
    
    func capturePhoto() {
        #if targetEnvironment(simulator)
        // Mock a photo capture in simulator since camera is unavailable
        if let dummyImage = UIImage(systemName: "person.crop.circle")?.jpegData(compressionQuality: 0.8) {
            DispatchQueue.main.async {
                self.capturedImage = dummyImage
            }
        }
        #else
        guard session.outputs.contains(output) else {
            print("Error: Photo output is not connected to the session.")
            return
        }
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
        #endif
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation() {
            DispatchQueue.main.async {
                self.capturedImage = data
                self.session.stopRunning()
            }
        }
    }
    
    func retake() {
        capturedImage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = camera.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== camera.session {
            uiView.videoPreviewLayer.session = camera.session
        }
    }
}

/// Selfie Capture View for KYC
struct SelfieCaptureView: View {
    @Binding var selfieData: Data?
    @StateObject private var camera = CameraManager()

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Text("Selfie Verification")
                .font(.sectionTitle)
                .foregroundColor(.textPrimary)

            Text("Position your face within the circle and capture")
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            ZStack {
                if let data = selfieData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                } else {
                    #if targetEnvironment(simulator)
                    ZStack {
                        Color.black
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                    #else
                    CameraPreview(camera: camera)
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                    #endif
                }
                
                Circle()
                    .strokeBorder(Color.accentGreen, lineWidth: 4)
                    .frame(width: 200, height: 200)
            }

            PillButton(title: selfieData != nil ? "Retake" : "Capture Selfie", style: .primary) {
                if selfieData != nil {
                    selfieData = nil
                    camera.retake()
                } else {
                    camera.capturePhoto()
                }
            }
            .frame(width: 200)
        }
        .padding(Spacing.xxl)
        .onAppear {
            camera.checkPermissions()
        }
        .onChange(of: camera.capturedImage) { newValue in
            if let newImage = newValue {
                selfieData = newImage
            }
        }
    }
}
