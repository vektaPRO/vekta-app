import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionViewModel()

    var body: some View {
        Group {
            if let role = session.currentUserRole {
                switch role {
                case "SuperAdmin":
                    SuperAdminDashboard()
                case "FulfillmentAdmin":
                    FulfillmentDashboard()
                case "Seller":
                    SellerDashboard()
                case "Courier":
                    CourierDashboard()
                default:
                    Text("Неизвестная роль")
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            session.fetchUserRole()
        }
    }
}
