import SwiftUI
import UIKit

/// Colour tokens for ORPHEUS.
///
/// These deliberately lean on system semantic colours rather than fixed hex
/// values. Doing so means Dark Mode, Increased Contrast, and Smart Invert are
/// handled by the platform instead of being approximated here — and it keeps the
/// app from drifting into the flat web-dashboard palette the brief rules out.
///
/// The only bespoke colour is the accent, which lives in the asset catalog so it
/// also tints the app icon and system controls.
enum OrpheusColor {

    /// Indigo, from `AccentColor` in the asset catalog.
    static let accent = Color.accentColor

    // MARK: Surfaces

    /// The page behind everything. Content sits on this.
    static let canvas = Color(uiColor: .systemGroupedBackground)

    /// Raised content surfaces: rows, cards, sheets.
    static let raised = Color(uiColor: .secondarySystemGroupedBackground)

    /// A surface raised above `raised`, used sparingly.
    static let elevated = Color(uiColor: .tertiarySystemGroupedBackground)

    // MARK: Text

    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)

    // MARK: Lines

    static let hairline = Color(uiColor: .separator)

    // MARK: Semantic

    /// Used for destructive confirmation, never for decoration.
    static let destructive = Color(uiColor: .systemRed)

    /// Indicates locked or protected state. Paired with a symbol so the meaning
    /// never depends on colour alone (Differentiate Without Color).
    static let locked = Color(uiColor: .systemIndigo)
}
