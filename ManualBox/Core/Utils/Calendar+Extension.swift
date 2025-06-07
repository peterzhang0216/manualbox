// Calendar+Extension.swift
// ManualBox
//
// Created by Peter's Mac on 2025/5/15.
//

import Foundation

extension Calendar {
    /// 计算两个日期之间的天数
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from)
        let toDate = startOfDay(for: to)
        let components = dateComponents([.day], from: fromDate, to: toDate)
        return components.day ?? 0
    }
}
