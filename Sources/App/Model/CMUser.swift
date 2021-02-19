import Fluent
import Vapor
import Mailgun

/// Represents a user of Madeleine Cafe
final class CMUser: Model, Hashable {
    static func == (lhs: CMUser, rhs: CMUser) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    init() {}
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "group")
    var group: ClassGroup
    
    @Field(key: "name")
    var name: String
    
    @Siblings(through: UserInterests.self, from: \.$user, to: \.$interest)
    public var interests: [Interest]
    
    @Siblings(through: Matches.self, from: \.$user1, to:\.$user2)
    public var previousMatches: [CMUser]
    
    @Siblings(through: Matches.self, from: \.$user2, to:\.$user1)
    public var previousMatched: [CMUser]
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "email_verified")
    var emailIsVerified: Bool
    
    @Field(key: "email_validation_token")
    var email_validation_token: Data
    
    init(id: UUID? = UUID(),
         name: String,
         email: String,
         classGroup: ClassGroup) throws {
        self.id = id
        self.name = name
        self.email = email
        self.$group.id = try classGroup.requireID()
        self.emailIsVerified = false
        self.email_validation_token = Data([UInt8].random(count: 16))
    }
    
    func getToken() -> String {
        var result = self.email_validation_token.base64EncodedString()
        result = result.replacingOccurrences(of: "+", with: "-")
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "=", with: "")
        return result
    }
    
    func getAccountManagementURL() -> String {
        return "https://www.madeleine.cafe/compte?token=\(getToken())"
    }
    
    func getActivationURL() -> String {
        return getAccountManagementURL().appending("&action=activer")
    }
    
    func sendConfirmationEmail(app: Application) {
        let emailStatus = sendSignupEmail(app: app, user: self)
        
        emailStatus.whenSuccess { (emailstatus) in
            print("Signup email sent to \(self.email)")
        }
        emailStatus.whenFailure { (emailstatus) in
            print("Signup email failed to send to \(self.email) with error \(emailstatus)")
        }
    }
}

extension CMUser: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("name", as: String.self, is: .alphanumeric)
    }
}

extension CMUser {
    func deleteUserAndAssociatedData(_ req: Request) -> EventLoopFuture<HTTPStatus> {
        self.$interests.get(on: req.db).flatMap { (interests) -> EventLoopFuture<Void> in
            if (interests.count > 0) { return self.$interests.detach(interests, on: req.db) }
            return req.eventLoop.next().makeSucceededFuture(Void())
        }.flatMap {
            return self.loadPreviousMatches(app: req.application, eventLoopGroup: req.eventLoop.next())
        }.flatMap {
            if (self.previousMatches.count > 0) { return self.$previousMatches.detach(self.previousMatches, on: req.db)}
            return req.eventLoop.next().makeSucceededFuture(Void())
        }.flatMap {
            if (self.previousMatched.count > 0) { return self.$previousMatched.detach(self.previousMatched, on: req.db) }
            return req.eventLoop.next().makeSucceededFuture(Void())
        }.flatMap { self.delete(on: req.db) }.flatMap{ req.eventLoop.makeSucceededFuture(HTTPStatus.ok)}
    }
    
    func wasAlreadyMatchedWith(user: CMUser) -> Bool {
        return Set(self.pastMatches()).contains(user)
    }
    
    func pastMatches() -> [CMUser] {
        var array = Array(self.previousMatched)
        array.append(contentsOf: self.previousMatches)
        return array
    }
    
    func exclusionCounts() -> Int {
        self.previousMatched.count + self.previousMatches.count
    }
    
    func loadPreviousMatches(app: Application, eventLoopGroup: EventLoopGroup) -> EventLoopFuture<Void> {
        return self.$previousMatches.load(on: app.db).flatMap { (result) in
            return self.$previousMatched.load(on: app.db).flatMap {
                return eventLoopGroup.next().makeSucceededFuture(Void())
            }
        }
    }
}
