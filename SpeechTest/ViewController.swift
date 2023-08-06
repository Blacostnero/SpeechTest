//
//  ViewController.swift
//  SpeechTest
//
//  Created by Borja Lacosta Sardinero on 13/10/22.
//

import UIKit
import AVFoundation
import Photos
import PhotosUI
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var openGalleryButton: UIButton!
    @IBOutlet weak var openCameraButton: UIButton!
    @IBOutlet weak var readTextButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    private var textToRead: String = ""
    private var imageToRead: UIImage?
    private let synthesizer = AVSpeechSynthesizer()
    private var utterance = AVSpeechUtterance()
    
    private enum Constants {
        static let opacityEnabled = Float(1)
        static let opacityDisabled = Float(0.5)
        static let textViewFont = UIFont.systemFont(ofSize: 22)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        readTextButton.setTitle("", for: .normal)
        readTextButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        readTextButton.setImage(UIImage(systemName: "pause.fill"), for: .selected)
        stopButton.setTitle("", for: .normal)
        stopButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        setPlayButtonState(enabled: false)
        setStopButtonState(enabled: false)
        
        textView.text = ""
        textView.font = Constants.textViewFont
        
        readTextButton.addTarget(self, action: #selector(readText), for: .touchUpInside)
        openGalleryButton.addTarget(self, action: #selector(openGallery), for: .touchUpInside)
        openCameraButton.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopSpeaking), for: .touchUpInside)
        
        synthesizer.delegate = self
    }
    
    private func setPlayButtonState(enabled: Bool) {
        readTextButton.isEnabled = enabled
        readTextButton.layer.opacity = enabled ? Constants.opacityEnabled : Constants.opacityDisabled
    }
    
    private func setStopButtonState(enabled: Bool) {
        stopButton.isEnabled = enabled
        stopButton.layer.opacity = enabled ? Constants.opacityEnabled : Constants.opacityDisabled
    }
    
    private func convertImageToText() {
        showLoader()
        defer { hideLoader() }
        
        guard let cgImage = imageToRead?.cgImage else {
            return
        }
        let handler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            let text = observations.compactMap({
                $0.topCandidates(1).first?.string
            }).joined(separator: " ")
            
            DispatchQueue.main.async {
                self?.textView.text = text
                self?.textToRead = text
                self?.setPlayButtonState(enabled: true)
            }
        }
        
        request.recognitionLevel = .accurate
        try? handler.perform([request])
    }

    @objc private func readText() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            readTextButton.isSelected = true
        } else if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            readTextButton.isSelected = false
        } else {
            utterance = AVSpeechUtterance(string: textToRead)
            utterance.voice = AVSpeechSynthesisVoice(language: "ca")
            utterance.rate = 0.5

            synthesizer.speak(utterance)
            setStopButtonState(enabled: true)
            readTextButton.isSelected = true
        }
    }
    
    @objc private func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        setStopButtonState(enabled: false)
        readTextButton.isSelected = false
        synthesizer.delegate?.speechSynthesizer!(synthesizer, didFinish: utterance)
    }
    
    @objc private func openGallery() {
        var phPickerConfig = PHPickerConfiguration(photoLibrary: .shared())
        phPickerConfig.selectionLimit = 1
        phPickerConfig.filter = PHPickerFilter.any(of: [.images, .livePhotos])
        let phPickerVC = PHPickerViewController(configuration: phPickerConfig)
        phPickerVC.delegate = self
        present(phPickerVC, animated: true)
    }
    
    @objc private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.allowsEditing = true
            present(picker, animated: true)
        }
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        if let result = results.first {
            let provider = result.itemProvider
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let image = image as? UIImage else {
                        return
                    }
                    self?.imageToRead = image
                    self?.convertImageToText()
                }
            }
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.editedImage] as? UIImage else {
            print("No image found")
            return
        }
        
        imageToRead = image
        convertImageToText()
    }
}

extension ViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let rangeFirst = NSRange(location: 0, length: characterRange.location)
        let rangeLast = NSRange(location: characterRange.upperBound+1, length: ((utterance.speechString.count-1) - characterRange.upperBound))
        let mutableAttributedString = NSMutableAttributedString(string: utterance.speechString)
        
        let attributesHighlighted: [NSAttributedString.Key: Any] = [
            .font: Constants.textViewFont,
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.black
        ]
        let attributesNormal: [NSAttributedString.Key: Any] = [
            .font: Constants.textViewFont
        ]
        mutableAttributedString.addAttributes(attributesNormal, range: rangeFirst)
        mutableAttributedString.addAttributes(attributesHighlighted, range: characterRange)
        mutableAttributedString.addAttributes(attributesNormal, range: rangeLast)
        textView.attributedText = mutableAttributedString
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        textView.text = utterance.speechString
    }
}
