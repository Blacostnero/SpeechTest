//
//  ViewControllerExtension.swift
//  SpeechTest
//
//  Created by Borja Lacosta Sardinero on 16/10/22.
//

import Foundation
import UIKit

extension UIViewController {
    
    func showLoader() {
        DispatchQueue.main.async {
            let activityView = UIActivityIndicatorView(style: .large)
            activityView.center = self.view.center
            self.view.addSubview(activityView)
            activityView.startAnimating()
        }
    }
    
    func hideLoader() {
        DispatchQueue.main.async {
            self.view.subviews.forEach({
                if $0.isKind(of: UIActivityIndicatorView.self) {
                    $0.removeFromSuperview()
                }
            })
        }
    }
}
