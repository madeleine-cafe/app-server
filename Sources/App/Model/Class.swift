import Fluent
import Vapor

final class ClassGroup: Model {
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
