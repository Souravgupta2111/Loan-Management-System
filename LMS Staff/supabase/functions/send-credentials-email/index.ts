// Supabase Edge Function: send-credentials-email
// Sends staff credentials via email using Gmail SMTP and Nodemailer
// Deploy: supabase functions deploy send-credentials-email
// Set secrets: supabase secrets set GMAIL_USER=your_email@gmail.com GMAIL_APP_PASSWORD=your_app_password

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import nodemailer from "npm:nodemailer";

const GMAIL_USER = Deno.env.get("GMAIL_USER") ?? "";
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD") ?? "";

interface CredentialEmailRequest {
  to_email: string;
  employee_name: string;
  employee_id: string;
  password: string;
  is_reset: boolean; // true = password reset, false = new account
  admin_name?: string;
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
    const body: CredentialEmailRequest = await req.json();
    const { to_email, employee_name, employee_id, password, is_reset, admin_name } = body;

    if (!to_email || !employee_id || !password) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to_email, employee_id, password" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
       console.error("Missing GMAIL_USER or GMAIL_APP_PASSWORD environment variables");
       return new Response(
         JSON.stringify({ error: "Server email configuration is missing" }),
         { status: 500, headers: { "Content-Type": "application/json" } }
       );
    }

    const subject = is_reset
      ? `LMS Staff — Your Password Has Been Reset`
      : `LMS Staff — Welcome! Your Login Credentials`;

    const htmlBody = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
          .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #1a237e, #283593); padding: 30px; text-align: center; }
          .header h1 { color: white; margin: 0; font-size: 22px; }
          .header p { color: rgba(255,255,255,0.8); margin: 8px 0 0; font-size: 14px; }
          .body { padding: 30px; }
          .greeting { font-size: 16px; color: #333; margin-bottom: 16px; }
          .cred-box { background: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; margin: 20px 0; }
          .cred-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }
          .cred-row:last-child { border-bottom: none; }
          .cred-label { color: #666; font-size: 13px; font-weight: 600; }
          .cred-value { color: #1a237e; font-size: 14px; font-weight: 700; font-family: monospace; }
          .warning { background: #fff3e0; border-left: 4px solid #ff9800; padding: 12px 16px; border-radius: 4px; margin: 16px 0; font-size: 13px; color: #e65100; }
          .footer { padding: 20px 30px; background: #fafafa; text-align: center; font-size: 12px; color: #999; border-top: 1px solid #eee; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🏦 LMS Staff Portal</h1>
            <p>${is_reset ? "Password Reset Notification" : "New Account Created"}</p>
          </div>
          <div class="body">
            <p class="greeting">Dear ${employee_name},</p>
            <p style="color:#555; font-size:14px;">
              ${is_reset
                ? `Your LMS Staff Portal password has been reset by ${admin_name || "the system administrator"}. Please use the credentials below to log in.`
                : `A new LMS Staff Portal account has been created for you by ${admin_name || "the system administrator"}. Please use the credentials below to log in for the first time.`
              }
            </p>
            <div class="cred-box">
              <div class="cred-row">
                <span class="cred-label">Employee ID</span>
                <span class="cred-value">${employee_id}</span>
              </div>
              <div class="cred-row">
                <span class="cred-label">Password</span>
                <span class="cred-value">${password}</span>
              </div>
            </div>
            <div class="warning">
              ⚠️ <strong>Security Notice:</strong> Please change your password after your first login. Do not share these credentials with anyone.
            </div>
            <p style="color:#555; font-size:13px; margin-top:20px;">
              If you did not expect this email, please contact your branch administrator immediately.
            </p>
          </div>
          <div class="footer">
            This is an automated message from LMS Staff Portal. Do not reply to this email.
          </div>
        </div>
      </body>
      </html>
    `;

    // Configure Nodemailer for Gmail SMTP
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: GMAIL_USER,
        pass: GMAIL_APP_PASSWORD
      }
    });

    const info = await transporter.sendMail({
      from: `"LMS Staff Portal" <${GMAIL_USER}>`,
      to: to_email,
      subject: subject,
      html: htmlBody,
    });

    return new Response(
      JSON.stringify({ success: true, message_id: info.messageId }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
