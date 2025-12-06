import SwiftUI
import AVFoundation

// MARK: - Local Image Storage Service
final class LocalImageService {
    static let shared = LocalImageService()

    private let fileManager = FileManager.default
    private let medicationPhotosFolder = "MedicationPhotos"

    private init() {
        createMedicationPhotosFolderIfNeeded()
    }

    private var medicationPhotosURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(medicationPhotosFolder)
    }

    private func createMedicationPhotosFolderIfNeeded() {
        guard let url = medicationPhotosURL else { return }
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Save medication photo locally and return the path
    func saveMedicationPhoto(_ image: UIImage, medicationId: UUID) -> String? {
        guard let url = medicationPhotosURL else { return nil }

        let fileName = "\(medicationId.uuidString).jpg"
        let fileURL = url.appendingPathComponent(fileName)

        // Resize image if needed
        let resizedImage = resizeImage(image, maxDimension: 800)

        guard let data = resizedImage.jpegData(compressionQuality: 0.8) else { return nil }

        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Failed to save medication photo: \(error)")
            return nil
        }
    }

    /// Load medication photo from local storage
    func loadMedicationPhoto(fileName: String) -> UIImage? {
        guard let url = medicationPhotosURL else { return nil }

        let fileURL = url.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        return UIImage(data: data)
    }

    /// Delete medication photo from local storage
    func deleteMedicationPhoto(fileName: String) {
        guard let url = medicationPhotosURL else { return }

        let fileURL = url.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)

        guard maxSize > maxDimension else { return image }

        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Camera Picker
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Fullscreen Image View
struct FullscreenImageView: View {
    @Environment(\.dismiss) var dismiss

    let image: UIImage
    let title: String

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image with pinch to zoom and drag
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                // Reset offset if zoomed out completely
                                if scale <= 1.0 {
                                    withAnimation(.spring()) {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    // Double tap to reset zoom
                    withAnimation(.spring()) {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }

            // Header overlay
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(title)
                        .font(.appBodyMedium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Placeholder for balance
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding()
                .padding(.top, 44)

                Spacer()

                // Instructions
                Text("Pinch to zoom • Double tap to reset")
                    .font(.appCaption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Image Source Picker
struct ImageSourcePicker: View {
    @Binding var selectedImage: UIImage?
    let currentImagePath: String?
    let onImageSelected: (UIImage) -> Void

    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var pickedImage: UIImage?

    var body: some View {
        Button {
            showActionSheet = true
        } label: {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let path = currentImagePath,
                          let localImage = LocalImageService.shared.loadMedicationPhoto(fileName: path) {
                    Image(uiImage: localImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.textSecondary)
                        Text("Add Photo")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(width: 100, height: 100)
                    .background(Color.cardBackgroundSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Edit badge
                if selectedImage != nil || currentImagePath != nil {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentYellow)
                        .background(Color.cardBackground)
                        .clipShape(Circle())
                        .offset(x: 40, y: 40)
                }
            }
        }
        .confirmationDialog("Select Photo Source", isPresented: $showActionSheet) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showPhotoLibrary = true
            }
            if selectedImage != nil || currentImagePath != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedImage = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $pickedImage)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(image: $pickedImage)
        }
        .onChange(of: pickedImage) { _, newImage in
            if let image = newImage {
                selectedImage = image
                onImageSelected(image)
                pickedImage = nil
            }
        }
    }
}
