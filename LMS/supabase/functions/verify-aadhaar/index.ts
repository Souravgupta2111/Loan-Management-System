const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: jsonHeaders });
    }

    const apiKey = Deno.env.get("KYC_API_KEY");
    const apiSecret = Deno.env.get("KYC_API_SECRET");
    const baseURL = Deno.env.get("KYC_API_BASE_URL") ?? "https://test-api.sandbox.co.in";
    if (!apiKey || !apiSecret) throw new Error("KYC provider secrets are not configured");

    const { aadhaar } = await request.json();
    if (!/^[0-9]{12}$/.test(aadhaar)) {
      return new Response(JSON.stringify({ error: "Invalid Aadhaar request" }), { status: 422, headers: jsonHeaders });
    }

    const authResponse = await fetch(`${baseURL}/authenticate`, {
      method: "POST",
      headers: { "x-api-key": apiKey, "x-api-secret": apiSecret, "x-api-version": "1.0" },
    });
    if (!authResponse.ok) throw new Error(`KYC authentication failed (${authResponse.status})`);
    const authPayload = await authResponse.json();
    const accessToken = authPayload.access_token ?? authPayload.data?.access_token;
    if (!accessToken) throw new Error("KYC provider returned no access token");

    // Using Sandbox Aadhaar API format. If the exact endpoint name differs, it will throw a readable 404 or Sandbox error.
    const verificationResponse = await fetch(`${baseURL}/kyc/aadhaar/verify`, {
      method: "POST",
      headers: {
        "authorization": accessToken,
        "x-api-key": apiKey,
        "content-type": "application/json",
        "accept": "application/json",
      },
      body: JSON.stringify({
        "@entity": "in.co.sandbox.kyc.aadhaar.verify.request",
        aadhaar_number: aadhaar,
        consent: "Y",
        reason: "Identity verification for loan customer onboarding",
      }),
    });
    const payload = await verificationResponse.json();
    if (!verificationResponse.ok) {
      return new Response(JSON.stringify({ 
        aadhaar: aadhaar,
        status: `Error: ${payload.message ?? "Aadhaar verification failed"} (${verificationResponse.status})`
      }), {
        status: 200,
        headers: jsonHeaders,
      });
    }

    const result = payload.data ?? payload;
    return new Response(JSON.stringify({
      aadhaar: result.aadhaar_number ?? aadhaar,
      status: result.status ?? "valid",
    }), { status: 200, headers: jsonHeaders });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unexpected error" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
