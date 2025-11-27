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
    var MenuMaterialNames: [String] = []
    var MenuMaterialCounts: [String] = []
    var MenuMaterialComments: [String] = []
    var MenuSteps: [String] = []
    var MenuStepAlarm: [Int?] = []
    var MenuStepImageData: [Data?] = []
    var Cookingtimes: Int = 0
    var MeanCookingTime: Int = 0    // in seconds
    
    init(MenuImageData: Data? = nil, MenuIndex: Int, MenuName: String, MenuMaterialNames: [String], MenuMaterialCounts: [String], MenuMaterialComments: [String], MenuSteps: [String], MenuStepAlarm: [Int?], MenuStepImageData: [Data?], Cookingtimes: Int, MeanCookingTime: Int) {
        self.MenuImageData = MenuImageData
        self.MenuIndex = MenuIndex
        self.MenuName = MenuName
        self.MenuMaterialNames = MenuMaterialNames
        self.MenuMaterialCounts = MenuMaterialCounts
        self.MenuMaterialComments = MenuMaterialComments
        self.MenuSteps = MenuSteps
        self.MenuStepAlarm = MenuStepAlarm
        self.MenuStepImageData = MenuStepImageData
        self.Cookingtimes = Cookingtimes
        self.MeanCookingTime = MeanCookingTime
    }
}
