// Supabase Edge Function: ai-chat
// Handles AI conversational queries using Google Gemini 2.5 Flash
// Deploy: supabase functions deploy ai-chat
// Set secret: supabase secrets set GEMINI_API_KEY=your_key

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { GoogleGenAI } from "npm:@google/genai";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface AIChatRequest {
  message: string;
  userId: string;
  role: "borrower" | "officer" | "manager";
  conversationId?: string; // Optional: for continuing an existing conversation
  contextData: any; // Role-specific context passed from the client
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    
    // Validate request body
    const body: AIChatRequest = await req.json();
    const { message, userId, role, contextData, conversationId } = body;

    if (!message || !userId || !role || !contextData) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: message, userId, role, contextData" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "Server configuration error: GEMINI_API_KEY not set" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    let currentConvId = conversationId;

    // 1. If no conversationId is provided, create a new session
    if (!currentConvId) {
      const { data: convData, error: convError } = await supabase
        .from("ai_conversations")
        .insert({
          user_id: userId,
          role: role,
          title: message.substring(0, 50),
        })
        .select("id")
        .single();
      
      if (convError) throw convError;
      currentConvId = convData.id;
    }

    // 2. Fetch recent conversation history (last 10 messages)
    let history: any[] = [];
    if (currentConvId) {
      const { data: historyData, error: historyError } = await supabase
        .from("ai_messages")
        .select("*")
        .eq("conversation_id", currentConvId)
        .order("created_at", { ascending: false })
        .limit(10);
        
      if (!historyError && historyData) {
        history = historyData.reverse(); // Order from oldest to newest
      }
    }

    // 3. Build System Prompt based on role
    let systemPrompt = "";
    switch (role) {
      case "borrower":
        systemPrompt = `You are a personal financial advisor for a loan management app. You have access to this user's financial data. Be helpful, clear, and avoid excessive jargon. Recommend products, explain terms, and help with EMI planning. Do not invent data that is not in the context.`;
        break;
      case "officer":
        systemPrompt = `You are an AI copilot for a loan officer at a bank. Help analyze borrower risk, draft communications, flag gaps in applications, and verify documents. Be professional, objective, and data-driven. Do not invent data that is not in the context.`;
        break;
      case "manager":
        systemPrompt = `You are an AI analytics assistant for a bank branch manager. Help analyze portfolio performance, staff metrics, NPA risks, and generate insights. Use data to support conclusions. Be strategic and professional. Do not invent data that is not in the context.`;
        break;
      default:
        systemPrompt = `You are a helpful assistant.`;
    }

    // Inject context data (e.g. loans, profile, applications)
    systemPrompt += `\n\n=== USER CONTEXT ===\n${JSON.stringify(contextData, null, 2)}\n===================`;

    // 4. Initialize Gemini API
    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY });
    
    // Prepare contents array for Gemini
    const contents = [];
    
    // Add system instruction as the first user message (a common pattern if system instructions aren't directly supported by the library version)
    contents.push({ role: "user", parts: [{ text: systemPrompt }] });
    contents.push({ role: "model", parts: [{ text: "Understood. I will follow these instructions and use the provided context." }] });
    
    // Add history
    for (const msg of history) {
      contents.push({ 
        role: msg.role === "assistant" ? "model" : "user", 
        parts: [{ text: msg.content }] 
      });
    }

    // Add current user message
    contents.push({ role: "user", parts: [{ text: message }] });

    // 5. Generate Content
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash-lite",
      contents: contents,
    });

    const reply = response.text || "I'm sorry, I couldn't generate a response.";

    // 6. Save User message to DB
    await supabase.from("ai_messages").insert({
      conversation_id: currentConvId,
      role: "user",
      content: message,
    });

    // 7. Save Assistant message to DB
    await supabase.from("ai_messages").insert({
      conversation_id: currentConvId,
      role: "assistant",
      content: reply,
    });

    // 8. Return response
    return new Response(
      JSON.stringify({
        reply: reply,
        conversationId: currentConvId,
      }),
      { 
        status: 200, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        } 
      }
    );

  } catch (err: any) {
    console.error("AI Chat Error:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal Server Error" }),
      { 
        status: 500, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        } 
      }
    );
  }
});
