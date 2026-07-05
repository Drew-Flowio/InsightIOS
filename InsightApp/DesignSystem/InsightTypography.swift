import SwiftUI

enum InsightTypography {
    static func title() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }

    static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    static func bodyMedium() -> Font {
        .system(size: 16, weight: .medium, design: .default)
    }

    static func caption() -> Font {
        .system(size: 13, weight: .medium, design: .default)
    }

    static func micro() -> Font {
        .system(size: 11, weight: .semibold, design: .rounded)
    }

    static func composer() -> Font {
        .system(size: 17, weight: .regular, design: .default)
    }
}
