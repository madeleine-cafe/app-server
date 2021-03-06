import Fluent
import Vapor

/// Represents an interest that a user can have.
final class Interest: Model, Hashable {
    static func == (lhs: Interest, rhs: Interest) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func interestsFromList(names:[String], on db: Database) -> EventLoopFuture<[Interest?]> {
        return names.map { return interestFromName(db: db, name: $0) }.flatten(on: db.eventLoop)
    }
    
    static func interestFromName(db: Database, name: String) -> EventLoopFuture<Interest?> {
        return Interest.query(on: db).filter(\.$name == name).first()
    }
    
    init() {}
    static let schema = "interests"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    init(id: UUID? = UUID(),
         name: String) throws {
        self.id = id
        self.name = name
    }
}
