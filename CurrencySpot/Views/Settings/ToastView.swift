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
                .foregroundStyle(.green)

            Text(message)
                .font(.system(.headline, design: .rounded))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondaryBackground)
                .stroke(Color.background, lineWidth: 2)
        )
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ToastView(message: "123", icon: "house")
}
