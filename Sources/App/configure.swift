import Vapor
import Fluent
import FluentPostgresDriver
import Mailgun

extension MailgunDomain {
    static var madeleineCafeMatching: MailgunDomain { .init("matching.madeleine.cafe", .eu) }
}

extension Application {
    static let databaseUrl = URL(string: Environment.get("DB_URL")!)!
}

// configures your application
public func configure(_ app: Application) throws {
    
    // register routes
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)

    // Only add this if you want to enable the default per-route logging
    let routeLogging = RouteLoggingMiddleware(logLevel: .info)

    // Add the default error middleware
    let error = ErrorMiddleware.default(environment: app.environment)
    // Clear any existing middleware.
    app.middleware = .init()
    app.middleware.use(cors)
    app.middleware.use(routeLogging)
    app.middleware.use(error)
    
    try app.databases.use(.postgres(url: Application.databaseUrl), as: .psql)
    
    app.mailgun.configuration = .environment
    app.mailgun.defaultDomain = .madeleineCafeMatching
    
    try routes(app)
}
