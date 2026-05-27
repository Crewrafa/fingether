import Foundation
import UserNotifications
import Supabase

// MARK: - Notification Service

enum NotificationService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Request Permission

    /// Solicita permiso para enviar notificaciones push
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Get Notifications

    /// Obtiene las notificaciones del usuario
    static func getNotifications(userId: UUID) async throws -> [AppNotification] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockNotifications(userId: userId)
        }

        let notifications: [AppNotification] = try await client
            .from("notifications")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value

        return notifications
    }

    // MARK: - Mark as Read

    /// Marca una notificación como leída
    static func markAsRead(notificationId: UUID) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.markMockNotificationAsRead(notificationId: notificationId)
            return
        }

        try await client
            .from("notifications")
            .update(["is_read": AnyJSON.bool(true)])
            .eq("id", value: notificationId.uuidString)
            .execute()
    }

    // MARK: - Get Unread Count

    /// Obtiene la cantidad de notificaciones sin leer
    static func getUnreadCount(userId: UUID) async throws -> Int {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockUnreadCount(userId: userId)
        }

        let notifications: [AppNotification] = try await client
            .from("notifications")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute()
            .value

        return notifications.count
    }

    // MARK: - Schedule Local Notification

    /// Programa una notificación local
    static func scheduleLocalNotification(title: String, body: String, date: Date) async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Silently handle — notification scheduling is non-critical
        }
    }
}
