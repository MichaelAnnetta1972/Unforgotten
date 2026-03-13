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

interface RoleChangePayload {
  target_user_id: string;
  new_role: string;
  account_name: string;
  changed_by_name: string;
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

async function sendPushNotification(
  token: string,
  payload: object,
  apnsToken: string
): Promise<boolean> {
  const url = `https://${APNS_HOST}/3/device/${token}`;

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
      console.error(
        `APNs error for token ${token.substring(0, 8)}...: ${response.status} ${body}`
      );
      return false;
    }

    return true;
  } catch (error) {
    console.error(
      `Failed to send push to ${token.substring(0, 8)}...: ${error}`
    );
    return false;
  }
}

const roleDisplayNames: Record<string, string> = {
  admin: "Admin",
  helper: "Helper",
  viewer: "Viewer",
  owner: "Owner",
};

serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload: RoleChangePayload = await req.json();
    const { target_user_id, new_role, account_name, changed_by_name } = payload;

    if (!target_user_id || !new_role) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get device tokens for the target user
    const { data: tokens, error: tokensError } = await supabase.rpc(
      "get_device_tokens_for_users",
      { p_user_ids: [target_user_id] }
    );

    if (tokensError) {
      console.error("Error fetching device tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({
          message: "No device tokens found for target user",
          sent: 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const apnsToken = await generateAPNsToken();

    const roleDisplay = roleDisplayNames[new_role] || new_role;
    const apnsPayload = {
      aps: {
        alert: {
          title: "Role Updated",
          body: `${changed_by_name} changed your role to ${roleDisplay} in "${account_name}".`,
        },
        sound: "default",
        category: "ROLE_CHANGE",
        "mutable-content": 1,
      },
      new_role: new_role,
      deep_link: "unforgotten://settings",
    };

    let sentCount = 0;
    const sendPromises = tokens.map(
      async (t: { user_id: string; token: string }) => {
        const success = await sendPushNotification(
          t.token,
          apnsPayload,
          apnsToken
        );
        if (success) sentCount++;
        return success;
      }
    );

    await Promise.all(sendPromises);

    console.log(
      `Sent ${sentCount}/${tokens.length} role change notifications to user ${target_user_id.substring(0, 8)}...`
    );

    return new Response(
      JSON.stringify({
        message: "Role change notifications sent",
        sent: sentCount,
        total: tokens.length,
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
