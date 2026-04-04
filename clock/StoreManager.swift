import Foundation
import RevenueCat
import StoreKit
import SwiftUI
internal import Combine

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var offerings: Offerings?
    @Published private(set) var lastError: Error?
    @Published private(set) var isPro: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isSandboxMode: Bool = AppConfiguration.isTestingMode
    @Published private(set) var isRevenueCatConfigured: Bool = AppConfiguration.isRevenueCatConfigured
    @Published private(set) var allowsTesterUnlocks: Bool = AppConfiguration.allowsTesterUnlocks
    private var hasUnlockedFreePro: Bool = false
    
    private let proEntitlementID = "Haiku Pro"
    private let preferredOfferingID = "default"
    private var customerInfoTask: Task<Void, Never>?

    private var canUseTesterUnlocks: Bool {
        allowsTesterUnlocks && AppConfiguration.isTestingMode
    }

    var isTestingProEnabled: Bool {
        canUseTesterUnlocks && hasUnlockedFreePro
    }

    var paywallOffering: Offering? {
        if let preferred = offerings?.offering(identifier: preferredOfferingID) {
            return preferred
        }
        return offerings?.current
    }
    
    init() {
        // Initialize from local cache first for instant UI response
        self.isPro = SharedTaskManager.shared.loadIsPro()
        self.hasUnlockedFreePro = AppConfiguration.allowsTesterUnlocks && SharedTaskManager.shared.loadHasUnlockedFreePro()
        if !AppConfiguration.allowsTesterUnlocks {
            SharedTaskManager.shared.saveHasUnlockedFreePro(false)
        }
        
        // Check environment
        Task {
            await detectEnvironment()
        }

        guard isRevenueCatConfigured else {
            print("RevenueCat: Missing API key. Skipping offerings and entitlement refresh.")
            return
        }

        // Then fetch fresh status from server
        Task {
            if let info = try? await Purchases.shared.customerInfo() {
                self.customerInfo = info
                self.refreshProStatus()
            }
            
            // Sync purchases to catch App Store promo code redemptions (e.g. lifetime)
            if let syncedInfo = try? await Purchases.shared.syncPurchases() {
                self.customerInfo = syncedInfo
                self.refreshProStatus()
            }
        }

        // Start listening to customer info updates
        subscribeToCustomerInfo()

        // Initial fetch of offerings
        refreshOfferings()
    }
    
    private func detectEnvironment() async {
        var detectedSandbox = false
        
        if #available(iOS 16.0, *) {
            if let result = try? await AppTransaction.shared,
               case .verified(let appTransaction) = result {
                // .sandbox covers both Sandbox and TestFlight
                if appTransaction.environment == .sandbox {
                    detectedSandbox = true
                }
            }
        }
        
        // Fallback/Double-check for older iOS or specific sandbox cases
        if !detectedSandbox {
            if #available(iOS 18.0, *) {
                // On iOS 18+, we rely strictly on AppTransaction to avoid deprecation warnings
            } else {
                if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
                    detectedSandbox = true
                }
            }
        }
        
        #if DEBUG
        detectedSandbox = true
        #endif
        
        let finalDetected = detectedSandbox
        await MainActor.run {
            self.isSandboxMode = finalDetected
            self.refreshProStatus()
        }
        
        if finalDetected {
            print("StoreManager: Sandbox/TestFlight environment detected.")
        }
    }
    
    func unlockProForFree() {
        guard canUseTesterUnlocks else { return }
        print("StoreManager: Unlocking Pro for free (Sandbox mode).")
        self.hasUnlockedFreePro = true
        SharedTaskManager.shared.saveHasUnlockedFreePro(true)
        self.isPro = true
        SharedTaskManager.shared.save(isPro: true)
        AnalyticsManager.shared.capture("purchase_completed", properties: ["method": "sandbox_free_unlock"])
    }

    func setTestingProEnabled(_ enabled: Bool) {
        guard canUseTesterUnlocks else { return }

        hasUnlockedFreePro = enabled
        SharedTaskManager.shared.saveHasUnlockedFreePro(enabled)

        if enabled {
            print("StoreManager: Testing Pro enabled.")
            isPro = true
            SharedTaskManager.shared.save(isPro: true)
            AnalyticsManager.shared.capture("purchase_completed", properties: ["method": "testing_toggle"])
        } else {
            print("StoreManager: Testing Pro disabled.")
            refreshProStatus()
        }
    }
    
    func refreshOfferings() {
        guard isRevenueCatConfigured else {
            offerings = nil
            return
        }

        Task {
            self.lastError = nil
            do {
                let fetchedOfferings = try await Purchases.shared.offerings()
                self.offerings = fetchedOfferings
                
                if fetchedOfferings.all.isEmpty {
                    print("RevenueCat: No available offerings returned from server.")
                    self.lastError = NSError(domain: "StoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No products available in the store right now."])
                } else if fetchedOfferings.offering(identifier: self.preferredOfferingID) != nil {
                    print("RevenueCat: Using preferred offering '\(self.preferredOfferingID)'.")
                } else if let currentID = fetchedOfferings.current?.identifier {
                    print("RevenueCat: Preferred offering missing. Falling back to current offering '\(currentID)'.")
                } else {
                    print("RevenueCat: Offerings found but no 'current' or preferred offering set.")
                }
            } catch {
                print("RevenueCat: Failed to fetch offerings: \(error)")
                self.lastError = error
            }
        }
    }
    
    private func subscribeToCustomerInfo() {
        guard isRevenueCatConfigured else { return }

        // The modern way to handle state changes in RevenueCat SDK
        customerInfoTask = Task {
            for await info in Purchases.shared.customerInfoStream {
                self.customerInfo = info
                self.refreshProStatus()
            }
        }
    }

    private func refreshProStatus() {
        let proActive = resolvedProStatus(from: customerInfo)

        if proActive != self.isPro {
            print("RevenueCat: Pro status changing from \(self.isPro) to \(proActive)")
            self.isPro = proActive
            SharedTaskManager.shared.save(isPro: proActive)
            if proActive {
                AnalyticsManager.shared.capture("purchase_completed")
            }
        }
    }

    private func resolvedProStatus(from info: CustomerInfo?) -> Bool {
        var proActive = false

        guard let info else {
            if canUseTesterUnlocks && hasUnlockedFreePro {
                return true
            }
            return false
        }

        // RevenueCat entitlement keys might have trailing spaces depending on how they were entered in the dashboard
        for (key, entitlement) in info.entitlements.all {
            if key.trimmingCharacters(in: .whitespaces) == proEntitlementID.trimmingCharacters(in: .whitespaces) {
                if entitlement.isActive {
                    proActive = true
                    break
                }
            }
        }
        
        // Fallback: Check if they own the lifetime product directly in case RevenueCat entitlement mapping is missing
        let lifetimeProductID = "reswin.clock.pro.lifetimev2"
        if info.nonSubscriptions.contains(where: { $0.productIdentifier == lifetimeProductID }) {
            proActive = true
        }
        
        print("RevenueCat: Checking entitlement '\(proEntitlementID)'. Active: \(proActive)")

        if canUseTesterUnlocks && hasUnlockedFreePro {
            proActive = true
        }

        return proActive
    }
    
    func syncPurchases() async {
        guard isRevenueCatConfigured else { return }
        
        do {
            if let info = try? await Purchases.shared.customerInfo() {
                self.customerInfo = info
                self.refreshProStatus()
            }
            if let syncedInfo = try? await Purchases.shared.syncPurchases() {
                self.customerInfo = syncedInfo
                self.refreshProStatus()
            }
        }
    }
    
    func purchase(package: Package) async throws {
        guard isRevenueCatConfigured else {
            throw StoreManagerError.purchasesUnavailable
        }

        let result = try await Purchases.shared.purchase(package: package)
        customerInfo = result.customerInfo
        refreshProStatus()
    }
    
    func restore() async {
        guard isRevenueCatConfigured else {
            print("RevenueCat: Restore skipped because purchases are unavailable in this build.")
            return
        }

        do {
            let info = try await Purchases.shared.restorePurchases()
            customerInfo = info
            refreshProStatus()
            AnalyticsManager.shared.capture("purchase_restored")
        } catch {
            print("RevenueCat: Restore failed: \(error)")
        }
    }
    
    deinit {
        customerInfoTask?.cancel()
    }
}

enum StoreManagerError: LocalizedError {
    case purchasesUnavailable

    var errorDescription: String? {
        switch self {
        case .purchasesUnavailable:
            return "Purchases are unavailable in this build."
        }
    }
}
