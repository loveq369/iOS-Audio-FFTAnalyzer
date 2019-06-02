//
//  Utils.swift
//  Sine Graph
//
//  Created by Shahar Ben-Dor on 1/28/19.
//  Copyright © 2019 Specter. All rights reserved.
//

import Foundation

class MathUtils {
    public static func map(fromMin: Double, fromMax: Double, toMin: Double, toMax: Double, value: Double) -> Double {
        let valueToScale = (value - fromMin) / (fromMax - fromMin)
        return (valueToScale * (toMax - toMin)) + toMin
    }
}
