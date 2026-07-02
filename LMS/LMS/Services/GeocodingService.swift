//
//  GeocodingService.swift
//  LMS
//
//  Converts Indian pincodes to lat/long using the Nominatim (OpenStreetMap)
//  free geocoding API. Used as fallback when branch_pincodes has no match
//  and GPS location is unavailable.
//

import Foundation

struct GeocodingService {

    static let shared = GeocodingService()

    private init() {}

    /// Geocodes an Indian pincode to coordinates using Nominatim API.
    /// Returns (latitude, longitude) or nil if geocoding fails.
    func geocodePincode(_ pincode: String) async -> (latitude: Double, longitude: Double)? {
        guard !pincode.isEmpty else { return nil }

        let query = pincode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pincode
        let urlString = "https://nominatim.openstreetmap.org/search?postalcode=\(query)&country=India&format=json&limit=1"

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("LMS-iOS-App/1.0", forHTTPHeaderField: "User-Agent") // Required by Nominatim ToS
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let results = try JSONDecoder().decode([NominatimResult].self, from: data)

            guard let first = results.first,
                  let lat = Double(first.lat),
                  let lon = Double(first.lon) else { return nil }

            return (latitude: lat, longitude: lon)
        } catch {
            print("[GeocodingService] Failed to geocode pincode \(pincode): \(error)")
            return nil
        }
    }
}

// MARK: - Nominatim Response

private struct NominatimResult: Codable {
    let lat: String
    let lon: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case displayName = "display_name"
    }
}
