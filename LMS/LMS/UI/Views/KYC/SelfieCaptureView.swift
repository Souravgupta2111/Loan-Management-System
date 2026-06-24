import SwiftUI
import AVFoundation
import Combine

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: Data? = nil
    
    private var output = AVCapturePhotoOutput()
    
    func checkPermissions() {
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
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
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

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let preview = AVCaptureVideoPreviewLayer(session: camera.session)
        preview.frame = view.frame
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.session = camera.session
            // Update frame to match bounds to keep it centered in the circle
            layer.frame = uiView.bounds
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
                    CameraPreview(camera: camera)
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
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
