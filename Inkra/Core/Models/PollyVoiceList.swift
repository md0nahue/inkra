import Foundation

struct PollyVoiceList {
    // 10 diverse Inkra voices with welcome phrases (no child voices)
    static let englishVoices: [PollyVoice] = [
        // US English Voices
        PollyVoice(id: "Matthew", name: "Matthew", gender: "Male", neural: true, languageCode: "en-US", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/matthew_inkra_welcome.mp3"),
        PollyVoice(id: "Joanna", name: "Joanna", gender: "Female", neural: true, languageCode: "en-US", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/joanna_inkra_welcome.mp3"),
        PollyVoice(id: "Ruth", name: "Ruth", gender: "Female", neural: true, languageCode: "en-US", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/ruth_inkra_welcome.mp3"),
        PollyVoice(id: "Stephen", name: "Stephen", gender: "Male", neural: true, languageCode: "en-US", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/stephen_inkra_welcome.mp3"),
        PollyVoice(id: "Kendra", name: "Kendra", gender: "Female", neural: true, languageCode: "en-US", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/kendra_inkra_welcome.mp3"),
        
        // British English Voices
        PollyVoice(id: "Arthur", name: "Arthur", gender: "Male", neural: true, languageCode: "en-GB", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/arthur_inkra_welcome.mp3"),
        PollyVoice(id: "Emma", name: "Emma", gender: "Female", neural: true, languageCode: "en-GB", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/emma_inkra_welcome.mp3"),
        PollyVoice(id: "Brian", name: "Brian", gender: "Male", neural: true, languageCode: "en-GB", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/brian_inkra_welcome.mp3"),
        
        // International English Voices
        PollyVoice(id: "Olivia", name: "Olivia", gender: "Female", neural: true, languageCode: "en-AU", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/olivia_inkra_welcome.mp3"),
        PollyVoice(id: "Aria", name: "Aria", gender: "Female", neural: true, languageCode: "en-NZ", 
                  demoUrl: "https://voicepublish.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/aria_inkra_welcome.mp3")
    ]
    
    
    static let allVoices: [PollyVoice] = englishVoices
    
    static let defaultVoiceId = "Matthew"
    
    static func voices(for language: String) -> [PollyVoice] {
        return englishVoices
    }
    
    static func defaultVoiceId(for language: String) -> String {
        return defaultVoiceId
    }
}