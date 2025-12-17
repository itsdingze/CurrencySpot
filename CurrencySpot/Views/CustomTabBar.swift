//
//  CustomTabBar.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/6/25.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation

    private let tabBarHeight: CGFloat = 30
    private let indicatorWidth: CGFloat = 50
    private let indicatorHeight: CGFloat = 2
    private let buttonSpacing: CGFloat = 6

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(TabItem.allCases.enumerated()), id: \.element) { index, tab in
                tabButton(for: tab, at: index)
            }
        }
        .frame(height: tabBarHeight)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
        .accessibilityHint("Navigation between app sections")
    }

    // MARK: - Private Views

    @ViewBuilder
    private func tabButton(for tab: TabItem, at index: Int) -> some View {
        let isSelected = selectedTab == index

        Button(action: { selectTab(at: index) }) {
            VStack(spacing: buttonSpacing) {
                tabLabel(for: tab, isSelected: isSelected)
                tabIndicator(isSelected: isSelected)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityHint(tab.accessibilityHint)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityInputLabels(tab.accessibilityInputLabels)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func tabLabel(for tab: TabItem, isSelected: Bool) -> some View {
        Label {
            Text(tab.title)
                .fontWeight(.regular)
        } icon: {
            Image(systemName: tab.icon)
        }
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(isSelected ? Color.accentColor : .gray)
    }

    @ViewBuilder
    private func tabIndicator(isSelected: Bool) -> some View {
        Capsule()
            .fill(isSelected ? Color.accentColor : Color.clear)
            .frame(width: indicatorWidth, height: indicatorHeight)
            .matchedGeometryEffect(id: "ACTIVETAB", in: animation, isSource: isSelected)
    }

    // MARK: - Private Methods

    private func selectTab(at index: Int) {
        withAnimation(.smooth) {
            selectedTab = index
        }
    }
}

private enum TabItem: String, CaseIterable, Identifiable {
    case convert
    case history
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .convert:
            "arrow.left.arrow.right"
        case .history:
            "chart.line.uptrend.xyaxis"
        case .settings:
            "gearshape"
        }
    }

    var title: String {
        rawValue.capitalized
    }

    var accessibilityLabel: String {
        switch self {
        case .convert:
            "Currency Converter"
        case .history:
            "Exchange Rate History"
        case .settings:
            "Settings and Preferences"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .convert:
            "Switch to currency conversion screen"
        case .history:
            "Switch to historical exchange rate charts"
        case .settings:
            "Switch to app settings and preferences"
        }
    }

    var accessibilityInputLabels: [String] {
        switch self {
        case .convert:
            ["Convert", "Calculator", "Exchange", "Converter"]
        case .history:
            ["History", "Charts", "Trends", "Historical data"]
        case .settings:
            ["Settings", "Preferences", "Configuration", "Options"]
        }
    }
}
