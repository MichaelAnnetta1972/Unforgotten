import SwiftUI

// MARK: - Header Image Adjuster View
/// A full-screen view for adjusting the size and position of a header background image.
/// Users can pinch to zoom and drag to position the image within a rectangular crop area
/// that matches the header's aspect ratio.
struct HeaderImageAdjusterView: View {
    let image: UIImage
    let headerAspectRatio: CGFloat // width / height
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var minimumScale: CGFloat = 1.0

    // Crop rectangle dimensions (calculated from container)
    private var cropWidth: CGFloat {
        max(containerSize.width - 32, 1)
    }

    private var cropHeight: CGFloat {
        cropWidth / max(headerAspectRatio, 0.1)
    }

    // Base displayed size of the image (aspect fit within container)
    private var baseDisplayedSize: CGSize {
        guard containerSize.width > 0 && containerSize.height > 0 else {
            return .zero
        }
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            return CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            return CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)

                    Spacer()

                    Text("Adjust Image")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button("Done") {
                        let cropped = cropImage()
                        onSave(cropped)
                    }
                    .foregroundColor(.accentYellow)
                    .fontWeight(.semibold)
                }
                .padding()
                .padding(.top, 44)
                .background(Color.black)
                .zIndex(1)

                // Adjustment area
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
                                            scale = min(max(scale * delta, minimumScale), 5.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            clampOffset()
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            clampOffset()
                                            lastOffset = offset
                                        }
                                )
                            )

                        // Crop overlay
                        HeaderCropOverlay(cropWidth: cropWidth, cropHeight: cropHeight)
                    }
                    .clipped()
                    .onAppear {
                        containerSize = geometry.size
                        calculateInitialScale()
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        containerSize = newSize
                        calculateInitialScale()
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

    // MARK: - Scale Calculation

    private func calculateInitialScale() {
        guard baseDisplayedSize.width > 0 && baseDisplayedSize.height > 0 else { return }

        let scaleToFillWidth = cropWidth / baseDisplayedSize.width
        let scaleToFillHeight = cropHeight / baseDisplayedSize.height
        let fillScale = max(scaleToFillWidth, scaleToFillHeight, 1.0)

        minimumScale = fillScale
        scale = fillScale
        offset = .zero
        lastOffset = .zero
    }

    // MARK: - Offset Clamping

    private func clampOffset() {
        let imageDisplayWidth = baseDisplayedSize.width * scale
        let imageDisplayHeight = baseDisplayedSize.height * scale

        let maxOffsetX = max(0, (imageDisplayWidth - cropWidth) / 2)
        let maxOffsetY = max(0, (imageDisplayHeight - cropHeight) / 2)

        withAnimation(.easeOut(duration: 0.2)) {
            offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
            offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
        }
        lastOffset = offset
    }

    // MARK: - Crop

    private func cropImage() -> UIImage {
        let normalizedImage = normalizeImageOrientation(image)
        let imageSize = normalizedImage.size

        // Calculate base displayed size (aspectRatio .fit within container)
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var baseSizeCalc: CGSize
        if imageAspect > containerAspect {
            baseSizeCalc = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            baseSizeCalc = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }

        // Apply user scale
        let displayedSize = CGSize(
            width: baseSizeCalc.width * scale,
            height: baseSizeCalc.height * scale
        )

        // Inverse offset: crop center relative to image center
        let pixelsPerPointX = imageSize.width / displayedSize.width
        let pixelsPerPointY = imageSize.height / displayedSize.height

        let cropCenterInPixelsX = imageSize.width / 2 + (-offset.width) * pixelsPerPointX
        let cropCenterInPixelsY = imageSize.height / 2 + (-offset.height) * pixelsPerPointY

        let cropWidthInPixels = cropWidth * pixelsPerPointX
        let cropHeightInPixels = cropHeight * pixelsPerPointY

        let cropRect = CGRect(
            x: cropCenterInPixelsX - cropWidthInPixels / 2,
            y: cropCenterInPixelsY - cropHeightInPixels / 2,
            width: cropWidthInPixels,
            height: cropHeightInPixels
        )

        // Clamp to image bounds
        let clampedRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))

        guard clampedRect.width > 0 && clampedRect.height > 0,
              let cgImage = normalizedImage.cgImage?.cropping(to: clampedRect) else {
            return normalizedImage
        }

        return UIImage(cgImage: cgImage)
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

// MARK: - Header Crop Overlay
/// Rectangular crop overlay that darkens the area outside the crop rectangle
struct HeaderCropOverlay: View {
    let cropWidth: CGFloat
    let cropHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Darkened overlay outside crop area
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            Rectangle()
                            RoundedRectangle(cornerRadius: 4)
                                .frame(width: cropWidth, height: cropHeight)
                                .position(
                                    x: geometry.size.width / 2,
                                    y: geometry.size.height / 2
                                )
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )

                // Crop rectangle border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropWidth, height: cropHeight)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
            }
        }
        .allowsHitTesting(false)
    }
}
