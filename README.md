Sintabo is a personal finance management application developed with Flutter. It streamlines the process of tracking expenses by utilizing on-device text recognition and cloud-based artificial intelligence to automate data entry from physical receipts.
Core Technologies
Optical Character Recognition (OCR)
The application utilizes the Google ML Kit Text Recognition SDK for its initial data processing layer. When a user captures an image of a receipt, the OCR engine performs a local scan on the device to identify raw text strings, coordinate blocks, and character sequences. This on-device processing ensures high speed and reduces the amount of data transmitted to the cloud, as only the extracted text is sent for further analysis rather than the entire high-resolution image.
Small Language Model (SLM) Integration
Once the raw text is captured, Sintabo employs a Small Language Model (Llama 3.3 70B) hosted on the Groq Cloud platform. This layer acts as the intelligence of the application. Raw OCR data is often disorganized and contains noise such as store headers, tax breakdowns, and transaction footers. The SLM is instructed via a specialized prompt to parse this unstructured text and return a structured JSON object containing four specific data points:
• Total Amount: The final balance due.
• Vendor Name: The identified commercial establishment.
• Category: A classification based on vendor type (e.g., Food, Transport, or Bills).
• Date: The transaction date normalized to a standard format.
Installation Guide
To set up the development environment or install a debug version of the application, follow these specific instructions:
Prerequisites
• Flutter SDK: Version 3.10.4 or higher.
• Git: For version control and cloning.
• Groq API Key: An active key from the Groq Cloud Console.
• Supabase Project: An active instance for database management.
Setup Steps
1. Clone the Repository:
Execute git clone [repository_url] in your terminal.
2. Install Dependencies:
Navigate to the project root and run flutter pub get to install packages including http, supabase_flutter, and google_mlkit_text_recognition.
3. Environment Configuration:
Create a file named .env in the root directory. Add your credentials in the format:
• SUPABASE_URL=[Your_URL]
• SUPABASE_ANON_KEY=[Your_Key]
• GROQ_API_KEY=[Your_Key]
4. Hardware Connection:
Connect a physical Android or iOS device. Ensure USB debugging is enabled, as the OCR functions require a physical camera.
5. Build and Run:
Execute flutter build apk --debug to generate a debug APK file.
Future Improvements
The project roadmap focuses on data synchronization, reliability, and advanced user features:
• Database Persistence: Implementing an automated save trigger that synchronizes validated OCR results directly into the Supabase PostgreSQL database.
• Advanced Analytics: Developing interactive spending charts and monthly comparison reports based on historical data stored in the cloud.
• Local Caching: Adding offline support to allow users to scan receipts without an active internet connection, queuing them for AI analysis once connectivity is restored.
• Review Interface: Enhancing the manual review step to highlight auto-filled fields, allowing users to verify AI accuracy before final submission.
