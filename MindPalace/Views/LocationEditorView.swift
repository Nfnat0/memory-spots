import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let photo: MemoryPhoto

    @State private var cameraPosition: MapCameraPosition
    @State private var draftCoordinate: CLLocationCoordinate2D?

    init(photo: MemoryPhoto) {
        self.photo = photo
        let coordinate = if let latitude = photo.latitude, let longitude = photo.longitude {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            CLLocationCoordinate2D(latitude: 35.6264, longitude: 139.7235)
        }
        _draftCoordinate = State(initialValue: photo.latitude.flatMap { latitude in
            photo.longitude.map { longitude in
                CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        })
        _cameraPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        if let draftCoordinate {
                            Marker("This Place", coordinate: draftCoordinate)
                        }
                    }
                    .mapControls {
                        MapCompass()
                        MapUserLocationButton()
                    }
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let coordinate = proxy.convert(value.location, from: .local) {
                                    draftCoordinate = coordinate
                                }
                            }
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(photo.title)
                        .font(.headline)
                    if let draftCoordinate {
                        Text("Latitude \(draftCoordinate.latitude.formatted(.number.precision(.fractionLength(5)))) / Longitude \(draftCoordinate.longitude.formatted(.number.precision(.fractionLength(5))))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tap the map to place a waypoint. It is fine to leave it empty.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("Place Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Remove Location") {
                        draftCoordinate = nil
                    }
                    .disabled(draftCoordinate == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        photo.latitude = draftCoordinate?.latitude
                        photo.longitude = draftCoordinate?.longitude
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
