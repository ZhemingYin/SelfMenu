//
//  Item.swift
//  SelfMenu
//
//  Created by 尹哲铭 on 19.11.25.
//

import Foundation
import SwiftData

@Model
final class MenuItems {
    var id: UUID = UUID()
    var MenuImageData: Data? = nil
    var MenuIndex: Int = 0
    var MenuName: String = "Unknown"
    var MenuMaterials: [String] = []
    var MenuSteps: [String] = []
    
    init(MenuImageData: Data? = nil, MenuIndex: Int, MenuName: String, MenuMaterials: [String], MenuSteps: [String]) {
        self.MenuImageData = MenuImageData
        self.MenuIndex = MenuIndex
        self.MenuName = MenuName
        self.MenuMaterials = MenuMaterials
        self.MenuSteps = MenuSteps
    }
}
