//
//  ContentView.swift
//  StoreKit-NoTransactions-Example
//
//  Created by Semeniuk Slava on 29.08.2023.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var store = InAppPurchaseStore()

    var body: some View {
        ZStack(alignment: .top) {
            Color.white
            VStack(spacing: 50) {
                Text(verbatim: "Has subscription: \(store.hasActiveSubscription)")
                productsView
            }
        }
        .overlay {
            if store.isPurchasing {
                Color.blue
                    .opacity(0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        Text("Purchasing")
                    }
            }
        }
    }

    var productsView: some View {
        VStack {
            ForEach(store.subscriptions) { product in
                Button(action: {
                    Task { await store.purchase(product: product) }
                }, label: {
                    Text(product.id)
                        .foregroundColor(Color.blue)
                })
                .frame(height: 30)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
