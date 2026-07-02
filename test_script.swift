import Foundation

let jsonString = """
{"fips":[{"accounts":[{"data":{"account":{"transactions":{"transaction":[{"amount":"36874.16","currentBalance":"243718.37","mode":"CASH","narration":"CASH/DE/335677214757/Riya Dube/UTJG/27324618","reference":"196599096","transactionTimestamp":"2026-02-08T03:31:09+00:00","txnId":"QLRJ11159840311526","type":"DEBIT","valueDate":"2026-02-09"},{"amount":"32108.96","currentBalance":"161053.4","mode":"CARD","narration":"CARD/DE/657861193351/Mahika Apte/XPBO/30993804","reference":"656828516","transactionTimestamp":"2026-06-08T10:13:19+00:00","txnId":"FWSE19310875650772","type":"DEBIT","valueDate":"2026-06-09"},{"amount":"34931.66","currentBalance":"98587.75","mode":"CARD","narration":"CARD/CR/595818406768/Darshit Toor/LRJU/79935340","reference":"820908379","transactionTimestamp":"2026-04-13T13:19:00+00:00","txnId":"XAZS25964454169763","type":"CREDIT","valueDate":"2026-04-14"},{"amount":"19313.94","currentBalance":"81730.23","mode":"CASH","narration":"CASH/CR/665997315487/Yuvaan Tella/HXHA/80000002","reference":"203019216","transactionTimestamp":"2026-04-12T19:40:22+00:00","txnId":"BCHV23316460916188","type":"CREDIT","valueDate":"2026-04-13"},{"amount":"44463.81","currentBalance":"134309.53","mode":"CASH","narration":"CASH/CR/569000024954/Kashvi Ravi/QRHD/94438482","reference":"095446777","transactionTimestamp":"2026-02-15T15:31:43+00:00","txnId":"LSMW12547245675684","type":"CREDIT","valueDate":"2026-02-16"},{"amount":"4830.3","currentBalance":"337420.67","mode":"CASH","narration":"CASH/CR/362080112880/Divit Ghose/TBFZ/71628378","reference":"194015733","transactionTimestamp":"2025-08-20T13:58:54+00:00","txnId":"ZHBD18806212317476","type":"CREDIT","valueDate":"2025-08-21"}]}}}}}],"status":"COMPLETED"}
"""

struct TransactionEntry: Decodable {
    let txnId: String?
    let type: String?         // "CREDIT" or "DEBIT"
    let mode: String?         // "UPI", "NEFT", "SALARY", etc.
    let amount: String?
    let currentBalance: String?
    let transactionTimestamp: String?
    let valueDate: String?
    let narration: String?
    let reference: String?
}

struct AccountData: Decodable {
    let transactions: TransactionsWrapper?
}

struct TransactionsWrapper: Decodable {
    let transaction: [TransactionEntry]?
}

struct DecryptedFI: Decodable {
    let account: AccountData?
}

struct DataItem: Decodable {
    let decryptedFI: DecryptedFI?
    
    // Custom decoding to map `account` properly since the provided JSON has `data` -> `account` directly without `decryptedFI`
    // Actually the JSON the user pasted doesn't have `decryptedFI`... Let's look at SetuAAService.swift again.
}
