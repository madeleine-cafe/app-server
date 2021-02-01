import Mailgun
import Vapor

let senderName = "Café Madeleine <no-reply@matching.madeleine.cafe>";

func sendMatchingEmail(app: Application,
                       user1: CMUser,
                       user2: CMUser) -> EventLoopFuture<ClientResponse> {
    let message = MailgunTemplateMessage (
        from: senderName,
        to: [user1.email, user2.email],
        replyTo: "\(user1.email), \(user2.email)",
        subject: "☕️ Programmez votre Madeleine Café !",
        template: "matching-email",
        templateData: ["personne1": user1.name,
                       "personne2": user2.name]
    )
    return app.mailgun().send(message)
}

func sendSignupEmail(app: Application, user: CMUser) -> EventLoopFuture<ClientResponse>
{
    let message = MailgunTemplateMessage (
        from: senderName,
        to: user.email,
        subject: "☕️ Confirmez votre inscription !",
        template: "signup",
        templateData: ["username": user.name,
                       "signup_url": user.getActivationURL()]
    )
    return app.mailgun().send(message)
}

func sendAccountManagementEmail(app: Application, user: CMUser) -> EventLoopFuture<ClientResponse>
{
    let message = MailgunTemplateMessage (
        from: senderName,
        to: user.email,
        subject: "☕️ Gérez votre compte",
        template: "account-management",
        templateData: ["username": user.name,
                       "account_management_url": user.getAccountManagementURL()]
    )
    return app.mailgun().send(message)
}

