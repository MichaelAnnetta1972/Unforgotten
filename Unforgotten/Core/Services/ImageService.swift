import SwiftUI
import PhotosUI
import Supabase

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Image Upload Service
final class ImageUploadService {
    static let shared = ImageUploadService()

    private let supabase = SupabaseManager.shared.client

    private init() {}

    /// Uploads a profile photo and returns the public URL
    func uploadProfilePhoto(image: UIImage, profileId: UUID) async throws -> String {
        try await uploadImage(
            image: image,
            bucket: SupabaseConfig.profilePhotosBucket,
            path: "profiles/\(profileId.uuidString)/photo.jpg"
        )
    }

    /// Uploads a medication photo and returns the public URL
    func uploadMedicationPhoto(image: UIImage, medicationId: UUID) async throws -> String {
        try await uploadImage(
            image: image,
            bucket: SupabaseConfig.medicationPhotosBucket,
            path: "medications/\(medicationId.uuidString)/photo.jpg"
        )
    }

    /// Generic image upload method
    private func uploadImage(image: UIImage, bucket: String, path: String) async throws -> String {
        // Resize image if needed
        let resizedImage = resizeImage(image, maxDimension: SupabaseConfig.maxImageDimension)

        // Convert to JPEG data
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw SupabaseError.invalidData
        }

        // Check file size
        if imageData.count > SupabaseConfig.maxImageSizeBytes {
            throw SupabaseError.uploadFailed
        }

        // Upload to Supabase Storage
        try await supabase.storage
            .from(bucket)
            .upload(
                path,
                data: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        // Get public URL with cache-busting timestamp
        let publicURL = try supabase.storage
            .from(bucket)
            .getPublicURL(path: path)

        // Add timestamp query parameter to bust SwiftUI's AsyncImage cache
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(publicURL.absoluteString)?t=\(timestamp)"
    }

    /// Delete an image from storage
    func deleteImage(bucket: String, path: String) async throws {
        try await supabase.storage
            .from(bucket)
            .remove(paths: [path])
    }

    /// Resize image to fit within max dimension while maintaining aspect ratio
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

// MARK: - Async Image View
struct AsyncProfileImage: View {
    let url: String?
    let size: CGFloat
    let placeholder: String

    init(url: String?, size: CGFloat = 80, placeholder: String = "person.circle.fill") {
        self.url = url
        self.size = size
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        Image(systemName: placeholder)
            .font(.system(size: size * 0.6))
            .foregroundColor(.textSecondary)
            .frame(width: size, height: size)
            .background(Color.cardBackgroundSoft)
            .clipShape(Circle())
    }
}

// MARK: - Photo Picker Button
struct PhotoPickerButton: View {
    @Binding var selectedImage: UIImage?
    let currentPhotoURL: String?
    let size: CGFloat

    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    @State private var showCropper = false

    init(selectedImage: Binding<UIImage?>, currentPhotoURL: String? = nil, size: CGFloat = 120) {
        self._selectedImage = selectedImage
        self.currentPhotoURL = currentPhotoURL
        self.size = size
    }

    var body: some View {
        Button {
            showImagePicker = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    AsyncProfileImage(url: currentPhotoURL, size: size)
                }

                // Edit badge
                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.accentYellow)
                    .clipShape(Circle())
                    .offset(x: 4, y: 4)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $pickedImage)
        }
        .onChange(of: pickedImage) { _, newImage in
            if newImage != nil {
                showCropper = true
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let image = pickedImage {
                ImageCropperView(
                    image: image,
                    onCrop: { croppedImage in
                        selectedImage = croppedImage
                        pickedImage = nil
                        showCropper = false
                    },
                    onCancel: {
                        pickedImage = nil
                        showCropper = false
                    }
                )
            }
        }
    }
}

// MARK: - Image Cropper View
struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    private let cropSize: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header - high z-index to stay on top
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)

                    Spacer()

                    Text("Scale & Position")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button("Done") {
                        let cropped = cropImage()
                        onCrop(cropped)
                    }
                    .foregroundColor(.accentYellow)
                    .fontWeight(.semibold)
                }
                .padding()
                .padding(.top, 44)
                .background(Color.black)
                .zIndex(1)

                // Crop area - clipped to prevent overflow
                GeometryReader { geometry in
                    ZStack {
                        // Image with gestures
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
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )

                        // Crop overlay
                        CropOverlay(cropSize: cropSize)
                    }
                    .clipped()
                    .onAppear {
                        containerSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        containerSize = newSize
                    }
                }
                .clipped()

                // Instructions
                Text("Pinch to zoom, drag to position")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
                    .padding(.bottom, 20)
            }
        }
    }

    private func cropImage() -> UIImage {
        // Normalize the image orientation first
        let normalizedImage = normalizeImageOrientation(image)
        let imageSize = normalizedImage.size

        // Calculate the image's base displayed size within the container (aspectRatio .fit)
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var baseDisplayedSize: CGSize
        if imageAspect > containerAspect {
            // Image is wider than container - width constrained
            baseDisplayedSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            // Image is taller than container - height constrained
            baseDisplayedSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }

        // Apply user scale
        let displayedSize = CGSize(
            width: baseDisplayedSize.width * scale,
            height: baseDisplayedSize.height * scale
        )

        // The crop center relative to the image center (in displayed coordinates)
        // offset moves the image, so to find what part of the image is at crop center,
        // we need the inverse: -offset
        let cropRelativeToImageX = -offset.width
        let cropRelativeToImageY = -offset.height

        // Convert to image pixel coordinates
        let pixelsPerPointX = imageSize.width / displayedSize.width
        let pixelsPerPointY = imageSize.height / displayedSize.height

        let cropCenterInPixelsX = imageSize.width / 2 + cropRelativeToImageX * pixelsPerPointX
        let cropCenterInPixelsY = imageSize.height / 2 + cropRelativeToImageY * pixelsPerPointY

        let cropWidthInPixels = cropSize * pixelsPerPointX
        let cropHeightInPixels = cropSize * pixelsPerPointY

        let cropRect = CGRect(
            x: cropCenterInPixelsX - cropWidthInPixels / 2,
            y: cropCenterInPixelsY - cropHeightInPixels / 2,
            width: cropWidthInPixels,
            height: cropHeightInPixels
        )

        // Clamp to image bounds
        let clampedRect = CGRect(
            x: max(0, min(cropRect.origin.x, imageSize.width - 1)),
            y: max(0, min(cropRect.origin.y, imageSize.height - 1)),
            width: min(cropRect.width, imageSize.width - max(0, cropRect.origin.x)),
            height: min(cropRect.height, imageSize.height - max(0, cropRect.origin.y))
        )

        // Ensure we have a valid crop rect
        guard clampedRect.width > 0 && clampedRect.height > 0 else {
            return normalizedImage
        }

        // Perform the crop
        if let cgImage = normalizedImage.cgImage?.cropping(to: clampedRect) {
            return UIImage(cgImage: cgImage)
        }

        return normalizedImage
    }

    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }
}

// MARK: - Crop Overlay
struct CropOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(
                x: (geometry.size.width - cropSize) / 2,
                y: (geometry.size.height - cropSize) / 2,
                width: cropSize,
                height: cropSize
            )

            ZStack {
                // Darkened overlay outside crop area
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            Rectangle()
                            Circle()
                                .frame(width: cropSize, height: cropSize)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )

                // Crop circle border
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .allowsHitTesting(false)
    }
}
