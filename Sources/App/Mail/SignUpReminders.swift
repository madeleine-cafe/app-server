import Vapor
import Fluent

func nonConfirmedUsers(on db: Database) -> EventLoopFuture<[CMUser]> {
    return CMUser.query(on: db).filter(\.$emailIsVerified == false).all()
}

func remindNonConfirmedEmailUsers(app: Application, eventLoopGroup: EventLoopGroup) -> EventLoopFuture<[CMUser]> {
    nonConfirmedUsers(on: app.db).flatMap { (users) -> EventLoopFuture<[CMUser]> in
        return users.compactMap { (user) -> EventLoopFuture<ClientResponse> in
            print("Sending Email to \(user.email)")
            return sendSignupReminderEmail(app: app, user: user)
        }.flatten(on: eventLoopGroup.next()).flatMap { (responses) in
            print("Sending reminder emails was successful.")
            return eventLoopGroup.next().makeSucceededFuture(users)
        }
    }
}
