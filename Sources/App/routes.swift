import Vapor
import Fluent

struct AccountUpdateMessage: Content {
    var name: String
}

struct SignupMessage: Content {
    var email: String
    var name: String
    var interests: [String]
    var discipline: String
    var year: String
}

extension String {
    func decodeURLData() -> Data? {
        var tokenString = self
        tokenString = tokenString.replacingOccurrences(of: "-", with: "+")
        tokenString = tokenString.replacingOccurrences(of: "_", with: "/")
        while tokenString.count % 4 != 0 {
            tokenString = tokenString.appending("=")
        }
        guard let data = Data(base64Encoded: tokenString) else {
            return nil
        }
        
        guard data.count == 16 else {
            return nil
        }
        
        return data
    }
}

extension SignupMessage: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

func routes(_ app: Application) throws {
    app.get("allow_listed_email_suffixes") { req -> EventLoopFuture<[String]> in
        let classGroups = ClassGroup.query(on: req.db).all()
        
        return classGroups.flatMap {
            return req.eventLoop.makeSucceededFuture(Array(Set($0.compactMap { return $0.email_suffix })))
        }
    }
    
    app.get("signup_options", ":domain") { req -> EventLoopFuture<Dictionary<String,Array<String>>> in
        let classGroups = ClassGroup.query(on: req.db)
            .filter(\.$email_suffix == req.parameters.get("domain")!).all()
        
        return classGroups.flatMap { (groups) -> EventLoopFuture<Dictionary<String,Array<String>>> in
            var disciplines  = Array<String>()
            var school_years = Array<String>()
            
            _ = groups.map {
                disciplines.append($0.discipline)
                school_years.append($0.year)
            }
            
            return Interest.query(on: req.db).all().flatMap { (interests) -> EventLoopFuture<Dictionary<String,Array<String>>> in
                return req.eventLoop.makeSucceededFuture(["disciplines": Array(Set(disciplines)).sorted(),
                                                          "interests": interests.compactMap { $0.name },
                                                          "school_years": Array(Set(school_years)).sorted()])
            }
        }
    }
    
    func lookupClassGroup(signupMessage:SignupMessage, on req: Request) -> EventLoopFuture<ClassGroup?>{
        guard let domain = signupMessage.email.components(separatedBy: "@").last else {
            print("Invalid email")
            return req.eventLoop.makeSucceededFuture(nil)
        }
        return ClassGroup.query(on: req.db)
            .filter(\.$email_suffix == domain)
            .filter(\.$discipline == signupMessage.discipline)
            .filter(\.$year == signupMessage.year).first()
    }
    
    app.post("signup") { req -> EventLoopFuture<HTTPStatus> in
        try SignupMessage.validate(content: req)
        guard let signup = try? req.content.decode(SignupMessage.self) else {
            return req.eventLoop.makeSucceededFuture(HTTPStatus.badRequest)
        }
        
        print("Received a signup request: \(signup)")
        
        let email = signup.email
        
        let classGroup = lookupClassGroup(signupMessage: signup, on: req)
        return classGroup.flatMap { (group) -> EventLoopFuture<HTTPStatus> in
            guard let group = group else {
                return req.eventLoop.makeSucceededFuture(HTTPStatus.badRequest)
            }
            
            return CMUser.query(on: req.db).filter(\.$email == email).count().flatMap { (count) -> EventLoopFuture<HTTPStatus> in
                if count > 0 {
                    return req.eventLoop.makeSucceededFuture(HTTPStatus.conflict)
                } else {
                    return Interest.interestsFromList(names: signup.interests, on: req.db).flatMap { (interests) -> EventLoopFuture<HTTPStatus> in
                        let user = try! CMUser(name: signup.name,
                                               email: signup.email,
                                               classGroup: group)
                        
                        user.sendConfirmationEmail(app: req.application)
                        
                        _ = user.save(on: req.db).whenSuccess({
                            (interests.filter { $0 != nil }.compactMap {$0!}.map({ (interest) in
                                user.$interests.attach(interest, on: req.db)
                            }))
                        })

                        return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
                    }
                }
            }
        }
    }
    
    app.get("account", "auth", ":email") { req -> EventLoopFuture<HTTPStatus> in
        return CMUser.query(on: req.db).filter(\.$email == req.parameters.get("email")!).first().flatMap { (user) -> EventLoopFuture<HTTPStatus> in
            if let user = user {
                _ = sendAccountManagementEmail(app: app, user: user)
            }
            return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
        }
    }
    
    app.get("account", ":token") { req -> EventLoopFuture<Dictionary<String,String>> in
        
        guard let tokenData = req.parameters.get("token")!.decodeURLData() else {
            return req.eventLoop.makeFailedFuture(SadMadeleines.unauthorized)
        }
        
        return CMUser.query(on: req.db).filter(\.$email_validation_token == tokenData).first().flatMap { (user) -> EventLoopFuture<Dictionary<String, String>> in
            guard let user = user else {
                return req.eventLoop.makeFailedFuture(SadMadeleines.noToken)
            }
            
            return req.eventLoop.makeSucceededFuture(["name": user.name])
        }
    }
    
    app.post("account", "update", ":token") { req -> EventLoopFuture<HTTPStatus> in
        guard let tokenData = req.parameters.get("token")!.decodeURLData() else {
            return req.eventLoop.makeSucceededFuture(HTTPStatus.unauthorized)
        }
        
        guard let accountUpdate = try? req.content.decode(AccountUpdateMessage.self) else {
            return req.eventLoop.makeSucceededFuture(HTTPStatus.badRequest)
        }
        
        return CMUser.query(on: req.db).filter(\.$email_validation_token == tokenData).first().flatMap { (user) -> EventLoopFuture<HTTPStatus> in
            guard let user = user else {
                return req.eventLoop.makeFailedFuture(SadMadeleines.noToken)
            }
            
            user.name = accountUpdate.name
            _ = user.save(on: req.db)
            
            return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
        }
    }
    
    app.get("account", "delete", ":token") { req -> EventLoopFuture<HTTPStatus> in
        guard let tokenData = req.parameters.get("token")!.decodeURLData() else {
            return req.eventLoop.makeSucceededFuture(HTTPStatus.unauthorized)
        }
        
        return CMUser.query(on: req.db).filter(\.$email_validation_token == tokenData).first().flatMap { (user) -> EventLoopFuture<HTTPStatus> in
            guard let user = user else {
                return req.eventLoop.makeFailedFuture(SadMadeleines.noToken)
            }
            
            return user.$interests.get(on: app.db).flatMap { (interests) -> EventLoopFuture<Void> in
                user.$interests.detach(interests, on: app.db)
            }.flatMap { user.delete(on: app.db) }.flatMap{ req.eventLoop.makeSucceededFuture(HTTPStatus.ok) }
        }
    }
    
    
    
    app.get("account","activate", ":token") { req -> EventLoopFuture<HTTPStatus> in
        guard let tokenData = req.parameters.get("token")!.decodeURLData() else {
            return req.eventLoop.makeFailedFuture(SadMadeleines.unauthorized)
        }
        
        return CMUser.query(on: req.db).filter(\.$email_validation_token == tokenData).first().flatMap { (user) -> EventLoopFuture<HTTPStatus> in
            guard let user = user else {
                return req.eventLoop.makeFailedFuture(SadMadeleines.noToken)
            }
            
            user.emailIsVerified = true
            return user.save(on: req.db).flatMap{ return req.eventLoop.makeSucceededFuture(HTTPStatus.ok) }
        }
    }
    
    app.get("account", "delete", "token") { req -> EventLoopFuture<HTTPStatus> in
        var tokenString = req.parameters.get("token")!
        
        guard let tokenData = tokenString.decodeURLData() else {
            return req.eventLoop.makeFailedFuture(SadMadeleines.unauthorized)
        }
        
        return CMUser.query(on: req.db).filter(\.$email_validation_token == tokenData).first().flatMap { (user) -> EventLoopFuture<HTTPStatus> in
            return user!.delete(on: req.db).flatMap { () -> EventLoopFuture<HTTPStatus> in
                return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
            }
        }
    }
    
}

enum SadMadeleines: Error {
    case unauthorized
    case noToken
}
