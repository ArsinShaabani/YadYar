//
//  NormalizerTests.swift
//  YadYarTests
//

import XCTest
@testable import YadYar

final class NormalizerTests: XCTestCase {

    func testPersianDigitsConverted() {
        XCTAssertEqual(PersianTextNormalizer.normalize("۱۴۰۳/۰۸/۱۵"), "1403/08/15")
        XCTAssertEqual(PersianTextNormalizer.normalize("٠٩١٢"), "0912")
    }

    func testZWNJReplacedBySpace() {
        XCTAssertEqual(PersianTextNormalizer.normalize("سه‌شنبه"), "سه شنبه")
        XCTAssertEqual(PersianTextNormalizer.normalize("پس‌فردا"), "پس فردا")
    }

    func testArabicLettersUnified() {
        XCTAssertEqual(PersianTextNormalizer.normalize("كتاب"), "کتاب")
        XCTAssertEqual(PersianTextNormalizer.normalize("رفيق"), "رفیق")
    }

    func testArabicDecimalSeparator() {
        XCTAssertEqual(PersianTextNormalizer.normalize("۵٫۳۰"), "5.30")
    }

    func testWhitespaceCollapsed() {
        XCTAssertEqual(PersianTextNormalizer.normalize("  قرار   ما   فردا  "), "قرار ما فردا")
    }
}
