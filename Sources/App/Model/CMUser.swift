import Fluent
import Vapor
import Mailgun

final class CMUser: Model {
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
