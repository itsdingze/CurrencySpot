//
//  DateRange.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import Foundation

/// A closed start/end date interval used for historical data queries.
struct DateRange: Sendable {
    let start: Date
    let end: Date
}
