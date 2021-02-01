import Vapor
import Fluent

final class UserInterests: Model {
    static let schema = "users+interests"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: CMUser

    @Parent(key: "interest_id")
    var interest: Interest

    init() { }

    init(id: UUID? = nil, user: CMUser, interest: Interest) throws {
        self.id = id
        self.$user.id = try user.requireID()
        self.$interest.id = try interest.requireID()
    }
}
