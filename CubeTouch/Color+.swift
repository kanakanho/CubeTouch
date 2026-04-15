//
//  Color+.swift
//  CubeTouch
//
//  Created by blueken on 2026/04/13.
//

import UIKit

enum CubeColor: String, Codable, CaseIterable {
    case black
    case darkGray
    case lightGray
    case white
    case gray
    case red
    case green
    case blue
    case cyan
    case yellow
    case magenta
    case orange
    case purple
    case brown
    case clear

    // MARK: - UIColor への変換
    var uiColor: UIColor {
        switch self {
            case .black: return .black
            case .darkGray: return .darkGray
            case .lightGray: return .lightGray
            case .white: return .white
            case .gray: return .gray
            case .red: return .red
            case .green: return .green
            case .blue: return .blue
            case .cyan: return .cyan
            case .yellow: return .yellow
            case .magenta: return .magenta
            case .orange: return .orange
            case .purple: return .purple
            case .brown: return .brown
            case .clear: return .clear
        }
    }
}
