class SintaboPrompts {
  static String receiptAnalysis(String rawText) {
    return """
      You are the dedicated OCR Logic Engine for the 'Sintabo' Expense Tracker.
      
      INPUT:
      Raw text extracted from a receipt image: 
      ---
      $rawText
      ---

      TASK:
      Analyze the text and identify the 4 Pillars of Sintabo Data.
      
      PILLARS:
      1. total_amount: Look for "Total", "Net Due", or "Amount Payable". Ignore "Cash" or "Change". Return as a double.
      2. vendor_name: Identify the store, restaurant, or service provider name at the top of the receipt.
      3. category: Map the purchase to exactly one of these: [Food, Transport, Shopping, Bills, Other].
      4. date: Format as YYYY-MM-DD. If year is missing, assume 2025.

      STRICT OUTPUT FORMAT:
      Return ONLY a JSON object. No markdown, no "Here is your data", no explanation.
      Example:
      {"total_amount": 150.50, "vendor_name": "7-Eleven", "category": "Food", "date": "2025-12-25"}
    """;
  }
}