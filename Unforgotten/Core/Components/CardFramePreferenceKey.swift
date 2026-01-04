//
//  CardFramePreferenceKey.swift
//  Unforgotten
//
//  Created on 2025-12-19
//

import SwiftUI

struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
