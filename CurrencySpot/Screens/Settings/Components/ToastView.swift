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
        HStack(spacing: .elementGap) {
            Image(systemName: icon)
                .font(.appTitle3)
                .foregroundStyle(Color.success)

            Text(message)
                .font(.appHeadline)
        }
        .padding(.fieldPadding)
        .background(
            RoundedRectangle(cornerRadius: .cardRadius)
                .fill(Color.secondaryBackground)
                .stroke(Color.background, lineWidth: 2)
        )
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ToastView(message: "123", icon: "house")
}
