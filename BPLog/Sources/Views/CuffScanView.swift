import SwiftUI
import PhotosUI

/// Camera sheet: take a photo of the cuff screen, OCR it, hand the numbers back to the log form.
struct CuffScanView: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (CuffOCR.Result) -> Void
    @State private var image: UIImage?
    @State private var reading: CuffOCR.Result?
    @State private var working = false
    @State private var failed = false
    @State private var showCamera = true
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 320).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if working {
                    ProgressView("Reading the numbers...")
                } else if let r = reading {
                    VStack(spacing: 6) {
                        Text("\(r.systolic) / \(r.diastolic)").font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                        if let p = r.pulse { Text("Pulse \(p)").font(.title3).foregroundStyle(.secondary) }
                        Text("Check these against your cuff, then tap Use.").font(.footnote).foregroundStyle(.secondary)
                    }
                    BigButton(title: "Use these numbers", systemImage: "checkmark") { onResult(r); dismiss() }
                    Button("Retake") { reading = nil; image = nil; showCamera = true }
                } else if failed {
                    EmptyState(symbol: "camera.metering.unknown", title: "Couldn't read it",
                               text: "Get closer so the three big numbers fill the frame, and avoid glare.")
                    BigButton(title: "Try again", systemImage: "camera") { failed = false; showCamera = true }
                    Button("Type them in instead") { dismiss() }
                }
                Spacer()
                if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                    PhotosPicker("Choose a photo", selection: $pickerItem, matching: .images)
                }
            }
            .padding()
            .navigationTitle("Scan cuff")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .fullScreenCover(isPresented: $showCamera) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    CameraPicker { img in showCamera = false; if let img { process(img) } }
                        .ignoresSafeArea()
                } else {
                    Color.clear.onAppear { showCamera = false }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { process(img) }
                }
            }
        }
    }

    private func process(_ img: UIImage) {
        image = img
        working = true
        failed = false
        Task {
            let r = await CuffOCR.read(img)
            working = false
            reading = r
            failed = r == nil
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.cameraCaptureMode = .photo
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            completion(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
    }
}
