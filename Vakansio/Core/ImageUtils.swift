import UIKit
import Foundation

enum ImageUtils {
    static func jpegBase64(from data: Data, maxSide: CGFloat = 512, quality: CGFloat = 0.72) -> String? {
        guard let image = UIImage(data: data) else { return nil }

        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return nil }

        let scale = min(1.0, maxSide / max(width, height))
        let targetSize = CGSize(
            width: max(1, (width * scale).rounded()),
            height: max(1, (height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpeg = resized.jpegData(compressionQuality: quality) else { return nil }
        return jpeg.base64EncodedString()
    }

    static func image(from base64: String?) -> UIImage? {
        guard let base64, !base64.isEmpty, let data = Data(base64Encoded: base64) else {
            return nil
        }
        return UIImage(data: data)
    }
}
