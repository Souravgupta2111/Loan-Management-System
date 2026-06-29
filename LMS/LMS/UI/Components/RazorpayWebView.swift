import SwiftUI
import WebKit

struct RazorpayWebView: UIViewRepresentable {
    let keyId: String
    let amountPaise: Int
    let orderId: String
    
    let onSuccess: (String, String, String) -> Void // paymentId, orderId, signature
    let onFailure: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "razorpay")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    background-color: #0E1614;
                    color: #ffffff;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                }
                .loader {
                    border: 3px solid #1A2E2A;
                    border-top: 3px solid #2ECC71;
                    border-radius: 50%;
                    width: 32px;
                    height: 32px;
                    animation: spin 1s linear infinite;
                }
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
            </style>
        </head>
        <body>
            <div class="loader"></div>
            <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
            <script>
                var options = {
                    "key": "\(keyId)",
                    "amount": \(amountPaise),
                    "currency": "INR",
                    "name": "LMS Repayment",
                    "description": "EMI Repayment Payment",
                    "order_id": "\(orderId)",
                    "handler": function (response){
                        window.webkit.messageHandlers.razorpay.postMessage({
                            status: 'success',
                            razorpay_payment_id: response.razorpay_payment_id,
                            razorpay_order_id: response.razorpay_order_id,
                            razorpay_signature: response.razorpay_signature
                        });
                    },
                    "theme": {
                        "color": "#1C3C34"
                    },
                    "modal": {
                        "ondismiss": function() {
                            window.webkit.messageHandlers.razorpay.postMessage({
                                status: 'cancelled'
                            });
                        }
                    }
                };
                
                var rzp = new Razorpay(options);
                
                rzp.on('payment.failed', function (response){
                    window.webkit.messageHandlers.razorpay.postMessage({
                        status: 'failed',
                        error_description: response.error.description || 'Payment Failed'
                    });
                });
                
                window.onload = function() {
                    rzp.open();
                };
            </script>
        </body>
        </html>
        """
        
        // Base URL must be a valid https origin for checkout.js to open properly
        webView.loadHTMLString(html, baseURL: URL(string: "https://api.razorpay.com"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        var parent: RazorpayWebView

        init(_ parent: RazorpayWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "razorpay",
                  let body = message.body as? [String: Any],
                  let status = body["status"] as? String else {
                return
            }

            switch status {
            case "success":
                let paymentId = body["razorpay_payment_id"] as? String ?? ""
                let orderId = body["razorpay_order_id"] as? String ?? ""
                let signature = body["razorpay_signature"] as? String ?? ""
                parent.onSuccess(paymentId, orderId, signature)
                
            case "failed":
                let desc = body["error_description"] as? String ?? "Payment failed"
                parent.onFailure(desc)
                
            case "cancelled":
                parent.onCancel()
                
            default:
                break
            }
        }
    }
}
