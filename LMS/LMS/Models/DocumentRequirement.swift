import Foundation

struct DocumentRequirement: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var isMandatory: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isMandatory = "is_mandatory"
    }
    
    init(name: String, isMandatory: Bool = true) {
        self.name = name
        self.isMandatory = isMandatory
    }
    
    init(from decoder: Decoder) throws {
        // Fallback for older data where it was just an array of Strings
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self.name = string
            self.isMandatory = true
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.isMandatory = try container.decode(Bool.self, forKey: .isMandatory)
            if let id = try? container.decode(UUID.self, forKey: .id) {
                self.id = id
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isMandatory, forKey: .isMandatory)
    }
}
