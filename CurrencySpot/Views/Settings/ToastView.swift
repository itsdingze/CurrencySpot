//
//  ToastView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/4/25.
//

import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.title3, design: .rounded))
                .foregroundColor(.green)

            Text(message)
                .font(.system(.headline, design: .rounded))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(lineWidth: 2)
                        .fill(Color.background)
                )
        )
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ToastView(message: "123", icon: "house")
}
