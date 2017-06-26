//
//  ViewController.swift
//  CoreMLIntroduction
//
//  Created by NATON on 2017/6/22.
//  Copyright © 2017年 NATON. All rights reserved.
//

import UIKit
import CoreML

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var classifier: UILabel!
    
    var model: Inceptionv3!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Core ML"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model = Inceptionv3()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    

    @IBAction func camera(_ sender: UIBarButtonItem) {
        //1.判断是否支持照相机
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        
        // 2.初始化一个图片库的对象
        let cameraPicker = UIImagePickerController()
        cameraPicker.delegate = self
        cameraPicker.sourceType =  .camera
        cameraPicker.allowsEditing = false
        // 3.跳转到图片库页面
        present(cameraPicker, animated: true, completion: nil)
    }
    
    @IBAction func openLibrary(_ sender: UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
    }
}

extension ViewController: UIImagePickerControllerDelegate {
    //点击返回的事件处理
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        //我们从Info字典中使用UIImagePickerControllerOriginalImage 当成key值来检索所选图像。我们也忽略了UIImagePickerController 曾经选择过的图像
        picker.dismiss(animated: true, completion: nil)
        classifier.text = "Analyzing Image..."
        guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage else {
            return
        }
        
        //由于我们的模型只接受尺寸为299x299的图像，我们将图像转为正方形，然后将图片设置为newImage
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 299, height: 299), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: 299, height: 299))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        //将newImage转换成CVPoxelBuffer,他基本上是一个保存在内存中的像素的图像缓冲区
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        
        guard (status == kCVReturnSuccess) else {
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue:0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height),bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space:rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        //我们将图像中存在的所有像素转换成与设备相关的RGB颜色空间。然后，通过将所有这些数据创建成一个 CGContext，我们可以在需要渲染（或更改）其一些基础属性时轻松调用它。这是我们通过翻译和缩放图像在接下来的两行代码中所做的
        context?.translateBy(x: 0, y: newImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        //最后，我们使图形上下文进入当前上下文，渲染图像，从顶层栈中删除上下文，并设置imageView.image为newImage
        UIGraphicsPushContext(context!)
        newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue:0))
        imageView.image = newImage
        
        //使用core ML
        guard let prediction = try? model.prediction(image: pixelBuffer!) else {
            return
        }
        
        classifier.text = "I think this is a \(prediction.classLabel)."
    }
}

