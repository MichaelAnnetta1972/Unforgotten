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

interface ContentState {
  medicationCount: number;
  appointments: { title: string; time: string }[];
  birthdays: string[];
  countdowns: { title: string; typeName: string }[];
  taskCount: number;
  lastUpdated: string;
}

interface BriefingRecipient {
  user_id: string;
  push_to_start_token: string;
  content_state: ContentState;
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

/**
 * Send a push-to-start Live Activity notification via APNs.
 * This creates a NEW Live Activity on the user's device remotely.
 * Uses "event": "start" with attributes-type, attributes, and content-state.
 */
async function sendPushToStartNotification(
  pushToStartToken: string,
  contentState: ContentState,
  apnsToken: string
): Promise<boolean> {
  const url = `https://${APNS_HOST}/3/device/${pushToStartToken}`;

  // Ensure lastUpdated is set for the content state
  const now = new Date().toISOString();
  const stateWithTimestamp: ContentState = {
    ...contentState,
    lastUpdated: contentState.lastUpdated || now,
  };

  // Push-to-start payload format for Live Activities
  const payload = {
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event: "start",
      "content-state": stateWithTimestamp,
      "attributes-type": "DailySummaryAttributes",
      attributes: {
        date: now,
      },
      alert: {
        title: "Good Morning ☀️",
        body: "Your daily overview is ready.",
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

    const apnsId = response.headers.get("apns-id");
    const body = await response.text();

    if (!response.ok) {
      console.error(
        `APNs error for token ${pushToStartToken.substring(0, 8)}...: status=${response.status} apns-id=${apnsId} body=${body}`
      );
      return false;
    }

    console.log(
      `APNs accepted token ${pushToStartToken.substring(0, 8)}...: status=${response.status} apns-id=${apnsId} body=${body || "(empty)"}`
    );
    return true;
  } catch (error) {
    console.error(
      `Failed to send push-to-start to ${pushToStartToken.substring(0, 8)}...: ${error}`
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

    // Get all recipients with their push-to-start tokens and cached briefing data
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
      `Found ${recipients.length} recipients for morning briefing push-to-start`
    );

    // Generate APNs token
    const apnsToken = await generateAPNsToken();

    // Send push-to-start to all recipients
    let sentCount = 0;
    const sendPromises = (recipients as BriefingRecipient[]).map(
      async (recipient) => {
        const success = await sendPushToStartNotification(
          recipient.push_to_start_token,
          recipient.content_state,
          apnsToken
        );
        if (success) sentCount++;
        return success;
      }
    );

    await Promise.all(sendPromises);

    console.log(
      `Sent ${sentCount}/${recipients.length} morning briefing push-to-start notifications`
    );

    return new Response(
      JSON.stringify({
        message: "Morning briefing push-to-start notifications sent",
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
