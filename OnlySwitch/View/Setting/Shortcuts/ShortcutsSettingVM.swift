//
//  ShortcutsSettingVM.swift
//  OnlySwitch
//
//  Created by Jacklandrin on 2022/1/1.
//

import Foundation
import KeyboardShortcuts
import Alamofire

let shorcutsDicKey = "shorcutsDicKey"

class ShorcutsItem:ObservableObject {
    let error:(_ info:String) -> Void
    @Published var name:String
    @Published var toggle:Bool
    {
        didSet {
            let shortcutsDic = UserDefaults.standard.dictionary(forKey: shorcutsDicKey)
            guard let shortcutsDic = shortcutsDic else {
                return
            }
            if toggle {
                let showShortcutsCount = shortcutsDic.filter{$0.value as! Bool == true}.count
                if showShortcutsCount > 5 {
                    error("The maximum number of shortcuts is 6")
                    toggle = false
                    return
                }
            }
            
            var newShortcutsDic = shortcutsDic
            newShortcutsDic[name] = toggle
            UserDefaults.standard.set(newShortcutsDic, forKey: shorcutsDicKey)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: changeSettingNotification, object: nil)
        }
    }
    
    @Published var keyboardShortcutName:KeyboardShortcuts.Name
    
    init(name:String, toggle:Bool, error: @escaping (_ info:String) -> Void) {
        self.name = name
        self.toggle = toggle
        self.error = error
        self.keyboardShortcutName = KeyboardShortcuts.Name(rawValue: name)!
    }
    
    func doShortcuts() {
        let _ = runShortcut(name: self.name).runAppleScript(isShellCMD: true).0
    }
    
}

class ShortcutsSettingVM:ObservableObject {
    static let shared = ShortcutsSettingVM()
    @Published var shortcutsList : [ShorcutsItem] = [ShorcutsItem]()
    @Published var errorInfo = ""
    @Published var showErrorToast = false
    @Published var sharedShortcutsList:[SharedShortcutsItem] = [SharedShortcutsItem]()

    
    func loadShortcutsList() {
        DispatchQueue.main.async {
            let result = getShortcutsList.runAppleScript(isShellCMD: true)
            if result.0 {
                let allshortcuts = (result.1 as! String).split(separator: "\r")
                let shortcutsDic = UserDefaults.standard.dictionary(forKey: shorcutsDicKey)
                var newShortcutsDic:[String:Bool] = [String:Bool]()
                if let shortcutsDic = shortcutsDic {
                    self.shortcutsList = [ShorcutsItem]()
                    for name in allshortcuts {
                        if let toggle = shortcutsDic[String(name)] as? Bool {
                            self.addItem(name: String(name), toggle: toggle)
                            newShortcutsDic[String(name)] = toggle
                        } else {
                            self.addItem(name: String(name), toggle: false)
                            newShortcutsDic[String(name)] = false
                        }
                    }
                } else {
                    self.shortcutsList = allshortcuts.map{ ShorcutsItem(name: String($0), toggle: false, error: {[weak self] info in
                        guard let strongSelf = self else {return}
                        strongSelf.errorInfo = info
                        strongSelf.showErrorToast = true
                    }) }
                    for name in allshortcuts {
                        newShortcutsDic[String(name)] = false
                    }
                }
                
                UserDefaults.standard.set(newShortcutsDic, forKey: shorcutsDicKey)
                UserDefaults.standard.synchronize()
            }
        }
        
    }
    
    func addItem(name:String, toggle:Bool) {
        self.shortcutsList.append(ShorcutsItem(name: String(name), toggle: toggle, error: {[weak self] info in
            guard let strongSelf = self else {return}
            strongSelf.errorInfo = info
            strongSelf.showErrorToast = true
        }))
    }
    
    func getAllInstalledShortcutName() -> [String]? {
        let result = getShortcutsList.runAppleScript(isShellCMD: true)
        if result.0 {
            let allshortcuts = (result.1 as! String).split(separator: "\r")
            return allshortcuts.map{String($0)}
        }
        return nil
    }
    
    
    
    func checkIfInstalled() {
        let installedShortcuts = getAllInstalledShortcutName()
        guard let installedShortcuts = installedShortcuts else {
            return
        }

        for item in sharedShortcutsList {
            if installedShortcuts.contains(item.shortcutInfo.name) {
                item.hasInstalled = true
            }
        }
        objectWillChange.send()
    }
    
    func loadData() {
        let request = AF.request("https://raw.githubusercontent.com/jacklandrin/OnlySwitch/main/OnlySwitch/ShortcutsMarket/ShortcutsMarket.json")
        request.responseDecodable(of:[ShortcutOnMarket].self) { response in
            guard let list = response.value else {
                self.loadDataFromLocal()
                return
            }
            self.sharedShortcutsList = list.map{SharedShortcutsItem(shortcutInfo: $0)}
            self.checkIfInstalled()
        }
        
        guard let url = Bundle.main.url(forResource: "ShortcutsMarket", withExtension: "json") else {
            print("json file not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let allShortcutsOnMarket = try JSONDecoder().decode([ShortcutOnMarket].self, from: data)
            self.sharedShortcutsList = allShortcutsOnMarket.map{SharedShortcutsItem(shortcutInfo: $0)}
            self.checkIfInstalled()
        } catch {
            print("json convert failed")
        }
        
    }
    
    
    func loadDataFromLocal() {
        
    }
}

class SharedShortcutsItem:ObservableObject {
    let shortcutInfo:ShortcutOnMarket
    @Published var hasInstalled = false
    init(shortcutInfo:ShortcutOnMarket) {
        self.shortcutInfo = shortcutInfo
    }
}

struct ShortcutOnMarket:Codable, Identifiable {
    enum CodingKeys:CodingKey {
        case name
        case link
        case author
        case description
    }
    var id = UUID()
    var name:String
    var link:String
    var author:String
    var description: String
}
