//
//  LocationService.swift
//  LMS
//
//  CoreLocation wrapper for fetching the user's GPS coordinates.
//  Used for nearest-branch assignment when pincode matching fails.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

@MainActor
class LocationService: NSObject, ObservableObject {

    static let shared = LocationService()

    // MARK: - Published State

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    // MARK: - Init

    private override init() {
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // City-level is fine
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public API

    /// Requests location permission from the user
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Fetches the current location as a one-shot request.
    /// Returns nil if permission is denied or location is unavailable.
    func fetchCurrentLocation() async -> CLLocationCoordinate2D? {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            requestPermission()
            // Wait briefly for the user to respond to the permission prompt
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let newStatus = locationManager.authorizationStatus
            guard newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways else {
                return nil
            }
        case .denied, .restricted:
            return nil
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    /// Returns true if the user has granted location permission
    var hasPermission: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: @preconcurrency CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location.coordinate
            self.locationError = nil
            self.locationContinuation?.resume(returning: location.coordinate)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error.localizedDescription
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
