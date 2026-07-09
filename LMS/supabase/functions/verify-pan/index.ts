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

    const { pan, name, dateOfBirth } = await request.json();
    if (!/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(pan) || typeof name !== "string" || typeof dateOfBirth !== "string") {
      return new Response(JSON.stringify({ error: "Invalid PAN request" }), { status: 422, headers: jsonHeaders });
    }

    const authResponse = await fetch(`${baseURL}/authenticate`, {
      method: "POST",
      headers: { "x-api-key": apiKey, "x-api-secret": apiSecret, "x-api-version": "1.0" },
    });
    if (!authResponse.ok) {
      const errorText = await authResponse.text();
      return new Response(JSON.stringify({
        pan: pan,
        status: `Auth Error (${authResponse.status}): ${errorText}`,
        name_as_per_pan_match: false,
        date_of_birth_match: false
      }), { status: 200, headers: jsonHeaders });
    }
    const authPayload = await authResponse.json();
    const accessToken = authPayload.access_token ?? authPayload.data?.access_token;
    if (!accessToken) throw new Error("KYC provider returned no access token");

    const verificationResponse = await fetch(`${baseURL}/kyc/pan/verify`, {
      method: "POST",
      headers: {
        "authorization": accessToken,
        "x-api-key": apiKey,
        "content-type": "application/json",
        "accept": "application/json",
      },
      body: JSON.stringify({
        "@entity": "in.co.sandbox.kyc.pan_verification.request",
        pan,
        name_as_per_pan: name,
        date_of_birth: dateOfBirth,
        consent: "Y",
        reason: "Identity verification for loan customer onboarding",
      }),
    });
    const payload = await verificationResponse.json();
    if (!verificationResponse.ok) {
      return new Response(JSON.stringify({ 
        pan: pan,
        status: `Error: ${payload.message ?? "PAN verification failed"} (${verificationResponse.status})`,
        name_as_per_pan_match: false,
        date_of_birth_match: false
      }), {
        status: 200,
        headers: jsonHeaders,
      });
    }

    const result = payload.data ?? payload;
    return new Response(JSON.stringify({
      pan: result.pan ?? pan,
      status: result.status ?? "invalid",
      name_as_per_pan_match: result.name_as_per_pan_match === true,
      date_of_birth_match: result.date_of_birth_match === true,
    }), { status: 200, headers: jsonHeaders });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unexpected error" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
