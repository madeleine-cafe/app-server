import Vapor
import Fluent

enum MatchingErrors: Error {
    case incorrectNumberOfUsersMatched
    case failedToSave
}

func saveMatchingAndSendEmails(app: Application, matching: [Match]) -> EventLoopFuture<[ClientResponse]>
{
    guard let matchingSaved = try? saveMatching(app: app, matching: matching) else {
        print("Failed sending matches")
        return app.eventLoopGroup.next().makeFailedFuture(MatchingErrors.failedToSave)
    }
    
    return matchingSaved.flatMap { (matches) -> EventLoopFuture<[ClientResponse]> in
        matches.compactMap { (match) -> EventLoopFuture<ClientResponse> in
            let user1 = match.users[0]
            let user2 = match.users[1]
            let user3 = match.users.count == 3 ? match.users[2] : nil;
            
            return sendMatchingEmail(app: app, user1: user1, user2: user2, user3: user3, sharedInterests: match.sharedInterests)
        }.flatten(on: app.eventLoopGroup.next())
    }
}

func saveMatching(app: Application, matching: [Match]) throws -> EventLoopFuture<[Match]>  {
    let matches = try matching.flatMap { (match)  in
        return try match.toMatches()
    }
    
    return matches.compactMap { (match) -> EventLoopFuture<Void> in
        return match.save(on: app.db)
    }.flatten(on: app.eventLoopGroup.next()).flatMap { (Void) -> EventLoopFuture<[Match]> in
        return app.eventLoopGroup.next().makeSucceededFuture(matching)
    }
}

struct Match: Hashable {
    var sharedInterests: [Interest]
    var users: [CMUser]
    
    func toMatches() throws -> [Matches] {
        if users.count == 2 {
            return [try Matches(user1: users.first!, user2: users.last!)]
        } else if (users.count == 3) {
            return [try Matches(user1: users.first!, user2: users.last!),
                    try Matches(user1: users[1], user2: users.last!),
                    try Matches(user1: users.first!, user2: users[1])
                    ]
        }
        throw MatchingErrors.incorrectNumberOfUsersMatched
    }
}

class Matches: Model {
    static let schema = "matches"
    
    required init() {}
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "matched_at", on: .create)
    var date: Date?
    
    @Parent(key: "user1")
    var user1: CMUser
    
    @Parent(key: "user2")
    var user2: CMUser
    
    init(id: UUID? = nil, user1: CMUser, user2: CMUser) throws {
        self.id = id
        self.$user1.id = try user1.requireID()
        self.$user2.id = try user2.requireID()
    }
}

