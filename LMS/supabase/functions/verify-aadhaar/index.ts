const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: jsonHeaders });
    }

    const apiKey = Deno.env.get("KYC_API_KEY");
    const apiSecret = Deno.env.get("KYC_API_SECRET");
    const baseURL = Deno.env.get("KYC_API_BASE_URL") ?? "https://api.sandbox.co.in";
    if (!apiKey || !apiSecret) throw new Error("KYC provider secrets are not configured");

    const body = await request.json();
    const { action, aadhaar, reference_id, otp } = body;

    // --- Step 0: Authenticate with Sandbox ---
    const authResponse = await fetch(`${baseURL}/authenticate`, {
      method: "POST",
      headers: { "x-api-key": apiKey, "x-api-secret": apiSecret, "x-api-version": "1.0" },
    });
    if (!authResponse.ok) throw new Error(`KYC authentication failed (${authResponse.status})`);
    const authPayload = await authResponse.json();
    const accessToken = authPayload.access_token ?? authPayload.data?.access_token;
    if (!accessToken) throw new Error("KYC provider returned no access token");

    const commonHeaders = {
      "authorization": accessToken,
      "x-api-key": apiKey,
      "content-type": "application/json",
      "accept": "application/json",
      "x-api-version": "1.0.0",
    };

    // --- Step 1: Generate OTP ---
    if (action === "generate_otp") {
      if (!/^[0-9]{12}$/.test(aadhaar)) {
        return new Response(JSON.stringify({ error: "Invalid Aadhaar number" }), { status: 422, headers: jsonHeaders });
      }

      const otpResponse = await fetch(`${baseURL}/kyc/aadhaar/okyc/otp`, {
        method: "POST",
        headers: commonHeaders,
        body: JSON.stringify({
          "@entity": "in.co.sandbox.kyc.aadhaar.okyc.otp.request",
          aadhaar_number: aadhaar,
          consent: "Y",
          reason: "Identity verification for loan customer onboarding",
        }),
      });
      const otpPayload = await otpResponse.json();

      if (!otpResponse.ok) {
        return new Response(JSON.stringify({
          success: false,
          error: otpPayload.message ?? `OTP generation failed (${otpResponse.status})`,
        }), { status: 200, headers: jsonHeaders });
      }

      const refId = otpPayload.data?.reference_id ?? otpPayload.reference_id;
      return new Response(JSON.stringify({
        success: true,
        reference_id: refId ? String(refId) : undefined,
        message: "OTP sent to Aadhaar-linked mobile number",
      }), { status: 200, headers: jsonHeaders });
    }

    // --- Step 2: Verify OTP ---
    if (action === "verify_otp") {
      if (!reference_id || !otp) {
        return new Response(JSON.stringify({ error: "reference_id and otp are required" }), { status: 422, headers: jsonHeaders });
      }

      const verifyResponse = await fetch(`${baseURL}/kyc/aadhaar/okyc/otp/verify`, {
        method: "POST",
        headers: commonHeaders,
        body: JSON.stringify({
          "@entity": "in.co.sandbox.kyc.aadhaar.okyc.request",
          reference_id: String(reference_id),
          otp: otp,
        }),
      });
      const verifyPayload = await verifyResponse.json();

      if (!verifyResponse.ok) {
        return new Response(JSON.stringify({
          success: false,
          error: verifyPayload.message ?? `OTP verification failed (${verifyResponse.status})`,
        }), { status: 200, headers: jsonHeaders });
      }

      const result = verifyPayload.data ?? verifyPayload;
      if (result.message) {
        return new Response(JSON.stringify({
          success: false,
          error: result.message,
        }), { status: 200, headers: jsonHeaders });
      }

      return new Response(JSON.stringify({
        success: true,
        status: "valid",
        name: result.name ?? result.full_name ?? "",
        aadhaar_last_four: result.aadhaar_number ?? "",
      }), { status: 200, headers: jsonHeaders });
    }

    return new Response(JSON.stringify({ error: "Invalid action. Use 'generate_otp' or 'verify_otp'" }), {
      status: 422,
      headers: jsonHeaders,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unexpected error" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
