import SwiftUI

// MARK: - Asset Type
enum AssetType: String, Codable {
    case image
    case video
}

// MARK: - Header Asset
struct HeaderAsset: Codable, Equatable {
    let fileName: String
    let type: AssetType

    /// Returns the file extension based on asset type
    var fileExtension: String {
        switch type {
        case .video: return "mp4"
        case .image: return "jpg"
        }
    }

    /// Returns just the base name without extension
    var baseName: String {
        fileName
    }
}

// MARK: - Header Style Assets
struct HeaderStyleAssets: Codable, Equatable {
    let home: HeaderAsset
    let familyAndFriends: HeaderAsset
    let medications: HeaderAsset
    let appointments: HeaderAsset
    let defaultHeader: HeaderAsset
    // Detail page assets
    let profileDetail: HeaderAsset
    let appointmentDetail: HeaderAsset
    let contactDetail: HeaderAsset
    let medicationDetail: HeaderAsset

    /// Get the asset for a specific page
    func asset(for page: PageIdentifier) -> HeaderAsset {
        switch page {
        case .home:
            return home
        case .profiles:
            return familyAndFriends
        case .medications:
            return medications
        case .appointments:
            return appointments
        case .profileDetail:
            return profileDetail
        case .appointmentDetail:
            return appointmentDetail
        case .contactDetail:
            return contactDetail
        case .medicationDetail:
            return medicationDetail
        case .birthdays, .contacts, .notes, .mood, .todoLists, .todoDetail, .settings, .stickyReminders:
            return defaultHeader
        }
    }
}

// MARK: - Header Style
struct HeaderStyle: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let defaultAccentColorHex: String
    let assets: HeaderStyleAssets

    /// Returns the default accent color as a SwiftUI Color
    var defaultAccentColor: Color {
        Color(hex: defaultAccentColorHex)
    }

    /// Returns the preview image name for the style picker
    var previewImageName: String {
        "\(id)_preview"
    }
}

// MARK: - Predefined Header Styles
extension HeaderStyle {
    /// All available header styles
    static let allStyles: [HeaderStyle] = [
        styleOne,
        styleTwo,
        styleThree,
        styleFour
    ]

    /// Default style (Style One)
    static let defaultStyle = styleOne

    /// Style One - Yellow accent
    static let styleOne = HeaderStyle(
        id: "style_one",
        name: "Style One",
        defaultAccentColorHex: "FFC93A", // Yellow
        assets: HeaderStyleAssets(
            home: HeaderAsset(fileName: "style_one_home", type: .video),
            familyAndFriends: HeaderAsset(fileName: "style_one_family", type: .image),
            medications: HeaderAsset(fileName: "style_one_medications", type: .image),
            appointments: HeaderAsset(fileName: "style_one_appointments", type: .image),
            defaultHeader: HeaderAsset(fileName: "style_one_default", type: .image),
            profileDetail: HeaderAsset(fileName: "style_one_profile_detail", type: .image),
            appointmentDetail: HeaderAsset(fileName: "style_one_appointment_detail", type: .image),
            contactDetail: HeaderAsset(fileName: "style_one_contact_detail", type: .image),
            medicationDetail: HeaderAsset(fileName: "style_one_medication_detail", type: .image)
        )
    )

    /// Style Two - Orange accent
    static let styleTwo = HeaderStyle(
        id: "style_two",
        name: "Style Two",
        defaultAccentColorHex: "FF9F0A", // Orange
        assets: HeaderStyleAssets(
            home: HeaderAsset(fileName: "style_two_home", type: .video),
            familyAndFriends: HeaderAsset(fileName: "style_two_family", type: .image),
            medications: HeaderAsset(fileName: "style_two_medications", type: .image),
            appointments: HeaderAsset(fileName: "style_two_appointments", type: .image),
            defaultHeader: HeaderAsset(fileName: "style_two_default", type: .image),
            profileDetail: HeaderAsset(fileName: "style_two_profile_detail", type: .image),
            appointmentDetail: HeaderAsset(fileName: "style_two_appointment_detail", type: .image),
            contactDetail: HeaderAsset(fileName: "style_two_contact_detail", type: .image),
            medicationDetail: HeaderAsset(fileName: "style_two_medication_detail", type: .image)
        )
    )

    /// Style Three - Pink accent
    static let styleThree = HeaderStyle(
        id: "style_three",
        name: "Style Three",
        defaultAccentColorHex: "f16690", // Pink
        assets: HeaderStyleAssets(
            home: HeaderAsset(fileName: "style_three_home", type: .video),
            familyAndFriends: HeaderAsset(fileName: "style_three_family", type: .image),
            medications: HeaderAsset(fileName: "style_three_medications", type: .image),
            appointments: HeaderAsset(fileName: "style_three_appointments", type: .image),
            defaultHeader: HeaderAsset(fileName: "style_three_default", type: .image),
            profileDetail: HeaderAsset(fileName: "style_three_profile_detail", type: .image),
            appointmentDetail: HeaderAsset(fileName: "style_three_appointment_detail", type: .image),
            contactDetail: HeaderAsset(fileName: "style_three_contact_detail", type: .image),
            medicationDetail: HeaderAsset(fileName: "style_three_medication_detail", type: .image)
        )
    )

    /// Style Four - Green accent
    static let styleFour = HeaderStyle(
        id: "style_four",
        name: "Style Four",
        defaultAccentColorHex: "6a863e", // Green
        assets: HeaderStyleAssets(
            home: HeaderAsset(fileName: "style_four_home", type: .video),
            familyAndFriends: HeaderAsset(fileName: "style_four_family", type: .image),
            medications: HeaderAsset(fileName: "style_four_medications", type: .image),
            appointments: HeaderAsset(fileName: "style_four_appointments", type: .image),
            defaultHeader: HeaderAsset(fileName: "style_four_default", type: .image),
            profileDetail: HeaderAsset(fileName: "style_four_profile_detail", type: .image),
            appointmentDetail: HeaderAsset(fileName: "style_four_appointment_detail", type: .image),
            contactDetail: HeaderAsset(fileName: "style_four_contact_detail", type: .image),
            medicationDetail: HeaderAsset(fileName: "style_four_medication_detail", type: .image)
        )
    )

    /// Find a style by ID
    static func style(for id: String) -> HeaderStyle? {
        allStyles.first { $0.id == id }
    }
}
