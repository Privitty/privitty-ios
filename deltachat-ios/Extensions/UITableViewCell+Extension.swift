import Foundation
import UIKit

extension UITableViewCell {
    func setCustomDisclosureIndicator(imageName: String, tintColor: UIColor) {
        let image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
        let imageView = UIImageView(image: image)
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        accessoryView = imageView
    }
}
