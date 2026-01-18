import SwiftUI
import PhotosUI
import UIKit

@available(iOS 16.0, *)
struct MissingPersonView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var personName = ""
    @State private var lastSeenLocation = ""
    @State private var lastSeenTime = ""
    @State private var physicalDescription = ""
    @State private var contactInfo = ""
    @State private var showingSentAlert = false

    // Photo picker state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        Form {
            // Photo section
            Section("Photo") {
                VStack(spacing: 16) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 120, height: 120)

                            VStack(spacing: 8) {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.black.opacity(0.3))
                                Text("Add photo")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text(selectedImage == nil ? "Select photo" : "Change photo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                    .onChange(of: selectedPhotoItem) { newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                // Resize image to reduce size for mesh transmission
                                selectedImage = resizeImage(image, maxSize: 300)
                            }
                        }
                    }

                    Text("Photo will be compressed for transmission")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Person details") {
                TextField("Full name", text: $personName)
                TextField("Last seen location", text: $lastSeenLocation)
                TextField("Last seen time", text: $lastSeenTime)
            }

            Section("Physical description") {
                TextEditor(text: $physicalDescription)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if physicalDescription.isEmpty {
                            Text("Height, clothing, distinguishing features...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("Contact information") {
                TextField("Phone or other contact", text: $contactInfo)
                    .keyboardType(.phonePad)
            }

            Section {
                Button {
                    sendMissingPerson()
                } label: {
                    HStack {
                        Spacer()
                        Text("Broadcast alert")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(personName.isEmpty || physicalDescription.isEmpty)
            }
        }
        .navigationTitle("Missing person")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Alert sent", isPresented: $showingSentAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("Missing person alert has been broadcast to the mesh network.")
        }
    }

    private func sendMissingPerson() {
        // Convert image to base64 if available
        var photoBase64: String? = nil
        if let image = selectedImage,
           let imageData = image.jpegData(compressionQuality: 0.5) {
            photoBase64 = imageData.base64EncodedString()
        }

        viewModel.meshService.sendMissingPerson(
            name: personName,
            lastSeenLocation: lastSeenLocation,
            lastSeenTime: lastSeenTime,
            description: physicalDescription,
            contactInfo: contactInfo,
            photoBase64: photoBase64
        )
        showingSentAlert = true
    }

    /// Resizes an image to fit within a max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)

        if ratio >= 1 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
