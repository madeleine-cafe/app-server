import Fluent
import Vapor

/// Represents a group of users that can be matched together
final class ClassGroup: Model, Hashable {
    static func == (lhs: ClassGroup, rhs: ClassGroup) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    init() {}
    static let schema = "classgroup"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "year")
    var year: String
    
    @Field(key: "discipline")
    var discipline: String
    
    @Field(key: "email_suffix")
    var email_suffix: String
    
    init(year: String, discipline: String, email_suffix: String) {
        self.discipline = discipline
        self.email_suffix = email_suffix
        self.year = year
        self.id = UUID()
    }
}
