import SwiftUI
import ContactsUI
import Contacts

/// SwiftUI wrapper around Apple's `CNContactPickerViewController`.
///
/// The picker is sandboxed by iOS — the app only ever receives the contacts the
/// user explicitly selected, never the full address book. This means no
/// `NSContactsUsageDescription` permission prompt is required.
struct ContactsPicker: UIViewControllerRepresentable {
    /// Called when the user finishes picking. An empty array means the user cancelled.
    let onComplete: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // No predicateForSelectionOfContact — gives us multi-select with the
        // standard "Done" button and a "Cancel" button.
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onComplete: ([CNContact]) -> Void

        init(onComplete: @escaping ([CNContact]) -> Void) {
            self.onComplete = onComplete
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onComplete([])
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onComplete(contacts)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onComplete([contact])
        }
    }
}

/// Plain-data extract of a CNContact's relevant fields, decoupled from the
/// Contacts framework so review screens don't depend on it.
struct ImportedContact: Identifiable, Equatable {
    let id = UUID()
    var fullName: String
    var phone: String?
    var email: String?
    var address: String?

    init(from contact: CNContact) {
        let given = contact.givenName.trimmingCharacters(in: .whitespaces)
        let family = contact.familyName.trimmingCharacters(in: .whitespaces)
        let composed = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        if !composed.isEmpty {
            self.fullName = composed
        } else if !contact.organizationName.isEmpty {
            self.fullName = contact.organizationName
        } else {
            self.fullName = ""
        }

        self.phone = contact.phoneNumbers.first?.value.stringValue
        self.email = contact.emailAddresses.first?.value as String?

        if let postal = contact.postalAddresses.first?.value {
            let parts = [
                postal.street,
                postal.city,
                postal.state,
                postal.postalCode,
                postal.country
            ].filter { !$0.isEmpty }
            self.address = parts.isEmpty ? nil : parts.joined(separator: ", ")
        } else {
            self.address = nil
        }
    }
}
