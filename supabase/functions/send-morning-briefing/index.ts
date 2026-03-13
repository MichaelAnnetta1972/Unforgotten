import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";

const APNS_KEY = Deno.env.get("APNS_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;

// Use api.sandbox.push.apple.com for development/TestFlight,
// api.push.apple.com for App Store production.
const APNS_HOST = "api.sandbox.push.apple.com";

interface BriefingRecipient {
  user_id: string;
  la_token: string;
  content_state: Record<string, unknown>;
}

async function generateAPNsToken(): Promise<string> {
  const privateKey = await jose.importPKCS8(APNS_KEY, "ES256");

  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({
      alg: "ES256",
      kid: APNS_KEY_ID,
    })
    .setIssuer(APNS_TEAM_ID)
    .setIssuedAt()
    .sign(privateKey);

  return jwt;
}

async function sendLiveActivityPush(
  laToken: string,
  contentState: Record<string, unknown>,
  apnsToken: string
): Promise<boolean> {
  const url = `https://${APNS_HOST}/3/device/${laToken}`;

  // Live Activity update push payload
  const payload = {
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event: "update",
      "content-state": contentState,
      alert: {
        title: "Good Morning",
        body: "Your daily briefing is ready.",
      },
    },
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        authorization: `bearer ${apnsToken}`,
        "apns-topic": `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        "apns-push-type": "liveactivity",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const body = await response.text();
      console.error(
        `APNs LA error for token ${laToken.substring(0, 8)}...: ${response.status} ${body}`
      );
      return false;
    }

    return true;
  } catch (error) {
    console.error(
      `Failed to send LA push to ${laToken.substring(0, 8)}...: ${error}`
    );
    return false;
  }
}

serve(async (req) => {
  try {
    // Verify authorization
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get all recipients with their LA tokens and cached briefing data
    const { data: recipients, error: rpcError } = await supabase.rpc(
      "get_morning_briefing_recipients"
    );

    if (rpcError) {
      console.error("Error fetching briefing recipients:", rpcError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch recipients" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!recipients || recipients.length === 0) {
      return new Response(
        JSON.stringify({
          message: "No recipients with briefing data for today",
          sent: 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(
      `Found ${recipients.length} recipients for morning briefing push`
    );

    // Generate APNs token
    const apnsToken = await generateAPNsToken();

    // Send to all recipients
    let sentCount = 0;
    const sendPromises = (recipients as BriefingRecipient[]).map(
      async (recipient) => {
        const success = await sendLiveActivityPush(
          recipient.la_token,
          recipient.content_state,
          apnsToken
        );
        if (success) sentCount++;
        return success;
      }
    );

    await Promise.all(sendPromises);

    console.log(
      `Sent ${sentCount}/${recipients.length} morning briefing pushes`
    );

    return new Response(
      JSON.stringify({
        message: "Morning briefing pushes sent",
        sent: sentCount,
        total: recipients.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
