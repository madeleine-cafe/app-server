import Mailgun
import Vapor

let senderName = "Madeleine Café <no-reply@matching.madeleine.cafe>";

func sendMatchingEmail(app: Application,
                       user1: CMUser,
                       user2: CMUser,
                       user3: CMUser?,
                       sharedInterests: [Interest]) -> EventLoopFuture<ClientResponse> {
    let salutations:String
    let emails: [String]
    let replyTos: String
    
    if user3 == nil {
        replyTos = "\(user1.email), \(user2.email)"
        emails = [user1.email, user2.email]
        salutations = "\(user1.name) et \(user2.name)"
    } else {
        emails = [user1.email, user2.email, user3!.email]
        replyTos = "\(user1.email), \(user2.email), \(user3!.email)"
        salutations = "\(user1.name), \(user2.name) et \(user3!.name)"
    }
    
    var interestString: String
    if sharedInterests.count > 0 {
        let delimiter = ", "
        interestString = sharedInterests.reduce("Nos petites madeleines nous ont dit qu'en plus du café vous aimez: ", { (previousResult, interest) -> String in
            return previousResult.appending(interest.name + delimiter)
        })
        interestString.removeLast(delimiter.count)
        interestString.append(".")
    } else {
        interestString = ""
    }
    
    
    let templateData = ["salutations": salutations,
                        "interests": interestString,
                        "jitsi_link": JitsiMeetProvider.uniqueURLForCall()
                        ]

    let message = MailgunTemplateMessage (
        from: senderName,
        to: emails,
        replyTo: replyTos,
        subject: "☕️ Programmez votre Madeleine Café !",
        template: "matching-email",
        templateData: templateData
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

func sendSignupReminderEmail(app: Application, user: CMUser) -> EventLoopFuture<ClientResponse>
{
    let message = MailgunTemplateMessage (
        from: senderName,
        to: user.email,
        subject: "☕️ [Rappel] Confirmez votre inscription !",
        template: "signup-reminder",
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
