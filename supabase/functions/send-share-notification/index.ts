import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";

const APNS_KEY = Deno.env.get("APNS_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;

// APNs endpoints per environment
const APNS_HOSTS: Record<string, string> = {
  sandbox: "api.sandbox.push.apple.com",
  production: "api.push.apple.com",
};

interface ShareNotificationPayload {
  event_type: "appointment" | "countdown";
  event_id: string;
  event_title: string;
  shared_by_name: string;
  member_user_ids: string[];
}

/**
 * Generate a JWT for Apple Push Notification service authentication
 */
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
 * Send a push notification to a single device via APNs HTTP/2
 */
async function sendPushNotification(
  deviceToken: string,
  payload: object,
  apnsToken: string,
  environment: string
): Promise<boolean> {
  const host = APNS_HOSTS[environment] || APNS_HOSTS.production;
  const url = `https://${host}/3/device/${deviceToken}`;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        authorization: `bearer ${apnsToken}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const body = await response.text();
      console.error(`APNs error for token ${deviceToken.substring(0, 8)}... (${environment} via ${host}): ${response.status} ${body}`);
      return false;
    }

    console.log(`APNs success for token ${deviceToken.substring(0, 8)}... (${environment} via ${host})`);
    return true;
  } catch (error) {
    console.error(`Failed to send push to ${deviceToken.substring(0, 8)}... (${environment}): ${error}`);
    return false;
  }
}

serve(async (req) => {
  try {
    // Verify the request has a valid authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload: ShareNotificationPayload = await req.json();
    const { event_type, event_id, event_title, shared_by_name, member_user_ids } = payload;

    if (!event_type || !event_id || !member_user_ids?.length) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Create a Supabase client with the service role key to bypass RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get device tokens for all target users (now includes environment)
    const { data: tokens, error: tokensError } = await supabase.rpc(
      "get_device_tokens_for_users",
      { p_user_ids: member_user_ids }
    );

    if (tokensError) {
      console.error("Error fetching device tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No device tokens found for users: ${member_user_ids.join(", ")}`);
      return new Response(
        JSON.stringify({ message: "No device tokens found for target users", sent: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${tokens.length} device token(s) for ${member_user_ids.length} user(s)`);

    // Generate APNs authentication token
    const apnsToken = await generateAPNsToken();

    // Build the notification payload
    const eventTypeDisplay = event_type === "appointment" ? "an appointment" : "a countdown";
    const apnsPayload = {
      aps: {
        alert: {
          title: "Shared with you",
          subtitle: `From ${shared_by_name}`,
          body: event_title
            ? `${shared_by_name} shared ${eventTypeDisplay} with you: "${event_title}"`
            : `${shared_by_name} shared ${eventTypeDisplay} with you`,
        },
        sound: "default",
        "category": "SHARED_ITEM",
        "mutable-content": 1,
      },
      // Custom data for deep linking
      event_type: event_type,
      event_id: event_id,
      deep_link: `unforgotten://${event_type}/${event_id}`,
    };

    // Send to all device tokens, using the correct APNs endpoint per token
    let sentCount = 0;
    const sendPromises = tokens.map(async (t: { user_id: string; token: string; environment: string }) => {
      const env = t.environment || "production";
      const success = await sendPushNotification(t.token, apnsPayload, apnsToken, env);
      if (success) sentCount++;
      return success;
    });

    await Promise.all(sendPromises);

    console.log(`Sent ${sentCount}/${tokens.length} push notifications for ${event_type} ${event_id}`);

    return new Response(
      JSON.stringify({ message: "Notifications sent", sent: sentCount, total: tokens.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
