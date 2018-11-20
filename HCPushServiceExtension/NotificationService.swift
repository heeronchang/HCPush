//
//  NotificationService.swift
//  HCPushServiceExtension
//
//  Created by Heeron on 2018/11/19.
//  Copyright © 2018 HeeronChang. All rights reserved.
//

import UserNotifications
import AVFoundation


typealias PlayVoiceBlock = () -> Void

class NotificationService: UNNotificationServiceExtension, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    var synthesizer: AVSpeechSynthesizer?
    var finshBlock: PlayVoiceBlock?
    var aVAudioPlayerFinshBlock: PlayVoiceBlock?
    
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
            
            /*      1       */
//            self.playVoice(content: bestAttemptContent.body) {
//                contentHandler(bestAttemptContent)
//            }
            
            /*      2       */
            self.combineVoice {
                contentHandler(bestAttemptContent)
            }
        }
    }
    /*      1       */
    /// 文字转语音，系统方法
    func playVoice(content: String, finshBlock: @escaping PlayVoiceBlock) {
        if content.count == 0 {
            return
        }
        
        self.finshBlock = finshBlock
//        if let finshBlock = finshBlock {
//            self.finshBlock = finshBlock
//        }
        
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try? session.setActive(true, options: [])
        try? session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
        // 创建嗓音
        let voice = AVSpeechSynthesisVoice.init(language: "zh-CN")
        
        // 创建语音合成器
        self.synthesizer = AVSpeechSynthesizer.init()
        self.synthesizer?.delegate = self
        
        // 实例化发声的对象
        let utterance = AVSpeechUtterance.init(string: content)
        utterance.voice = voice
        utterance.rate = 0.5 // 语速
        
        self.synthesizer?.speak(utterance)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("start")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("end")
        self.finshBlock!()
    }
    
/*      1       */
    
/*      2       */
    func combineVoice(finishBlock: @escaping PlayVoiceBlock) {
        self.aVAudioPlayerFinshBlock = finishBlock
        
        // 合成物，轨道集合，但不是最终产物
        let composition = AVMutableComposition()
        
        let fileNameArray = ["daozhang","1","2","3","4","5","6"]
        var allTime = CMTime.zero
        for value in fileNameArray {
            let audioPath = Bundle.main.path(forResource: value, ofType: "m4a")!
            let audioPathUrl = URL(fileURLWithPath: audioPath)
            // 将源文件转换为可处理的资源，初次加工
            let audioAsset = AVURLAsset(url: audioPathUrl)
            
            // 音频轨道素材，音轨属性，合成物所需要的原料
            let audioTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: 0)!
            
            // 将初始资产再加工成可以拼接的音轨资产
            let audioAssetTrack: AVAssetTrack = audioAsset.tracks(withMediaType: AVMediaType.audio).first!
            
            // 控制时间
            let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: audioAsset.duration)
            
            // 音频合并，插入音轨文件
            try? audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: allTime)
            // 更新当前的位置
            allTime = CMTimeAdd(allTime, audioAsset.duration)
        }
        
        // 合并后的文件导出， presetName 要和之后的 session.outputFileType 相对应
        let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)!
        let outPutFilePath = filePath.deletingLastPathComponent().appendingPathComponent("xindong.m4a")
        
        if FileManager.default.fileExists(atPath: outPutFilePath.path) {
            try? FileManager.default.removeItem(at: outPutFilePath)
        }
        
        session.outputURL = outPutFilePath
        session.outputFileType = AVFileType.m4a
        session.shouldOptimizeForNetworkUse = true
        
        session.exportAsynchronously(completionHandler: {
            print("session...", session)
            switch session.status {
            case .unknown:
                print("unknown")
                self.aVAudioPlayerFinshBlock?()
            case .waiting:
                print("waiting")
                self.aVAudioPlayerFinshBlock?()
            case .exporting:
                print("exporting")
                self.aVAudioPlayerFinshBlock?()
            case .failed:
                print("failed")
                self.aVAudioPlayerFinshBlock?()
            case .cancelled:
                print("cancelled")
                self.aVAudioPlayerFinshBlock?()
            case .completed:
                print("completed")
                self.myPlayer = try? AVAudioPlayer(contentsOf: outPutFilePath)
                self.myPlayer?.delegate = self
                self.myPlayer?.play()
            }
        })
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.aVAudioPlayerFinshBlock?()
    }
    
    var myPlayer: AVAudioPlayer?
    
    var filePath: URL {
        get {
            let string = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
            let fileUrl = URL(fileURLWithPath: string!)
            let folderName = fileUrl.appendingPathComponent("MergeAudio")
            try? FileManager.default.createDirectory(at: folderName, withIntermediateDirectories: true, attributes: [:])
            
            return folderName.appendingPathComponent("xindong.m4a")
        }
    }
    
/*      2       */
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}


