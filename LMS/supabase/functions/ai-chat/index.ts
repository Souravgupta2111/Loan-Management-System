
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { message, userId, role, conversationId, contextData } = await req.json();

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    let reply = "";

    if (!apiKey) {
      // Fallback smart mock if no API key is provided
      const lowerMessage = message.toLowerCase();
      if (lowerMessage.includes("eligible") || lowerMessage.includes("personal loan")) {
          const score = contextData.profile.creditScore || 0;
          if (score >= 700) {
              reply = `With your excellent credit score of ${score}, you are highly likely to be eligible for a Personal Loan. Check the 'Apply' section for pre-approved offers!`;
          } else {
              reply = "You can check your eligibility by applying for a Personal Loan in the 'Apply' section. We review applications based on credit score, income, and KYC status.";
          }
      } else if (lowerMessage.includes("emi") || lowerMessage.includes("due") || lowerMessage.includes("schedule")) {
          if (contextData.activeLoans.length > 0) {
              const nextEmi = contextData.emiSchedule.find((e: any) => e.status === "due" || e.status === "upcoming");
              if (nextEmi) {
                  reply = `Your next EMI of ₹${nextEmi.emiAmount} is due on ${nextEmi.dueDate}.`;
              } else {
                  reply = "You don't have any pending EMIs at the moment. Great job!";
              }
          } else {
              reply = "You don't have any active loans with us, so there are no upcoming EMIs.";
          }
      } else if (lowerMessage.includes("credit score") || lowerMessage.includes("improve")) {
          reply = `Your current credit score is ${contextData.profile.creditScore || 'unavailable'}. To improve it, make sure to pay your EMIs on time and keep your credit utilization low.`;
      } else {
          reply = `This is a simulated offline response because the GEMINI_API_KEY secret is not set in Supabase. You asked: "${message}"`;
      }
    } else {
      // Call Gemini API
      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: `You are a helpful, professional AI Financial Advisor for a loan management app.
              Here is the user's financial context in JSON: ${JSON.stringify(contextData)}
              
              User's message: ${message}
              
              Provide a helpful, concise answer. Keep it under 3-4 sentences. Format nicely.`
            }]
          }]
        })
      });

      const data = await response.json();
      if (data.error) {
        throw new Error(data.error.message);
      }
      
      reply = data.candidates[0].content.parts[0].text;
    }

    const responseBody = {
      reply: reply,
      conversationId: conversationId || crypto.randomUUID(),
    };

    return new Response(JSON.stringify(responseBody), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    const errorBody = {
      reply: `DEBUG ERROR: ${error.message || String(error)}`,
      conversationId: crypto.randomUUID(),
    };
    return new Response(JSON.stringify(errorBody), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  }
});
